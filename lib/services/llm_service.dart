import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/meso_import_data.dart';
import 'csv_segmenter.dart';
import 'model_service.dart';
import 'target_math.dart';

class RawExtractedExercise {
  final String name;
  final String group;
  final String sets;
  final String reps;
  final String rpe;

  const RawExtractedExercise({
    required this.name,
    required this.group,
    required this.sets,
    required this.reps,
    required this.rpe,
  });

  factory RawExtractedExercise.fromJson(Map<String, dynamic> json) {
    return RawExtractedExercise(
      name: (json['name'] as String?) ?? 'Unknown',
      group: (json['group'] as String?) ?? 'other',
      sets: (json['sets'] as String?) ?? '3',
      reps: (json['reps'] as String?) ?? '8',
      rpe: (json['rpe'] as String?) ?? '',
    );
  }
}

class RawExtractedDay {
  final String label;
  final List<RawExtractedExercise> exercises;

  const RawExtractedDay({required this.label, required this.exercises});

  factory RawExtractedDay.fromJson(Map<String, dynamic> json) {
    return RawExtractedDay(
      label: (json['label'] as String?) ?? '',
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => RawExtractedExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LlmService {
  static const String defaultUrl = 'http://10.0.2.2:1234/v1/chat/completions';

  Future<MesoImportData> interpretPlan(
    String csvContent, {
    String? apiUrl,
    void Function(int done, int total)? onProgress,
  }) async {
    await WakelockPlus.enable();
    try {
      if (apiUrl != null) {
        return await _runExternalApi(csvContent, apiUrl, onProgress);
      }
      return await _runLocalInterpretation(csvContent, onProgress);
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<MesoImportData> interpretDescription(
    String description,
    int numWeeks, {
    required String apiUrl,
    void Function(int done, int total)? onProgress,
  }) async {
    await WakelockPlus.enable();
    try {
      final outlineText = await _chat(apiUrl, _outlineInstructions(description, numWeeks));
      final outlineJson = _extractFirstJson(outlineText);
      final programName = (outlineJson['name'] as String?)?.trim().isNotEmpty == true
          ? outlineJson['name'] as String
          : 'Generated Program';
      final dayLabels = (outlineJson['days'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();

      if (dayLabels.isEmpty) {
        throw LlmException('No training days in LLM outline.', rawResponse: outlineText);
      }

      final days = <ImportDay>[];
      final skipped = <String>[];

      for (int i = 0; i < dayLabels.length; i++) {
        onProgress?.call(i + 1, dayLabels.length);
        final label = dayLabels[i];
        try {
          final text = await _chat(apiUrl, _dayGenInstructions(description, label, numWeeks));
          final obj = _extractFirstJson(text);
          obj['dayIdx'] = i;
          if ((obj['label'] as String?)?.isEmpty ?? true) obj['label'] = label;
          days.add(ImportDay.fromJson(obj));
        } on LlmException {
          skipped.add(label);
        }
      }

      return MesoImportData(
        name: programName,
        numWeeks: numWeeks,
        days: days,
        skippedDayLabels: skipped,
      );
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<MesoImportData> _runLocalInterpretation(
    String csvContent,
    void Function(int done, int total)? onProgress,
  ) async {
    final path = await ModelService.modelPath();

    final modelParams = ModelParams(path: path, gpuLayers: 15);
    const ctxParams = ContextParams(nCtx: 16384, nBatch: 256, nUbatch: 256);

    LlamaEngine? engine;
    try {
      try {
        engine = Platform.isIOS
            ? await LlamaEngine.spawnFromProcess(
                modelParams: modelParams,
                contextParams: ctxParams,
              )
            : await LlamaEngine.spawn(
                libraryPath: 'libllama.so',
                modelParams: modelParams,
                contextParams: ctxParams,
              );
      } on Exception catch (e) {
        final msg = e.toString();
        if (msg.contains('libllama') ||
            msg.contains('dlopen') ||
            msg.contains('LlamaLibrary')) {
          final hint = Platform.isIOS
              ? 'llama.xcframework not embedded in Runner target.'
              : Platform.isAndroid
                  ? 'llama-cpp-dart .aar missing from android/app/libs/.'
                  : 'libllama shared library not found.';
          throw LlmException('LLM native library failed to load. $hint\n$msg');
        }
        rethrow;
      }

      final segments = CsvSegmenter.segment(csvContent);
      final results = <(int, int, RawExtractedDay)>[];
      final skipped = <String>[];

      for (int i = 0; i < segments.length; i++) {
        final seg = segments[i];
        onProgress?.call(i + 1, segments.length);
        try {
          final session = await engine.createSession();
          final buffer = StringBuffer();

          await for (final ev in session.generate(
            prompt: _buildChunkPrompt(seg.csvLines),
            addSpecial: true,
            parseSpecial: true,
            sampler: const SamplerParams(temperature: 0.0),
            maxTokens: 1024,
          )) {
            switch (ev) {
              case TokenEvent():
                buffer.write(ev.text);
              case DoneEvent():
                if (ev.trailingText.isNotEmpty) buffer.write(ev.trailingText);
              case ShiftEvent():
                break;
            }
          }

          await session.dispose();
          results.add((seg.weekIdx, seg.dayIdx, _parseDay(buffer.toString())));
        } on LlmException {
          skipped.add(seg.label.isEmpty ? 'Day ${seg.dayIdx + 1}' : seg.label);
        }
      }

      return _merge(results, skipped);
    } finally {
      await engine?.dispose();
    }
  }

  Future<MesoImportData> _runExternalApi(
    String csvContent,
    String url,
    void Function(int done, int total)? onProgress,
  ) async {
    final segments = CsvSegmenter.segment(csvContent);
    final results = <(int, int, RawExtractedDay)>[];
    final skipped = <String>[];

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      onProgress?.call(i + 1, segments.length);
      try {
        final text = await _chat(url, _chunkInstructions(seg.csvLines));
        results.add((seg.weekIdx, seg.dayIdx, _parseDay(text)));
      } on LlmException {
        skipped.add(seg.label.isEmpty ? 'Day ${seg.dayIdx + 1}' : seg.label);
      }
    }

    return _merge(results, skipped);
  }

  Future<String> _chat(String url, String prompt) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'local-model',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.0,
      }),
    );
    if (response.statusCode != 200) {
      throw LlmException('API failed: ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['choices'][0]['message']['content'] as String;
  }

  Map<String, dynamic> _extractFirstJson(String raw) {
    var text = raw;
    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fenceMatch != null) text = fenceMatch.group(1)!.trim();
    final objects = splitJsonObjects(text);
    if (objects.isEmpty) {
      throw LlmException('No JSON object in response', rawResponse: raw);
    }
    return objects.first;
  }

  MesoImportData _merge(
    List<(int, int, RawExtractedDay)> results,
    List<String> skipped,
  ) {
    // Group by dayIdx → weekIdx → RawExtractedDay
    final byDay = <int, Map<int, RawExtractedDay>>{};
    int maxWeek = 0;
    for (final (weekIdx, dayIdx, day) in results) {
      byDay.putIfAbsent(dayIdx, () => {})[weekIdx] = day;
      if (weekIdx > maxWeek) maxWeek = weekIdx;
    }

    final days = <ImportDay>[];
    for (final dayIdx in byDay.keys.toList()..sort()) {
      final weekMap = byDay[dayIdx]!;
      final firstDay = weekMap.values.first;
      final label = firstDay.label.isEmpty ? 'Day ${dayIdx + 1}' : firstDay.label;

      final nExercises =
          weekMap.values.map((d) => d.exercises.length).fold(0, (a, b) => a > b ? a : b);

      final exercises = <ImportExercise>[];
      for (int pos = 0; pos < nExercises; pos++) {
        final weekRaw = <({int weekIdx, String sets, String reps, String rpe})>[];
        String exName = 'Unknown';
        String exGroup = 'other';

        for (final weekIdx in weekMap.keys.toList()..sort()) {
          final exList = weekMap[weekIdx]!.exercises;
          if (pos < exList.length) {
            final ex = exList[pos];
            if (exName == 'Unknown') {
              exName = ex.name;
              exGroup = ex.group;
            }
            weekRaw.add((weekIdx: weekIdx, sets: ex.sets, reps: ex.reps, rpe: ex.rpe));
          }
        }

        if (weekRaw.isEmpty) continue;

        exercises.add(ImportExercise(
          name: exName,
          muscleGroup: exGroup,
          weekTargets: TargetMath.buildWeekTargets(weekRaw),
        ));
      }

      days.add(ImportDay(dayIdx: dayIdx, label: label, exercises: exercises));
    }

    return MesoImportData(
      name: 'Imported Block',
      numWeeks: maxWeek + 1,
      days: days,
      skippedDayLabels: skipped,
    );
  }

  String _buildChunkPrompt(String csvLines) =>
      '<bos><|turn>user\n${_chunkInstructions(csvLines)}<turn|>\n<|turn>model\n';

  String _chunkInstructions(String csvLines) =>
      '''You are a workout parser. Extract the exercises from this single training day CSV.
Copy reps, sets, and RPE cell values verbatim as strings. Do not do math.
Respond with JSON only, no markdown.

SCHEMA:
{"label":"<day label>","exercises":[{"name":"<exercise name>","group":"chest|back|shoulders|arms|legs|core|other","sets":"<raw>","reps":"<raw>","rpe":"<raw>"}]}

CSV:
$csvLines''';

  String _outlineInstructions(String description, int numWeeks) =>
      '''You are a strength training program designer. The user wants a $numWeeks-week program.

Read the description and output a JSON outline with the program name and an ordered list of distinct training day labels (do not repeat for each week — list each unique day type once).
Respond with JSON only, no markdown.

SCHEMA:
{"name":"<program name>","days":["<Day 1 label>","<Day 2 label>",...]}

DESCRIPTION:
$description''';

  String _dayGenInstructions(String description, String dayLabel, int numWeeks) =>
      '''You are a strength training program designer. Generate the "$dayLabel" training day for a $numWeeks-week mesocycle.

For each exercise include a weekTargets array with one entry per week (weekIdx 0 to ${numWeeks - 1}). Apply progressive overload: increase reps or decrease RIR across weeks. Use 3-5 exercises.
Respond with JSON only, no markdown.

SCHEMA:
{"label":"$dayLabel","exercises":[{"name":"<exercise name>","group":"chest|back|shoulders|arms|legs|core|other","weekTargets":[{"weekIdx":0,"reps":[8,8,8],"rir":[3,3,3]},{"weekIdx":1,"reps":[9,9,9],"rir":[2,2,2]},...]}]}

reps and rir arrays must have the same length as the number of sets for that exercise. Include all $numWeeks weekTargets for every exercise.

PROGRAM DESCRIPTION:
$description''';

  RawExtractedDay _parseDay(String raw) {
    var text = raw;

    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fenceMatch != null) text = fenceMatch.group(1)!.trim();

    final objects = splitJsonObjects(text);
    if (objects.isEmpty) {
      throw LlmException('No JSON object in response', rawResponse: raw);
    }

    // Merge all objects into one day (model may emit one object per CSV row).
    String label = '';
    final exercises = <RawExtractedExercise>[];
    for (final obj in objects) {
      final day = RawExtractedDay.fromJson(obj);
      if (label.isEmpty && day.label.isNotEmpty) label = day.label;
      exercises.addAll(day.exercises);
    }
    return RawExtractedDay(label: label, exercises: exercises);
  }

  static List<Map<String, dynamic>> splitJsonObjects(String text) {
    final results = <Map<String, dynamic>>[];
    int depth = 0;
    int start = -1;
    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0 && start != -1) {
        final chunk = text.substring(start, i + 1).replaceAllMapped(
            RegExp(r',\s*([\]}])'), (m) => m.group(1)!);
          try {
            results.add(jsonDecode(chunk) as Map<String, dynamic>);
          } on FormatException {
            // skip malformed object
          }
          start = -1;
        }
      }
    }
    return results;
  }
}

class LlmException implements Exception {
  final String message;
  final String? rawResponse;
  LlmException(this.message, {this.rawResponse});

  @override
  String toString() => message;
}

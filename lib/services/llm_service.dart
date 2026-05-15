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
    String experienceLevel = 'intermediate',
    void Function(int done, int total)? onProgress,
    void Function(String reasoningDelta)? onReasoning,
  }) async {
    await WakelockPlus.enable();
    try {
      onReasoning?.call('');
      final outlineText = await _chat(apiUrl, _outlineInstructions(description, numWeeks, experienceLevel), onReasoning: onReasoning);
      final outlineJson = _extractFirstJson(outlineText);
      final programName = (outlineJson['name'] as String?)?.trim().isNotEmpty == true
          ? outlineJson['name'] as String
          : 'Generated Program';
      final allLabels = (outlineJson['days'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .take(7)
          .toList();

      while (allLabels.length < 7) {
        allLabels.add('Rest');
      }

      if (allLabels.isEmpty) {
        throw LlmException('No training days in LLM outline.', rawResponse: outlineText);
      }

      final restPattern = RegExp(r'^\s*(rest|off|recovery)\b', caseSensitive: false);
      final trainingCount = allLabels.where((l) => !restPattern.hasMatch(l)).length;

      if (trainingCount == 0) {
        throw LlmException('No training days in LLM outline.', rawResponse: outlineText);
      }

      final days = <ImportDay>[];
      final skipped = <String>[];
      int progressDone = 0;

      for (int i = 0; i < allLabels.length; i++) {
        final label = allLabels[i];
        if (restPattern.hasMatch(label)) {
          days.add(ImportDay(dayIdx: i, label: label, exercises: []));
          continue;
        }
        onProgress?.call(++progressDone, trainingCount);
        // Small gap between requests — lets the LLM server finish cleanup
        if (progressDone > 1) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
        ImportDay? importedDay;
        final prompt = _dayGenInstructions(description, label, numWeeks, experienceLevel);
        for (int attempt = 0; attempt < 3 && importedDay == null; attempt++) {
          try {
            // Signal the UI to clear reasoning for the new call on the first attempt
            if (attempt == 0) onReasoning?.call('');
            final useStream = attempt == 0 ? onReasoning : null;
            final text = await _chat(apiUrl, prompt, onReasoning: useStream);
            final obj = _extractFirstJson(text);
            obj['dayIdx'] = i;
            if ((obj['label'] as String?)?.isEmpty ?? true) obj['label'] = label;
            importedDay = ImportDay.fromJson(obj);
          } catch (_) {
            if (attempt < 2) {
              await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
            }
          }
        }
        if (importedDay != null) {
          days.add(importedDay);
        } else {
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
            maxTokens: 2048,
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

  Future<String> _chat(
    String url,
    String prompt, {
    void Function(String reasoningDelta)? onReasoning,
  }) async {
    if (onReasoning == null) {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'local-model',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.0,
          'max_tokens': 4096,
        }),
      );
      if (response.statusCode != 200) {
        throw LlmException('API failed: ${response.body}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = json['choices']?[0]?['message'] as Map<String, dynamic>?;
      return (msg?['content'] as String?)?.isNotEmpty == true
          ? msg!['content'] as String
          : (msg?['reasoning_content'] as String?) ?? '';
    }

    // Streaming SSE path — surfaces reasoning_content live, falls back to
    // plain-JSON parse if the endpoint ignores stream:true.
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': 'local-model',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.0,
        'stream': true,
        'max_tokens': 4096,
      });
      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw LlmException('API failed: $body');
      }
      final buffer = StringBuffer();
      final reasoningBuffer = StringBuffer();
      final rawLines = <String>[];
      bool sawSseLine = false;
      await for (final line in streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        rawLines.add(line);
        if (!line.startsWith('data: ')) continue;
        sawSseLine = true;
        final data = line.substring(6).trim();
        if (data == '[DONE]') break;
        try {
          final chunk = jsonDecode(data) as Map<String, dynamic>;
          final delta = chunk['choices']?[0]?['delta'] as Map<String, dynamic>?;
          if (delta == null) continue;
          final content = delta['content'] as String?;
          if (content != null) buffer.write(content);
          final reasoning =
              (delta['reasoning_content'] ?? delta['reasoning']) as String?;
          if (reasoning != null && reasoning.isNotEmpty) {
            reasoningBuffer.write(reasoning);
            onReasoning(reasoning);
          }
        } on FormatException {
          continue;
        }
      }
      // Fallback: endpoint returned plain JSON (ignored stream:true)
      if (!sawSseLine || buffer.isEmpty) {
        final raw = rawLines.join('\n');
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final msg = json['choices']?[0]?['message'] as Map<String, dynamic>?;
          final reasoning =
              (msg?['reasoning_content'] ?? msg?['reasoning']) as String?;
          if (reasoning != null && reasoning.isNotEmpty) onReasoning(reasoning);
          final content = (msg?['content'] as String?)?.isNotEmpty == true
              ? msg!['content'] as String
              : (msg?['reasoning_content'] as String?) ?? '';
          return content;
        } on FormatException {
          // raw is not valid JSON either; fall through
        }
      }
      // If content buffer is still empty but we got reasoning, the model may
      // have emitted the JSON inside reasoning_content rather than content.
      if (buffer.isEmpty && reasoningBuffer.isNotEmpty) {
        return reasoningBuffer.toString();
      }
      return buffer.toString();
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _extractFirstJson(String raw) {
    // 1. Try to find content within triple backticks (JSON fences)
    final fences = RegExp(r'```(?:json)?\s*([\s\S]*?)```').allMatches(raw);
    for (final f in fences) {
      final text = f.group(1)!.trim();
      final objects = splitJsonObjects(text);
      for (final obj in objects) {
        if (obj.containsKey('exercises') || obj.containsKey('days')) return obj;
      }
    }

    // 2. Fallback: Search the entire raw string for any JSON objects
    final objects = splitJsonObjects(raw);
    if (objects.isEmpty) {
      throw LlmException('No JSON object in response', rawResponse: raw);
    }

    // Prioritize the "richest" object or the first one that matches our schema
    Map<String, dynamic>? best;
    int maxKeys = -1;
    for (final obj in objects) {
      if (obj.containsKey('exercises') || obj.containsKey('days')) return obj;
      if (obj.length > maxKeys) {
        maxKeys = obj.length;
        best = obj;
      }
    }
    return best ?? objects.first;
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

  /// Returns 0-indexed week indices that should be deload weeks.
  /// Rule: deload every 5th week (indices 4, 9, 14…), capped to numWeeks.
  List<int> _deloadWeekIndices(int numWeeks) {
    if (numWeeks < 5) return [];
    final result = <int>[];
    for (int i = 4; i < numWeeks; i += 5) {
      result.add(i);
    }
    return result;
  }

  String _outlineInstructions(String description, int numWeeks, String experienceLevel) =>
      '''You are an expert strength and hypertrophy coach designing a $numWeeks-week training program for a ${experienceLevel.toUpperCase()} lifter.

Output a JSON object with:
- "name": a short, descriptive program name.
- "days": EXACTLY 7 strings (representing Monday through Sunday in order).

CRITICAL — TRAINING DAY COUNT:
Count the number of training days in the description before writing anything.
"3 day" = 3 training labels. "4 day" = 4 training labels. Never deviate.
Verify: count your non-Rest entries. It MUST match the description.

FORMAT FOR "days":
- Use descriptive labels for training sessions (e.g., "Upper A", "Push").
- Use exactly "Rest" for rest days.
- Ensure the array has EXACTLY 7 items.

SPLIT SELECTION (defaults when unspecified):
- 2–3 training days → full-body or push/pull/legs variant
- 4 days → upper/lower (each muscle hit 2×/week)
- 5 days → upper/lower/full-body or PPL+upper
- 6 days → PPL (push/pull/legs × 2)
Prefer splits where each major muscle group appears at least TWICE per week.
Avoid single-muscle bro splits (chest day, back day, etc.) unless explicitly requested.

STRUCTURE:
- Exactly 7 entries total (training + rest = 7).
- No more than 2 consecutive training days (avoid 3+ in a row unless requested).
- Balance push/pull, quad/hip-hinge, horizontal/vertical within the week.

Example — "3 day full body":
{"name":"3-Day Full Body","days":["Full Body A","Rest","Full Body B","Rest","Full Body C","Rest","Rest"]}

Example — "4 day upper lower":
{"name":"4-Day Upper/Lower","days":["Upper A","Lower A","Rest","Upper B","Lower B","Rest","Rest"]}

Respond with JSON only. No markdown, no commentary.
SCHEMA: {"name":"<name>","days":["<Mon>","<Tue>","<Wed>","<Thu>","<Fri>","<Sat>","<Sun>"]}

DESCRIPTION:
$description''';

  String _dayGenInstructions(String description, String dayLabel, int numWeeks, String experienceLevel) {
    final deloadWeeks = _deloadWeekIndices(numWeeks);
    final deloadNote = deloadWeeks.isEmpty
        ? ''
        : '''
DELOAD WEEKS (weekIdx values: ${deloadWeeks.join(', ')}):
On these weeks reduce fatigue and prime for the next training block:
- Cut working sets to 2 per exercise (regardless of normal set count).
- Keep the same rep targets but raise RIR to 3–4.
- Keep the same exercises — only volume and proximity to failure change.
Example deload weekTarget: {"weekIdx":${deloadWeeks.first},"reps":[8,8],"rir":[4,4]}
All other weekIdx values are normal training weeks.''';

    // Experience-level-specific guidance based on evidence-based volume landmarks.
    final (levelDesc, compoundSets, isoSets, weeklyVolume, rirNote) = switch (experienceLevel) {
      'beginner' => (
          'BEGINNER (< 1 year of consistent, proper training)',
          '2–3 sets',
          '1–2 sets',
          '4–8 sets per muscle group per week (MEV). Beginners respond to even minimal volume; do not over-prescribe sets.',
          'Start RIR 3–4 on compounds (technique still being learned). Accessories RIR 2. Progression is fast — prioritise adding reps/weight rather than chasing failure.',
        ),
      'advanced' => (
          'ADVANCED (4+ years of consistent, proper training)',
          '3–4 sets',
          '3–4 sets',
          '12–20 sets per muscle group per week (MAV). Advanced lifters need high volume to continue progressing. Prioritise lagging muscle groups.',
          'Compounds can start at RIR 2 (week 0) and push to RIR 0 by the final week. Accessories should reach RIR 0 by week 1–2.',
        ),
      _ => ( // intermediate (default)
          'INTERMEDIATE (1–4 years of consistent, proper training)',
          '3–4 sets',
          '2–3 sets',
          '8–15 sets per muscle group per week. Train each muscle at least twice per week for optimal hypertrophy.',
          'Compounds start RIR 3 (week 0), end at RIR 0–1 (final week). Accessories start RIR 2 and reach RIR 0 by the last training week.',
        ),
    };

    return '''You are an expert strength and hypertrophy coach. Design the "$dayLabel" session for a $numWeeks-week mesocycle.
LIFTER LEVEL: $levelDesc

═══ EXERCISE SELECTION ═══
- 4–6 exercises. Compounds first, isolations last.
- Use specific movement names: "Barbell Back Squat" not "Quad Exercise", "Seated Cable Row" not "Row".
- "group" must be exactly one of: chest | back | shoulders | arms | legs | core | other.
- Choose exercises appropriate for a $experienceLevel lifter on a "$dayLabel" day.

═══ SETS & REPS ═══
Compound lifts (squats, deadlifts, bench press, OHP, barbell/dumbbell rows, pull-ups, chin-ups, Romanian deadlifts):
- $compoundSets working sets.
- Strength focus: 3–6 reps. Hypertrophy focus: 6–12 reps. Infer from the description; default to hypertrophy.

Accessory & isolation exercises (curls, lateral raises, tricep pushdowns/extensions, leg curls, leg extensions, cable flyes, face pulls, calf raises, rear-delt flyes):
- $isoSets working sets.
- 10–20 reps (accessories respond well to higher reps and proximity to failure).

WEEKLY VOLUME: $weeklyVolume
- If a muscle is trained twice per week → roughly half the weekly sets per session.
- If trained once per week → full weekly set count in that session.

═══ RIR PROGRESSION ═══
RIR = reps in reserve (0 = failure, 1 = one rep left, etc.)
$rirNote

COMPOUNDS vs ACCESSORIES: accessories are safer to push closer to failure than compounds.
Accessories should ALWAYS have equal or lower RIR than compounds in the same week.

Progressive overload: each week show either a rep increase OR an RIR decrease (or both).
Do NOT keep reps and RIR identical across consecutive weeks — progression is mandatory.
$deloadNote

═══ MANDATORY FORMAT RULES ═══
- Every exercise must have EXACTLY $numWeeks weekTargets, weekIdx 0 through ${numWeeks - 1}.
- "reps" and "rir" arrays must be the same length (one entry per set in that week).
- This is always a training session — always output a non-empty exercise list.
- STRICT: Do not include any extra fields like "description", "sets", or "notes". Stick exactly to the schema.

Respond with JSON only. No markdown, no commentary.

SCHEMA:
{"label":"$dayLabel","exercises":[{"name":"<name>","group":"<group>","weekTargets":[{"weekIdx":0,"reps":[8,8,8],"rir":[3,3,3]},{"weekIdx":1,"reps":[9,9,9],"rir":[2,2,2]},...]}]}

PROGRAM DESCRIPTION:
$description''';
  }

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
    int start = -1;
    int depth = 0;
    bool inString = false;
    bool escape = false;
    List<String> stack = [];

    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (c == '\\') {
        escape = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (!inString) {
        if (c == '{') {
          if (depth == 0) {
            start = i;
            stack.clear();
          }
          depth++;
          stack.add('{');
        } else if (c == '[') {
          if (depth > 0) stack.add('[');
        } else if (c == ']') {
          if (depth > 0 && stack.isNotEmpty && stack.last == '[') {
            stack.removeLast();
          }
        } else if (c == '}') {
          if (depth > 0) {
            if (stack.isNotEmpty && stack.last == '{') {
              stack.removeLast();
            }
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
      }
    }

    if (start != -1) {
      String chunk = text.substring(start);
      if (inString) {
        if (escape) {
          chunk = chunk.substring(0, chunk.length - 1);
        }
        chunk += '"';
      }
      for (int i = stack.length - 1; i >= 0; i--) {
        if (stack[i] == '{') {
          chunk += '}';
        } else if (stack[i] == '[') {
          chunk += ']';
        }
      }

      // Clean up incomplete property keys like `,"key"}` or `{"key"}`
      chunk = chunk.replaceAllMapped(
          RegExp(r'([,{])\s*"[^"]+"\s*}'), (m) => "${m.group(1)}}");
      // Clean up incomplete key-value pairs like `"key":}`
      chunk = chunk.replaceAllMapped(
          RegExp(r'"[^"]+"\s*:\s*([\]}])'), (m) => m.group(1)!);
      // Clean up trailing commas like `,]` or `,}`
      chunk = chunk.replaceAllMapped(
          RegExp(r',\s*([\]}])'), (m) => m.group(1)!);

      try {
        results.add(jsonDecode(chunk) as Map<String, dynamic>);
      } on FormatException {
        // skip
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

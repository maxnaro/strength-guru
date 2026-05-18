import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/meso_import_data.dart';
import '../models/plan_advisory.dart';
import '../theme/groups.dart';
import 'csv_segmenter.dart';
import 'model_service.dart';
import 'target_math.dart';
import 'volume_validator.dart';

typedef _DayBrief = ({
  int dayIdx,
  String label,
  Set<String> muscles,
  Map<String, int> setBudget,
  List<String> primaryCompounds,
});

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
    String goal = 'mix',
    int? trainingDays,
    String sportContext = '',
    List<({String name, String group})> exerciseLibrary = const [],
    void Function(int done, int total)? onProgress,
    void Function(String reasoningDelta)? onReasoning,
  }) async {
    await WakelockPlus.enable();
    try {
      final libByGroup = <String, List<String>>{};
      for (final ex in exerciseLibrary) {
        (libByGroup[ex.group] ??= []).add(ex.name);
      }
      onReasoning?.call('');
      final outlineText = await _chat(
        apiUrl,
        _outlineInstructions(description, numWeeks, experienceLevel,
            goal: goal, trainingDays: trainingDays, sportContext: sportContext),
        onReasoning: onReasoning,
      );
      final outlineJson = _extractFirstJson(outlineText);
      var programName = (outlineJson['name'] as String?)?.trim().isNotEmpty == true
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

      // When trainingDays is pinned by the UI picker, validate the count and retry once.
      if (trainingDays != null) {
        final actual = allLabels.where((l) => !restPattern.hasMatch(l)).length;
        if (actual != trainingDays) {
          onReasoning?.call('');
          try {
            final retryText = await _chat(
              apiUrl,
              _outlineInstructions(description, numWeeks, experienceLevel,
                  goal: goal, trainingDays: trainingDays, sportContext: sportContext),
              onReasoning: onReasoning,
            );
            final retryJson = _extractFirstJson(retryText);
            final newLabels = (retryJson['days'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .take(7)
                .toList();
            while (newLabels.length < 7) { newLabels.add('Rest'); }
            if (newLabels.isNotEmpty) {
              allLabels
                ..clear()
                ..addAll(newLabels);
              if ((retryJson['name'] as String?)?.trim().isNotEmpty == true) {
                programName = retryJson['name'] as String;
              }
            }
          } catch (_) {}
        }
      }

      final trainingCount = allLabels.where((l) => !restPattern.hasMatch(l)).length;

      if (trainingCount == 0) {
        throw LlmException('No training days in LLM outline.', rawResponse: outlineText);
      }

      final briefs = _parseBriefs(outlineJson, allLabels, experienceLevel, goal);

      final days = <ImportDay>[];
      final skipped = <String>[];
      int progressDone = 0;

      // Running accumulators for whole-week context.
      final runningSets = <String, int>{};
      final doneDays = <({String label, List<String> compounds, Map<String, int> sets})>[];
      // Compounds already assigned as primary across previous days.
      final usedPrimaryCompounds = <String>{};

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
        final relGroups = _groupsForDayLabel(label);
        final dayLib = relGroups.isEmpty
            ? exerciseLibrary.map((e) => e.name).toList()
            : relGroups.expand((g) => libByGroup[g] ?? <String>[]).toList();
        final brief = briefs[i];
        // Compute remaining set budget: planned budget minus already-assigned sets.
        final remaining = {
          for (final entry in brief.setBudget.entries)
            entry.key: (entry.value - (runningSets[entry.key] ?? 0)).clamp(0, 99),
        };
        final prompt = _dayGenInstructions(
          description,
          label,
          numWeeks,
          experienceLevel,
          goal: goal,
          sportContext: sportContext,
          exerciseLibrary: dayLib,
          brief: brief,
          priorDays: List.unmodifiable(doneDays),
          remainingSetBudget: remaining,
          usedPrimaryCompounds: usedPrimaryCompounds,
        );
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
          // Update running context for subsequent days.
          final summary = _summarizeDay(importedDay);
          for (final entry in summary.sets.entries) {
            runningSets[entry.key] = (runningSets[entry.key] ?? 0) + entry.value;
          }
          doneDays.add((label: label, compounds: summary.compounds, sets: summary.sets));
          usedPrimaryCompounds.addAll(brief.primaryCompounds);
        } else {
          skipped.add(label);
        }
      }

      final result = MesoImportData(
        name: programName,
        numWeeks: numWeeks,
        days: days,
        skippedDayLabels: skipped,
      );

      final volAdvisories = VolumeValidator.validate(result,
          experienceLevel: experienceLevel, goal: goal);
      final criticAdvisories = await _critiquePlan(
        result, description, numWeeks, experienceLevel, goal,
        trainingDays, sportContext, apiUrl, onReasoning: onReasoning,
      );

      final seen = <String>{};
      result.advisories.addAll(
        [...volAdvisories, ...criticAdvisories]
            .where((a) => seen.add('${a.scope}|${a.message}')),
      );

      return result;
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<MesoImportData> fixPlanAdvisories(
    MesoImportData data,
    List<PlanAdvisory> advisories, {
    required String apiUrl,
    String experienceLevel = 'intermediate',
    String goal = 'mix',
    String sportContext = '',
    String description = '',
    List<({String name, String group})> exerciseLibrary = const [],
    void Function(String reasoningDelta)? onReasoning,
  }) async {
    await WakelockPlus.enable();
    try {
      final advisoryText =
          advisories.map((a) => '- [${a.scope}] ${a.message}').join('\n');
      final planJson = jsonEncode(data.toJson());
      final deloadWeeks = _deloadWeekIndices(data.numWeeks);
      final deloadNote = deloadWeeks.isEmpty
          ? ''
          : '\nDELOAD WEEKS (weekIdx: ${deloadWeeks.join(', ')}): keep sets at 2, do NOT raise volume to fix below-MEV on these weeks.';
      final libNote = exerciseLibrary.isEmpty
          ? ''
          : '\nEXERCISE LIBRARY (prefer these exact names):\n${exerciseLibrary.map((e) => e.name).join('\n')}';
      final dayIdxList = data.days.map((d) => d.dayIdx).join(', ');
      final dayDetailTable = data.days.map((d) {
        if (d.exercises.isEmpty) return '- dayIdx ${d.dayIdx} (${d.label}): [rest]';
        final summary = _summarizeDay(d);
        final compStr = summary.compounds.isEmpty ? 'none' : summary.compounds.join(', ');
        final setStr = summary.sets.entries.map((e) => '${e.key}:${e.value}').join(', ');
        return '- dayIdx ${d.dayIdx} (${d.label}): ${d.exercises.length} exercises'
            ' | compounds: $compStr | sets — $setStr';
      }).join('\n');

      final prompt = '''You are an evidence-based S&C coach fixing a mesocycle plan.
The current draft plan has the following validation advisories:
$advisoryText

Advisories describe the entire mesocycle unless they name specific weeks. Apply your fix to every week the issue affects (typically all weeks), not just week 1.
$deloadNote
$libNote

CURRENT PLAN PER DAY (preserve exercise count; rebalance compounds/sets across days to fix issues):
$dayDetailTable

CURRENT PLAN JSON:
$planJson

TASK:
Return the COMPLETE plan. All ${data.days.length} days MUST appear in the response in dayIdx order ($dayIdxList). Rest days and unchanged training days MUST be echoed back verbatim — do NOT omit, do NOT collapse them.
- numWeeks: ${data.numWeeks} — DO NOT change this value.
- Each training day MUST return the same number of exercises as listed above (or more if adding). Do NOT delete exercises without a direct replacement.
- Adjust sets/reps to fix volume issues.
- Change exercises if necessary to address balance or SAID principle issues.

Respond with JSON only — no markdown, no commentary.
SCHEMA: {"name":"<name>","numWeeks":${data.numWeeks},"days":[{"dayIdx":0,"label":"...","exercises":[]}]}''';

      onReasoning?.call('# Fixing Plan\n');
      MesoImportData? result;
      for (int attempt = 0; attempt < 3 && result == null; attempt++) {
        try {
          if (attempt > 0) {
            await Future.delayed(Duration(milliseconds: 300 * attempt));
          }
          final text = await _chat(apiUrl, prompt, onReasoning: attempt == 0 ? onReasoning : null);
          final obj = _extractFirstJson(text);
          result = MesoImportData.fromJson(obj);
        } catch (_) {
          if (attempt == 2) rethrow;
        }
      }

      final fixed = _mergeFixedDays(data, result!);

      // Re-validate
      final volAdvisories = VolumeValidator.validate(fixed,
          experienceLevel: experienceLevel, goal: goal);
      final criticAdvisories = await _critiquePlan(
        fixed,
        description.trim().isEmpty ? data.name : description,
        fixed.numWeeks,
        experienceLevel,
        goal,
        null,
        sportContext,
        apiUrl,
        onReasoning: onReasoning,
      );

      final seen = <String>{};
      fixed.advisories.addAll(
        [...volAdvisories, ...criticAdvisories]
            .where((a) => seen.add('${a.scope}|${a.message}')),
      );

      return fixed;
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
          : ((msg?['reasoning_content'] ?? msg?['reasoning'] ?? msg?['thinking'])
                  as String?) ??
              '';
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
          final reasoning = (delta['reasoning_content'] ??
              delta['reasoning'] ??
              delta['thinking']) as String?;
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
              : ((msg?['reasoning_content'] ?? msg?['reasoning'] ?? msg?['thinking'])
                      as String?) ??
                  '';
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
{"label":"<day label>","exercises":[{"name":"<exercise name>","group":"chest|back|shoulders|biceps|triceps|forearms|quads|hamstrings|glutes|abs|calves|other","sets":"<raw>","reps":"<raw>","rpe":"<raw>"}]}

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

  String _outlineInstructions(
    String description,
    int numWeeks,
    String experienceLevel, {
    String goal = 'mix',
    int? trainingDays,
    String sportContext = '',
  }) {
    final trainingDaysLine = trainingDays != null
        ? '- Training days: EXACTLY $trainingDays non-Rest entries. This is an absolute constraint — count before writing.'
        : '';

    final goalLabel = switch (goal) {
      'strength' => 'STRENGTH — maximal force; prioritise heavy compound movements',
      'hypertrophy' => 'HYPERTROPHY — muscle size; moderate–high volume, varied rep ranges',
      _ => 'MIX — balanced strength + hypertrophy; compounds heavy, accessories moderate volume',
    };

    final sportSection = sportContext.trim().isEmpty
        ? ''
        : '''
SPORT / CONTEXT: ${sportContext.trim()}
Apply the SAID principle (Specific Adaptation to Imposed Demands) when choosing labels and exercise emphasis:
1. Identify the dominant movement patterns of this sport.
2. Identify the chronically undertrained antagonist groups.
3. Bias day labels and accessory focus toward those antagonists and sport-specific stabilisers.
   Examples: climbing → push antagonists (chest, triceps, wrist extensors), rotator cuff, core; running → posterior chain, glute med, anti-rotation core.''';

    return '''You are an evidence-based strength and conditioning coach. Your recommendations follow:
- Schoenfeld's volume landmarks (MEV / MAV / MRV, diminishing returns above MAV)
- Helms' RIR-based autoregulation
- The SAID principle (specific adaptation to imposed demands)

═══ INPUTS ═══
- Experience: ${experienceLevel.toUpperCase()}
- Goal: $goalLabel
- Weeks: $numWeeks
$trainingDaysLine
$sportSection

═══ TASK ═══
Design a 7-entry weekly template (Monday–Sunday) as JSON.

REASON FIRST (use reasoning_content if available):
a. Count the exact number of training days required from the description or the pinned value above.
b. Identify the goal and implied weekly volume band.
c. If sportContext is present, apply SAID bias.
d. Choose a split where each major muscle hits ≥2×/wk where day count permits.
e. Verify your non-Rest count matches the required training-day count. If it does not, recount and fix.

THEN emit JSON only — no markdown, no commentary.

SPLIT DEFAULTS (when unspecified):
- 2–3 days → full-body or PPL variant
- 4 days → upper/lower (each muscle 2×/wk)
- 5 days → upper/lower/full-body or PPL+upper
- 6 days → PPL×2

STRUCTURE RULES:
- Exactly 7 entries total (training + rest = 7).
- Avoid 4+ consecutive training days. Up to 3 in a row is acceptable when day count demands it.
- Balance push/pull, quad/hip-hinge, horizontal/vertical across the week.
- Training labels: descriptive ("Upper A", "Push", "Full Body B"). Rest days: exactly "Rest".
- Avoid single-muscle bro splits (chest day, back day) unless explicitly requested.

MANDATORY CONSTRAINTS:
ONLY if the description explicitly names a specific protocol (e.g. a named exercise, a testing day, an AMRAP), reflect it in the matching day's label. Do NOT add testing days, 1RM days, AMRAP days, or peaking weeks the description does not request — default plans end with a deload, not a max-effort test.

═══ BRIEFS (required in output) ═══
For every training day (skip Rest days) emit a brief that divides the weekly volume across the split. Rules:
- "muscles": list of muscle groups trained that day.
- "setBudget": per-muscle set target for ONE week so the sum across all days for that muscle lands inside MEV–MAV. Do NOT assign the full weekly allocation to a single day.
- "primaryCompounds": 1–2 specific compound names for this day. Each compound must appear in exactly one day's primaryCompounds across the whole week — no shared primary compounds between days.

Example — Push day in a 4-day upper/lower, intermediate, hypertrophy:
{"dayIdx":0,"label":"Push","muscles":["chest","shoulders","triceps"],"setBudget":{"chest":5,"shoulders":3,"triceps":3},"primaryCompounds":["Barbell Bench Press","Overhead Press"]}

SCHEMA:
{"name":"<name>","days":["<Mon>","...","<Sun>"],
 "briefs":[{"dayIdx":<int>,"label":"<label>","muscles":["<group>",...],"setBudget":{"<group>":<sets>,...},"primaryCompounds":["<name>","<name>"]},...]}

Only include briefs entries for training days (days where label != "Rest").

DESCRIPTION:
$description''';
  }

  String _dayGenInstructions(
    String description,
    String dayLabel,
    int numWeeks,
    String experienceLevel, {
    String goal = 'mix',
    String sportContext = '',
    List<String> exerciseLibrary = const [],
    _DayBrief? brief,
    List<({String label, List<String> compounds, Map<String, int> sets})> priorDays =
        const [],
    Map<String, int> remainingSetBudget = const {},
    Set<String> usedPrimaryCompounds = const {},
  }) {
    final deloadWeeks = _deloadWeekIndices(numWeeks);
    final deloadNote = deloadWeeks.isEmpty
        ? ''
        : '''
DELOAD WEEKS (weekIdx: ${deloadWeeks.join(', ')}):
- Cut working sets to 2 per exercise.
- Keep rep targets; raise RIR to 3–4.
- Keep same exercises — only volume and proximity-to-failure change.
Example: {"weekIdx":${deloadWeeks.first},"reps":[8,8],"rir":[4,4]}
All other weekIdx values are normal training weeks.''';

    final (levelDesc, compoundSets, isoSets, weeklyVolume) = switch (experienceLevel) {
      'beginner' => (
          'BEGINNER (< 1 year of consistent training)',
          '2–3 sets',
          '1–2 sets',
          '4–8 sets per muscle group/week (MEV). Prioritise technique over volume. Linear progression is the primary driver.',
        ),
      'advanced' => (
          'ADVANCED (4+ years of consistent training)',
          '3–5 sets',
          '3–4 sets',
          '12–20 sets per muscle group/week (MAV). Volume above MAV yields diminishing returns — do NOT push to MRV unless this is a specialisation block.',
        ),
      _ => (
          'INTERMEDIATE (1–4 years of consistent training)',
          '3–4 sets',
          '2–3 sets',
          '8–15 sets per muscle group/week. Train each muscle group ≥2×/wk for optimal hypertrophy.',
        ),
    };

    final (compoundReps, isoReps, rirNote) = switch (goal) {
      'strength' => (
          '1–6 reps (3–5 for volume work; singles on test weeks)',
          '6–10 reps',
          'Compounds: start RIR 2 (week 0), progress to RIR 0 by final training week. Accessories: start RIR 1, reach RIR 0 by week 2. Strength demands high proximity to failure on the key compound lift.',
        ),
      'hypertrophy' => (
          '6–12 reps',
          '10–20 reps',
          'Compounds: start RIR 3 (week 0), end RIR 0–1 (final training week). Accessories: start RIR 2, reach RIR 0 by last week. Higher rep ranges and proximity to failure are the primary hypertrophy drivers.',
        ),
      _ => (
          '4–8 reps (include a heavy top set + back-off set where sets ≥ 3)',
          '8–15 reps',
          'Compounds: start RIR 2–3 (week 0), end RIR 0–1. Mix a heavy set (4–6 reps) with a back-off set (8–10 reps) for the primary compound. Accessories: start RIR 2, reach RIR 0.',
        ),
    };

    final sportSection = sportContext.trim().isEmpty
        ? ''
        : '''

═══ SPORT CONTEXT (SAID PRINCIPLE) ═══
Sport/context: ${sportContext.trim()}
Exercise selection must address sport-specific muscular imbalances. When two exercises are equally appropriate, choose the one that targets the athlete's undertrained antagonists.
- Climbing → prioritise: chest (DB press, push-up), triceps, wrist extensors (reverse curl, rice bucket), rotator cuff (face pull, band ER), anti-rotation core. Avoid adding load to finger flexors.
- Running → prioritise: glute med (lateral band walk, single-leg press), hamstrings (Nordic curl, leg curl), anti-rotation core (Pallof press), ankle stability.
- Cycling → prioritise: posterior chain (RDL, leg curl), horizontal pull, push/pull balance.
- BJJ / wrestling / combat sports → prioritise: rotational core, neck, wrist stability, posterior chain, trap-3 raises.
- General fitness → no restriction; follow standard split selection.''';

    // ── Weekly-context block (only rendered when there are prior days) ──
    final weeklyContextSection = priorDays.isEmpty
        ? ''
        : () {
            final sb = StringBuffer('\n═══ WEEKLY CONTEXT (already generated) ═══\n');
            for (final d in priorDays) {
              final setStr = d.sets.entries.map((e) => '${e.key}:${e.value}').join(', ');
              final compStr =
                  d.compounds.isEmpty ? 'none' : d.compounds.join(', ');
              sb.writeln('${d.label} | compounds: $compStr | sets — $setStr');
            }
            return sb.toString().trimRight();
          }();

    // ── Day brief block ──
    final briefSection = () {
      final targetMuscles = brief?.muscles.isNotEmpty == true
          ? brief!.muscles.join(', ')
          : 'inferred from label';
      final budgetStr = remainingSetBudget.isEmpty
          ? 'see weekly volume guidelines'
          : remainingSetBudget.entries
              .where((e) => e.value > 0)
              .map((e) => '${e.key}: ${e.value} sets remaining')
              .join(', ');
      final primaryStr = brief?.primaryCompounds.isNotEmpty == true
          ? brief!.primaryCompounds.join(', ')
          : 'choose freely';
      final usedStr = usedPrimaryCompounds.isEmpty
          ? ''
          : '\nDO NOT use these as primary compounds (already claimed by earlier days): ${usedPrimaryCompounds.join(', ')}.';

      return '''

═══ DAY BRIEF ═══
Target muscles: $targetMuscles
Remaining weekly set budget for this day: $budgetStr$usedStr
Primary compound(s) for this day: $primaryStr''';
    }();

    return '''You are an evidence-based strength and conditioning coach (Schoenfeld volume landmarks, Helms RIR autoregulation, SAID principle). Design the "$dayLabel" session of a $numWeeks-week mesocycle.
LIFTER LEVEL: $levelDesc
GOAL: ${goal.toUpperCase()}
$sportSection
$weeklyContextSection
$briefSection

═══ USER CONSTRAINTS — MUST HONOUR ═══
Source description: "$description"
- Any explicitly named exercise MUST appear in this session if appropriate for "$dayLabel".
- Encode a protocol in weekTargets ONLY if the description above explicitly names it:
  · If — and only if — the description says "1RM test" or "max test": weekIdx:${numWeeks - 1}, reps:[1], rir:[0] for the relevant compound.
  · If the description says "AMRAP": reps:[20], rir:[0].
  · If the description says "pause reps": include in the exercise name (e.g. "Pause Bench Press").
- Do NOT invent testing days, 1RM sets, or AMRAP sets the description does not request. Normal final weeks use the standard RIR progression, NOT a max test.
- Respect any stated exercise order (e.g. "start with deadlift").

═══ EXERCISE SELECTION ═══
- 4–6 exercises total. Compounds first, isolations last.
- Use specific names: "Barbell Back Squat" not "Squat", "Seated Cable Row" not "Row".
- "group" must be exactly one of: chest | back | shoulders | biceps | triceps | forearms | quads | hamstrings | glutes | abs | calves | other.
${exerciseLibrary.isEmpty ? '' : 'EXERCISE LIBRARY (prefer these exact names — only invent a name if no match exists):\n${exerciseLibrary.join('\n')}'}

═══ SETS & REPS ═══
Compound lifts (squat, deadlift, bench, OHP, barbell/DB row, pull-up, chin-up, RDL):
- $compoundSets working sets.
- Rep target: $compoundReps.

Accessory & isolation (curls, lateral raises, tricep work, leg curl, leg extension, cable fly, face pull, calf raise, rear-delt fly):
- $isoSets working sets.
- Rep target: $isoReps.

WEEKLY VOLUME: $weeklyVolume
- Use the per-muscle "remaining" set budget from the DAY BRIEF above. Do not assign more sets than the budget allows for muscles trained on multiple days.

═══ RIR PROGRESSION ═══
RIR = reps in reserve (0 = failure, 1 = one rep left).
$rirNote
Progressive overload: each week show a rep increase OR an RIR decrease (or both). NEVER keep reps AND rir identical across consecutive normal weeks — progression is mandatory.
Accessories should always have equal or lower RIR than compounds in the same week.
$deloadNote

═══ MANDATORY FORMAT RULES ═══
- Every exercise MUST have EXACTLY $numWeeks weekTargets, weekIdx 0 through ${numWeeks - 1}.
- "reps" and "rir" arrays must be the same length (one entry per set that week).
- This is a training session — always output a non-empty exercise list.
- STRICT: Do NOT include any extra fields ("sets", "description", "notes"). If you are about to add one, stop and remove it.

Respond with JSON only. No markdown, no commentary.

SCHEMA:
{"label":"$dayLabel","exercises":[{"name":"<name>","group":"<group>","weekTargets":[{"weekIdx":0,"reps":[8,8,8],"rir":[3,3,3]},{"weekIdx":1,"reps":[9,9,9],"rir":[2,2,2]},...]}]}''';
  }

  Set<String> _groupsForDayLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('push') || l.contains('chest')) {
      return {'chest', 'shoulders', 'triceps', 'abs'};
    }
    if (l.contains('pull') || l.contains('back') || l.contains('row')) {
      return {'back', 'biceps', 'forearms', 'abs'};
    }
    if (l.contains('lower') || l.contains('leg') || l.contains('squat') ||
        l.contains('dead') || l.contains('hinge')) {
      return {'quads', 'hamstrings', 'glutes', 'calves', 'abs'};
    }
    if (l.contains('upper')) {
      return {'chest', 'back', 'shoulders', 'biceps', 'triceps', 'abs'};
    }
    if (l.contains('shoulder') || l.contains('delt') || l.contains('ohp')) {
      return {'shoulders', 'triceps', 'abs'};
    }
    if (l.contains('arm') || l.contains('curl') || l.contains('tricep')) {
      return {'biceps', 'triceps', 'forearms'};
    }
    // Full body or unknown → no filtering, return empty to use full library
    return {};
  }

  // ─────────────────────── Week-context helpers ───────────────────────

  /// Parse `briefs` from the outline JSON, falling back to defaults.
  List<_DayBrief> _parseBriefs(
    Map<String, dynamic> outlineJson,
    List<String> allLabels,
    String experienceLevel,
    String goal,
  ) {
    // Try to parse LLM-provided briefs.
    final rawBriefs = outlineJson['briefs'] as List<dynamic>?;
    if (rawBriefs != null && rawBriefs.isNotEmpty) {
      try {
        final parsed = <int, _DayBrief>{};
        for (final rb in rawBriefs) {
          final m = rb as Map<String, dynamic>;
          final idx = (m['dayIdx'] as int?) ?? -1;
          if (idx < 0 || idx >= allLabels.length) continue;
          final muscles = ((m['muscles'] as List<dynamic>?) ?? [])
              .map((e) => e.toString())
              .toSet();
          final rawBudget = m['setBudget'] as Map<String, dynamic>? ?? {};
          final setBudget = rawBudget.map((k, v) => MapEntry(k, (v as num).toInt()));
          final compounds = ((m['primaryCompounds'] as List<dynamic>?) ?? [])
              .map((e) => e.toString())
              .toList();
          parsed[idx] = (
            dayIdx: idx,
            label: allLabels[idx],
            muscles: muscles,
            setBudget: setBudget,
            primaryCompounds: compounds,
          );
        }
        if (parsed.isNotEmpty) {
          return [
            for (int i = 0; i < allLabels.length; i++)
              parsed[i] ?? _defaultBrief(i, allLabels[i], experienceLevel, goal),
          ];
        }
      } catch (_) {}
    }
    // Fallback: derive default brief from label.
    return [
      for (int i = 0; i < allLabels.length; i++)
        _defaultBrief(i, allLabels[i], experienceLevel, goal),
    ];
  }

  _DayBrief _defaultBrief(
      int dayIdx, String label, String experienceLevel, String goal) {
    final muscles = _groupsForDayLabel(label);
    // Rough per-muscle set budget: midpoint of level-appropriate weekly volume
    // split evenly across muscles in this day's focus group.
    final midpoint = switch (experienceLevel) {
      'beginner' => 6,
      'advanced' => 16,
      _ => 11,
    };
    final share = muscles.isEmpty ? midpoint : (midpoint / muscles.length).ceil();
    final setBudget = {for (final m in muscles) m: share};
    return (
      dayIdx: dayIdx,
      label: label,
      muscles: muscles,
      setBudget: setBudget,
      primaryCompounds: const <String>[],
    );
  }

  /// Returns per-muscle set count for a generated day (week 0 as representative sample).
  ({Map<String, int> sets, List<String> compounds}) _summarizeDay(ImportDay day) {
    final sets = <String, int>{};
    final compounds = <String>[];
    for (final ex in day.exercises) {
      final w0 = ex.targetForWeek(0);
      final count = w0.reps.length;
      if (count > 0) {
        final g = ex.muscleGroup;
        sets[g] = (sets[g] ?? 0) + count;
      }
    }
    return (sets: sets, compounds: compounds);
  }

  Future<List<PlanAdvisory>> _critiquePlan(
    MesoImportData data,
    String description,
    int numWeeks,
    String experienceLevel,
    String goal,
    int? trainingDays,
    String sportContext,
    String apiUrl, {
    void Function(String)? onReasoning,
  }) async {
    final volTable = StringBuffer();
    for (var w = 0; w < numWeeks; w++) {
      final s = VolumeValidator.setsForWeek(data, w);
      if (s.isEmpty) continue;
      final line = s.entries.map((e) => '${e.key.label}: ${e.value}').join(', ');
      volTable.writeln('W${w + 1}: $line');
    }

    final prompt =
        '''You are an evidence-based S&C coach reviewing a generated mesocycle.

INPUTS:
- Description: "$description"
- Weeks: $numWeeks
- Experience: $experienceLevel
- Goal: $goal
- Training days/week: ${trainingDays ?? 'inferred'}
- Sport/context: ${sportContext.isEmpty ? 'general' : sportContext}

VOLUME PER WEEK (sets per muscle):
${volTable.toString().trim()}

PLAN:
${_serializePlanForCritic(data)}

SEVERITY GUIDE:
- "warn" = objective problem: missing mandatory item, broken constraint, broken progression, volume clearly outside safe range.
- "info" = soft recommendation the user may intentionally ignore: exercise frequency choice, split style, exercise name alternatives.

TASK: Identify up to 5 issues. Check only:
1. Constraint honoring — only flag missing items the description EXPLICITLY names. Do NOT flag a missing 1RM/max test/AMRAP/peaking week unless the description literally requests one.
2. Sport specificity — SAID principle misapplied for stated sport (skip if sportContext is general/empty)
3. Volume — flagrant MEV/MRV violation vs stated goal (not minor deviations)
4. Progression — reps/RIR flat or regresses across consecutive normal (non-deload) weeks

Frame issues at mesocycle scope. Only name specific weeks when the issue is week-specific (e.g., a progression break between W2→W3).

DO NOT flag: exercise frequency per week (user's choice), split type, exercise naming style.
If the plan looks solid, output an empty advisories array.
Output JSON only — no markdown, no commentary.
SCHEMA: {"advisories":[{"severity":"warn"|"info","scope":"<topic>","message":"<concise issue>"}]}
STRICT: max 5 items. Do NOT add any field other than severity, scope, message.''';

    try {
      onReasoning?.call('# Reviewing Plan\n');
      final text = await _chat(apiUrl, prompt, onReasoning: onReasoning);
      final json = _extractFirstJson(text);
      final rawList = json['advisories'] as List<dynamic>? ?? [];
      return rawList
          .map((e) {
            final m = e as Map<String, dynamic>;
            return PlanAdvisory(
              severity: (m['severity'] as String?) == 'info'
                  ? AdvisorySeverity.info
                  : AdvisorySeverity.warn,
              scope: (m['scope'] as String?) ?? 'general',
              message: (m['message'] as String?) ?? '',
              source: 'critic',
            );
          })
          .where((a) => a.message.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _serializePlanForCritic(MesoImportData data) {
    final sb = StringBuffer();
    for (final day in data.days) {
      if (day.exercises.isEmpty) {
        sb.writeln('${day.label}: [rest]');
        continue;
      }
      sb.writeln('${day.label}:');
      for (final ex in day.exercises) {
        final targets = ex.weekTargets
            .map((t) =>
                'W${t.weekIdx + 1}: ${t.reps.length}×${t.reps.isNotEmpty ? t.reps.first : '?'}@RIR${t.rir.isNotEmpty ? t.rir.first : '?'}')
            .join(', ');
        sb.writeln('  ${ex.name} (${ex.muscleGroup}) — $targets');
      }
    }
    return sb.toString();
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

  static ImportDay _pickDay(ImportDay original, ImportDay? fixed) {
    if (fixed == null) return original;
    // Guard: model returned fewer than half the original exercises — truncation,
    // not an intentional swap. Keep original.
    if (original.exercises.length >= 3 &&
        fixed.exercises.length * 2 < original.exercises.length) {
      return original;
    }
    return fixed;
  }

  static MesoImportData _mergeFixedDays(
      MesoImportData original, MesoImportData fixedResult) {
    final fixedByIdx = {for (final d in fixedResult.days) d.dayIdx: d};
    final mergedDays = [
      for (final orig in original.days) _pickDay(orig, fixedByIdx[orig.dayIdx]),
    ];
    return MesoImportData(
      name: fixedResult.name,
      numWeeks: original.numWeeks,
      days: mergedDays,
      skippedDayLabels: original.skippedDayLabels,
    );
  }

  // ignore: library_private_types_in_public_api
  static MesoImportData mergeFixedDaysForTest(
          MesoImportData original, MesoImportData fixedResult) =>
      _mergeFixedDays(original, fixedResult);

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
          RegExp(r'([,{])\s*"[^"]+"\s*}'), (m) => '${m.group(1)}}');
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

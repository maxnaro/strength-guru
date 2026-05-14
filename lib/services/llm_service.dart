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
  final String phase;
  final String week;
  final List<RawExtractedExercise> exercises;

  const RawExtractedDay({
    required this.label,
    required this.phase,
    required this.week,
    required this.exercises,
  });

  factory RawExtractedDay.fromJson(Map<String, dynamic> json) {
    return RawExtractedDay(
      label: (json['label'] as String?) ?? '',
      phase: (json['phase'] as String?) ?? '',
      week: (json['week'] as String?) ?? '',
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
    void Function(int done, int total)? onProgress,
    void Function(String reasoningDelta)? onReasoning,
  }) async {
    await WakelockPlus.enable();
    try {
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
        final prompt = _dayGenInstructions(description, label, numWeeks, experienceLevel, goal: goal, sportContext: sportContext);
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

    // Extract Phases
    final phases = <ImportPhase>[];
    final weekPhaseNames = <int, String>{}; // weekIdx -> phase name
    for (final (weekIdx, _, day) in results) {
      if (day.phase.isNotEmpty && !weekPhaseNames.containsKey(weekIdx)) {
        weekPhaseNames[weekIdx] = day.phase;
      }
    }

    if (weekPhaseNames.isEmpty) {
      phases.add(ImportPhase(
        name: 'Phase 1',
        startWeekIdx: 0,
        endWeekIdx: maxWeek,
      ));
    } else {
      String? currentPhaseName;
      int? start;
      for (int w = 0; w <= maxWeek; w++) {
        final pName = weekPhaseNames[w] ?? currentPhaseName ?? 'Phase 1';
        if (pName != currentPhaseName) {
          if (currentPhaseName != null) {
            phases.add(ImportPhase(
              name: currentPhaseName,
              startWeekIdx: start!,
              endWeekIdx: w - 1,
            ));
          }
          currentPhaseName = pName;
          start = w;
        }
      }
      if (currentPhaseName != null) {
        phases.add(ImportPhase(
          name: currentPhaseName,
          startWeekIdx: start!,
          endWeekIdx: maxWeek,
        ));
      }
    }

    final days = <ImportDay>[];
    for (final dayIdx in byDay.keys.toList()..sort()) {
      final weekMap = byDay[dayIdx]!;

      // Determine default label and per-week labels
      String defaultLabel = '';
      final weekLabels = <int, String>{};
      for (final entry in weekMap.entries) {
        if (defaultLabel.isEmpty && entry.value.label.isNotEmpty) {
          defaultLabel = entry.value.label;
        }
        if (entry.value.label.isNotEmpty) {
          weekLabels[entry.key] = entry.value.label;
        }
      }
      if (defaultLabel.isEmpty) defaultLabel = 'Day ${dayIdx + 1}';

      // Intelligent Name-Based Alignment
      final exercises = <ImportExercise>[];
      final seenExNames = <String>{};

      for (final weekIdx in weekMap.keys.toList()..sort()) {
        final rawDay = weekMap[weekIdx]!;
        for (final rawEx in rawDay.exercises) {
          if (seenExNames.contains(rawEx.name)) continue;

          // New exercise found, collect its targets across all weeks
          seenExNames.add(rawEx.name);
          final weekRaw =
              <({int weekIdx, String sets, String reps, String rpe})>[];
          String exGroup = rawEx.group;

          for (final wIdx in weekMap.keys.toList()..sort()) {
            final otherDay = weekMap[wIdx]!;
            // Find exercise with same name in this week
            final match =
                otherDay.exercises.where((e) => e.name == rawEx.name).firstOrNull;
            if (match != null) {
              weekRaw.add((
                weekIdx: wIdx,
                sets: match.sets,
                reps: match.reps,
                rpe: match.rpe
              ));
            }
          }

          exercises.add(ImportExercise(
            name: rawEx.name,
            muscleGroup: exGroup,
            weekTargets: TargetMath.buildWeekTargets(weekRaw),
          ));
        }
      }

      days.add(ImportDay(
        dayIdx: dayIdx,
        label: defaultLabel,
        weekLabels: weekLabels,
        exercises: exercises,
      ));
    }

    return MesoImportData(
      name: 'Imported Block',
      numWeeks: maxWeek + 1,
      phases: phases,
      days: days,
      skippedDayLabels: skipped,
    );
  }

  String _buildChunkPrompt(String csvLines) =>
      '<bos><|turn>user\n${_chunkInstructions(csvLines)}<turn|>\n<|turn>model\n';

  String _chunkInstructions(String csvLines) =>
      '''You are a workout parser. Extract the exercises from this single training day CSV.
Copy reps, sets, and RPE cell values verbatim as strings. Do not do math.
Include any Phase (e.g. "Phase 1") or Week (e.g. "Week 1") context found in the CSV.
Respond with JSON only, no markdown.

SCHEMA:
{"phase":"<phase name>","week":"<week name>","label":"<day label>","exercises":[{"name":"<exercise name>","group":"chest|back|shoulders|arms|legs|core|other","sets":"<raw>","reps":"<raw>","rpe":"<raw>"}]}

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
If the description names specific exercises, final-week tests (e.g. "1RM test"), AMRAPs, or required protocols, note them in your reasoning and surface them in relevant day labels (e.g. "Lower A — 1RM Day").

Example — "3 day full body":
{"name":"3-Day Full Body","days":["Full Body A","Rest","Full Body B","Rest","Full Body C","Rest","Rest"]}

Example — "4 day upper lower":
{"name":"4-Day Upper/Lower","days":["Upper A","Lower A","Rest","Upper B","Lower B","Rest","Rest"]}

SCHEMA: {"name":"<name>","days":["<Mon>","<Tue>","<Wed>","<Thu>","<Fri>","<Sat>","<Sun>"]}

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

    return '''You are an evidence-based strength and conditioning coach (Schoenfeld volume landmarks, Helms RIR autoregulation, SAID principle). Design the "$dayLabel" session of a $numWeeks-week mesocycle.
LIFTER LEVEL: $levelDesc
GOAL: ${goal.toUpperCase()}
$sportSection

═══ USER CONSTRAINTS — MUST HONOUR ═══
Source description: "$description"
- Any explicitly named exercise MUST appear in this session if appropriate for "$dayLabel".
- Any named protocol MUST be encoded in weekTargets:
  · "1RM test" or "max test" on the final week → weekIdx:${numWeeks - 1}, reps:[1], rir:[0] for the relevant compound.
  · "AMRAP" → reps:[20], rir:[0] (signals max-effort set).
  · "pause reps" → include in exercise name (e.g. "Pause Bench Press").
- Respect any stated exercise order (e.g. "start with deadlift").

═══ EXERCISE SELECTION ═══
- 4–6 exercises total. Compounds first, isolations last.
- Use specific names: "Barbell Back Squat" not "Squat", "Seated Cable Row" not "Row".
- "group" must be exactly one of: chest | back | shoulders | arms | legs | core | other.

═══ SETS & REPS ═══
Compound lifts (squat, deadlift, bench, OHP, barbell/DB row, pull-up, chin-up, RDL):
- $compoundSets working sets.
- Rep target: $compoundReps.

Accessory & isolation (curls, lateral raises, tricep work, leg curl, leg extension, cable fly, face pull, calf raise, rear-delt fly):
- $isoSets working sets.
- Rep target: $isoReps.

WEEKLY VOLUME: $weeklyVolume
- Muscle trained once/wk → full weekly set count that session.
- Muscle trained twice/wk → ~half the weekly sets per session.

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
    String phase = '';
    String week = '';
    final exercises = <RawExtractedExercise>[];
    for (final obj in objects) {
      final day = RawExtractedDay.fromJson(obj);
      if (label.isEmpty && day.label.isNotEmpty) label = day.label;
      if (phase.isEmpty && day.phase.isNotEmpty) phase = day.phase;
      if (week.isEmpty && day.week.isNotEmpty) week = day.week;
      exercises.addAll(day.exercises);
    }
    return RawExtractedDay(
      label: label,
      phase: phase,
      week: week,
      exercises: exercises,
    );
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

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/meso_import_data.dart';
import 'model_service.dart';

class LlmService {
  static const String defaultUrl = 'http://10.0.2.2:1234/v1/chat/completions';

  Future<MesoImportData> interpretPlan(String csvContent, {String? apiUrl}) async {
    await WakelockPlus.enable();
    try {
      if (apiUrl != null) {
        return await _runExternalApi(csvContent, apiUrl);
      }
      return await _runLocalInterpretation(csvContent);
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<MesoImportData> _runLocalInterpretation(String csvContent) async {
    final path = await ModelService.modelPath();

    // Using Q3_K_M model (~2.3GB) allows for some gpuLayers.
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

      final session = await engine.createSession();
      final buffer = StringBuffer();

      await for (final ev in session.generate(
        prompt: _buildPrompt(csvContent),
        addSpecial: true,
        parseSpecial: true,
        sampler: const SamplerParams(temperature: 0.0),
        maxTokens: 8192,
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
      return _parse(buffer.toString());
    } finally {
      await engine?.dispose();
    }
  }

  String _buildPrompt(String csv) =>
      '<bos><|turn>user\n${_instructions(csv)}<turn|>\n<|turn>model\n';

  Future<MesoImportData> _runExternalApi(String csvContent, String url) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'local-model',
        'messages': [
          {'role': 'user', 'content': _instructions(csvContent)},
        ],
        'temperature': 0.0,
      }),
    );

    if (response.statusCode != 200) {
      throw LlmException('API failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = json['choices'][0]['message']['content'] as String;
    return _parse(text);
  }

  String _instructions(String csv) =>
      '''You are a precision workout parser. Transform the provided CSV into JSON.

### EXTRACTION RULES:
1. **WEEKS & MERGING**: 
   - Match exercises across vertical weeks by their **POSITION** within the day.
   - Produce ONE exercise object per unique slot, with multiple `weekTargets`.
2. **DAY IDENTIFICATION**:
   - Days start at: "FULL BODY", "LOWER", "UPPER", "DAY X", or "REST DAY".
   - **REST DAYS**: Must be included as a day object with `exercises: []`.
3. **SAME-DAY DUPLICATES**: 
   - Keep "Top Set", "Back-off", etc., as SEPARATE exercises in the list.

### MATH & DATA RULES:
- **PER-EXERCISE RIR TRACKING**: 
  - Calculate RIR for each individual exercise independently based on the RPE column in its row.
  - **RIR = (10 - RPE_MAX)**.
  - **NO AVERAGING**: If RPE is "7-8", use 8. If RPE is "~6-8", use 8.
  - **LOWEST RIR WINS**: Always choose the most intense (lowest) RIR value for that exercise.
  - **LOOKUP**: "7-8" -> 2 RIR, "8-9" -> 1 RIR, "9-10" -> 0 RIR.
  - **INTENSIFICATION BIAS**: If a specific exercise's RPE range stays static for 3+ consecutive weeks, manually decrease its RIR by 1 in the later weeks to reflect intended progressive overload.
  - **ROUNDING**: Always round RIR **DOWN** (e.g., 10 - 8.5 = 1.5 -> **1 RIR**).
- **INTEGERS ONLY**: sets, reps, rir, weekIdx, dayIdx MUST be integers.
  - If a number has a "+" (e.g. "1+"), use the base number (1).
- **REPS**: Use the LOWEST number in a range (e.g., "8-10" -> 8). "AMRAP" -> 10.
- **MUSCLE GROUPS**: chest, back, shoulders, arms, legs, core, other.

SCHEMA:
{
  "name": "Program Name",
  "numWeeks": integer,
  "days": [
    {
      "dayIdx": integer,
      "label": "Day Label",
      "exercises": [
        {
          "name": "Exercise",
          "muscleGroup": "chest|back|shoulders|arms|legs|core|other",
          "weekTargets": [{ "weekIdx": 0, "sets": 3, "reps": 8, "rir": 2 }]
        }
      ]
    }
  ]
}

EXAMPLE INPUT:
Week 1,Exercise,Sets,Reps,RPE
Day 1,Bench Press Top,1,1,~8
,Bench Press,3,8,7-8
REST DAY,,,,
Week 2,Exercise,Sets,Reps,RPE
Day 1,Bench Press Top,1,1,8.5
,Bench Press,3,8,7-8
REST DAY,,,,
Week 3,Exercise,Sets,Reps,RPE
Day 1,Bench Press Top,1,1,~9
,Bench Press,3,8,7-8

EXAMPLE OUTPUT:
{
  "name": "Progressive Meso",
  "numWeeks": 3,
  "days": [
    {
      "dayIdx": 0,
      "label": "Day 1",
      "exercises": [
        {
          "name": "Bench Press Top",
          "muscleGroup": "chest",
          "weekTargets": [
            { "weekIdx": 0, "sets": 1, "reps": 1, "rir": 2 },
            { "weekIdx": 1, "sets": 1, "reps": 1, "rir": 1 },
            { "weekIdx": 2, "sets": 1, "reps": 1, "rir": 1 }
          ]
        },
        {
          "name": "Bench Press",
          "muscleGroup": "chest",
          "weekTargets": [
            { "weekIdx": 0, "sets": 3, "reps": 8, "rir": 2 },
            { "weekIdx": 1, "sets": 3, "reps": 8, "rir": 2 },
            { "weekIdx": 2, "sets": 3, "reps": 8, "rir": 1 }
          ]
        }
      ]
    },
    { "dayIdx": 1, "label": "REST DAY", "exercises": [] }
  ]
}

ACTUAL CSV:
$csv''';

  MesoImportData _parse(String raw) {
    var text = raw;

    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fenceMatch != null) text = fenceMatch.group(1)!.trim();

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw LlmException('No JSON object in response', rawResponse: raw);
    }
    text = text.substring(start, end + 1);

    // Strip trailing commas that break jsonDecode
    text = text.replaceAll(RegExp(r',\s*([\]}])'), r'$1');

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return MesoImportData.fromJson(json);
    } on FormatException catch (e) {
      throw LlmException('JSON parse failed: ${e.message}', rawResponse: raw);
    }
  }
}

class LlmException implements Exception {
  final String message;
  final String? rawResponse;
  LlmException(this.message, {this.rawResponse});

  @override
  String toString() => message;
}

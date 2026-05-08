import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/meso_import_data.dart';
import 'model_service.dart';

class LlmService {
  static const bool useLmStudio = true;
  static const String _lmStudioUrl = 'http://10.0.2.2:1234/v1/chat/completions';

  Future<MesoImportData> interpretPlan(String csvContent) async {
    if (useLmStudio) {
      return _runLmStudio(csvContent);
    }

    final path = await ModelService.modelPath();

    // Enable wakelock to prevent system sleep during heavy LLM load
    await WakelockPlus.enable();

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
      await WakelockPlus.disable();
    }
  }

  String _buildPrompt(String csv) =>
      '<bos><|turn>user\n${_instructions(csv)}<turn|>\n<|turn>model\n';

  Future<MesoImportData> _runLmStudio(String csvContent) async {
    final response = await http.post(
      Uri.parse(_lmStudioUrl),
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
      throw LlmException('LM Studio failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = json['choices'][0]['message']['content'] as String;
    return _parse(text);
  }

  String _instructions(String csv) =>
      '''You are a precision workout parser. Extract every exercise row from the provided CSV and output JSON.

STRICT NUMERIC RULES:
1. RIR & RPE ARE THE SAME: If the CSV provides RPE (e.g., "8"), convert it to RIR using (10 - RPE).
   - Example: RPE 8 = 2 RIR.
   - Example: RPE 7.5 = 2 RIR (round to nearest integer).
   - If RIR is provided directly, use it.
   - If BOTH are missing, use 0.
2. INTEGER ONLY: "sets", "reps", and "rir" MUST be integers.
3. COMPLEX NOTATION: If reps are "8/8/8" or "8, 6, 7", take the FIRST number (8).
4. RANGES: If reps are "8-10", take the LOWEST number (8).
5. TEXT FALLBACK: If reps is "AMRAP" or "Failure", use 10.
6. STRIP UNITS: Use only the number. Never include "kg", "lbs", or "sec".

EXTRACTION RULES:
- Include EVERY row. Do not summarize or skip.
- Remove modifiers like "(Heavy)" or "(Back off)" from the exercise name. Only provide the base exercise name.
- Muscle groups: chest, back, shoulders, arms, legs, core, other.
- The number of weeks should be dynamic to match the input CSV.

OUTPUT: A single JSON object. No markdown. No code blocks. No explanation. Just JSON.

SCHEMA:
{
  "name": "Block Name",
  "numWeeks": integer,
  "days": [
    {
      "dayIdx": integer,
      "label": "string",
      "exercises": [
        {
          "name": "string",
          "muscleGroup": "chest|back|shoulders|arms|legs|core|other",
          "weekTargets": [
            { "weekIdx": integer, "sets": integer, "reps": integer, "rir": integer }
          ]
        }
      ]
    }
  ]
}

RULES:
- dayIdx is 0-based.
- weekIdx is 0-based.
- If the CSV contains multiple weeks of data for an exercise, include a weekTarget for EACH week.
- If all weeks share same volume, weekTargets has one entry with weekIdx 0.

EXAMPLE INPUT:
Day 1: Chest & Back
Bench Press,Chest,3,8,2
Rows,Back,3,10,2

EXAMPLE OUTPUT:
{
  "name": "My Meso",
  "numWeeks": 1,
  "days": [
    {
      "dayIdx": 0,
      "label": "Day 1: Chest & Back",
      "exercises": [
        {
          "name": "Bench Press",
          "muscleGroup": "chest",
          "weekTargets": [{ "weekIdx": 0, "sets": 3, "reps": 8, "rir": 2 }]
        },
        {
          "name": "Rows",
          "muscleGroup": "back",
          "weekTargets": [{ "weekIdx": 0, "sets": 3, "reps": 10, "rir": 2 }]
        }
      ]
    }
  ]
}

ACTUAL CSV TO PARSE:
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

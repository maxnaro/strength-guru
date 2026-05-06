import 'dart:convert';
import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../models/meso_import_data.dart';
import 'model_service.dart';

class LlmService {
  Future<MesoImportData> interpretPlan(String csvContent) async {
    final path = await ModelService.modelPath();

    final modelParams = ModelParams(path: path, gpuLayers: 99);
    const ctxParams = ContextParams(nCtx: 4096, nBatch: 512, nUbatch: 512);

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
        if (msg.contains('libllama') || msg.contains('dlopen') || msg.contains('LlamaLibrary')) {
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
      return _parse(buffer.toString());
    } finally {
      await engine?.dispose();
    }
  }

  String _buildPrompt(String csv) =>
      '<bos><|turn>user\n${_instructions(csv)}<turn|>\n<|turn>model\n';

  String _instructions(String csv) => '''You are a workout plan parser. Read the CSV and output JSON only.

OUTPUT: A single JSON object. No markdown. No code blocks. No explanation. Just JSON.

SCHEMA:
{
  "name": "string",
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
- If all weeks share same volume, weekTargets has one entry with weekIdx 0.
- If RIR is absent, use 2.
- Infer muscleGroup from exercise name.

CSV:
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

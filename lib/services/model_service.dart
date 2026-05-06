import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ModelService {
  static const _modelUrl =
      'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf';
  static const _filename = 'gemma-4-E2B-it-Q4_K_M.gguf';
  // Sanity floor: real file is ~3.11 GB
  static const _minBytes = 2800000000;
  // Fallback if Q4_K_M triggers JetSam kill on 6 GB iOS devices:
  // _modelUrl = '.../gemma-4-E2B-it-Q3_K_M.gguf'
  // _filename = 'gemma-4-E2B-it-Q3_K_M.gguf'
  // _minBytes = 2200000000

  static Future<String> modelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(dir.path, 'sg_models'));
    await modelsDir.create(recursive: true);
    return p.join(modelsDir.path, _filename);
  }

  static Future<bool> isDownloaded() async {
    final path = await modelPath();
    final file = File(path);
    if (!await file.exists()) return false;
    return (await file.length()) >= _minBytes;
  }

  /// Yields progress 0.0–1.0. Writes to a .tmp file then renames atomically.
  /// Caller is responsible for cancellation (just stop listening).
  static Stream<double> download() async* {
    final path = await modelPath();
    final tmpPath = '$path.tmp';

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(_modelUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw ModelDownloadException(
            'HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      final sink = File(tmpPath).openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) yield received / total;
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      await File(tmpPath).rename(path);
      yield 1.0;
    } finally {
      client.close();
    }
  }
}

class ModelDownloadException implements Exception {
  final String message;
  ModelDownloadException(this.message);

  @override
  String toString() => message;
}

import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

class ModelService {
  static const _modelUrl =
      'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q3_K_M.gguf';
  static const _filename = 'gemma-4-E2B-it-Q3_K_M.gguf';
  static const _subdir = 'sg_models';
  static const _taskId = 'sg-model-download';
  // Sanity floor: real file is ~2.32 GB
  static const _minBytes = 2200000000;
  // Fallback if Q4_K_M triggers JetSam kill on 6 GB iOS devices:
  // _modelUrl = '.../gemma-4-E2B-it-Q3_K_M.gguf'
  // _filename = 'gemma-4-E2B-it-Q3_K_M.gguf'
  // _minBytes = 2200000000

  static DownloadTask _buildTask() => DownloadTask(
        taskId: _taskId,
        url: _modelUrl,
        filename: _filename,
        baseDirectory: BaseDirectory.applicationDocuments,
        directory: _subdir,
        updates: Updates.statusAndProgress,
        retries: 5,
        allowPause: true,
      );

  static Future<String> modelPath() async {
    return _buildTask().filePath();
  }

  static Future<bool> isDownloaded() async {
    final path = await modelPath();
    final file = File(path);
    if (!await file.exists()) return false;
    return (await file.length()) >= _minBytes;
  }

  /// Persistent download via OS-managed foreground service (Android) or
  /// background URLSession (iOS). Survives screen-off and app suspension.
  /// Yields progress 0.0–1.0. Caller should call [cancel] to abort —
  /// just unsubscribing keeps the OS task running.
  static Stream<double> download() {
    final controller = StreamController<double>();

    Future<void> run() async {
      try {
        await FileDownloader()
            .permissions
            .request(PermissionType.notifications);

        FileDownloader().configureNotification(
          running: const TaskNotification(
              'Downloading model', '{filename} · {progress}'),
          complete: const TaskNotification('Model ready', ''),
          error: const TaskNotification('Download failed', ''),
          progressBar: true,
        );

        final result = await FileDownloader().download(
          _buildTask(),
          onProgress: (progress) {
            if (!controller.isClosed && progress >= 0 && progress <= 1) {
              controller.add(progress);
            }
          },
        );

        if (controller.isClosed) return;

        switch (result.status) {
          case TaskStatus.complete:
            controller.add(1.0);
            await controller.close();
          case TaskStatus.canceled:
            await controller.close();
          default:
            controller.addError(ModelDownloadException(
                result.exception?.description ?? result.status.name));
            await controller.close();
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    }

    run();
    return controller.stream;
  }

  static Future<void> cancel() async {
    await FileDownloader().cancelTaskWithId(_taskId);
  }
}

class ModelDownloadException implements Exception {
  final String message;
  ModelDownloadException(this.message);

  @override
  String toString() => message;
}

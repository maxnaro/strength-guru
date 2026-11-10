import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/download.dart';
import '../providers.dart';
import 'api.dart';

class BackupService {
  static Future<void> backup([WidgetRef? ref]) async {
    final sync = ref!.read(syncClientProvider)!;
    await sync.synchronize();
    if (sync.pending > 0)
      throw StateError(
        'Resolve or export pending changes before creating a server backup.',
      );
    final response = await appApi.request('GET', 'backups');
    await downloadBytes(
      response.bodyBytes,
      'strength-guru.sqlite',
      'application/vnd.sqlite3',
    );
  }

  static Future<bool> restore(WidgetRef ref) async {
    final sync = ref.read(syncClientProvider)!;
    await sync.synchronize();
    if (sync.pending > 0)
      throw StateError(
        'Export or resolve pending workout changes before restoring.',
      );
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.single.bytes == null) return false;
    final inspected = await appApi.request(
      'POST',
      'backups/inspect',
      bytes: result.files.single.bytes,
    );
    final preview = Map<String, dynamic>.from(
      jsonDecode(inspected.body) as Map,
    );
    if (!ref.context.mounted) return false;
    final counts = preview['counts'] as Map;
    final confirmed = await showDialog<bool>(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          '${counts['mesocycles']} programs, ${counts['session_logs']} sessions and ${counts['set_entries']} sets. This replaces the server training data. A recovery snapshot will be saved first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await sync.synchronize();
    if (sync.pending > 0)
      throw StateError('Resolve pending changes before restoring.');
    await appApi.json(
      'POST',
      'backups/restore',
      body: {'token': preview['token'], 'confirmed': true},
    );
    await sync.synchronize();
    ref.invalidate(activeMesoProvider);
    ref.invalidate(allMesosProvider);
    return true;
  }
}

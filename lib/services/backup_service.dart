import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';
import '../db/database.dart';
import '../providers.dart';

class BackupService {
  static const _dbName = 'strength_guru';

  static Future<File> _getDbFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, '$_dbName.sqlite'));
  }

  static Future<void> backup() async {
    final file = await _getDbFile();
    if (!await file.exists()) {
      throw Exception('Database file not found at ${file.path}');
    }

    // Use share_plus to export the file.
    // XFile is part of cross_file, which share_plus re-exports or depends on.
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'StrengthGuru Backup',
      text: 'My StrengthGuru workout data backup.',
    );
  }

  static Future<bool> restore(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) {
      return false;
    }

    final backupFile = File(result.files.single.path!);

    // --- Validation Phase ---
    try {
      final testDb = sqlite3.open(backupFile.path);
      try {
        // 1. Basic integrity check
        final integrity = testDb.select('PRAGMA integrity_check');
        if (integrity.first[0] != 'ok') {
          throw Exception('Database integrity check failed.');
        }

        // 2. Schema check: verify a core table exists
        final tables = testDb.select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='mesocycles'");
        if (tables.isEmpty) {
          throw Exception('Invalid StrengthGuru backup (missing core tables).');
        }
      } finally {
        testDb.dispose();
      }
    } catch (e) {
      throw Exception('The selected file is not a valid StrengthGuru backup: $e');
    }

    final db = ref.read(dbProvider);

    // 1. Close the current database connection.
    // This ensures no processes are locking the file.
    await db.close();

    final dbFile = await _getDbFile();

    // 2. Delete temporary SQLite files if they exist.
    // These are created in WAL (Write-Ahead Logging) mode or Journal mode.
    final walFile = File('${dbFile.path}-wal');
    final shmFile = File('${dbFile.path}-shm');
    final journalFile = File('${dbFile.path}-journal');
    
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();
    if (await journalFile.exists()) await journalFile.delete();

    // 3. Overwrite the database file with the backup.
    await backupFile.copy(dbFile.path);

    // 4. Invalidate the provider to force a re-open on next access.
    ref.invalidate(dbProvider);

    return true;
  }
}

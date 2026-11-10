import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:strength_guru_core/sync/storage.dart';
import 'package:strength_guru_core/sync/protocol.dart';
import 'package:uuid/uuid.dart';
import 'store.dart';

class Backups {
  final Store store;
  final Directory directory;
  final Map<String, (File, DateTime)> _staged = {};
  Backups(this.store, this.directory);

  Future<File> snapshot() async {
    await directory.create(recursive: true);
    final file = File('${directory.path}/${const Uuid().v4()}.sqlite');
    await store.db.customStatement('VACUUM INTO ?', [file.path]);
    return file;
  }

  Future<Map<String, dynamic>> inspect(List<int> bytes) async {
    await directory.create(recursive: true);
    final token = const Uuid().v4();
    final file = File('${directory.path}/import-$token.sqlite');
    await file.writeAsBytes(bytes, flush: true);
    try {
      final source = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        source.execute('PRAGMA trusted_schema = OFF');
        if (source.select('PRAGMA integrity_check').single.values.single !=
            'ok')
          throw const ProtocolException(
            'invalid_backup',
            'SQLite integrity check failed.',
          );
        if (source.select('PRAGMA user_version').single.values.single != 8)
          throw const ProtocolException(
            'unsupported_schema',
            'Export a schema-v8 backup using the current native app.',
          );
        final counts = <String, int>{};
        for (final table in trainingKeys.keys) {
          if (source.select(
                'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
                ['table', table],
              ).length !=
              1)
            throw ProtocolException(
              'invalid_backup',
              'Missing training table: $table.',
            );
          counts[table] =
              source.select('SELECT COUNT(*) AS n FROM "$table"').single['n']
                  as int;
        }
        if (source.select('PRAGMA foreign_key_check').isNotEmpty)
          throw const ProtocolException(
            'invalid_backup',
            'The backup contains broken training references.',
          );
        _staged[token] = (file, DateTime.now());
        return {'token': token, 'counts': counts};
      } finally {
        source.close();
      }
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }

  Future<void> restore(String token) async {
    final staged = _staged.remove(token);
    if (staged == null ||
        DateTime.now().difference(staged.$2) > const Duration(hours: 1))
      throw const ProtocolException(
        'expired_import',
        'Select the backup again.',
      );
    final source = sqlite3.open(staged.$1.path, mode: OpenMode.readOnly);
    try {
      await snapshot(); // A consistent recovery point before any replacement.
      await store.db.transaction(() async {
        for (final table in trainingKeys.keys.toList().reversed) {
          await store.db.customStatement('DELETE FROM "$table"');
        }
        for (final table in trainingKeys.keys) {
          for (final row in source.select('SELECT * FROM "$table"')) {
            if (table == 'settings' &&
                (row['key'] as String).startsWith('llm_'))
              continue;
            await upsertRawRow(store.db, table, Map<String, dynamic>.from(row));
          }
        }
        await store.db.customStatement('DELETE FROM sg_revisions');
        await store.db.customStatement('DELETE FROM sg_operations');
        await store.db.customStatement(
          "UPDATE sg_jobs SET state = 'cancelled' WHERE state IN ('running', 'queued')",
        );
        await writeMeta(store.db, 'epoch', const Uuid().v4());
      });
    } finally {
      source.close();
      await staged.$1.delete();
    }
  }
}

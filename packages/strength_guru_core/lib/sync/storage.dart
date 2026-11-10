import 'dart:convert';
import 'package:drift/drift.dart';
import '../db/database.dart';

// Parent-first order; delete in reverse order. Only these tables cross the wire.
const trainingKeys = <String, List<String>>{
  'mesocycles': ['id'],
  'exercises': ['id'],
  'exercise_slots': ['id'],
  'week_targets': ['mesocycle_id', 'week_idx', 'slot_id'],
  'program_days': ['mesocycle_id', 'day_idx'],
  'day_overrides': ['mesocycle_id', 'week_idx', 'day_idx'],
  'session_logs': ['id'],
  'set_entries': ['id'],
  'settings': ['key'],
};

Future<void> initializeSyncStorage(AppDatabase db) async {
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS sg_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  );
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS sg_revisions (resource TEXT PRIMARY KEY, revision INTEGER NOT NULL)',
  );
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS sg_outbox (id TEXT PRIMARY KEY, resource TEXT NOT NULL, body TEXT NOT NULL, state TEXT NOT NULL DEFAULT \'pending\', error TEXT)',
  );
}

Future<String?> readMeta(AppDatabase db, String key) async =>
    (await db
            .customSelect(
              'SELECT value FROM sg_meta WHERE key = ?',
              variables: [Variable(key)],
            )
            .getSingleOrNull())
        ?.read<String>('value');
Future<void> writeMeta(
  AppDatabase db,
  String key,
  String value,
) => db.customStatement(
  'INSERT INTO sg_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
  [key, value],
);
Future<int> revisionFor(AppDatabase db, String resource) async =>
    (await db
            .customSelect(
              'SELECT revision FROM sg_revisions WHERE resource = ?',
              variables: [Variable(resource)],
            )
            .getSingleOrNull())
        ?.read<int>('revision') ??
    0;

Future<Map<String, dynamic>> trainingSnapshot(AppDatabase db) async => {
  for (final table in trainingKeys.keys)
    table: [
      for (final row
          in await db
              .customSelect(
                'SELECT * FROM "$table" ORDER BY ${trainingKeys[table]!.map((key) => '"$key"').join(',')}',
              )
              .get())
        row.data,
    ],
};

final _columnCache = Expando<Map<String, Set<String>>>();

Future<void> upsertRawRow(
  AppDatabase db,
  String table,
  Map<String, dynamic> row,
) async {
  final keys = table == 'sg_revisions' ? ['resource'] : trainingKeys[table];
  if (keys == null) throw ArgumentError('Unknown table');
  final cache = _columnCache[db] ??= <String, Set<String>>{};
  final columns = cache[table] ??=
      (await db.customSelect('PRAGMA table_info("$table")').get())
          .map((r) => r.read<String>('name'))
          .toSet();
  if (row.isEmpty || row.keys.any((k) => !columns.contains(k)))
    throw ArgumentError('Invalid row');
  final names = row.keys.map((k) => '"$k"').join(',');
  final updates = row.keys
      .where((k) => !keys.contains(k))
      .map((k) => '"$k" = excluded."$k"')
      .join(',');
  await db.customStatement(
    'INSERT INTO "$table" ($names) VALUES (${List.filled(row.length, '?').join(',')}) ON CONFLICT (${keys.map((k) => '"$k"').join(',')}) DO ${updates.isEmpty ? 'NOTHING' : 'UPDATE SET $updates'}',
    row.values.toList(),
  );
}

Future<void> applySyncPage(AppDatabase db, Map<String, dynamic> page) async {
  await db.transaction(() async {
    final snapshot = page['snapshot'] as Map<String, dynamic>?;
    if (snapshot != null) {
      for (final table in trainingKeys.keys.toList().reversed) {
        await db.customStatement('DELETE FROM "$table"');
      }
      await db.customStatement('DELETE FROM sg_revisions');
      for (final table in trainingKeys.keys) {
        for (final row in snapshot[table] as List) {
          await upsertRawRow(db, table, Map<String, dynamic>.from(row as Map));
        }
      }
      for (final row in page['revisions'] as List? ?? []) {
        await upsertRawRow(
          db,
          'sg_revisions',
          Map<String, dynamic>.from(row as Map),
        );
      }
    }
    for (final change in page['changes'] as List? ?? []) {
      final table = change['table'] as String;
      final row = Map<String, dynamic>.from(
        jsonDecode(change['data'] as String) as Map,
      );
      if (change['deleted'] == 1) {
        final keys = trainingKeys[table];
        if (keys == null) throw ArgumentError('Unknown deletion table');
        await db.customStatement(
          'DELETE FROM "$table" WHERE ${keys.map((k) => '"$k" = ?').join(' AND ')}',
          keys.map((k) => row[k]).toList(),
        );
      } else {
        await upsertRawRow(db, table, row);
      }
    }
    await writeMeta(db, 'epoch', page['epoch'] as String);
    await writeMeta(db, 'cursor', '${page['cursor']}');
  });
  db.markTablesUpdated(db.allTables.toSet());
}

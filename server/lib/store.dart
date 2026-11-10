import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/sync/protocol.dart';
import 'package:strength_guru_core/sync/storage.dart';
import 'package:uuid/uuid.dart';

class Store {
  final AppDatabase db;
  Store(this.db);

  Future<void> initialize() async {
    await initializeSyncStorage(db);
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement('PRAGMA journal_mode = WAL');
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS sg_changes (seq INTEGER PRIMARY KEY AUTOINCREMENT, "table" TEXT NOT NULL, data TEXT NOT NULL, deleted INTEGER NOT NULL)',
    );
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS sg_operations (id TEXT PRIMARY KEY, body TEXT NOT NULL, result TEXT NOT NULL)',
    );
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS sg_jobs (id TEXT PRIMARY KEY, kind TEXT NOT NULL, request TEXT NOT NULL, state TEXT NOT NULL, progress TEXT NOT NULL DEFAULT \'Queued\', result TEXT, error TEXT, checkpoints TEXT NOT NULL DEFAULT \'{}\', created_at TEXT NOT NULL)',
    );
    if (await readMeta(db, 'epoch') == null)
      await writeMeta(db, 'epoch', const Uuid().v4());
    for (final table in [...trainingKeys.keys, 'sg_revisions']) {
      final columns = await db
          .customSelect('PRAGMA table_info("$table")')
          .get();
      final keys = columns.map((r) => r.read<String>('name')).toList();
      for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
        final source = event == 'DELETE' ? 'OLD' : 'NEW';
        final json = keys.map((k) => "'$k', $source.\"$k\"").join(', ');
        final primaryKeys = table == 'sg_revisions'
            ? ['resource']
            : trainingKeys[table]!;
        final moved = primaryKeys
            .map((k) => 'OLD."$k" IS NOT NEW."$k"')
            .join(' OR ');
        final oldJson = keys.map((k) => "'$k', OLD.\"$k\"").join(', ');
        final tombstone = event == 'UPDATE'
            ? 'INSERT INTO sg_changes ("table", data, deleted) SELECT \'$table\', json_object($oldJson), 1 WHERE $moved;'
            : '';
        await db.customStatement(
          'DROP TRIGGER IF EXISTS "sg_${table}_${event.toLowerCase()}"',
        );
        await db.customStatement(
          'CREATE TRIGGER "sg_${table}_${event.toLowerCase()}" AFTER $event ON "$table" BEGIN $tombstone INSERT INTO sg_changes ("table", data, deleted) VALUES (\'$table\', json_object($json), ${event == 'DELETE' ? 1 : 0}); END',
        );
      }
    }
  }

  Future<int> get cursor async =>
      (await db
              .customSelect('SELECT COALESCE(MAX(seq), 0) AS n FROM sg_changes')
              .getSingle())
          .read<int>('n');

  Future<Map<String, dynamic>> sync({
    int? since,
    String? epoch,
  }) => db.transaction(() async {
    final currentEpoch = (await readMeta(db, 'epoch'))!;
    final end = await cursor;
    if (since == null || epoch != currentEpoch || since > end) {
      return {
        'epoch': currentEpoch,
        'cursor': end,
        'snapshot': await trainingSnapshot(db),
        'revisions': [
          for (final r
              in await db.customSelect('SELECT * FROM sg_revisions').get())
            r.data,
        ],
      };
    }
    final changes = await db
        .customSelect(
          'SELECT * FROM sg_changes WHERE seq > ? AND seq <= ? ORDER BY seq LIMIT 1000',
          variables: [Variable(since), Variable(end)],
        )
        .get();
    final next = changes.isEmpty ? end : changes.last.read<int>('seq');
    return {
      'epoch': currentEpoch,
      'cursor': next,
      'hasMore': next < end,
      'changes': [for (final r in changes) r.data],
    };
  });

  Future<Map<String, dynamic>> command(
    Map<String, dynamic> body,
  ) => db.transaction(() async {
    final id = body['operationId'];
    if (id is! String || id.length > 100)
      throw const ProtocolException(
        'invalid_operation',
        'A valid operation ID is required.',
      );
    if (body['epoch'] != await readMeta(db, 'epoch'))
      throw const ProtocolException(
        'dataset_changed',
        'The server database was restored. Review pending changes before reconnecting.',
        409,
      );
    final prior = await db
        .customSelect(
          'SELECT * FROM sg_operations WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    final encoded = jsonEncode(body);
    if (prior != null) {
      if (prior.read<String>('body') != encoded)
        throw const ProtocolException(
          'operation_reused',
          'This operation ID was already used for different data.',
          409,
        );
      return Map<String, dynamic>.from(
        jsonDecode(prior.read<String>('result')) as Map,
      );
    }
    final type = body['type'] as String;
    final p = Map<String, dynamic>.from(body['payload'] as Map);
    _validate(type, p);
    final mesoId =
        p['mesoId'] ??
        ([
              'activateMeso',
              'deleteMeso',
              'renameMeso',
              'duplicateMeso',
              'setMesoCurrentWeek',
              'setMesoNumWeeks',
            ].contains(type)
            ? p['id']
            : null);
    if (mesoId != null) {
      final meso = await (db.select(
        db.mesocycles,
      )..where((t) => t.id.equals(mesoId as String))).getSingleOrNull();
      if (meso == null ||
          type == 'getOrCreateSessionLog' &&
              ((p['weekIdx'] as int) < 0 ||
                  (p['weekIdx'] as int) >= meso.numWeeks)) {
        throw const ProtocolException(
          'deleted_reference',
          'The referenced program or week was removed. Your local change has been retained.',
          409,
        );
      }
    }
    final resource = await commandResource(db, type, p);
    final revision = await revisionFor(db, resource);
    if (type != 'getOrCreateSessionLog' &&
        body['expectedRevision'] != revision) {
      throw const ProtocolException(
        'conflict',
        'This record changed on another device. Your local edit has been retained.',
        409,
      );
    }
    if (type == 'upsertSetEntry') {
      final refs = await db
          .customSelect(
            'SELECT 1 FROM session_logs s JOIN exercise_slots x ON x.mesocycle_id = s.mesocycle_id WHERE s.id = ? AND x.id = ? AND x.exercise_id = ?',
            variables: [
              Variable(p['sessionId'] as String),
              Variable(p['slotId'] as String),
              Variable(p['exerciseId'] as String),
            ],
          )
          .get();
      if (refs.isEmpty)
        throw const ProtocolException(
          'deleted_reference',
          'The program or exercise for this set was removed. Your local set has been retained.',
          409,
        );
    }
    final result = await executeCommand(db, type, p);
    await upsertRawRow(db, 'sg_revisions', {
      'resource': resource,
      'revision': revision + 1,
    });
    final response = {
      'result': result,
      'resource': resource,
      'revision': revision + 1,
    };
    await db.customStatement(
      'INSERT INTO sg_operations (id, body, result) VALUES (?, ?, ?)',
      [id, encoded, jsonEncode(response)],
    );
    return response;
  });

  void _validate(String type, Map<String, dynamic> p) {
    for (final k in [
      'numWeeks',
      'targetWeekIdx',
      'setIndex',
      'weekIdx',
      'fromWeekIdx',
      'fromWeek',
    ]) {
      final v = p[k];
      if (v != null && (v is! int || v < (k == 'weekIdx' ? -1 : 0) || v > 104))
        throw ProtocolException('invalid_value', 'Invalid $k.');
    }
    for (final k in ['dayIdx', 'dayA', 'dayB', 'fromIdx', 'toIdx']) {
      final v = p[k];
      if (v != null && (v is! int || v < 0 || v > 6))
        throw ProtocolException('invalid_value', 'Invalid $k.');
    }
    if (type == 'upsertSetEntry') {
      final w = p['weight'];
      final reps = p['reps'];
      final rir = p['rir'];
      if (w != null && (w is! num || !w.isFinite || w < 0 || w > 2000) ||
          reps != null && (reps is! int || reps < 0 || reps > 999) ||
          rir != null && (rir is! int || rir < 0 || rir > 10))
        throw const ProtocolException('invalid_set', 'Invalid set values.');
    }
  }
}

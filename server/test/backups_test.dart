import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/db/queries.dart';
import 'package:strength_guru_core/seed/seeder.dart';
import 'package:strength_guru_core/sync/storage.dart';
import 'package:strength_guru_server/store.dart';
import 'package:strength_guru_server/backups.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late Backups backups;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = await Directory.systemTemp.createTemp('sg-backup-test-');
    db = AppDatabase(NativeDatabase(File('${dir.path}/live.sqlite')));
    final store = Store(db);
    await store.initialize();
    await Seeder.seedIfEmpty(db);
    backups = Backups(store, Directory('${dir.path}/backups'));
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'backup preview and restore preserve slots, arrays and logged history',
    () async {
      final meso = (await db.getActiveMesocycle())!;
      final slot = (await db.select(db.exerciseSlots).get()).first;
      final session = await db.getOrCreateSessionLog(meso.id, 0, 0);
      await db.upsertSetEntry(
        sessionId: session.id,
        exerciseId: slot.exerciseId,
        slotId: slot.id,
        setIndex: 0,
        weight: 87.5,
        reps: 7,
        rir: 1,
        done: true,
      );
      final before = await trainingSnapshot(db);
      final epoch = await readMeta(db, 'epoch');
      final snapshot = await backups.snapshot();
      final preview = await backups.inspect(await snapshot.readAsBytes());
      expect((preview['counts'] as Map)['set_entries'], 1);
      await db.renameMeso(meso.id, 'Changed');
      await backups.restore(preview['token'] as String);
      expect(await trainingSnapshot(db), before);
      expect(await readMeta(db, 'epoch'), isNot(epoch));
      expect((await db.getSetsForSession(session.id)).single.weight, 87.5);
    },
  );

  test('invalid backup leaves the live database intact', () async {
    final before = await trainingSnapshot(db);
    await expectLater(backups.inspect([0, 1, 2, 3]), throwsA(anything));
    expect(await trainingSnapshot(db), before);
  });

  test('foreign keys reject orphan set changes', () async {
    await expectLater(
      db.customStatement(
        "INSERT INTO session_logs (id, mesocycle_id, week_idx, day_idx) VALUES ('orphan', 'missing', 0, 0)",
      ),
      throwsA(anything),
    );
  });
}

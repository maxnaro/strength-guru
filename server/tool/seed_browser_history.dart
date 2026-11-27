// Populate only the disposable browser-test database for realistic profiling.
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/db/queries.dart';
import 'package:strength_guru_core/seed/seeder.dart';

Future<void> main() async {
  final directory = Platform.environment['DATA_DIR'];
  if (directory == null || !directory.contains('strength-guru-browser-')) {
    throw StateError(
      'This fixture only accepts a disposable browser-test directory.',
    );
  }
  final db = AppDatabase(
    NativeDatabase(File('$directory/strength_guru.sqlite')),
  );
  try {
    await Seeder.seedIfEmpty(db);
    if (Platform.environment['TEST_HISTORY'] != '1') return;
    final meso = (await db.getActiveMesocycle())!;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final start = monday.subtract(const Duration(days: 103 * 7));
    final slots = (await db.select(db.exerciseSlots).get()).take(5).toList();
    await db.transaction(() async {
      await (db.update(
        db.mesocycles,
      )..where((t) => t.id.equals(meso.id))).write(
        MesocyclesCompanion(
          numWeeks: const Value(104),
          startDate: Value(start),
        ),
      );
      for (final slot in await db.select(db.exerciseSlots).get()) {
        await db.upsertWeekTarget(
          mesoId: meso.id,
          weekIdx: 103,
          slotId: slot.id,
          reps: [10, 10, 10],
          rir: [2, 2, 2],
        );
      }
      for (var week = 0; week < 103; week++) {
        for (final day in [0, 2, 4]) {
          final logged = start.add(Duration(days: week * 7 + day));
          final session = await db.getOrCreateSessionLog(
            meso.id,
            week,
            day,
            startedAt: logged,
          );
          for (final slot in slots) {
            for (var set = 0; set < 3; set++) {
              await db.upsertSetEntry(
                sessionId: session.id,
                exerciseId: slot.exerciseId,
                slotId: slot.id,
                setIndex: set,
                weight: 60 + week / 4,
                reps: 8 + set,
                rir: 2,
                done: true,
                loggedAt: logged,
              );
            }
          }
        }
      }
    });
    stdout.writeln(
      'History fixture: 309 sessions, 4635 logged sets, 104 weeks.',
    );
  } finally {
    await db.close();
  }
}

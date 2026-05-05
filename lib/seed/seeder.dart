import 'package:drift/drift.dart' show Value;

import '../db/database.dart';
import '../db/plan.dart';
import '../db/queries.dart';
import '../util/ids.dart';

class Seeder {
  static Future<void> seedIfEmpty(AppDatabase db) async {
    final existing = await db.select(db.mesocycles).get();
    if (existing.isNotEmpty) return;
    await _seed(db);
  }

  static Future<void> forceReseed(AppDatabase db) async {
    await db.wipeAllData();
    await _seed(db);
  }

  static Future<void> _seed(AppDatabase db) async {
    await db.transaction(() async {
      // Insert exercises and collect name→id map.
      final nameToId = <String, String>{};
      for (final def in kExercises) {
        final id = newId();
        await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: id,
          name: def.name,
          group: def.group,
        ));
        nameToId[def.name] = id;
      }

      final startDate = _thisWeekMonday();
      final mesoId = newId();
      await db.into(db.mesocycles).insert(MesocyclesCompanion.insert(
        id: mesoId,
        name: 'Zercher Focus',
        startDate: startDate,
        isActive: const Value(true),
        numWeeks: const Value(9),
        deloadWeeks: const Value('3,8'),
      ));

      // Insert week targets for all 9 weeks.
      // Deloads: W4 (idx 3) and W9 (idx 8). Intensity phase W5-W8 adds +1 set.
      for (var w = 0; w < 9; w++) {
        final rir = const [2, 2, 1, 4, 1, 1, 2, 0, 4][w];
        final isDeload = w == 3 || w == 8;
        for (final def in kExercises) {
          final exId = nameToId[def.name]!;
          final sets = isDeload ? def.baseSets : def.baseSets + (w >= 4 ? 1 : 0);
          await db.into(db.weekTargets).insert(WeekTargetsCompanion.insert(
            mesocycleId: mesoId,
            weekIdx: w,
            exerciseId: exId,
            sets: sets,
            reps: def.baseReps,
            rir: rir,
          ));
        }
      }
    });
  }

  static DateTime _thisWeekMonday() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday - 1; // 0=Mon, 6=Sun
    final monday = now.subtract(Duration(days: dayOfWeek));
    return DateTime(monday.year, monday.month, monday.day);
  }

}

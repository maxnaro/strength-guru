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
      // 1. Insert unique exercises by name and group.
      final nameToExId = <String, String>{};
      for (final def in kExercises) {
        if (!nameToExId.containsKey(def.name)) {
          final id = newId();
          await db.into(db.exercises).insert(ExercisesCompanion.insert(
                id: id,
                name: def.name,
                group: def.group,
              ));
          nameToExId[def.name] = id;
        }
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

      // 2. Create slots for each ExerciseDef key.
      final keyToSlotId = <String, String>{};
      for (final def in kExercises) {
        final slotId = newId();
        await db.into(db.exerciseSlots).insert(ExerciseSlotsCompanion.insert(
              id: slotId,
              mesocycleId: mesoId,
              exerciseId: nameToExId[def.name]!,
            ));
        keyToSlotId[def.key] = slotId;
      }

      // Day labels
      final dayLabels = [
        'Chest & Shoulders',
        'Quads & Calves',
        'Rest',
        'Back',
        'Glutes & Hamstrings',
        'Triceps & Biceps',
        'Rest'
      ];
      for (var d = 0; d < 7; d++) {
        await db.into(db.programDays).insert(ProgramDaysCompanion.insert(
              mesocycleId: mesoId,
              dayIdx: d,
              label: Value(dayLabels[d]),
            ));
      }

      final weeklyRir = [2, 2, 1, 4, 1, 1, 2, 0, 4];
      final topSetReps = [6, 5, 4, 4, 3, 2, 1, 1, 5];

      for (var w = 0; w < 9; w++) {
        final rir = weeklyRir[w];
        for (final def in kExercises) {
          final slotId = keyToSlotId[def.key]!;
          var reps = def.baseReps;
          var targetRir = rir;

          if (def.key.endsWith('_top')) {
            reps = topSetReps[w];
          } else if (def.key == 'sissy_squats') {
            reps = 99; // AMRAP
            targetRir = 0; // n/a
          }

          await db.into(db.weekTargets).insert(WeekTargetsCompanion.insert(
                mesocycleId: mesoId,
                weekIdx: w,
                slotId: slotId,
                sets: def.baseSets,
                reps: reps,
                rir: targetRir,
              ));
        }

        // Day Overrides to handle exercise variations and specific ordering.
        final dayExercises = <int, List<String>>{
          0: [
            'dips_top',
            'dips_backoff',
            (w == 0 || w == 4 || w == 5)
                ? 'barbell_shoulder_press'
                : 'machine_shoulder_press',
            (w == 2 || w == 4) ? 'dumbbell_chest_flyes' : 'cable_chest_flyes',
            'dumbbell_lateral_raises',
            'cable_lateral_raises',
            (w == 4) ? 'dumbbell_rear_delt_flyes' : 'cable_rear_delt_flyes',
          ],
          1: [
            'zercher_squat_top',
            'zercher_squat_backoff',
            (w == 0 || w == 1) ? 'smith_machine_squat' : 'hack_squat',
            'quad_extensions',
            'standing_calf_raises',
            'sissy_squats',
          ],
          2: [],
          3: [
            'pull_ups_top',
            'pull_ups_backoff',
            'pendlay_rows',
            'uni_lateral_lat_pulldowns',
            (w == 1) ? 'cable_rows' : 'machine_rows',
            'lat_pullovers',
          ],
          4: [
            'zercher_deadlifts_top',
            'zercher_deadlifts_backoff',
            'rdls',
            'machine_hip_thrust',
            'seated_hamstring_curls',
            'lying_hamstring_curls',
          ],
          5: [
            'straight_bar_pushdowns',
            'overhead_extensions',
            'single_arm_extensions',
            'chin_ups',
            'preacher_curls',
            'single_arm_drag_curls',
          ],
          6: [],
        };

        for (var d = 0; d < 7; d++) {
          final keys = dayExercises[d]!;
          if (keys.isEmpty) continue;
          final ids = keys.map((k) => keyToSlotId[k]!).join(',');
          await db.into(db.dayOverrides).insert(DayOverridesCompanion.insert(
                mesocycleId: mesoId,
                weekIdx: w,
                dayIdx: d,
                exerciseIdsCsv: ids,
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

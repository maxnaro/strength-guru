import 'package:drift/drift.dart' show Value;

import '../db/database.dart';
import '../db/default_exercises.dart';
import '../db/plan.dart';
import '../db/queries.dart';
import '../util/ids.dart';

class Seeder {
  static Future<void> seedIfEmpty(AppDatabase db) async {
    // 1. Always ensure global exercises are present in the DB.
    await _syncGlobalExercises(db);

    // 2. Only seed the default mesocycle if no mesocycles exist.
    final existing = await db.select(db.mesocycles).get();
    if (existing.isNotEmpty) return;
    await _seed(db);
  }

  static Future<void> forceReseed(AppDatabase db) async {
    await db.wipeAllData();
    await _syncGlobalExercises(db);
    await _seed(db);
  }

  static Future<void> _syncGlobalExercises(AppDatabase db) async {
    await db.transaction(() async {
      final existingExercises = await db.select(db.exercises).get();
      final existingNames = existingExercises.map((e) => e.name).toSet();

      // Seed the comprehensive global exercise database.
      for (final def in kAllDefaultExercises) {
        if (!existingNames.contains(def.name)) {
          await db.into(db.exercises).insert(ExercisesCompanion.insert(
                id: newId(),
                name: def.name,
                group: def.group,
              ));
          existingNames.add(def.name);
        }
      }

      // Ensure any exercises specific to the default plan are also present.
      for (final def in kExercises) {
        if (!existingNames.contains(def.name)) {
          await db.into(db.exercises).insert(ExercisesCompanion.insert(
                id: newId(),
                name: def.name,
                group: def.group,
              ));
          existingNames.add(def.name);
        }
      }
    });
  }

  static Future<void> _seed(AppDatabase db) async {
    await db.transaction(() async {
      // Re-fetch exercises to get their actual IDs for the mesocycle slots.
      final existingExercises = await db.select(db.exercises).get();
      final nameToExId = { for (var e in existingExercises) e.name: e.id };

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

      // Exercises that have a top set (first set is heavy/low rep)
      final exercisesWithTopSet = {
        'dips', 'zercher_squat', 'pull_ups', 'zercher_deadlifts'
      };

      for (var w = -1; w < 9; w++) {
        final rir = w == -1 ? weeklyRir[0] : weeklyRir[w];
        final effectiveW = w == -1 ? 0 : w;

        for (final def in kExercises) {
          final slotId = keyToSlotId[def.key]!;
          
          final targetReps = List.filled(def.baseSets, def.baseReps);
          final targetRir = List.filled(def.baseSets, rir);

          if (exercisesWithTopSet.contains(def.key)) {
            targetReps[0] = topSetReps[effectiveW];
            // Backoff sets for these are 12 reps (hardcoded from previous ExerciseDef backoff)
            for (var i = 1; i < targetReps.length; i++) {
              targetReps[i] = 12;
            }
          } else if (def.key == 'sissy_squats') {
            for (var i = 0; i < targetReps.length; i++) {
              targetReps[i] = 99; // AMRAP
              targetRir[i] = 0; // n/a
            }
          }

          await db.into(db.weekTargets).insert(WeekTargetsCompanion.insert(
                mesocycleId: mesoId,
                weekIdx: w,
                slotId: slotId,
                reps: targetReps,
                rir: targetRir,
              ));
        }

        // Day Overrides to handle exercise variations and specific ordering.
        final dayExercises = <int, List<String>>{
          0: [
            'dips',
            (effectiveW == 0 || effectiveW == 4 || effectiveW == 5)
                ? 'barbell_shoulder_press'
                : 'machine_shoulder_press',
            (effectiveW == 2 || effectiveW == 4) ? 'dumbbell_chest_flyes' : 'cable_chest_flyes',
            'dumbbell_lateral_raises',
            'cable_lateral_raises',
            (effectiveW == 4) ? 'dumbbell_rear_delt_flyes' : 'cable_rear_delt_flyes',
          ],
          1: [
            'zercher_squat',
            (effectiveW == 0 || effectiveW == 1) ? 'smith_machine_squat' : 'hack_squat',
            'quad_extensions',
            'standing_calf_raises',
            'sissy_squats',
          ],
          2: [],
          3: [
            'pull_ups',
            'pendlay_rows',
            'uni_lateral_lat_pulldowns',
            (effectiveW == 1) ? 'cable_rows' : 'machine_rows',
            'lat_pullovers',
          ],
          4: [
            'zercher_deadlifts',
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

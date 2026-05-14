import 'package:flutter_test/flutter_test.dart';
import 'package:strength_guru/models/meso_import_data.dart';

void main() {
  group('ImportWeekTarget round-trip', () {
    test('toJson → fromJson preserves values', () {
      const original = ImportWeekTarget(weekIdx: 1, reps: [8, 8, 8], rir: [2, 2, 2]);
      final json = original.toJson();
      final restored = ImportWeekTarget.fromJson(json);
      expect(restored.weekIdx, original.weekIdx);
      expect(restored.reps, original.reps);
      expect(restored.rir, original.rir);
    });
  });

  group('ImportExercise round-trip', () {
    test('toJson → fromJson preserves values', () {
      final original = ImportExercise(
        name: 'Bench Press',
        muscleGroup: 'chest',
        weekTargets: [
          const ImportWeekTarget(weekIdx: 0, reps: [8, 8], rir: [2, 2]),
          const ImportWeekTarget(weekIdx: 1, reps: [8, 8], rir: [1, 1]),
        ],
      );
      final json = original.toJson();
      final restored = ImportExercise.fromJson(json);
      expect(restored.name, original.name);
      expect(restored.muscleGroup, original.muscleGroup);
      expect(restored.weekTargets.length, 2);
      expect(restored.weekTargets[1].rir, [1, 1]);
    });
  });

  group('ImportDay round-trip', () {
    test('toJson → fromJson preserves values', () {
      final original = ImportDay(
        dayIdx: 0,
        label: 'DAY 1',
        exercises: [
          ImportExercise(
            name: 'Squat',
            muscleGroup: 'legs',
            weekTargets: [
              const ImportWeekTarget(weekIdx: 0, reps: [5, 5, 5, 5], rir: [2, 2, 2, 2]),
            ],
          ),
        ],
      );
      final json = original.toJson();
      final restored = ImportDay.fromJson(json);
      expect(restored.dayIdx, 0);
      expect(restored.label, 'DAY 1');
      expect(restored.exercises.first.name, 'Squat');
    });
  });

  group('ImportPhase round-trip', () {
    test('toJson → fromJson preserves values', () {
      const original =
          ImportPhase(name: 'Phase A', startWeekIdx: 0, endWeekIdx: 3);
      final json = original.toJson();
      final restored = ImportPhase.fromJson(json);
      expect(restored.name, original.name);
      expect(restored.startWeekIdx, original.startWeekIdx);
      expect(restored.endWeekIdx, original.endWeekIdx);
    });
  });

  group('MesoImportData round-trip', () {
    test('toJson → fromJson preserves full structure', () {
      final original = MesoImportData(
        name: 'Test Block',
        numWeeks: 3,
        phases: [
          const ImportPhase(name: 'Phase 1', startWeekIdx: 0, endWeekIdx: 2),
        ],
        days: [
          ImportDay(
            dayIdx: 0,
            label: 'DAY 1',
            exercises: [
              ImportExercise(
                name: 'Bench Press',
                muscleGroup: 'chest',
                weekTargets: [
                  const ImportWeekTarget(
                      weekIdx: 0, reps: [8, 8, 8], rir: [2, 2, 2]),
                  const ImportWeekTarget(
                      weekIdx: 1, reps: [8, 8, 8], rir: [1, 1, 1]),
                  const ImportWeekTarget(
                      weekIdx: 2, reps: [8, 8, 8], rir: [1, 1, 1]),
                ],
              ),
            ],
          ),
          ImportDay(dayIdx: 1, label: 'REST DAY', exercises: []),
        ],
      );

      final json = original.toJson();
      final restored = MesoImportData.fromJson(json);

      expect(restored.name, 'Test Block');
      expect(restored.numWeeks, 3);
      expect(restored.phases.length, 1);
      expect(restored.phases[0].name, 'Phase 1');
      expect(restored.days.length, 2);
      expect(restored.days[0].exercises.length, 1);
      expect(restored.days[0].exercises[0].weekTargets.length, 3);
      expect(restored.days[0].exercises[0].weekTargets[1].rir, [1, 1, 1]);
      expect(restored.days[1].label, 'REST DAY');
      expect(restored.days[1].exercises, isEmpty);
    });
  });
}

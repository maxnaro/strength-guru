import 'package:flutter_test/flutter_test.dart';
import 'package:strength_guru/models/meso_import_data.dart';
import 'package:strength_guru/models/plan_advisory.dart';
import 'package:strength_guru/services/volume_validator.dart';
import 'package:strength_guru/theme/groups.dart';

ImportExercise _exercise(String name, String group, int sets, int reps, int rir) {
  return ImportExercise(
    name: name,
    muscleGroup: group,
    weekTargets: [
      ImportWeekTarget(
        weekIdx: 0,
        reps: List.filled(sets, reps),
        rir: List.filled(sets, rir),
      ),
    ],
  );
}

ImportDay _trainingDay(int idx, List<ImportExercise> exercises) {
  return ImportDay(dayIdx: idx, label: 'Day ${idx + 1}', exercises: exercises);
}

MesoImportData _plan(List<ImportDay> days, {int numWeeks = 8}) {
  return MesoImportData(name: 'Test', numWeeks: numWeeks, days: days);
}

void main() {
  group('VolumeValidator.validate', () {
    test('empty plan returns no advisories', () {
      final data = _plan([]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      expect(result, isEmpty);
    });

    test('all major groups at MAV — no advisories', () {
      // chest: 14 sets, back: 16 sets, quads: 14 sets — all at MAV
      final day1 = _trainingDay(0, [
        _exercise('Bench Press', 'chest', 14, 8, 2),
        _exercise('Barbell Row', 'back', 16, 8, 2),
      ]);
      final day2 = _trainingDay(1, [
        _exercise('Squat', 'quads', 14, 8, 2),
      ]);
      final data = _plan([day1, day2]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      expect(result.where((a) => a.scope == 'chest' || a.scope == 'back' || a.scope == 'quads'),
          isEmpty);
    });

    test('chest below MEV emits below-MEV advisory', () {
      final day = _trainingDay(0, [
        _exercise('Bench Press', 'chest', 4, 8, 2),
        _exercise('Squat', 'quads', 10, 5, 3),
        _exercise('Row', 'back', 12, 8, 2),
      ]);
      final data = _plan([day]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final chestAdvisory = result.where((a) => a.scope == 'chest').firstOrNull;
      expect(chestAdvisory, isNotNull);
      expect(chestAdvisory!.message, contains('below MEV'));
      expect(chestAdvisory.severity, AdvisorySeverity.warn);
    });

    test('back above MRV emits above-MRV advisory', () {
      final day = _trainingDay(0, [
        _exercise('Row', 'back', 30, 8, 2),
        _exercise('Squat', 'quads', 10, 5, 3),
        _exercise('Bench', 'chest', 10, 8, 2),
      ]);
      final data = _plan([day]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final backAdvisory = result.where((a) => a.scope == 'back').firstOrNull;
      expect(backAdvisory, isNotNull);
      expect(backAdvisory!.message, contains('above MRV'));
    });

    test('no quad work emits zero-sets advisory', () {
      final day = _trainingDay(0, [
        _exercise('Bench Press', 'chest', 12, 8, 2),
        _exercise('Row', 'back', 14, 8, 2),
      ]);
      final data = _plan([day]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final quadAdvisory = result.where((a) => a.scope == 'quads').firstOrNull;
      expect(quadAdvisory, isNotNull);
      expect(quadAdvisory!.message, contains('No'));
    });

    test('4-day plan with chest on 1 day emits frequency advisory', () {
      // chest only on day 0; 4 training days total
      final days = [
        _trainingDay(0, [_exercise('Bench', 'chest', 10, 8, 2)]),
        _trainingDay(1, [_exercise('Squat', 'quads', 10, 5, 2)]),
        _trainingDay(2, [_exercise('Row', 'back', 12, 8, 2)]),
        _trainingDay(3, [_exercise('Deadlift', 'hamstrings', 8, 5, 2)]),
      ];
      final data = _plan(days);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final freqAdvisory =
          result.where((a) => a.scope == 'chest_freq').firstOrNull;
      expect(freqAdvisory, isNotNull);
      expect(freqAdvisory!.message, contains('1×/wk'));
    });

    test('beginner scaling: 6 chest sets does not trigger below-MEV', () {
      // Beginner MEV for chest = 8 * 0.7 = 5.6 → rounded to 6. 6 sets == threshold → no warn.
      final day = _trainingDay(0, [
        _exercise('Bench', 'chest', 6, 8, 2),
        _exercise('Squat', 'quads', 6, 8, 2),
        _exercise('Row', 'back', 7, 8, 2),
      ]);
      final data = _plan([day]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'beginner', goal: 'mix');
      final chestAdvisory = result.where((a) => a.scope == 'chest').firstOrNull;
      expect(chestAdvisory, isNull);
    });

    test('intermediate: 6 chest sets triggers below-MEV (MEV=8)', () {
      final day = _trainingDay(0, [
        _exercise('Bench', 'chest', 6, 8, 2),
        _exercise('Squat', 'quads', 10, 8, 2),
        _exercise('Row', 'back', 12, 8, 2),
      ]);
      final data = _plan([day]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final chestAdvisory = result.where((a) => a.scope == 'chest').firstOrNull;
      expect(chestAdvisory, isNotNull);
    });

    test('push:pull ratio warn when push heavy (mix goal)', () {
      final day = _trainingDay(0, [
        _exercise('Bench', 'chest', 15, 8, 2),
        _exercise('OHP', 'shoulders', 12, 8, 2),
        _exercise('Row', 'back', 8, 8, 2),
      ]);
      final data = _plan([day]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final balanceAdvisory = result.where((a) => a.scope == 'balance').firstOrNull;
      expect(balanceAdvisory, isNotNull);
      expect(balanceAdvisory!.message, contains('pull'));
    });

    test('push:pull ratio skipped for strength goal', () {
      final day = _trainingDay(0, [
        _exercise('Bench', 'chest', 15, 3, 1),
        _exercise('OHP', 'shoulders', 12, 3, 1),
        _exercise('Row', 'back', 8, 3, 1),
      ]);
      final data = _plan([day]);
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'strength');
      final balanceAdvisory = result.where((a) => a.scope == 'balance').firstOrNull;
      expect(balanceAdvisory, isNull);
    });
  });

  group('VolumeValidator.setsForWeek', () {
    test('counts sets correctly for target week', () {
      final ex = _exercise('Bench', 'chest', 4, 8, 2);
      // Add a second week target
      ex.weekTargets.add(ImportWeekTarget(
        weekIdx: 1,
        reps: [8, 8, 8],
        rir: [1, 1, 1],
      ));
      final data = _plan([_trainingDay(0, [ex])]);
      expect(VolumeValidator.setsForWeek(data, 0)[MuscleGroup.chest], 4);
      expect(VolumeValidator.setsForWeek(data, 1)[MuscleGroup.chest], 3);
    });
  });
}

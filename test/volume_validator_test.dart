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

ImportExercise _exerciseMultiWeek(
  String name,
  String group,
  List<(int sets, int reps, int rir)> weeks,
) {
  return ImportExercise(
    name: name,
    muscleGroup: group,
    weekTargets: [
      for (var i = 0; i < weeks.length; i++)
        ImportWeekTarget(
          weekIdx: i,
          reps: List.filled(weeks[i].$1, weeks[i].$2),
          rir: List.filled(weeks[i].$1, weeks[i].$3),
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

  group('VolumeValidator.validate — mesocycle-wide framing', () {
    test('deload week only: advisory names specific week', () {
      // W1-W3 chest fine (12 sets), W4 deload (0 sets) → advisory names week 4
      final ex = _exerciseMultiWeek('Bench', 'chest', [
        (12, 8, 2), // W1
        (12, 8, 1), // W2
        (12, 8, 1), // W3
        (0, 8, 3),  // W4 deload
      ]);
      // Also need back + quads to avoid unrelated advisories
      final back = _exerciseMultiWeek('Row', 'back', [
        (12, 8, 2), (12, 8, 1), (12, 8, 1), (0, 8, 3),
      ]);
      final quads = _exerciseMultiWeek('Squat', 'quads', [
        (10, 5, 3), (10, 5, 2), (10, 5, 2), (0, 5, 4),
      ]);
      final data = MesoImportData(
        name: 'Test',
        numWeeks: 4,
        days: [_trainingDay(0, [ex, back, quads])],
      );
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final chestAdvisory = result.where((a) => a.scope == 'chest').firstOrNull;
      // Should fire for deload zero, scoped to week 4 only
      expect(chestAdvisory, isNotNull);
      expect(chestAdvisory!.message, contains('week 4'));
      expect(chestAdvisory.message, isNot(contains('week 1')));
    });

    test('all weeks below MEV: no week qualifier in message', () {
      // Chest 4 sets every week in a 3-week plan → "below MEV" with no suffix
      final ex = _exerciseMultiWeek('Bench', 'chest', [
        (4, 8, 2), (4, 8, 1), (4, 8, 1),
      ]);
      final back = _exerciseMultiWeek('Row', 'back', [
        (12, 8, 2), (12, 8, 1), (12, 8, 1),
      ]);
      final quads = _exerciseMultiWeek('Squat', 'quads', [
        (10, 5, 3), (10, 5, 2), (10, 5, 2),
      ]);
      final data = MesoImportData(
        name: 'Test',
        numWeeks: 3,
        days: [_trainingDay(0, [ex, back, quads])],
      );
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final chestAdvisory = result.where((a) => a.scope == 'chest').firstOrNull;
      expect(chestAdvisory, isNotNull);
      expect(chestAdvisory!.message, contains('below MEV'));
      // No week qualifier when all weeks affected
      expect(chestAdvisory.message, isNot(contains('week')));
    });
  });

  group('VolumeValidator.setsForWeek', () {
    test('counts sets correctly for target week', () {
      final ex = _exercise('Bench', 'chest', 4, 8, 2);
      // Add a second week target
      ex.weekTargets.add(const ImportWeekTarget(
        weekIdx: 1,
        reps: [8, 8, 8],
        rir: [1, 1, 1],
      ));
      final data = _plan([_trainingDay(0, [ex])]);
      expect(VolumeValidator.setsForWeek(data, 0)[MuscleGroup.chest], 4);
      expect(VolumeValidator.setsForWeek(data, 1)[MuscleGroup.chest], 3);
    });
  });

  group('VolumeValidator.validate — scaling and secondary muscle rules', () {
    test('advanced scaling raises MRV ceiling — 26 back sets no advisory', () {
      // Advanced MRV back = 25 * 1.15 = 28.75 → 29. 26 sets should be fine.
      final day = _trainingDay(0, [
        _exercise('Row', 'back', 26, 8, 2),
        _exercise('Bench', 'chest', 14, 8, 2),
        _exercise('Squat', 'quads', 14, 8, 2),
      ]);
      final result = VolumeValidator.validate(
        _plan([day]),
        experienceLevel: 'advanced',
        goal: 'mix',
      );
      final backAdvisory = result.where((a) => a.scope == 'back').firstOrNull;
      expect(backAdvisory, isNull);
    });

    test('beginner skips secondary-major zero-sets advisory for biceps', () {
      final day = _trainingDay(0, [
        _exercise('Bench', 'chest', 6, 8, 2),
        _exercise('Squat', 'quads', 6, 8, 2),
        _exercise('Row', 'back', 7, 8, 2),
      ]);
      final result = VolumeValidator.validate(
        _plan([day]),
        experienceLevel: 'beginner',
        goal: 'mix',
      );
      final bicepsAdvisory = result.where((a) => a.scope == 'biceps').firstOrNull;
      expect(bicepsAdvisory, isNull);
    });

    test('intermediate emits zero-sets advisory for biceps when missing', () {
      final day = _trainingDay(0, [
        _exercise('Bench', 'chest', 10, 8, 2),
        _exercise('Squat', 'quads', 10, 8, 2),
        _exercise('Row', 'back', 12, 8, 2),
      ]);
      final result = VolumeValidator.validate(
        _plan([day]),
        experienceLevel: 'intermediate',
        goal: 'mix',
      );
      final bicepsAdvisory = result.where((a) => a.scope == 'biceps').firstOrNull;
      expect(bicepsAdvisory, isNotNull);
      expect(bicepsAdvisory!.message, contains('No'));
    });
  });

  group('VolumeValidator.validate — _formatWeeks branch coverage', () {
    test('frequency advisory with range suffix when subset of weeks affected', () {
      // Chest 1x/wk in weeks 2–4, but 2x/wk in weeks 1 and 5
      final chestA = _exerciseMultiWeek('Bench A', 'chest', [
        (6, 8, 2), // W1 — day 0
        (6, 8, 2), // W2
        (6, 8, 2), // W3
        (6, 8, 2), // W4
        (6, 8, 2), // W5
      ]);
      final chestB = _exerciseMultiWeek('Bench B', 'chest', [
        (4, 8, 2), // W1 — day 1
        (0, 8, 3), // W2
        (0, 8, 3), // W3
        (0, 8, 3), // W4
        (4, 8, 2), // W5
      ]);
      final back = _exerciseMultiWeek('Row', 'back', [
        (12, 8, 2), (12, 8, 2), (12, 8, 2), (12, 8, 2), (12, 8, 2),
      ]);
      final quads = _exerciseMultiWeek('Squat', 'quads', [
        (10, 5, 3), (10, 5, 2), (10, 5, 2), (10, 5, 2), (10, 5, 2),
      ]);
      final data = MesoImportData(
        name: 'Test',
        numWeeks: 5,
        days: [
          _trainingDay(0, [chestA, back, quads]),
          _trainingDay(1, [chestB]),
          _trainingDay(2, [_exercise('Leg Press', 'quads', 8, 10, 2)]),
          _trainingDay(3, [_exercise('Pull-down', 'back', 8, 10, 2)]),
        ],
      );
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final freqAdvisory =
          result.where((a) => a.scope == 'chest_freq').firstOrNull;
      expect(freqAdvisory, isNotNull);
      // Range suffix expected: "in weeks 2–4"
      expect(freqAdvisory!.message, contains('2–4'));
    });

    test('above MRV advisory with non-contiguous week comma list', () {
      // Back above MRV (25) in W1 and W3, fine in W2
      final ex = _exerciseMultiWeek('Row', 'back', [
        (30, 8, 2), // W1 above MRV
        (20, 8, 2), // W2 fine
        (30, 8, 2), // W3 above MRV
      ]);
      final chest = _exerciseMultiWeek('Bench', 'chest', [
        (10, 8, 2), (10, 8, 2), (10, 8, 2),
      ]);
      final quads = _exerciseMultiWeek('Squat', 'quads', [
        (10, 5, 3), (10, 5, 2), (10, 5, 2),
      ]);
      final data = MesoImportData(
        name: 'Test',
        numWeeks: 3,
        days: [_trainingDay(0, [ex, chest, quads])],
      );
      final result = VolumeValidator.validate(data,
          experienceLevel: 'intermediate', goal: 'mix');
      final backAdvisory = result.where((a) => a.scope == 'back').firstOrNull;
      expect(backAdvisory, isNotNull);
      expect(backAdvisory!.message, contains('above MRV'));
      // Non-contiguous → comma list, not range
      expect(backAdvisory.message, contains('weeks 1, 3'));
    });
  });
}

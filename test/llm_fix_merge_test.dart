import 'package:flutter_test/flutter_test.dart';

import 'package:strength_guru/models/meso_import_data.dart';
import 'package:strength_guru/services/llm_service.dart';

ImportDay _day(int idx, String label, {int exercises = 2}) => ImportDay(
      dayIdx: idx,
      label: label,
      exercises: List.generate(
        exercises,
        (i) => ImportExercise(
          name: 'Exercise $i',
          muscleGroup: 'chest',
          weekTargets: [ImportWeekTarget(weekIdx: 0, reps: [8, 8, 8], rir: [2, 2, 2])],
        ),
      ),
    );

MesoImportData _meso(List<ImportDay> days) =>
    MesoImportData(name: 'Test', numWeeks: 4, days: days);

void main() {
  group('_mergeFixedDays', () {
    test('splices fixed days into original; preserves unchanged', () {
      final original = _meso([
        _day(0, 'Upper A', exercises: 3),
        _day(1, 'Rest', exercises: 0),
        _day(2, 'Lower A', exercises: 3),
        _day(3, 'Rest', exercises: 0),
        _day(4, 'Upper B', exercises: 3),
      ]);

      // Model returned only days 0 and 2 (fixed), omitted the rest
      final fixedResult = _meso([
        _day(0, 'Upper A', exercises: 4), // changed — added an exercise
        _day(2, 'Lower A', exercises: 5), // changed
      ]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days.length, 5);
      expect(merged.days[0].exercises.length, 4); // fixed
      expect(merged.days[1].exercises.length, 0); // original rest
      expect(merged.days[2].exercises.length, 5); // fixed
      expect(merged.days[3].exercises.length, 0); // original rest
      expect(merged.days[4].exercises.length, 3); // original unchanged
    });

    test('empty days in fixedResult returns original plan', () {
      final original = _meso([
        _day(0, 'Push', exercises: 4),
        _day(1, 'Pull', exercises: 4),
      ]);
      final fixedResult = _meso([]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days.length, 2);
      expect(merged.days[0].exercises.length, 4);
      expect(merged.days[1].exercises.length, 4);
    });

    test('extra dayIdx in fixedResult not in original is silently dropped', () {
      final original = _meso([
        _day(0, 'Full Body', exercises: 5),
      ]);
      // Model hallucinated a dayIdx 7
      final fixedResult = _meso([
        _day(0, 'Full Body', exercises: 6),
        _day(7, 'Phantom', exercises: 2),
      ]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days.length, 1);
      expect(merged.days[0].dayIdx, 0);
      expect(merged.days[0].exercises.length, 6);
    });

    test('numWeeks pinned to original even when fixedResult differs', () {
      final original = _meso([_day(0, 'Push')]);
      final fixedResult =
          MesoImportData(name: 'Fixed', numWeeks: 99, days: [_day(0, 'Push')]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.numWeeks, 4); // original.numWeeks
    });
  });

  group('within-day sanity guard (_pickDay)', () {
    test('1 exercise returned, original had 5 — guard fires, keeps original', () {
      final original = _meso([_day(0, 'Quads/Calves', exercises: 5)]);
      final fixedResult = _meso([_day(0, 'Quads/Calves', exercises: 1)]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days[0].exercises.length, 5);
    });

    test('0 exercises returned, original had 4 — guard fires, keeps original', () {
      final original = _meso([_day(0, 'Lower A', exercises: 4)]);
      final fixedResult = _meso([_day(0, 'Lower A', exercises: 0)]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days[0].exercises.length, 4);
    });

    test('2 exercises returned, original had 5 — below half, guard fires, keeps original', () {
      final original = _meso([_day(0, 'Push', exercises: 5)]);
      final fixedResult = _meso([_day(0, 'Push', exercises: 2)]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days[0].exercises.length, 5);
    });

    test('3 exercises returned, original had 5 — at half threshold, uses fixed', () {
      final original = _meso([_day(0, 'Push', exercises: 5)]);
      final fixedResult = _meso([_day(0, 'Push', exercises: 3)]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days[0].exercises.length, 3);
    });

    test('1 exercise returned, original had 1 — small day, uses fixed', () {
      final original = _meso([_day(0, 'Accessory', exercises: 1)]);
      final fixedResult = _meso([_day(0, 'Accessory', exercises: 1)]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days[0].exercises.length, 1);
    });

    test('1 exercise returned, original had 2 — under guard threshold, uses fixed', () {
      final original = _meso([_day(0, 'Short Day', exercises: 2)]);
      final fixedResult = _meso([_day(0, 'Short Day', exercises: 1)]);

      final merged = LlmService.mergeFixedDaysForTest(original, fixedResult);

      expect(merged.days[0].exercises.length, 1);
    });
  });
}

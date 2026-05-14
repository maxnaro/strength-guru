import 'package:flutter_test/flutter_test.dart';
import 'package:strength_guru/services/target_math.dart';

void main() {
  group('TargetMath.parseReps', () {
    test('range uses lowest', () => expect(TargetMath.parseReps('8-10'), 8));
    test('AMRAP maps to 10', () => expect(TargetMath.parseReps('AMRAP'), 10));
    test('amrap case-insensitive', () => expect(TargetMath.parseReps('amrap'), 10));
    test('plus notation uses base', () => expect(TargetMath.parseReps('1+'), 1));
    test('plain integer', () => expect(TargetMath.parseReps('12'), 12));
    test('empty defaults to 8', () => expect(TargetMath.parseReps(''), 8));
  });

  group('TargetMath.parseRir', () {
    test('"7-8" → 2', () => expect(TargetMath.parseRir('7-8'), 2));
    test('"8-9" → 1', () => expect(TargetMath.parseRir('8-9'), 1));
    test('"9-10" → 0', () => expect(TargetMath.parseRir('9-10'), 0));
    test('"~8" → 2', () => expect(TargetMath.parseRir('~8'), 2));
    test('"8.5" → 1 (floor)', () => expect(TargetMath.parseRir('8.5'), 1));
    test('"8.5-9" takes max (9) → 1', () => expect(TargetMath.parseRir('8.5-9'), 1));
    test('empty defaults to 2', () => expect(TargetMath.parseRir(''), 2));
    test('clamps to 0 minimum', () => expect(TargetMath.parseRir('10'), 0));
    test('rest time "1-2 min" ignored → 2', () => expect(TargetMath.parseRir('1-2 min'), 2));
    test('rest time "3-5 min" ignored → 2', () => expect(TargetMath.parseRir('3-5 min'), 2));
    test('rest time "3 min" ignored → 2', () => expect(TargetMath.parseRir('3 min'), 2));
    test('rep range "10-12" ignored → 2', () => expect(TargetMath.parseRir('10-12'), 2));
    test('rep range "15-20" ignored → 2', () => expect(TargetMath.parseRir('15-20'), 2));
    test('plain value > 10 ignored → 2', () => expect(TargetMath.parseRir('12'), 2));
  });

  group('TargetMath.parseSets', () {
    test('plain integer', () => expect(TargetMath.parseSets('3'), 3));
    test('empty defaults to 3', () => expect(TargetMath.parseSets(''), 3));
    test('zero clamps to 3', () => expect(TargetMath.parseSets('0'), 3));
    test('range takes first digit', () => expect(TargetMath.parseSets('3-4'), 3));
  });

  group('TargetMath.buildWeekTargets', () {
    test('produces correct reps/rir lists sized by sets', () {
      final result = TargetMath.buildWeekTargets([
        (weekIdx: 0, sets: '3', reps: '8-10', rpe: '7-8'),
      ]);
      expect(result.length, 1);
      expect(result[0].weekIdx, 0);
      expect(result[0].reps, [8, 8, 8]);
      expect(result[0].rir, [2, 2, 2]);
    });

    test('no intensification bias for fewer than 3 identical RPE weeks', () {
      final result = TargetMath.buildWeekTargets([
        (weekIdx: 0, sets: '3', reps: '8', rpe: '7-8'),
        (weekIdx: 1, sets: '3', reps: '8', rpe: '7-8'),
      ]);
      expect(result[0].rir, [2, 2, 2]);
      expect(result[1].rir, [2, 2, 2]);
    });

    test('intensification bias applied at index 2+ when RPE identical', () {
      final result = TargetMath.buildWeekTargets([
        (weekIdx: 0, sets: '3', reps: '8', rpe: '7-8'),
        (weekIdx: 1, sets: '3', reps: '8', rpe: '7-8'),
        (weekIdx: 2, sets: '3', reps: '8', rpe: '7-8'),
      ]);
      expect(result[0].rir, [2, 2, 2]);
      expect(result[1].rir, [2, 2, 2]);
      expect(result[2].rir, [1, 1, 1]); // bias applied
    });

    test('no bias when RPE changes', () {
      final result = TargetMath.buildWeekTargets([
        (weekIdx: 0, sets: '3', reps: '8', rpe: '7-8'),
        (weekIdx: 1, sets: '3', reps: '8', rpe: '8-9'),
        (weekIdx: 2, sets: '3', reps: '8', rpe: '7-8'),
      ]);
      expect(result[2].rir, [2, 2, 2]); // no bias since not all same
    });

    test('RIR does not go below 0 with bias', () {
      final result = TargetMath.buildWeekTargets([
        (weekIdx: 0, sets: '1', reps: '1', rpe: '9-10'),
        (weekIdx: 1, sets: '1', reps: '1', rpe: '9-10'),
        (weekIdx: 2, sets: '1', reps: '1', rpe: '9-10'),
      ]);
      expect(result[2].rir, [0]); // clamp at 0
    });
  });
}

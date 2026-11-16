// Regenerate: cd server && dart run tool/browser_fixtures.dart
// Check that browser expectations still match native domain calculations: add --check.
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/db/queries.dart';
import 'package:strength_guru_core/seed/seeder.dart';
import 'package:strength_guru_core/util/rep_calc.dart';

Future<void> main(List<String> args) async {
  final db = AppDatabase(NativeDatabase.memory());
  try {
    await Seeder.seedIfEmpty(db);
    final meso = (await db.select(db.mesocycles).get()).first;
    final slot = (await db.select(db.exerciseSlots).get()).first;
    final cases = <Map<String, dynamic>>[];
    for (final weeks in [1, 2, 3, 4, 5, 6, 8]) {
      for (final deloads in <Set<int>>[
        {},
        {0},
        {weeks - 1},
        if (weeks > 3) {1, 2},
        {for (var i = 0; i < weeks; i++) i},
      ]) {
        for (final endpoints in [
          [8, 3, 12, 0],
          [15, 0, 5, 4],
          [1, 5, 99, 0],
        ]) {
          final config = [
            {
              'startReps': endpoints[0],
              'startRir': endpoints[1],
              'endReps': endpoints[2],
              'endRir': endpoints[3],
            },
          ];
          await db.applyExerciseProgression(
            mesoId: meso.id,
            numWeeks: weeks,
            slotId: slot.id,
            sets: [
              (
                startReps: endpoints[0],
                startRir: endpoints[1],
                endReps: endpoints[2],
                endRir: endpoints[3],
              ),
            ],
            deloadWeeks: deloads,
          );
          final rows =
              await (db.select(db.weekTargets)..where(
                    (t) =>
                        t.mesocycleId.equals(meso.id) &
                        t.slotId.equals(slot.id),
                  ))
                  .get();
          rows.sort((a, b) => a.weekIdx.compareTo(b.weekIdx));
          cases.add({
            'weeks': weeks,
            'deloads': deloads.toList()..sort(),
            'config': config,
            'expected': rows
                .where((t) => t.weekIdx >= 0 && t.weekIdx < weeks)
                .map(
                  (t) => {'weekIdx': t.weekIdx, 'reps': t.reps, 'rir': t.rir},
                )
                .toList(),
          });
        }
      }
    }
    final reps = <Map<String, dynamic>>[];
    for (final formula in RepFormula.values) {
      for (final weight in [0.0, 42.5, 100.0]) {
        for (final count in [0, 1, 8, 36, 37, 50]) {
          for (final rir in [0, 2, 5]) {
            final one = estimate1Rm(weight, count, rir, formula);
            reps.add({
              'formula': formula.name,
              'weight': weight,
              'reps': count,
              'rir': rir,
              'oneRm': one,
              'targetWeight': weightForReps(one, count, rir, formula),
              'suggestedReps': repsForWeight(one, weight, formula),
            });
          }
        }
      }
    }
    final result =
        '${const JsonEncoder.withIndent('  ').convert({'source': 'Dart Queries.applyExerciseProgression and util/rep_calc.dart', 'progression': cases, 'repCalculations': reps})}\n';
    final file = File(
      '../frontend/src/lib/domain/fixtures/dart-calculations.json',
    );
    if (args.contains('--check')) {
      if (!file.existsSync() || file.readAsStringSync() != result)
        throw StateError(
          'Browser calculation fixtures differ. Regenerate and review domain changes.',
        );
      stdout.writeln('Dart/browser calculation fixtures match.');
    } else {
      file.writeAsStringSync(result);
      stdout.writeln(
        'Wrote ${cases.length} progression and ${reps.length} rep fixtures.',
      );
    }
  } finally {
    await db.close();
  }
}

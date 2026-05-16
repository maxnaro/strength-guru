import '../models/meso_import_data.dart';
import '../models/plan_advisory.dart';
import '../theme/groups.dart';

class VolumeValidator {
  static const _mev = {
    MuscleGroup.chest: 8,
    MuscleGroup.back: 10,
    MuscleGroup.shoulders: 8,
    MuscleGroup.biceps: 6,
    MuscleGroup.triceps: 6,
    MuscleGroup.quads: 8,
    MuscleGroup.hamstrings: 6,
    MuscleGroup.glutes: 6,
    MuscleGroup.calves: 6,
    MuscleGroup.abs: 6,
  };

  static const _mrv = {
    MuscleGroup.chest: 22,
    MuscleGroup.back: 25,
    MuscleGroup.shoulders: 20,
    MuscleGroup.biceps: 20,
    MuscleGroup.triceps: 18,
    MuscleGroup.quads: 22,
    MuscleGroup.hamstrings: 20,
    MuscleGroup.glutes: 16,
    MuscleGroup.calves: 16,
    MuscleGroup.abs: 20,
  };

  static const _majorMuscles = {
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.quads,
  };

  static const _secondaryMajor = {
    MuscleGroup.biceps,
    MuscleGroup.triceps,
  };

  static Map<MuscleGroup, int> setsForWeek(MesoImportData data, int weekIdx) {
    final result = <MuscleGroup, int>{};
    for (final day in data.days) {
      for (final ex in day.exercises) {
        final g = MuscleGroupX.fromString(ex.muscleGroup);
        if (g == MuscleGroup.other || g == MuscleGroup.rest || g == MuscleGroup.forearms) {
          continue;
        }
        result[g] = (result[g] ?? 0) + ex.targetForWeek(weekIdx).reps.length;
      }
    }
    return result;
  }

  static List<PlanAdvisory> validate(
    MesoImportData data, {
    required String experienceLevel,
    required String goal,
    int weekToCheck = 0,
  }) {
    if (data.days.isEmpty) return [];

    final scale = switch (experienceLevel) {
      'beginner' => 0.7,
      'advanced' => 1.15,
      _ => 1.0,
    };

    final advisories = <PlanAdvisory>[];
    final setsPerGroup = setsForWeek(data, weekToCheck);

    // Track how many distinct days each group appears on
    final daysPerGroup = <MuscleGroup, Set<int>>{};
    for (final day in data.days) {
      for (final ex in day.exercises) {
        final g = MuscleGroupX.fromString(ex.muscleGroup);
        if (g == MuscleGroup.other || g == MuscleGroup.rest || g == MuscleGroup.forearms) {
          continue;
        }
        (daysPerGroup[g] ??= {}).add(day.dayIdx);
      }
    }

    for (final g in _mev.keys) {
      final mev = (_mev[g]! * scale).round();
      final mrv = (_mrv[g]! * scale).round();
      final sets = setsPerGroup[g] ?? 0;

      final isMajor = _majorMuscles.contains(g);
      final isSecondary = _secondaryMajor.contains(g);
      final skipSecondary = isSecondary && experienceLevel == 'beginner';

      if (sets == 0 && (isMajor || (isSecondary && !skipSecondary))) {
        advisories.add(PlanAdvisory(
          severity: AdvisorySeverity.warn,
          scope: g.name,
          message: 'No ${g.label} work in week 1.',
          source: 'volume',
        ));
      } else if (sets > 0 && sets < mev) {
        advisories.add(PlanAdvisory(
          severity: AdvisorySeverity.warn,
          scope: g.name,
          message: '${g.label}: $sets sets — below MEV (~$mev).',
          source: 'volume',
        ));
      } else if (sets > mrv) {
        advisories.add(PlanAdvisory(
          severity: AdvisorySeverity.warn,
          scope: g.name,
          message: '${g.label}: $sets sets — above MRV (~$mrv).',
          source: 'volume',
        ));
      }
    }

    // Frequency check for major muscles when plan has 4+ training days
    final trainingDayCount = data.days.where((d) => d.exercises.isNotEmpty).length;
    if (trainingDayCount >= 4) {
      for (final g in _majorMuscles) {
        final dayCount = daysPerGroup[g]?.length ?? 0;
        if ((setsPerGroup[g] ?? 0) > 0 && dayCount < 2) {
          advisories.add(PlanAdvisory(
            severity: AdvisorySeverity.warn,
            scope: '${g.name}_freq',
            message: '${g.label} trained only 1×/wk — aim for ≥2×/wk.',
            source: 'volume',
          ));
        }
      }
    }

    // Push:pull ratio (skip for strength — powerlifting splits are squat-heavy by design)
    if (goal != 'strength') {
      final pushSets = (setsPerGroup[MuscleGroup.chest] ?? 0) +
          (setsPerGroup[MuscleGroup.shoulders] ?? 0) +
          (setsPerGroup[MuscleGroup.triceps] ?? 0);
      final pullSets =
          (setsPerGroup[MuscleGroup.back] ?? 0) + (setsPerGroup[MuscleGroup.biceps] ?? 0);
      if (pushSets > 0 && pullSets > 0) {
        final ratio = pushSets / pullSets;
        if (ratio > 1.7) {
          advisories.add(PlanAdvisory(
            severity: AdvisorySeverity.warn,
            scope: 'balance',
            message: 'Push:pull ratio ${ratio.toStringAsFixed(1)}:1 — consider adding pulling volume.',
            source: 'volume',
          ));
        } else if (ratio < 0.6) {
          final pullRatio = pullSets / pushSets;
          advisories.add(PlanAdvisory(
            severity: AdvisorySeverity.warn,
            scope: 'balance',
            message: 'Pull:push ratio ${pullRatio.toStringAsFixed(1)}:1 — consider adding pressing volume.',
            source: 'volume',
          ));
        }
      }
    }

    return advisories;
  }
}

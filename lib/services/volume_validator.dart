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

  static Map<MuscleGroup, Set<int>> _daysForWeek(MesoImportData data, int weekIdx) {
    final result = <MuscleGroup, Set<int>>{};
    for (final day in data.days) {
      for (final ex in day.exercises) {
        final g = MuscleGroupX.fromString(ex.muscleGroup);
        if (g == MuscleGroup.other || g == MuscleGroup.rest || g == MuscleGroup.forearms) {
          continue;
        }
        if (ex.targetForWeek(weekIdx).reps.isNotEmpty) {
          (result[g] ??= {}).add(day.dayIdx);
        }
      }
    }
    return result;
  }

  static String _formatWeeks(Set<int> weeks, int total) {
    if (weeks.length == total) return '';
    final sorted = weeks.toList()..sort();
    final isRange =
        sorted.length >= 3 && sorted.last - sorted.first == sorted.length - 1;
    if (isRange) return ' in weeks ${sorted.first + 1}–${sorted.last + 1}';
    return ' in week${sorted.length == 1 ? '' : 's'} ${sorted.map((w) => w + 1).join(', ')}';
  }

  static List<PlanAdvisory> validate(
    MesoImportData data, {
    required String experienceLevel,
    required String goal,
  }) {
    if (data.days.isEmpty) return [];

    final numWeeks = data.numWeeks;

    final scale = switch (experienceLevel) {
      'beginner' => 0.7,
      'advanced' => 1.15,
      _ => 1.0,
    };

    final advisories = <PlanAdvisory>[];

    final weekSets = [for (var w = 0; w < numWeeks; w++) setsForWeek(data, w)];
    final weekDays = [for (var w = 0; w < numWeeks; w++) _daysForWeek(data, w)];

    final trainingDayCount = data.days.where((d) => d.exercises.isNotEmpty).length;

    for (final g in _mev.keys) {
      final mev = (_mev[g]! * scale).round();
      final mrv = (_mrv[g]! * scale).round();

      final isMajor = _majorMuscles.contains(g);
      final isSecondary = _secondaryMajor.contains(g);
      final skipSecondary = isSecondary && experienceLevel == 'beginner';

      final zeroWeeks = <int>{};
      final belowMevWeeks = <int>{};
      final aboveMrvWeeks = <int>{};

      for (var w = 0; w < numWeeks; w++) {
        final sets = weekSets[w][g] ?? 0;
        if (sets == 0 && (isMajor || (isSecondary && !skipSecondary))) {
          zeroWeeks.add(w);
        } else if (sets > 0 && sets < mev) {
          belowMevWeeks.add(w);
        } else if (sets > mrv) {
          aboveMrvWeeks.add(w);
        }
      }

      if (zeroWeeks.isNotEmpty) {
        final suffix = _formatWeeks(zeroWeeks, numWeeks);
        advisories.add(PlanAdvisory(
          severity: AdvisorySeverity.warn,
          scope: g.name,
          message: 'No ${g.label} work$suffix.',
          source: 'volume',
        ));
      }
      if (belowMevWeeks.isNotEmpty) {
        final sets = weekSets[belowMevWeeks.first][g]!;
        final suffix = _formatWeeks(belowMevWeeks, numWeeks);
        advisories.add(PlanAdvisory(
          severity: AdvisorySeverity.warn,
          scope: g.name,
          message: '${g.label}: $sets sets — below MEV (~$mev)$suffix.',
          source: 'volume',
        ));
      }
      if (aboveMrvWeeks.isNotEmpty) {
        final sets = weekSets[aboveMrvWeeks.first][g]!;
        final suffix = _formatWeeks(aboveMrvWeeks, numWeeks);
        advisories.add(PlanAdvisory(
          severity: AdvisorySeverity.warn,
          scope: g.name,
          message: '${g.label}: $sets sets — above MRV (~$mrv)$suffix.',
          source: 'volume',
        ));
      }
    }

    if (trainingDayCount >= 4) {
      for (final g in _majorMuscles) {
        final lowFreqWeeks = <int>{};
        for (var w = 0; w < numWeeks; w++) {
          final sets = weekSets[w][g] ?? 0;
          final dayCount = weekDays[w][g]?.length ?? 0;
          if (sets > 0 && dayCount < 2) lowFreqWeeks.add(w);
        }
        if (lowFreqWeeks.isNotEmpty) {
          final suffix = _formatWeeks(lowFreqWeeks, numWeeks);
          advisories.add(PlanAdvisory(
            severity: AdvisorySeverity.info,
            scope: '${g.name}_freq',
            message: '${g.label} trained only 1×/wk$suffix — consider ≥2×/wk for hypertrophy.',
            source: 'volume',
          ));
        }
      }
    }

    if (goal != 'strength') {
      final tooPushWeeks = <int, double>{};
      final tooPullWeeks = <int, double>{};
      for (var w = 0; w < numWeeks; w++) {
        final s = weekSets[w];
        final pushSets = (s[MuscleGroup.chest] ?? 0) +
            (s[MuscleGroup.shoulders] ?? 0) +
            (s[MuscleGroup.triceps] ?? 0);
        final pullSets =
            (s[MuscleGroup.back] ?? 0) + (s[MuscleGroup.biceps] ?? 0);
        if (pushSets > 0 && pullSets > 0) {
          final ratio = pushSets / pullSets;
          if (ratio > 1.7) {
            tooPushWeeks[w] = ratio;
          } else if (ratio < 0.6) {
            tooPullWeeks[w] = pullSets / pushSets;
          }
        }
      }
      if (tooPushWeeks.isNotEmpty) {
        final ratio = tooPushWeeks.values.first;
        final suffix = _formatWeeks(tooPushWeeks.keys.toSet(), numWeeks);
        advisories.add(PlanAdvisory(
          severity: AdvisorySeverity.warn,
          scope: 'balance',
          message:
              'Push:pull ratio ${ratio.toStringAsFixed(1)}:1$suffix — consider adding pulling volume.',
          source: 'volume',
        ));
      }
      if (tooPullWeeks.isNotEmpty) {
        final pullRatio = tooPullWeeks.values.first;
        final suffix = _formatWeeks(tooPullWeeks.keys.toSet(), numWeeks);
        advisories.add(PlanAdvisory(
          severity: AdvisorySeverity.warn,
          scope: 'balance',
          message:
              'Pull:push ratio ${pullRatio.toStringAsFixed(1)}:1$suffix — consider adding pressing volume.',
          source: 'volume',
        ));
      }
    }

    return advisories;
  }
}

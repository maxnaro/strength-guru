import 'package:flutter/material.dart';

enum MuscleGroup {
  chest,
  shoulders,
  back,
  biceps,
  triceps,
  forearms,
  quads,
  hamstrings,
  glutes,
  abs,
  calves,
  other,
  rest
}

extension MuscleGroupX on MuscleGroup {
  String get label => switch (this) {
        MuscleGroup.chest => 'Chest',
        MuscleGroup.shoulders => 'Shoulders',
        MuscleGroup.back => 'Back',
        MuscleGroup.biceps => 'Biceps',
        MuscleGroup.triceps => 'Triceps',
        MuscleGroup.forearms => 'Forearms',
        MuscleGroup.quads => 'Quads',
        MuscleGroup.hamstrings => 'Hamstrings',
        MuscleGroup.glutes => 'Glutes',
        MuscleGroup.abs => 'Abs',
        MuscleGroup.calves => 'Calves',
        MuscleGroup.other => 'Other',
        MuscleGroup.rest => 'Rest',
      };

  String get title => switch (this) {
        MuscleGroup.chest => 'Chest day.',
        MuscleGroup.shoulders => 'Shoulders day.',
        MuscleGroup.back => 'Back day.',
        MuscleGroup.biceps => 'Biceps day.',
        MuscleGroup.triceps => 'Triceps day.',
        MuscleGroup.forearms => 'Forearms day.',
        MuscleGroup.quads => 'Quads day.',
        MuscleGroup.hamstrings => 'Hamstrings day.',
        MuscleGroup.glutes => 'Glutes day.',
        MuscleGroup.abs => 'Abs day.',
        MuscleGroup.calves => 'Calves day.',
        MuscleGroup.other => 'Workout day.',
        MuscleGroup.rest => 'Recovery day.',
      };

  // Olympic plate colors
  Color get color => switch (this) {
        MuscleGroup.chest => const Color(0xFFE89B9B),
        MuscleGroup.shoulders => const Color(0xFFE8B29B),
        MuscleGroup.back => const Color(0xFF9BB6E8),
        MuscleGroup.biceps => const Color(0xFF9BE8E8),
        MuscleGroup.triceps => const Color(0xFF9BE8B2),
        MuscleGroup.forearms => const Color(0xFFB2E89B),
        MuscleGroup.quads => const Color(0xFFEBD479),
        MuscleGroup.hamstrings => const Color(0xFFE89BD4),
        MuscleGroup.glutes => const Color(0xFFA8C9A0),
        MuscleGroup.abs => const Color(0xFFD4E89B),
        MuscleGroup.calves => const Color(0xFFC99BA8),
        MuscleGroup.other => const Color(0xFFE8E4DC),
        MuscleGroup.rest => const Color(0xFFC8C2B6),
      };

  Color tint(Brightness brightness) => brightness == Brightness.light
      ? _lightTints[this]!
      : _darkTints[this]!;

  static const _lightTints = {
    MuscleGroup.chest: Color(0xFFFBE9E9),
    MuscleGroup.shoulders: Color(0xFFFBF1E9),
    MuscleGroup.back: Color(0xFFE8EFFB),
    MuscleGroup.biceps: Color(0xFFE9FBFB),
    MuscleGroup.triceps: Color(0xFFE9FBF1),
    MuscleGroup.forearms: Color(0xFFF1FBE9),
    MuscleGroup.quads: Color(0xFFFBF4D9),
    MuscleGroup.hamstrings: Color(0xFFFBE9F5),
    MuscleGroup.glutes: Color(0xFFE6F1E1),
    MuscleGroup.abs: Color(0xFFF5FBE9),
    MuscleGroup.calves: Color(0xFFFBE9EF),
    MuscleGroup.other: Color(0xFFF2EEE5),
    MuscleGroup.rest: Color(0xFFEDE9DF),
  };

  static const _darkTints = {
    MuscleGroup.chest: Color(0xFF2A1818),
    MuscleGroup.shoulders: Color(0xFF2A2018),
    MuscleGroup.back: Color(0xFF182027),
    MuscleGroup.biceps: Color(0xFF182727),
    MuscleGroup.triceps: Color(0xFF182720),
    MuscleGroup.forearms: Color(0xFF202718),
    MuscleGroup.quads: Color(0xFF292412),
    MuscleGroup.hamstrings: Color(0xFF2A1825),
    MuscleGroup.glutes: Color(0xFF192218),
    MuscleGroup.abs: Color(0xFF252718),
    MuscleGroup.calves: Color(0xFF2A181E),
    MuscleGroup.other: Color(0xFF232118),
    MuscleGroup.rest: Color(0xFF1E1D1A),
  };

  static MuscleGroup fromString(String s) => MuscleGroup.values.firstWhere(
        (g) => g.name == s.toLowerCase(),
        orElse: () => switch (s.toLowerCase()) {
          'push' => MuscleGroup.chest,
          'pull' => MuscleGroup.back,
          'legs' => MuscleGroup.quads,
          'arms' => MuscleGroup.biceps,
          _ => MuscleGroup.other,
        },
      );

  static MuscleGroup primaryFromGroups(List<String> groups) {
    if (groups.isEmpty) return MuscleGroup.rest;
    final counts = <MuscleGroup, int>{};
    for (final gStr in groups) {
      final g = fromString(gStr);
      counts[g] = (counts[g] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

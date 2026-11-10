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
  rest,
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

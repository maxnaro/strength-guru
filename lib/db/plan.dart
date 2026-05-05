class DefaultPlan {
  // Day index: 0=Mon, 1=Tue, 2=Wed(rest), 3=Thu, 4=Fri, 5=Sat, 6=Sun(rest)
  static const Map<int, List<String>> _exercises = {
    0: [
      'Dips', 'Machine Shoulder Press', 'Cable Chest Flyes',
      'Dumbbell Lateral Raises', 'Cable Lateral Raises', 'Cable Rear Delt Flyes',
    ],
    1: [
      'Zercher Squat', 'Hack Squat', 'Quad Extensions',
      'Standing Calf Raises', 'Sissy Squats',
    ],
    2: [],
    3: [
      'Pull-ups', 'Pendlay Rows', 'Uni-lateral Lat Pulldowns',
      'Machine Rows', 'Lat Pullovers',
    ],
    4: [
      'Zercher Deadlifts', 'RDLs', 'Machine Hip Thrust',
      'Seated Hamstring Curls', 'Lying Hamstring Curls',
    ],
    5: [
      'Straight-bar Pushdowns', 'Overhead Extensions', 'Single-arm Extensions',
      'Hammer Curls', 'Preacher Curls', 'Single-arm Drag Curls',
    ],
    6: [],
  };

  static bool isRestDay(int dayIdx) => dayIdx == 2 || dayIdx == 6;

  static List<String> exerciseNamesForDay(int dayIdx) =>
      _exercises[dayIdx] ?? [];
}

// ── Exercise definitions ──────────────────────────────────────────────────────

class ExerciseDef {
  final String name;
  final String group; // MuscleGroup.name
  final int baseSets;
  final int baseReps;

  const ExerciseDef(this.name, this.group, this.baseSets, this.baseReps);
}

const kExercises = [
  // Day 1 — Chest & Shoulders (Mon)
  ExerciseDef('Dips', 'chest', 3, 12),
  ExerciseDef('Machine Shoulder Press', 'shoulders', 2, 15),
  ExerciseDef('Cable Chest Flyes', 'chest', 3, 15),
  ExerciseDef('Dumbbell Lateral Raises', 'shoulders', 3, 12),
  ExerciseDef('Cable Lateral Raises', 'shoulders', 3, 12),
  ExerciseDef('Cable Rear Delt Flyes', 'shoulders', 3, 20),
  // Day 2 — Quads & Calves (Tue)
  ExerciseDef('Zercher Squat', 'quads', 2, 12),
  ExerciseDef('Hack Squat', 'quads', 3, 15),
  ExerciseDef('Quad Extensions', 'quads', 2, 15),
  ExerciseDef('Standing Calf Raises', 'calves', 4, 20),
  ExerciseDef('Sissy Squats', 'quads', 3, 15),
  // Day 3 — Back (Thu)
  ExerciseDef('Pull-ups', 'back', 2, 12),
  ExerciseDef('Pendlay Rows', 'back', 3, 15),
  ExerciseDef('Uni-lateral Lat Pulldowns', 'back', 2, 15),
  ExerciseDef('Machine Rows', 'back', 2, 12),
  ExerciseDef('Lat Pullovers', 'back', 2, 15),
  // Day 4 — Glutes & Hamstrings (Fri)
  ExerciseDef('Zercher Deadlifts', 'hamstrings', 2, 12),
  ExerciseDef('RDLs', 'hamstrings', 2, 12),
  ExerciseDef('Machine Hip Thrust', 'glutes', 3, 16),
  ExerciseDef('Seated Hamstring Curls', 'hamstrings', 2, 16),
  ExerciseDef('Lying Hamstring Curls', 'hamstrings', 2, 20),
  // Day 5 — Triceps & Biceps (Sat)
  ExerciseDef('Straight-bar Pushdowns', 'triceps', 3, 12),
  ExerciseDef('Overhead Extensions', 'triceps', 3, 12),
  ExerciseDef('Single-arm Extensions', 'triceps', 2, 15),
  ExerciseDef('Hammer Curls', 'biceps', 3, 12),
  ExerciseDef('Preacher Curls', 'biceps', 3, 12),
  ExerciseDef('Single-arm Drag Curls', 'biceps', 2, 15),
];

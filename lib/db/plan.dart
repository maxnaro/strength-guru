class DefaultPlan {
  // Day index: 0=Mon, 1=Tue, 2=Wed(rest), 3=Thu, 4=Fri, 5=Sat, 6=Sun(rest)
  static const Map<int, List<String>> _exercises = {
    0: [
      'Dips', 'Dips', 'Machine Shoulder Press', 'Cable Chest Flyes',
      'Dumbbell Lateral Raises', 'Cable Lateral Raises', 'Cable Rear Delt Flyes',
    ],
    1: [
      'Zercher Squat', 'Zercher Squat', 'Hack Squat', 'Quad Extensions',
      'Standing Calf Raises', 'Sissy Squats',
    ],
    2: [],
    3: [
      'Pull-ups', 'Pull-ups', 'Pendlay Rows', 'Uni-lateral Lat Pulldowns',
      'Machine Rows', 'Lat Pullovers',
    ],
    4: [
      'Zercher Deadlifts', 'Zercher Deadlifts', 'RDLs', 'Machine Hip Thrust',
      'Seated Hamstring Curls', 'Lying Hamstring Curls',
    ],
    5: [
      'Straight-bar Pushdowns', 'Overhead Extensions', 'Single-arm Extensions',
      'Chin-ups', 'Preacher Curls', 'Single-arm Drag Curls',
    ],
    6: [],
  };

  static bool isRestDay(int dayIdx) => dayIdx == 2 || dayIdx == 6;

  static List<String> exerciseNamesForDay(int dayIdx) =>
      _exercises[dayIdx] ?? [];
}

// ── Exercise definitions ──────────────────────────────────────────────────────

class ExerciseDef {
  final String key;
  final String name;
  final String group; // MuscleGroup.name
  final int baseSets;
  final int baseReps;

  const ExerciseDef(this.key, this.name, this.group, this.baseSets, this.baseReps);
}

const kExercises = [
  // Day 1 — Chest & Shoulders
  ExerciseDef('dips', 'Dips', 'chest', 4, 12),
  ExerciseDef('machine_shoulder_press', 'Machine Shoulder Press', 'shoulders', 2, 15),
  ExerciseDef('barbell_shoulder_press', 'Barbell Shoulder Press', 'shoulders', 2, 15),
  ExerciseDef('cable_chest_flyes', 'Cable Chest Flyes', 'chest', 3, 15),
  ExerciseDef('dumbbell_chest_flyes', 'Dumbbell Chest Flyes', 'chest', 3, 15),
  ExerciseDef('dumbbell_lateral_raises', 'Dumbbell Lateral Raises', 'shoulders', 3, 12),
  ExerciseDef('cable_lateral_raises', 'Cable Lateral Raises', 'shoulders', 3, 12),
  ExerciseDef('cable_rear_delt_flyes', 'Cable Rear Delt Flyes', 'shoulders', 3, 20),
  ExerciseDef('dumbbell_rear_delt_flyes', 'Dumbbell Rear Delt Flyes', 'shoulders', 3, 20),
  // Day 2 — Quads & Calves
  ExerciseDef('zercher_squat', 'Zercher Squat', 'quads', 3, 12),
  ExerciseDef('smith_machine_squat', 'Smith Machine Squat', 'quads', 3, 15),
  ExerciseDef('hack_squat', 'Hack Squat', 'quads', 3, 15),
  ExerciseDef('quad_extensions', 'Quad Extensions', 'quads', 2, 15),
  ExerciseDef('standing_calf_raises', 'Standing Calf Raises', 'calves', 4, 20),
  ExerciseDef('sissy_squats', 'Sissy Squats', 'quads', 3, 99),
  // Day 3 — Back
  ExerciseDef('pull_ups', 'Pull-ups', 'back', 3, 12),
  ExerciseDef('pendlay_rows', 'Pendlay Rows', 'back', 3, 15),
  ExerciseDef('uni_lateral_lat_pulldowns', 'Uni-lateral Lat Pulldowns', 'back', 2, 15),
  ExerciseDef('machine_rows', 'Machine Rows', 'back', 2, 12),
  ExerciseDef('cable_rows', 'Cable Rows', 'back', 2, 12),
  ExerciseDef('lat_pullovers', 'Lat Pullovers', 'back', 2, 15),
  // Day 4 — Glutes & Hamstrings
  ExerciseDef('zercher_deadlifts', 'Zercher Deadlifts', 'hamstrings', 3, 12),
  ExerciseDef('rdls', 'RDLs', 'hamstrings', 2, 12),
  ExerciseDef('machine_hip_thrust', 'Machine Hip Thrust', 'glutes', 3, 16),
  ExerciseDef('seated_hamstring_curls', 'Seated Hamstring Curls', 'hamstrings', 2, 16),
  ExerciseDef('lying_hamstring_curls', 'Lying Hamstring Curls', 'hamstrings', 2, 20),
  // Day 5 — Triceps & Biceps
  ExerciseDef('straight_bar_pushdowns', 'Straight-bar Pushdowns', 'triceps', 3, 12),
  ExerciseDef('overhead_extensions', 'Overhead Extensions', 'triceps', 3, 12),
  ExerciseDef('single_arm_extensions', 'Single-arm Extensions', 'triceps', 2, 15),
  ExerciseDef('chin_ups', 'Chin-ups', 'biceps', 3, 12),
  ExerciseDef('preacher_curls', 'Preacher Curls', 'biceps', 3, 12),
  ExerciseDef('single_arm_drag_curls', 'Single-arm Drag Curls', 'biceps', 2, 15),
];



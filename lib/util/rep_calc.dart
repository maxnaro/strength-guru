enum RepFormula { epley, brzycki }

double estimate1Rm(double weight, int reps, int rir, RepFormula f) {
  final r = reps + rir;
  if (r <= 0) return weight;
  return switch (f) {
    RepFormula.epley => weight * (1 + r / 30.0),
    RepFormula.brzycki =>
      r >= 37 ? weight : weight * 36.0 / (37.0 - r),
  };
}

double weightForReps(double oneRm, int targetReps, int targetRir, RepFormula f) {
  final r = targetReps + targetRir;
  return switch (f) {
    RepFormula.epley => oneRm / (1 + r / 30.0),
    RepFormula.brzycki => oneRm * (37.0 - r) / 36.0,
  };
}

int repsForWeight(double oneRm, double weight, RepFormula f) {
  if (weight <= 0 || oneRm <= 0) return 0;
  final raw = switch (f) {
    RepFormula.epley => ((oneRm / weight) - 1) * 30,
    RepFormula.brzycki => 37 - 36 * weight / oneRm,
  };
  return raw.round().clamp(0, 50);
}

double roundToStep(double v, double step) => (v / step).round() * step;

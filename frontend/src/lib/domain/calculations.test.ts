import { describe, expect, it } from "vitest";
import fixtures from "./fixtures/dart-calculations.json";
import {
  estimate1Rm,
  weightForReps,
  repsForWeight,
  progression,
} from "./training";
describe("calculation parity with native Dart", () => {
  for (const [index, c] of fixtures.progression.entries()) {
    it(`progression fixture ${index}: ${c.weeks} weeks, deload ${c.deloads.join(",") || "none"}`, () => {
      expect(progression(c.config, c.weeks, c.deloads)).toEqual(c.expected);
    });
  }
  for (const [index, c] of fixtures.repCalculations.entries()) {
    it(`rep formula fixture ${index}: ${c.formula}, ${c.weight} × ${c.reps} @ ${c.rir} RIR`, () => {
      const one = estimate1Rm(c.weight, c.reps, c.rir, c.formula);
      expect(one).toBeCloseTo(c.oneRm, 9);
      expect(weightForReps(one, c.reps, c.rir, c.formula)).toBeCloseTo(
        c.targetWeight,
        9,
      );
      expect(repsForWeight(one, c.weight, c.formula)).toEqual(c.suggestedReps);
    });
  }
});

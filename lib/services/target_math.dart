import '../models/meso_import_data.dart';

class TargetMath {
  static int parseReps(String s) {
    final clean = s.trim().toUpperCase();
    if (clean == 'AMRAP') return 10;
    // Handle "1+" form — use base number
    final plusMatch = RegExp(r'^(\d+)\+').firstMatch(clean);
    if (plusMatch != null) return int.parse(plusMatch.group(1)!);
    // Range "8-10" → lowest
    final rangeMatch = RegExp(r'^(\d+)\s*[-–]\s*\d+').firstMatch(clean);
    if (rangeMatch != null) return int.parse(rangeMatch.group(1)!);
    // Plain integer
    final intMatch = RegExp(r'(\d+)').firstMatch(clean);
    if (intMatch != null) return int.parse(intMatch.group(1)!);
    return 8;
  }

  static int parseRir(String rpe) {
    if (rpe.trim().isEmpty) return 2;
    // Rest-time strings ("1-2 min", "3 min") — not RPE
    if (rpe.toLowerCase().contains('min')) return 2;
    final clean = rpe.trim().replaceAll('~', '').replaceAll('approx', '').trim();
    // Parse range "7-8" or "8.5-9" → take the max
    final rangeMatch =
        RegExp(r'(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)').firstMatch(clean);
    if (rangeMatch != null) {
      final max = double.parse(rangeMatch.group(2)!);
      // Max > 10 means it's a rep range (e.g. "10-12"), not RPE
      if (max > 10) return 2;
      return (10 - max).floor().clamp(0, 10);
    }
    // Plain number "9" or "8.5"
    final numMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(clean);
    if (numMatch != null) {
      final val = double.parse(numMatch.group(1)!);
      if (val > 10) return 2;
      return (10 - val).floor().clamp(0, 10);
    }
    return 2;
  }

  static int parseSets(String s) {
    final match = RegExp(r'(\d+)').firstMatch(s.trim());
    if (match != null) {
      final n = int.parse(match.group(1)!);
      return n < 1 ? 3 : n;
    }
    return 3;
  }

  static List<ImportWeekTarget> buildWeekTargets(
    List<({int weekIdx, String sets, String reps, String rpe})> weekRaw,
  ) {
    final results = <ImportWeekTarget>[];

    for (int i = 0; i < weekRaw.length; i++) {
      final w = weekRaw[i];
      final sets = parseSets(w.sets);
      final reps = parseReps(w.reps);
      int rir = parseRir(w.rpe);

      // Intensification bias: if rpe string identical for 3+ consecutive weeks,
      // decrement RIR by 1 starting at index 2.
      if (i >= 2) {
        final allSame = weekRaw
            .sublist(0, i + 1)
            .every((x) => x.rpe.trim() == weekRaw[0].rpe.trim());
        if (allSame) rir = (rir - 1).clamp(0, 10);
      }

      results.add(ImportWeekTarget(
        weekIdx: w.weekIdx,
        reps: List.filled(sets, reps),
        rir: List.filled(sets, rir),
      ));
    }

    return results;
  }
}

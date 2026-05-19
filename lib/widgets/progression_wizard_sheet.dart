import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';

// ── Public entry point ────────────────────────────────────────────────────────

void showExerciseProgressionWizard(
  BuildContext context, {
  required String mesoId,
  required int numWeeks,
  required String slotId,
  required String exerciseName,
  required MuscleGroup group,
  WeekTarget? initialTarget,
  Set<int> deloadWeeks = const {},
}) {
  showSGSheet<void>(
    context,
    isScrollControlled: true,
    maxHeightFraction: 0.92,
    child: ExerciseProgressionSheet(
      mesoId: mesoId,
      numWeeks: numWeeks,
      slotId: slotId,
      exerciseName: exerciseName,
      group: group,
      initialTarget: initialTarget,
      deloadWeeks: deloadWeeks,
    ),
  );
}

// ── Per-set config ────────────────────────────────────────────────────────────

class _SetConfig {
  int baseReps;
  int baseRir;
  int repsPerWeek;
  int rirPerWeek;

  _SetConfig({
    required this.baseReps,
    required this.baseRir,
    this.repsPerWeek = 0,
    this.rirPerWeek = 0,
  });

  _SetConfig copyWith({
    int? baseReps,
    int? baseRir,
    int? repsPerWeek,
    int? rirPerWeek,
  }) =>
      _SetConfig(
        baseReps: baseReps ?? this.baseReps,
        baseRir: baseRir ?? this.baseRir,
        repsPerWeek: repsPerWeek ?? this.repsPerWeek,
        rirPerWeek: rirPerWeek ?? this.rirPerWeek,
      );
}

// ── RIR helper ────────────────────────────────────────────────────────────────

// Number of non-deload weeks before weekIdx — mirrors progressionIdx in queries.
int _progIdx(int weekIdx, Set<int> deloadWeeks) {
  var idx = 0;
  for (var w = 0; w < weekIdx; w++) {
    if (!deloadWeeks.contains(w)) idx++;
  }
  return idx;
}

int _effectiveReps(_SetConfig config, int weekIdx, Set<int> deloadWeeks) {
  final isDeload = deloadWeeks.contains(weekIdx);
  final pIdx = _progIdx(weekIdx, deloadWeeks);
  final repsIdx = isDeload ? (pIdx - 1).clamp(0, 9999) : pIdx;
  return (config.baseReps + repsIdx * config.repsPerWeek).clamp(1, 99);
}

int _effectiveRir(_SetConfig config, int weekIdx, Set<int> deloadWeeks) {
  if (deloadWeeks.contains(weekIdx)) return 4;
  final pIdx = _progIdx(weekIdx, deloadWeeks);
  if (weekIdx > 0 && deloadWeeks.contains(weekIdx - 1)) {
    return (config.baseRir + (pIdx - 1).clamp(0, 9999) * config.rirPerWeek)
        .clamp(0, 5);
  }
  return (config.baseRir + pIdx * config.rirPerWeek).clamp(0, 5);
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class ExerciseProgressionSheet extends ConsumerStatefulWidget {
  final String mesoId;
  final int numWeeks;
  final String slotId;
  final String exerciseName;
  final MuscleGroup group;
  final WeekTarget? initialTarget;
  final Set<int> deloadWeeks;

  const ExerciseProgressionSheet({
    super.key,
    required this.mesoId,
    required this.numWeeks,
    required this.slotId,
    required this.exerciseName,
    required this.group,
    required this.initialTarget,
    this.deloadWeeks = const {},
  });

  @override
  ConsumerState<ExerciseProgressionSheet> createState() =>
      _ExerciseProgressionSheetState();
}

class _ExerciseProgressionSheetState
    extends ConsumerState<ExerciseProgressionSheet> {
  late List<_SetConfig> _sets;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTarget;
    if (t != null && t.reps.isNotEmpty) {
      _sets = List.generate(
        t.reps.length,
        (i) => _SetConfig(
          baseReps: t.reps[i],
          baseRir: t.rir.length > i ? t.rir[i] : 3,
        ),
      );
    } else {
      _sets = [_SetConfig(baseReps: 8, baseRir: 3)];
    }
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      final db = ref.read(dbProvider);
      await db.applyExerciseProgression(
        mesoId: widget.mesoId,
        numWeeks: widget.numWeeks,
        slotId: widget.slotId,
        sets: _sets
            .map((s) => (
                  baseReps: s.baseReps,
                  baseRir: s.baseRir,
                  repsPerWeek: s.repsPerWeek,
                  rirPerWeek: s.rirPerWeek,
                ))
            .toList(),
        deloadWeeks: widget.deloadWeeks,
      );
      for (var w = 0; w < widget.numWeeks; w++) {
        ref.invalidate(weekTargetsProvider(WeekKey(widget.mesoId, w)));
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final groupColor = widget.group.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────
        Row(children: [
          SGGroupDot(widget.group, size: 8),
          const SizedBox(width: 6),
          Text('PROGRESSION ARC',
              style: SGText.mono(11, color: p.textDim, ls: 1.0)),
        ]),
        const SizedBox(height: 6),
        Text(widget.exerciseName,
            style: SGText.display(20, color: p.text)),
        const SizedBox(height: 20),

        // ── Per-set configs ──────────────────────────────────────
        Text('SETS', style: SGText.mono(10, color: p.textFaint)),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (int i = 0; i < _sets.length; i++)
                  _SetRow(
                    index: i,
                    config: _sets[i],
                    groupColor: groupColor,
                    palette: p,
                    canDelete: _sets.length > 1,
                    onDelete: () => setState(() => _sets.removeAt(i)),
                    onChanged: (updated) =>
                        setState(() => _sets[i] = updated),
                  ),
                const SizedBox(height: 8),
                SGButton.ghost(
                  label: '+ Add set',
                  color: p.textDim,
                  onTap: () => setState(() => _sets.add(
                        _SetConfig(
                          baseReps: _sets.last.baseReps,
                          baseRir: _sets.last.baseRir,
                        ),
                      )),
                ),
                const SizedBox(height: 20),

                // ── Preview ──────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('PREVIEW',
                      style: SGText.mono(10, color: p.textFaint)),
                ),
                const SizedBox(height: 8),
                _ProgressionPreview(
                  numWeeks: widget.numWeeks,
                  sets: _sets,
                  groupColor: groupColor,
                  palette: p,
                  deloadWeeks: widget.deloadWeeks,
                ),
                const SizedBox(height: 20),
                SGButton.solid(
                  label: _applying ? 'Applying…' : 'Apply Arc',
                  color: groupColor,
                  fullWidth: true,
                  onTap: _applying ? null : _apply,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Set row ───────────────────────────────────────────────────────────────────

class _SetRow extends StatelessWidget {
  final int index;
  final _SetConfig config;
  final Color groupColor;
  final SGPalette palette;
  final bool canDelete;
  final VoidCallback onDelete;
  final ValueChanged<_SetConfig> onChanged;

  const _SetRow({
    required this.index,
    required this.config,
    required this.groupColor,
    required this.palette,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.chipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Set label + delete
          Row(children: [
            Text('SET ${index + 1}',
                style: SGText.mono(10, color: palette.textFaint)),
            const Spacer(),
            if (canDelete)
              GestureDetector(
                onTap: onDelete,
                child:
                    Icon(Icons.close, size: 16, color: palette.textFaint),
              ),
          ]),
          const SizedBox(height: 10),

          // W1 reps + RIR
          Row(children: [
            Expanded(
              child: SGStepper(
                value: config.baseReps,
                min: 1,
                max: 99,
                step: 1,
                label: 'W1 REPS',
                accentColor: groupColor,
                onChanged: (v) =>
                    onChanged(config.copyWith(baseReps: v.toInt())),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SGStepper(
                value: config.baseRir,
                min: 0,
                max: 5,
                step: 1,
                label: 'W1 RIR',
                accentColor: groupColor,
                onChanged: (v) =>
                    onChanged(config.copyWith(baseRir: v.toInt())),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Progression per week
          Text('WEEKLY CHANGE',
              style: SGText.mono(9, color: palette.textFaint)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: SGStepper(
                value: config.repsPerWeek,
                min: -5,
                max: 5,
                step: 1,
                label: 'REPS/WK',
                accentColor: groupColor,
                onChanged: (v) =>
                    onChanged(config.copyWith(repsPerWeek: v.toInt())),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SGStepper(
                value: config.rirPerWeek,
                min: -3,
                max: 3,
                step: 1,
                label: 'RIR/WK',
                accentColor: groupColor,
                onChanged: (v) =>
                    onChanged(config.copyWith(rirPerWeek: v.toInt())),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Progression preview ───────────────────────────────────────────────────────

class _ProgressionPreview extends StatelessWidget {
  final int numWeeks;
  final List<_SetConfig> sets;
  final Color groupColor;
  final SGPalette palette;
  final Set<int> deloadWeeks;

  const _ProgressionPreview({
    required this.numWeeks,
    required this.sets,
    required this.groupColor,
    required this.palette,
    this.deloadWeeks = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(numWeeks, (w) {
          final isDeload = deloadWeeks.contains(w);
          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: palette.chipBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDeload
                    ? palette.warn.withValues(alpha: 0.4)
                    : palette.border,
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('W${w + 1}',
                        style: SGText.mono(9, color: palette.textFaint)),
                    if (isDeload) ...[
                      const SizedBox(width: 4),
                      Text('DL',
                          style: SGText.mono(8, color: palette.warn)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                for (int i = 0; i < sets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _WeekSetChip(
                    setIdx: i,
                    weekIdx: w,
                    config: sets[i],
                    groupColor: groupColor,
                    palette: palette,
                    deloadWeeks: deloadWeeks,
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _WeekSetChip extends StatelessWidget {
  final int setIdx;
  final int weekIdx;
  final _SetConfig config;
  final Color groupColor;
  final SGPalette palette;
  final Set<int> deloadWeeks;

  const _WeekSetChip({
    required this.setIdx,
    required this.weekIdx,
    required this.config,
    required this.groupColor,
    required this.palette,
    this.deloadWeeks = const {},
  });

  @override
  Widget build(BuildContext context) {
    final reps = _effectiveReps(config, weekIdx, deloadWeeks);
    final rir = _effectiveRir(config, weekIdx, deloadWeeks);
    final isDeload = deloadWeeks.contains(weekIdx);
    final hasProgression = config.repsPerWeek != 0 || config.rirPerWeek != 0;
    final valueColor = isDeload
        ? palette.warn
        : (hasProgression ? groupColor : palette.textDim);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'S${setIdx + 1} ',
          style: SGText.mono(8, color: palette.textFaint),
        ),
        Text(
          '$reps@$rir',
          style: SGText.body(12,
              color: valueColor,
              weight: (hasProgression || isDeload)
                  ? FontWeight.w600
                  : FontWeight.normal),
        ),
      ],
    );
  }
}

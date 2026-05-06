import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';

class MesoEditSheet extends ConsumerStatefulWidget {
  final String mesoId;
  final int weekIdx;
  final int numWeeks;
  final String exerciseId;
  final String exerciseName;
  final MuscleGroup group;
  final WeekTarget? initialTarget;

  const MesoEditSheet({
    super.key,
    required this.mesoId,
    required this.weekIdx,
    required this.numWeeks,
    required this.exerciseId,
    required this.exerciseName,
    required this.group,
    required this.initialTarget,
  });

  @override
  ConsumerState<MesoEditSheet> createState() => _MesoEditSheetState();
}

class _MesoEditSheetState extends ConsumerState<MesoEditSheet> {
  late int _sets;
  late int _reps;
  late int _rir;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sets = widget.initialTarget?.sets ?? 3;
    _reps = widget.initialTarget?.reps ?? 8;
    _rir = widget.initialTarget?.rir ?? 3;
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final groupColor = widget.group.color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow
        Row(children: [
          SGGroupDot(widget.group, size: 8),
          const SizedBox(width: 6),
          Text(
            'WEEK ${widget.weekIdx + 1}',
            style: SGText.mono(11, color: p.textDim),
          ),
        ]),
        const SizedBox(height: 6),
        Text(widget.exerciseName,
            style: SGText.display(20, color: p.text)),
        const SizedBox(height: 20),
        // Steppers
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SGStepper(
              value: _sets,
              min: 1,
              max: 10,
              step: 1,
              label: 'SETS',
              accentColor: groupColor,
              onChanged: (v) => setState(() => _sets = v.toInt()),
            ),
            const SizedBox(height: 10),
            SGStepper(
              value: _reps,
              min: 1,
              max: 30,
              step: 1,
              label: 'REPS',
              accentColor: groupColor,
              onChanged: (v) => setState(() => _reps = v.toInt()),
            ),
            const SizedBox(height: 10),
            SGStepper(
              value: _rir,
              min: 0,
              max: 5,
              step: 1,
              label: 'RIR',
              accentColor: groupColor,
              onChanged: (v) => setState(() => _rir = v.toInt()),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Apply to all weeks
        SGButton.ghost(
          label: 'Apply to all weeks →',
          color: p.textDim,
          fullWidth: true,
          onTap: _saving ? null : () => _save(applyForward: true),
        ),
        const SizedBox(height: 10),
        // Done
        SGButton.solid(
          label: 'Done',
          color: widget.group.color,
          fullWidth: true,
          onTap: _saving ? null : () => _save(applyForward: false),
        ),
      ],
    );
  }

  Future<void> _save({required bool applyForward}) async {
    setState(() => _saving = true);
    try {
      final db = ref.read(dbProvider);
      if (applyForward) {
        await db.applyWeekTargetForward(
          mesoId: widget.mesoId,
          fromWeekIdx: widget.weekIdx,
          numWeeks: widget.numWeeks,
          exerciseId: widget.exerciseId,
          sets: _sets,
          reps: _reps,
          rir: _rir,
        );
      } else {
        await db.upsertWeekTarget(
          mesoId: widget.mesoId,
          weekIdx: widget.weekIdx,
          exerciseId: widget.exerciseId,
          sets: _sets,
          reps: _reps,
          rir: _rir,
        );
      }
      // Invalidate all week target caches for this meso.
      for (var w = 0; w < widget.numWeeks; w++) {
        ref.invalidate(weekTargetsProvider(WeekKey(widget.mesoId, w)));
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

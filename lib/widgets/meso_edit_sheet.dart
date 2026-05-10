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
  final String slotId;
  final String exerciseName;
  final MuscleGroup group;
  final WeekTarget? initialTarget;

  const MesoEditSheet({
    super.key,
    required this.mesoId,
    required this.weekIdx,
    required this.numWeeks,
    required this.slotId,
    required this.exerciseName,
    required this.group,
    required this.initialTarget,
  });

  @override
  ConsumerState<MesoEditSheet> createState() => _MesoEditSheetState();
}

class _MesoEditSheetState extends ConsumerState<MesoEditSheet> {
  late List<int> _reps;
  late List<int> _rir;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reps = widget.initialTarget?.reps ?? [8, 8, 8];
    _rir = widget.initialTarget?.rir ?? [3, 3, 3];
  }

  void _updateSets(int count) {
    setState(() {
      if (count > _reps.length) {
        // Grow
        final lastReps = _reps.lastOrNull ?? 8;
        final lastRir = _rir.lastOrNull ?? 3;
        _reps.addAll(List.filled(count - _reps.length, lastReps));
        _rir.addAll(List.filled(count - _rir.length, lastRir));
      } else if (count < _reps.length) {
        // Shrink
        _reps = _reps.take(count).toList();
        _rir = _rir.take(count).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final groupColor = widget.group.color;
    final allSame = _reps.every((r) => r == _reps.first) &&
        _rir.every((r) => r == _rir.first);

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
        const SizedBox(height: 16),

        SGStepper(
          value: _reps.length,
          min: 1,
          max: 10,
          step: 1,
          label: 'SETS',
          accentColor: groupColor,
          onChanged: (v) => _updateSets(v.toInt()),
        ),
        const SizedBox(height: 16),

        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (int i = 0; i < _reps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text('SET ${i + 1}',
                              style: SGText.mono(10, color: p.textFaint)),
                        ),
                        Expanded(
                          child: SGStepper(
                            value: _reps[i],
                            min: 1,
                            max: 99,
                            step: 1,
                            label: 'REPS',
                            accentColor: groupColor,
                            onChanged: (v) =>
                                setState(() => _reps[i] = v.toInt()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SGStepper(
                            value: _rir[i],
                            min: 0,
                            max: 5,
                            step: 1,
                            label: 'RIR',
                            accentColor: groupColor,
                            onChanged: (v) =>
                                setState(() => _rir[i] = v.toInt()),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (_reps.length > 1 && !allSame)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SGButton.ghost(
              label: 'Make all sets same as Set 1',
              color: p.textDim,
              fullWidth: true,
              onTap: () => setState(() {
                _reps = List.filled(_reps.length, _reps.first);
                _rir = List.filled(_rir.length, _rir.first);
              }),
            ),
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
          slotId: widget.slotId,
          reps: _reps,
          rir: _rir,
        );
      } else {
        await db.upsertWeekTarget(
          mesoId: widget.mesoId,
          weekIdx: widget.weekIdx,
          slotId: widget.slotId,
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

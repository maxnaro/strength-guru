import 'package:flutter/material.dart';

import '../models/meso_import_data.dart';
import '../theme/groups.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';

class ImportWeekEditSheet extends StatefulWidget {
  final ImportExercise ex;
  final int weekIdx;
  final int numWeeks;
  final MuscleGroup group;
  final VoidCallback onChanged;

  const ImportWeekEditSheet({
    super.key,
    required this.ex,
    required this.weekIdx,
    required this.numWeeks,
    required this.group,
    required this.onChanged,
  });

  @override
  State<ImportWeekEditSheet> createState() => _ImportWeekEditSheetState();
}

class _ImportWeekEditSheetState extends State<ImportWeekEditSheet> {
  late List<int> _reps;
  late List<int> _rir;

  @override
  void initState() {
    super.initState();
    final t = widget.ex.targetForWeek(widget.weekIdx);
    _reps = List.of(t.reps);
    _rir = List.of(t.rir);
  }

  void _updateSets(int count) {
    setState(() {
      if (count > _reps.length) {
        final lastReps = _reps.lastOrNull ?? 8;
        final lastRir = _rir.lastOrNull ?? 2;
        _reps.addAll(List.filled(count - _reps.length, lastReps));
        _rir.addAll(List.filled(count - _rir.length, lastRir));
      } else if (count < _reps.length) {
        _reps = _reps.take(count).toList();
        _rir = _rir.take(count).toList();
      }
    });
  }

  void _apply({required bool forward}) {
    final end = forward ? widget.numWeeks - 1 : widget.weekIdx;
    for (var w = widget.weekIdx; w <= end; w++) {
      widget.ex.setWeekTarget(
        ImportWeekTarget(weekIdx: w, reps: List.of(_reps), rir: List.of(_rir)),
      );
    }
    widget.onChanged();
    Navigator.of(context).pop();
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
        Row(children: [
          SGGroupDot(widget.group, size: 8),
          const SizedBox(width: 6),
          Text(
            'WEEK ${widget.weekIdx + 1}',
            style: SGText.mono(11, color: p.textDim),
          ),
        ]),
        const SizedBox(height: 6),
        Text(widget.ex.name, style: SGText.display(20, color: p.text)),
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
        SGButton.ghost(
          label: 'Apply to all weeks →',
          color: p.textDim,
          fullWidth: true,
          onTap: () => _apply(forward: true),
        ),
        const SizedBox(height: 10),
        SGButton.solid(
          label: 'Done',
          color: groupColor,
          fullWidth: true,
          onTap: () => _apply(forward: false),
        ),
      ],
    );
  }
}

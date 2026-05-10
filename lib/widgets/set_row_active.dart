import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/tokens.dart';
import '../theme/sg_atoms.dart';

class SetRowActive extends ConsumerStatefulWidget {
  final int setIndex;
  final String exerciseId;
  final String slotId;
  final String? sessionId;
  final int targetReps;
  final int targetRir;
  final double? suggestedWeight;
  final SetEntry? initialEntry;
  final SetEntry? recentSessionEntry;
  final MuscleGroup group;
  final Future<void> Function(double? weight, int reps, int rir) onLogSet;

  const SetRowActive({
    super.key,
    required this.setIndex,
    required this.exerciseId,
    required this.slotId,
    required this.sessionId,
    required this.targetReps,
    required this.targetRir,
    required this.suggestedWeight,
    this.initialEntry,
    this.recentSessionEntry,
    required this.group,
    required this.onLogSet,
  });

  @override
  ConsumerState<SetRowActive> createState() => _SetRowActiveState();
}

class _SetRowActiveState extends ConsumerState<SetRowActive> {
  late double? _weight;
  late int _reps;
  late int _selectedRir;
  bool _showRirPicker = false;
  bool _logging = false;
  bool _userHasManuallyPickedRir = false;

  @override
  void initState() {
    super.initState();
    _weight = widget.initialEntry?.weight ?? widget.recentSessionEntry?.weight ?? widget.suggestedWeight;
    _reps = widget.initialEntry?.reps ?? widget.recentSessionEntry?.reps ?? widget.targetReps;
    _selectedRir = widget.initialEntry?.rir ?? widget.recentSessionEntry?.rir ?? widget.targetRir;
  }

  @override
  void didUpdateWidget(SetRowActive old) {
    super.didUpdateWidget(old);
    if (old.suggestedWeight == null && widget.suggestedWeight != null) {
      _weight = widget.suggestedWeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final brightness = Theme.of(context).brightness;
    final groupColor = widget.group.color;
    final groupTint = widget.group.tint(brightness);

    // Suggested set (first set of last session)
    final suggKey = PrevSetKey(
        widget.exerciseId, 0, widget.sessionId);
    final suggAsync = ref.watch(suggestedSetProvider(suggKey));
    final sugg = suggAsync.valueOrNull;

    final hintWeight = sugg?.weight != null ? _fmt(sugg!.weight!) : null;
    final hintReps = sugg?.reps?.toString();
    final hintRir = sugg?.rir?.toString();

    // Auto-initialize if values are null and suggestion becomes available
    if (_weight == null && sugg?.weight != null && widget.recentSessionEntry == null) {
      _weight = sugg!.weight;
    }
    // Only default reps if current reps match the target (user hasn't changed it)
    if (_reps == widget.targetReps && sugg?.reps != null && sugg!.reps != widget.targetReps && widget.recentSessionEntry == null) {
       _reps = sugg.reps!;
    }
    // Only default RIR if it hasn't been adjusted
    if (!_showRirPicker && !_userHasManuallyPickedRir && _selectedRir == widget.targetRir && sugg?.rir != null && widget.recentSessionEntry == null) {
      _selectedRir = sugg!.rir!;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: groupTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: groupColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${widget.setIndex + 1}',
                    style: SGText.mono(11, color: groupColor)),
              ),
            ),
            const SizedBox(width: 8),
            Text('Set ${widget.setIndex + 1}',
                style: SGText.body(13, weight: FontWeight.w600, color: p.text)),
            const Spacer(),
            Flexible(
              child: Text(
                'TARGET ${widget.targetReps} reps · RIR ${widget.targetRir}',
                style: SGText.mono(10, color: p.textDim),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (sugg != null) ...[
            Text(
              'Last: ${hintWeight != null ? "${hintWeight}kg" : "—"} x '
              '${hintReps ?? "—"} · '
              'RIR ${hintRir ?? "—"}',
              style: SGText.body(12,
                  color: p.textFaint, style: FontStyle.italic),
            ),
            const SizedBox(height: 10),
          ],
          // Steppers
          Row(
            children: [
              Expanded(
                child: SGStepper(
                  value: _weight ?? 0,
                  min: 0,
                  max: 500,
                  step: 2.5,
                  label: 'WEIGHT (KG)',
                  accentColor: groupColor,
                  onChanged: (v) => setState(() => _weight = v.toDouble()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SGStepper(
                  value: _reps,
                  min: 1,
                  max: 50,
                  step: 1,
                  label: 'REPS',
                  accentColor: groupColor,
                  onChanged: (v) => setState(() => _reps = v.toInt()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // RIR section
          if (!_showRirPicker)
            Row(children: [
              GestureDetector(
                onTap: () => setState(() => _showRirPicker = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Adjust RIR',
                      style: SGText.body(13, color: p.textDim)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _logging ? null : _handleLogSet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: groupColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text('Log set',
                              style: SGText.body(15,
                                  weight: FontWeight.w700,
                                  color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RIR $_selectedRir',
                            style: SGText.mono(9, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ])
          else
            _RirPicker(
              selectedRir: _selectedRir,
              targetRir: widget.targetRir,
              groupColor: groupColor,
              onSelect: (rir) =>
                  setState(() {
                    _selectedRir = rir;
                    _showRirPicker = false;
                    _userHasManuallyPickedRir = true;
                  }),
            ),
        ],
      ),
    );
  }

  Future<void> _handleLogSet() async {
    setState(() => _logging = true);
    try {
      await widget.onLogSet(_weight, _reps, _selectedRir);
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

class _RirPicker extends StatelessWidget {
  final int selectedRir;
  final int targetRir;
  final Color groupColor;
  final ValueChanged<int> onSelect;

  const _RirPicker({
    required this.selectedRir,
    required this.targetRir,
    required this.groupColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ADJUST RIR', style: SGText.mono(10, color: p.textFaint)),
        const SizedBox(height: 6),
        Row(
          children: List.generate(6, (i) {
            final isPlan = i == targetRir;
            final isSelected = i == selectedRir;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  margin: EdgeInsets.only(right: i < 5 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? groupColor.withValues(alpha: 0.2)
                        : p.chipBg,
                    borderRadius: BorderRadius.circular(10),
                    border: isPlan
                        ? Border.all(color: groupColor, width: 1.5)
                        : isSelected
                            ? Border.all(color: groupColor, width: 1.5)
                            : null,
                  ),
                  child: Column(
                    children: [
                      Text('$i',
                          style: SGText.display(16,
                              color: isSelected ? groupColor : p.text)),
                      if (isPlan)
                        Text('PLAN',
                            style: SGText.mono(7, color: groupColor)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

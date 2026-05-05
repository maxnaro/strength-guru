import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/tokens.dart';
import '../theme/sg_atoms.dart';
import 'exercise_picker.dart';

enum SwapScope { sessionOnly, weekForward }

class SwapMenu extends ConsumerStatefulWidget {
  final Exercise currentExercise;
  final DayKey dayKey;
  final Mesocycle meso;
  final VoidCallback onSwapped;

  const SwapMenu({
    super.key,
    required this.currentExercise,
    required this.dayKey,
    required this.meso,
    required this.onSwapped,
  });

  @override
  ConsumerState<SwapMenu> createState() => _SwapMenuState();
}

class _SwapMenuState extends ConsumerState<SwapMenu> {
  SwapScope _scope = SwapScope.sessionOnly;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final currentGroup = MuscleGroupX.fromString(widget.currentExercise.group);
    final planIds = ref
        .watch(dayPlanProvider(widget.dayKey))
        .valueOrNull
        ?.map((e) => e.id)
        .toSet() ?? {};
    // Exclude all exercises currently in plan except the one being swapped out.
    final excludeIds = planIds..remove(widget.currentExercise.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Swap Exercise', style: SGText.display(20, color: p.text)),
        const SizedBox(height: 12),
        _ScopeToggle(
          selected: _scope,
          onChanged: (s) => setState(() => _scope = s),
          palette: p,
        ),
        const SizedBox(height: 16),
        ExercisePicker(
          defaultGroup: currentGroup,
          excludeIds: excludeIds,
          onSelected: _handleSwap,
        ),
        const SizedBox(height: 16),
        SGButton.ghost(
          label: 'Cancel',
          fullWidth: true,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _handleSwap(Exercise newExercise) async {
    final db = ref.read(dbProvider);
    final key = widget.dayKey;

    // Fetch current exercise list (with overrides applied).
    final currentList = await ref.read(dayPlanProvider(key).future);
    final newIds = currentList
        .map((ex) => ex.id == widget.currentExercise.id ? newExercise.id : ex.id)
        .toList();

    if (_scope == SwapScope.sessionOnly) {
      await db.setDayOverride(key.mesoId, key.weekIdx, key.dayIdx, newIds);
    } else {
      await db.setWeekForwardOverride(
          key.mesoId, key.weekIdx, widget.meso.numWeeks, key.dayIdx, newIds);
    }

    ref.invalidate(dayPlanProvider(key));

    if (mounted) {
      Navigator.of(context).pop();
      widget.onSwapped();
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ScopeToggle extends StatelessWidget {
  final SwapScope selected;
  final ValueChanged<SwapScope> onChanged;
  final SGPalette palette;

  const _ScopeToggle({
    required this.selected,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _ToggleItem(
            label: 'This session',
            selected: selected == SwapScope.sessionOnly,
            palette: palette,
            onTap: () => onChanged(SwapScope.sessionOnly),
          ),
          _ToggleItem(
            label: 'Week + forward',
            selected: selected == SwapScope.weekForward,
            palette: palette,
            onTap: () => onChanged(SwapScope.weekForward),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final bool selected;
  final SGPalette palette;
  final VoidCallback onTap;

  const _ToggleItem({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label,
                style: SGText.body(13,
                    weight: FontWeight.w600,
                    color: selected ? palette.text : palette.textDim)),
          ),
        ),
      ),
    );
  }
}

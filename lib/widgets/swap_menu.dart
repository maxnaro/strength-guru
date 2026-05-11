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
  final String slotId;
  final DayKey dayKey;
  final Mesocycle meso;
  final VoidCallback onSwapped;

  const SwapMenu({
    super.key,
    required this.currentExercise,
    required this.slotId,
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
    
    // In the new slot-based architecture, we don't necessarily need to exclude 
    // the same exercise because we allow duplicates. 
    // However, for the picker, excluding the *exact* same exercise is still reasonable.
    final excludeIds = <String>{}; 

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

    // 1. Create a NEW slot for the new exercise
    final newSlot = await db.createExerciseSlot(widget.meso.id, newExercise.id);

    // 2. Baseline targets from the old slot
    final oldTarget = await db.getWeekTarget(widget.meso.id, key.weekIdx, widget.slotId);
    if (oldTarget != null) {
      if (_scope == SwapScope.sessionOnly) {
        await db.upsertWeekTarget(
          mesoId: widget.meso.id,
          weekIdx: key.weekIdx,
          slotId: newSlot.id,
          reps: oldTarget.reps,
          rir: oldTarget.rir,
        );
      } else {
        await db.applyWeekTargetForward(
          mesoId: widget.meso.id,
          fromWeekIdx: key.weekIdx,
          numWeeks: widget.meso.numWeeks,
          slotId: newSlot.id,
          reps: oldTarget.reps,
          rir: oldTarget.rir,
        );
      }
    }

    // 3. Fetch current slot list for this day and swap the ID
    final currentItems = await ref.read(dayPlanProvider(key).future);
    final newSlotIds = currentItems
        .map((item) => item.slot.id == widget.slotId ? newSlot.id : item.slot.id)
        .toList();

    if (_scope == SwapScope.sessionOnly) {
      await db.setDayOverride(key.mesoId, key.weekIdx, key.dayIdx, newSlotIds);
    } else {
      await db.setWeekForwardOverride(
          key.mesoId, key.weekIdx, widget.meso.numWeeks, key.dayIdx, newSlotIds);
      if (key.weekIdx == 0) {
        await db.setDayOverride(key.mesoId, -1, key.dayIdx, newSlotIds);
      }
    }

    if (_scope == SwapScope.sessionOnly) {
      ref.invalidate(dayPlanProvider(key));
      ref.invalidate(weekTargetsProvider(WeekKey(key.mesoId, key.weekIdx)));
    } else {
      // Invalidate the timeline program view
      ref.invalidate(programDayExercisesProvider(
          ProgramDayKey(key.mesoId, key.dayIdx)));

      // Invalidate all forward weeks
      for (int w = key.weekIdx; w < widget.meso.numWeeks; w++) {
        ref.invalidate(dayPlanProvider(DayKey(key.mesoId, w, key.dayIdx)));
        ref.invalidate(weekTargetsProvider(WeekKey(key.mesoId, w)));
      }
    }

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

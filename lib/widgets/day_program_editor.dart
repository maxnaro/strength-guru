import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';
import 'exercise_picker.dart';

class DayProgramEditor extends ConsumerStatefulWidget {
  final Mesocycle meso;
  final int dayIdx;

  const DayProgramEditor({
    super.key,
    required this.meso,
    required this.dayIdx,
  });

  @override
  ConsumerState<DayProgramEditor> createState() => _DayProgramEditorState();
}

class _DayProgramEditorState extends ConsumerState<DayProgramEditor> {
  List<Exercise>? _exercises;
  bool _initialized = false;
  late TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final key = ProgramDayKey(widget.meso.id, widget.dayIdx);
    final asyncExs = ref.watch(programDayExercisesProvider(key));
    final daySettingsAsync = ref.watch(programDayProvider(key));

    if (!_initialized && asyncExs.hasValue && daySettingsAsync.hasValue) {
      _exercises = List.from(asyncExs.value!);
      _labelController.text = daySettingsAsync.value?.label ?? '';
      _initialized = true;
    }

    if (_exercises == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'EDITING DAY ${widget.dayIdx + 1}',
              style: SGText.mono(12, color: p.textFaint),
            ),
            const Spacer(),
            TextButton(
              onPressed: _resetToDefault,
              child: Text('Reset to default',
                  style: SGText.mono(11, color: p.warn)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _labelController,
          style: SGText.display(24, color: p.text),
          decoration: InputDecoration(
            hintText: 'Split Name (e.g. Chest & Shoulders)',
            hintStyle: SGText.display(24, color: p.textFaint),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 16),
        ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = _exercises!.removeAt(oldIdx);
                _exercises!.insert(newIdx, item);
              });
            },
            children: [
              for (int i = 0; i < _exercises!.length; i++)
                _DraggableRow(
                  key: ValueKey('${_exercises![i].id}_$i'),
                  index: i,
                  exercise: _exercises![i],
                  onDelete: () => setState(() => _exercises!.removeAt(i)),
                ),
            ],
          ),
        const SizedBox(height: 12),
        SGButton.ghost(
          label: '+ Add exercise',
          onTap: _showPicker,
        ),
        const SizedBox(height: 24),
        SGButton.solid(
          label: 'Save Changes',
          onTap: _save,
          fullWidth: true,
        ),
      ],
    );
  }

  void _resetToDefault() async {
    final db = ref.read(dbProvider);
    await db.clearProgramDay(widget.meso.id, widget.dayIdx);
    _invalidate();
    if (mounted) Navigator.pop(context);
  }

  void _showPicker() {
    showSGSheet(
      context,
      maxHeightFraction: 0.8,
      child: ExercisePicker(
        defaultGroup: MuscleGroup.values[widget.dayIdx % 6], // fallback
        excludeIds: _exercises!.map((e) => e.id).toSet(),
        onSelected: (ex) {
          if (_exercises!.any((e) => e.id == ex.id)) {
            Navigator.pop(context);
            return;
          }
          setState(() => _exercises!.add(ex));
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _save() async {
    final db = ref.read(dbProvider);

    // Check for clobbering week overrides
    List<int> clobberedWeeks = [];
    for (int w = 1; w < widget.meso.numWeeks; w++) {
      final ov = await db.getDayOverride(widget.meso.id, w, widget.dayIdx);
      if (ov != null) clobberedWeeks.add(w + 1);
    }

    if (clobberedWeeks.isNotEmpty && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: pal(ctx).surface,
          title: Text('Overwrite Overrides?',
              style: SGText.display(18, color: pal(ctx).text)),
          content: Text(
            'This day has custom swaps in weeks ${clobberedWeeks.join(', ')}. Saving this program will overwrite them. Continue?',
            style: SGText.body(14, color: pal(ctx).textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: SGText.body(14, color: pal(ctx).textFaint)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('Overwrite', style: SGText.body(14, color: pal(ctx).warn)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final ids = _exercises!.map((e) => e.id).toList();
    await db.setWeekForwardOverride(
      widget.meso.id,
      0,
      widget.meso.numWeeks,
      widget.dayIdx,
      ids,
    );

    await db.upsertProgramDay(
      widget.meso.id,
      widget.dayIdx,
      _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
    );

    _invalidate();
    if (mounted) Navigator.pop(context);
  }

  void _invalidate() {
    final key = ProgramDayKey(widget.meso.id, widget.dayIdx);
    ref.invalidate(programDayExercisesProvider(key));
    ref.invalidate(programDayProvider(key));
    for (int w = 0; w < widget.meso.numWeeks; w++) {
      ref.invalidate(dayPlanProvider(DayKey(widget.meso.id, w, widget.dayIdx)));
      ref.invalidate(weekTargetsProvider(WeekKey(widget.meso.id, w)));
      ref.invalidate(sessionLogProvider(DayKey(widget.meso.id, w, widget.dayIdx)));
    }
  }
}

class _DraggableRow extends StatelessWidget {
  final int index;
  final Exercise exercise;
  final VoidCallback onDelete;

  const _DraggableRow({
    super.key,
    required this.index,
    required this.exercise,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final group = MuscleGroupX.fromString(exercise.group);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_indicator, color: p.textFaint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: SGText.body(16, color: p.text)),
                Text(group.label.toUpperCase(),
                    style: SGText.mono(10, color: p.textFaint)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: p.textFaint, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';

class ExercisePicker extends ConsumerStatefulWidget {
  final MuscleGroup defaultGroup;
  final Set<String> excludeIds;
  final ValueChanged<Exercise> onSelected;

  const ExercisePicker({
    super.key,
    required this.defaultGroup,
    this.excludeIds = const {},
    required this.onSelected,
  });

  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  final _nameCtrl = TextEditingController();
  late MuscleGroup _pickedGroup = widget.defaultGroup;
  String? _addError;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() => _addError = null);

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAddCustom() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final db = ref.read(dbProvider);
    final ex = await db.findOrCreateExerciseByName(name, _pickedGroup.name);

    ref.invalidate(allExercisesProvider);
    setState(() => _addError = null);
    widget.onSelected(ex);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final exercisesAsync = ref.watch(allExercisesProvider);

    final query = _nameCtrl.text.trim().toLowerCase();
    final allExercises = exercisesAsync.valueOrNull ?? [];
    final isDuplicate = allExercises.any((e) => e.name.toLowerCase() == query);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Custom creation area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(SGRadius.card),
            border: Border.all(color: p.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ADD CUSTOM', style: SGText.mono(10, color: p.textFaint)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: p.chipBg,
                        borderRadius: BorderRadius.circular(SGRadius.chip),
                      ),
                      child: TextField(
                        controller: _nameCtrl,
                        style: SGText.body(15, color: p.text),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Exercise name...',
                          hintStyle: SGText.body(15, color: p.textFaint),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: InputBorder.none,
                          fillColor: Colors.transparent
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SGButton.soft(
                    label: 'Add',
                    color: (_nameCtrl.text.isNotEmpty && !isDuplicate) ? null : p.textFaint,
                    onTap: (_nameCtrl.text.isNotEmpty && !isDuplicate) ? _handleAddCustom : null,
                  ),
                ],
              ),
              if (_addError != null) ...[
                const SizedBox(height: 8),
                Text(_addError!, style: SGText.body(13, color: p.warn)),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MuscleGroup.values
                    .where((g) => g != MuscleGroup.rest)
                    .map((g) {
                  final active = _pickedGroup == g;
                  return GestureDetector(
                    onTap: () => setState(() => _pickedGroup = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? g.color : p.chipBg,
                        borderRadius: BorderRadius.circular(SGRadius.chip),
                      ),
                      child: Text(
                        g.label.toUpperCase(),
                        style: SGText.mono(10,
                            color: active ? Colors.black : p.textDim),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // List area
        exercisesAsync.when(
          data: (list) {
            final filtered = list
                .where((e) => !widget.excludeIds.contains(e.id))
                .where((e) => e.name.toLowerCase().contains(query))
                .toList();

            final sameGroup = filtered.where((e) => e.group == _pickedGroup.name).toList();
            final otherGroup = filtered.where((e) => e.group != _pickedGroup.name).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sameGroup.isNotEmpty) ...[
                  Text('${_pickedGroup.label.toUpperCase()} EXERCISES', style: SGText.mono(10, color: p.textFaint)),
                  const SizedBox(height: 12),
                  ...sameGroup.map((e) => _ExerciseRow(e, onTap: () => widget.onSelected(e))),
                  const SizedBox(height: 16),
                ],
                if (query.isNotEmpty && otherGroup.isNotEmpty) ...[
                  if (sameGroup.isNotEmpty)
                    const SizedBox(height: 8),
                  Text('OTHER GROUPS', style: SGText.mono(10, color: p.textFaint)),
                  const SizedBox(height: 12),
                  ...otherGroup.map((e) => _ExerciseRow(e, onTap: () => widget.onSelected(e))),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error: $err'),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _ExerciseRow(this.exercise, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final group = MuscleGroupX.fromString(exercise.group);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SGGroupDot(group, size: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                exercise.name,
                style: SGText.body(16, color: p.text),
              ),
            ),
            Text(
              group.label.toUpperCase(),
              style: SGText.mono(10, color: p.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';
import '../widgets/meso_edit_sheet.dart';
import '../widgets/meso_switcher.dart';
import '../widgets/day_program_editor.dart';
import '../widgets/exercise_picker.dart';

enum _MesoViz { calendar, timeline }

class MesoScreen extends ConsumerStatefulWidget {
  const MesoScreen({super.key});

  @override
  ConsumerState<MesoScreen> createState() => _MesoScreenState();
}

class _MesoScreenState extends ConsumerState<MesoScreen> {
  _MesoViz _viz = _MesoViz.calendar;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad =
        MediaQuery.of(context).padding.bottom + SGTabBar.kBaseHeight + 16;
    final mesoAsync = ref.watch(activeMesoProvider);

    return Scaffold(
      backgroundColor: p.bg,
      body: mesoAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: p.accent)),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: SGText.body(14))),
        data: (meso) {
          if (meso == null) return _noMesoView(context, p);
          return _buildContent(context, p, meso, topPad, bottomPad);
        },
      ),
    );
  }

  Widget _noMesoView(BuildContext context, SGPalette p) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('No active mesocycle.', style: SGText.display(22, color: p.text)),
        const SizedBox(height: 12),
        SGButton.solid(
          label: '+ New Mesocycle',
          color: p.accent,
          onTap: () => _showSwitcher(context),
        ),
      ]),
    );
  }

  Widget _buildContent(BuildContext context, SGPalette p, Mesocycle meso,
      double topPad, double bottomPad) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 8),
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CURRENT MESOCYCLE',
                    style: SGText.mono(11, color: p.textFaint, ls: 1.2)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showSwitcher(context),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(meso.name,
                            style: SGText.display(26, color: p.text)),
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: p.chipBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            Icon(Icons.expand_more, size: 18, color: p.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meso.numWeeks} weeks · started '
                  '${DateFormat('yyyy-MM-dd').format(meso.startDate)}',
                  style: SGText.body(13, color: p.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Viz toggle ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VizToggle(
              selected: _viz,
              palette: p,
              onChanged: (v) => setState(() => _viz = v),
            ),
          ),
          const SizedBox(height: 16),
          // ── Viz content ────────────────────────────────────────
          if (_viz == _MesoViz.calendar)
            _CalendarView(meso: meso)
          else
            _TimelineView(meso: meso),
          const SizedBox(height: 20),
          // ── Bottom CTAs ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SGButton.ghost(
                  label: '+ Add week',
                  color: p.textDim,
                  fullWidth: true,
                  onTap: () => _addWeek(meso),
                ),
                const SizedBox(height: 10),
                SGButton.solid(
                  label: "Today's Session →",
                  color: p.text,
                  fullWidth: true,
                  onTap: () => ref.read(tabIndexProvider.notifier).state = 1,
                ),
              ],
            ),
          ),
          // ── Settings gear (re-seed / wipe) ────────────────────
          const SizedBox(height: 20),
          Center(child: _SettingsRow(meso: meso)),
        ],
      ),
    );
  }

  void _showSwitcher(BuildContext context) {
    showSGSheet(
      context,
      isScrollControlled: true,
      maxHeightFraction: 0.75,
      child: const MesoSwitcher(),
    );
  }

  Future<void> _addWeek(Mesocycle meso) async {
    final db = ref.read(dbProvider);
    await (db.update(db.mesocycles)..where((t) => t.id.equals(meso.id)))
        .write(MesocyclesCompanion(numWeeks: Value(meso.numWeeks + 1)));
    ref.invalidate(activeMesoProvider);
  }
}

// ── Viz toggle ────────────────────────────────────────────────────────────────

class _VizToggle extends StatelessWidget {
  final _MesoViz selected;
  final SGPalette palette;
  final ValueChanged<_MesoViz> onChanged;

  const _VizToggle({
    required this.selected,
    required this.palette,
    required this.onChanged,
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
          _VizItem(
            label: 'Calendar',
            selected: selected == _MesoViz.calendar,
            palette: palette,
            onTap: () => onChanged(_MesoViz.calendar),
          ),
          _VizItem(
            label: 'Timeline',
            selected: selected == _MesoViz.timeline,
            palette: palette,
            onTap: () => onChanged(_MesoViz.timeline),
          ),
        ],
      ),
    );
  }
}

class _VizItem extends StatelessWidget {
  final String label;
  final bool selected;
  final SGPalette palette;
  final VoidCallback onTap;

  const _VizItem({
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
            child: Text(
              label,
              style: SGText.body(13,
                  weight: FontWeight.w600,
                  color: selected ? palette.text : palette.textDim),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Calendar view ─────────────────────────────────────────────────────────────

class _CalendarView extends ConsumerStatefulWidget {
  final Mesocycle meso;

  const _CalendarView({required this.meso});

  @override
  ConsumerState<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<_CalendarView> {
  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayIndices = [0, 1, 2, 3, 4, 5, 6];

  final Set<int> _locallyDeletedWeeks = {};
  int _mesoNumWeeks = 0;

  @override
  void initState() {
    super.initState();
    _mesoNumWeeks = widget.meso.numWeeks;
  }

  @override
  void didUpdateWidget(_CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meso.numWeeks != widget.meso.numWeeks) {
      _locallyDeletedWeeks.clear();
      _mesoNumWeeks = widget.meso.numWeeks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final todayKey = ref.watch(todayKeyProvider);
    final sessionLogsAsync = ref.watch(mesoSessionLogsProvider(widget.meso.id));
    final sessionLogs = sessionLogsAsync.valueOrNull ?? [];

    final now = DateTime.now();
    final todayDayIdx = (now.weekday - 1) % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              ..._dayLabels.map((l) => Expanded(
                    child: Center(
                      child:
                          Text(l, style: SGText.mono(9, color: p.textFaint)),
                    ),
                  )),
              const SizedBox(width: 28),
            ],
          ),
          const SizedBox(height: 4),
          // Week rows
          ...List.generate(_mesoNumWeeks, (weekIdx) {
            if (_locallyDeletedWeeks.contains(weekIdx)) {
              return const SizedBox.shrink();
            }

            final isDeload =
                ref.watch(isDeloadWeekProvider(WeekKey(widget.meso.id, weekIdx)));
            final isCurrentWeek = todayKey?.weekIdx == weekIdx;
            final isPastWeek = todayKey != null && weekIdx < todayKey.weekIdx;

            return Dismissible(
              key: ValueKey('week-${widget.meso.id}-$weekIdx-${widget.meso.numWeeks}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                if (_mesoNumWeeks - _locallyDeletedWeeks.length <= 1) return false;
                return true;
              },
              onDismissed: (_) {
                setState(() => _locallyDeletedWeeks.add(weekIdx));
                ref.read(dbProvider).deleteWeek(widget.meso.id, weekIdx);
              },
              background: Container(
                color: p.warn,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 4),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: isCurrentWeek
                    ? BoxDecoration(
                        color: p.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Row(
                  children: [
                    ..._dayIndices.map((dayIdx) {
                      final groupAsync = ref.watch(
                          dayGroupProvider(DayKey(widget.meso.id, weekIdx, dayIdx)));
                      final group = groupAsync.valueOrNull ?? MuscleGroup.rest;
                      final isRest = group == MuscleGroup.rest;
                      final isToday = isCurrentWeek && dayIdx == todayDayIdx;
                      final isPast =
                          isPastWeek || (isCurrentWeek && dayIdx < todayDayIdx);

                      // Check if session exists for this cell
                      final sessionExists = sessionLogs.any(
                          (s) => s.weekIdx == weekIdx && s.dayIdx == dayIdx);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            ref.read(selectedLogDayProvider.notifier).state =
                                DayKey(widget.meso.id, weekIdx, dayIdx);
                            ref.read(tabIndexProvider.notifier).state = 1;
                          },
                          child: AspectRatio(
                            aspectRatio: 1 / 1.1,
                            child: Container(
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: isRest
                                    ? p.railBg
                                    : (isDeload && !isRest)
                                        ? group.color.withValues(alpha: 0.25)
                                        : group.color
                                            .withValues(alpha: isPast ? 0.35 : 0.6),
                                borderRadius: BorderRadius.circular(6),
                                border: isToday
                                    ? Border.all(color: p.text, width: 2)
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  if (isDeload && !isRest && !sessionExists)
                                    const Center(
                                      child: Text('D',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white)),
                                    ),
                                  if (sessionExists)
                                    const Center(
                                      child: Icon(Icons.check,
                                          size: 16, color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Deload toggle
                    GestureDetector(
                      onTap: () =>
                          ref.read(dbProvider).toggleDeloadWeek(widget.meso.id, weekIdx),
                      child: Container(
                        width: 24,
                        height: 32,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: isDeload ? p.warn.withValues(alpha: 0.15) : p.chipBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            'D',
                            style: SGText.mono(11,
                                weight: FontWeight.w900,
                                color: isDeload ? p.warn : p.textFaint),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          // Legend
          Consumer(builder: (context, ref, _) {
            final usedSplits = <String, Color>{};

            // Collect splits from all training days in the meso
            for (var d = 0; d < 7; d++) {
              final groupAsync =
                  ref.watch(dayGroupProvider(DayKey(widget.meso.id, 0, d)));
              final group = groupAsync.valueOrNull;

              if (group != null && group != MuscleGroup.rest) {
                final daySettingsAsync = ref.watch(
                    programDayProvider(ProgramDayKey(widget.meso.id, d)));
                final labelText =
                    daySettingsAsync.valueOrNull?.label ?? group.label;

                if (!usedSplits.containsKey(labelText)) {
                  usedSplits[labelText] = group.color;
                }
              }
            }

            if (usedSplits.isEmpty) return const SizedBox.shrink();

            final sortedSplits = usedSplits.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));

            return Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final entry in sortedSplits)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.value,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(entry.key, style: SGText.mono(10, color: p.textDim)),
                    ],
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Timeline view ─────────────────────────────────────────────────────────────

class _TimelineView extends ConsumerWidget {
  final Mesocycle meso;

  const _TimelineView({required this.meso});

  static const _trainingDays = [0, 1, 2, 4, 5]; // Mon,Tue,Wed,Fri,Sat

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    final brightness = Theme.of(context).brightness;

    // Load all week targets for all weeks
    final allTargets = <int, Map<String, WeekTarget>>{};
    for (var w = 0; w < meso.numWeeks; w++) {
      final t = ref.watch(weekTargetsProvider(WeekKey(meso.id, w)));
      allTargets[w] = t.valueOrNull ?? {};
    }

    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Week header row
              Row(
                children: [
                  const SizedBox(width: 130),
                  ...List.generate(meso.numWeeks, (w) {
                    final isDeload = ref.watch(isDeloadWeekProvider(WeekKey(meso.id, w)));
                    return GestureDetector(
                      onTap: () => ref.read(dbProvider).toggleDeloadWeek(meso.id, w),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 68,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        alignment: Alignment.center,
                        child: Text(
                          isDeload ? 'DELOAD' : 'W${w + 1}',
                          style:
                              SGText.mono(9, color: isDeload ? p.warn : p.textDim),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              // Day sections
              ..._trainingDays.map((dayIdx) {
                final groupAsync = ref.watch(dayGroupProvider(DayKey(meso.id, 0, dayIdx)));
                final group = groupAsync.valueOrNull ?? MuscleGroup.rest;
                final exercisesAsync = ref.watch(programDayExercisesProvider(ProgramDayKey(meso.id, dayIdx)));
                final daySettingsAsync = ref.watch(programDayProvider(ProgramDayKey(meso.id, dayIdx)));
                final customLabel = daySettingsAsync.valueOrNull?.label;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day header
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: group.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (customLabel ?? _dayName(dayIdx)).toUpperCase(),
                            style: SGText.display(13, color: p.text),
                          ),
                          const SizedBox(width: 8),
                          if (group != MuscleGroup.rest) SGGroupDot(group, size: 6),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.edit, size: 14, color: p.textFaint),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => showSGSheet(
                              context,
                              isScrollControlled: true,
                              maxHeightFraction: 0.9,
                              child: DayProgramEditor(meso: meso, dayIdx: dayIdx),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Exercise rows
                      exercisesAsync.when(
                        data: (exercises) => Column(
                          children: exercises.map((ex) {
                            return _TimelineRow(
                              exercise: ex,
                              mesoId: meso.id,
                              group: group,
                              numWeeks: meso.numWeeks,
                              allTargets: allTargets,
                              palette: p,
                              brightness: brightness,
                              onNameTap: () => _programSwap(context, ref, group, ex, dayIdx),
                              onCellTap: (weekIdx, target) => _editCell(
                                context,
                                ref,
                                weekIdx: weekIdx,
                                exercise: ex,
                                group: group,
                                target: target,
                              ),
                            );
                          }).toList(),
                        ),
                        loading: () => Text('Loading...', style: SGText.body(12, color: p.textFaint)),
                        error: (err, _) => Text('Error: $err', style: SGText.body(12, color: p.warn)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        Positioned(
          right: -1,
          top: 0,
          bottom: 0,
          width: 40,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [p.bg, p.bg.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _dayName(int dayIdx) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayIdx];
  }

  void _programSwap(BuildContext context, WidgetRef ref, MuscleGroup group,
      Exercise ex, int dayIdx) {
    showSGSheet(
      context,
      maxHeightFraction: 0.8,
      child: ExercisePicker(
        defaultGroup: group,
        excludeIds: {ex.id},
        onSelected: (newEx) async {
          final db = ref.read(dbProvider);
          final key = ProgramDayKey(meso.id, dayIdx);
          final current = await ref.read(programDayExercisesProvider(key).future);
          final ids = current.map((e) => e.id == ex.id ? newEx.id : e.id).toList();

          await db.setWeekForwardOverride(
            meso.id,
            0,
            meso.numWeeks,
            dayIdx,
            ids,
          );

          ref.invalidate(programDayExercisesProvider(key));
          for (int w = 0; w < meso.numWeeks; w++) {
            ref.invalidate(dayPlanProvider(DayKey(meso.id, w, dayIdx)));
            ref.invalidate(weekTargetsProvider(WeekKey(meso.id, w)));
          }
          if (!context.mounted) return;
          Navigator.pop(context);
        },
      ),
    );
  }

  void _editCell(
    BuildContext context,
    WidgetRef ref, {
    required int weekIdx,
    required Exercise exercise,
    required MuscleGroup group,
    required WeekTarget? target,
  }) {
    showSGSheet(
      context,
      isScrollControlled: true,
      maxHeightFraction: 0.9,
      child: MesoEditSheet(
        mesoId: meso.id,
        weekIdx: weekIdx,
        numWeeks: meso.numWeeks,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        group: group,
        initialTarget: target,
      ),
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  final Exercise exercise;
  final String mesoId;
  final MuscleGroup group;
  final int numWeeks;
  final Map<int, Map<String, WeekTarget>> allTargets;
  final SGPalette palette;
  final Brightness brightness;
  final VoidCallback onNameTap;
  final void Function(int weekIdx, WeekTarget? target) onCellTap;

  const _TimelineRow({
    required this.exercise,
    required this.mesoId,
    required this.group,
    required this.numWeeks,
    required this.allTargets,
    required this.palette,
    required this.brightness,
    required this.onNameTap,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Exercise name
          GestureDetector(
            onTap: onNameTap,
            child: SizedBox(
              width: 130,
              child: Text(
                exercise.name,
                style:
                    SGText.body(12, weight: FontWeight.w500, color: palette.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Week cells
          ...List.generate(numWeeks, (w) {
            final target = allTargets[w]?[exercise.id];
            final isDeload = ref.watch(isDeloadWeekProvider(WeekKey(mesoId, w)));
            return GestureDetector(
              onTap: () => onCellTap(w, target),
              child: Container(
                width: 68,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isDeload
                      ? palette.warn.withValues(alpha: 0.08)
                      : group.tint(brightness).withValues(alpha: 0.5),                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border, width: 0.5),
                ),
                child: target == null
                    ? Icon(Icons.add, size: 14, color: palette.textFaint)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${target.sets}×${target.reps}',
                            style: SGText.display(11, color: palette.text),
                          ),
                          Text(
                            'RIR${target.rir}',
                            style: SGText.mono(7, color: palette.textDim),
                          ),
                        ],
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingsRow extends ConsumerWidget {
  final Mesocycle meso;

  const _SettingsRow({required this.meso});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: () => _reseed(context, ref),
          icon: Icon(Icons.refresh, size: 16, color: p.textFaint),
          label: Text('Re-seed', style: SGText.body(13, color: p.textFaint)),
        ),
        TextButton.icon(
          onPressed: () => _setWeek(context, ref),
          icon: Icon(Icons.calendar_today, size: 16, color: p.textFaint),
          label: Text('Set week', style: SGText.body(13, color: p.textFaint)),
        ),
        TextButton.icon(
          onPressed: () => _wipe(context, ref),
          icon: Icon(Icons.delete_outline, size: 16, color: p.accent),
          label: Text('Wipe data', style: SGText.body(13, color: p.accent)),
        ),
        Consumer(builder: (ctx, r, _) {
          final mode = r.watch(themeModeProvider);
          final isDark = mode == ThemeMode.dark ||
              (mode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);
          return TextButton.icon(
            onPressed: () => r.read(themeModeProvider.notifier).state =
                isDark ? ThemeMode.light : ThemeMode.dark,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
                size: 16, color: p.textFaint),
            label: Text(isDark ? 'Light' : 'Dark',
                style: SGText.body(13, color: p.textFaint)),
          );
        }),
      ],
    );
  }

  Future<void> _reseed(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-seed?'),
        content:
            const Text('Wipes all data and recreates the starter mesocycle.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Re-seed')),
        ],
      ),
    );
    if (confirm != true) return;
    final db = ref.read(dbProvider);
    await db.wipeAllData();
    ref.invalidate(activeMesoProvider);
    ref.invalidate(allMesosProvider);
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe all data?'),
        content: const Text('Permanently deletes everything. Cannot undo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Wipe', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(dbProvider).wipeAllData();
    ref.invalidate(activeMesoProvider);
    ref.invalidate(allMesosProvider);
  }

  Future<void> _setWeek(BuildContext context, WidgetRef ref) async {
    final p = pal(context);
    final selectedWeek = await showSGSheet<int>(
      context,
      maxHeightFraction: 0.6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Set Current Week', style: SGText.display(20, color: p.text)),
          const SizedBox(height: 16),
          ...List.generate(meso.numWeeks, (i) {
            return ListTile(
              title:
                  Text('Week ${i + 1}', style: SGText.body(16, color: p.text)),
              onTap: () => Navigator.pop(context, i),
            );
          }),
          const SizedBox(height: 10),
          SGButton.ghost(
            label: 'Cancel',
            color: p.textDim,
            fullWidth: true,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );

    if (selectedWeek != null) {
      final db = ref.read(dbProvider);
      await db.setMesoCurrentWeek(meso.id, selectedWeek);
      ref.invalidate(activeMesoProvider);
      ref.invalidate(todayKeyProvider);
    }
  }
}

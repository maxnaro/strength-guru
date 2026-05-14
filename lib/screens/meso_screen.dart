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
import '../widgets/about_sheet.dart';

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

    // Listen for cross-screen navigation requests
    ref.listen(timelineRequestedWeekProvider, (prev, next) {
      if (next != null) {
        setState(() => _viz = _MesoViz.timeline);
      }
    });

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
                Row(
                  children: [
                    Expanded(
                      child: Text('CURRENT MESOCYCLE',
                          style: SGText.mono(11, color: p.textFaint, ls: 1.2)),
                    ),
                    IconButton(
                      icon: Icon(Icons.info_outline, size: 18, color: p.textFaint),
                      onPressed: () => showSGSheet(
                        context,
                        child: const AboutSheet(),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
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

class _TimelineView extends ConsumerStatefulWidget {
  final Mesocycle meso;

  const _TimelineView({required this.meso});

  @override
  ConsumerState<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<_TimelineView>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  int? _highlightedWeekIdx;
  late final AnimationController _highlightController;
  late final Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _highlightAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final req = ref.read(timelineRequestedWeekProvider);
      if (req != null) {
        _scrollToAndHighlight(req);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  void _scrollToAndHighlight(int weekIdx) {
    setState(() => _highlightedWeekIdx = weekIdx);
    
    final offset = weekIdx * 70.0;
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );

    _highlightController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _highlightedWeekIdx = null);
        ref.read(timelineRequestedWeekProvider.notifier).state = null;
      }
    });
  }

  static const _trainingDays = [0, 1, 2, 3, 4, 5, 6]; // Mon-Sun

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final brightness = Theme.of(context).brightness;

    ref.listen(timelineRequestedWeekProvider, (prev, next) {
      if (next != null && next != _highlightedWeekIdx) {
        _scrollToAndHighlight(next);
      }
    });

    // Load all week targets for all weeks
    final allTargets = <int, Map<String, WeekTarget>>{};
    for (var w = 0; w < widget.meso.numWeeks; w++) {
      final t = ref.watch(weekTargetsProvider(WeekKey(widget.meso.id, w)));
      allTargets[w] = t.valueOrNull ?? {};
    }

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Week header row
              Row(
                children: [
                  const SizedBox(width: 130),
                  ...List.generate(widget.meso.numWeeks, (w) {
                    final isDeload =
                        ref.watch(isDeloadWeekProvider(WeekKey(widget.meso.id, w)));
                    final isHighlighted = _highlightedWeekIdx == w;
                    return GestureDetector(
                      onTap: () =>
                          ref.read(dbProvider).toggleDeloadWeek(widget.meso.id, w),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedBuilder(
                        animation: _highlightAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 68,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            alignment: Alignment.center,
                            decoration: isHighlighted
                                ? BoxDecoration(
                                    color: p.accent.withValues(
                                        alpha: 0.2 * _highlightAnimation.value),
                                    borderRadius: BorderRadius.circular(4),
                                  )
                                : null,
                            child: child,
                          );
                        },
                        child: Text(
                          isDeload ? 'DELOAD' : 'W${w + 1}',
                          style: SGText.mono(9,
                              color: isDeload ? p.warn : p.textDim),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              // Day sections
              ..._trainingDays.map((dayIdx) {
                final groupAsync =
                    ref.watch(dayGroupProvider(DayKey(widget.meso.id, 0, dayIdx)));
                final group = groupAsync.valueOrNull ?? MuscleGroup.rest;
                final itemsAsync = ref.watch(
                    programDayExercisesProvider(ProgramDayKey(widget.meso.id, dayIdx)));
                final daySettingsAsync = ref
                    .watch(programDayProvider(ProgramDayKey(widget.meso.id, dayIdx)));
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
                            icon: Icon(Icons.swap_horiz,
                                size: 16, color: p.textFaint),
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                _showSwapPicker(context, ref, widget.meso.id, dayIdx),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, size: 14, color: p.textFaint),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => showSGSheet(
                              context,
                              isScrollControlled: true,
                              maxHeightFraction: 0.9,
                              child: DayProgramEditor(
                                  meso: widget.meso, dayIdx: dayIdx),
                            ),
                          ),
                          _DayActionMenu(meso: widget.meso, dayIdx: dayIdx),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Exercise rows
                      itemsAsync.when(
                        data: (items) => Column(
                          children: items.map((item) {
                            return _TimelineRow(
                              item: item,
                              mesoId: widget.meso.id,
                              group: group,
                              numWeeks: widget.meso.numWeeks,
                              allTargets: allTargets,
                              palette: p,
                              brightness: brightness,
                              highlightedWeekIdx: _highlightedWeekIdx,
                              highlightAnimation: _highlightAnimation,
                              onNameTap: () =>
                                  _programSwap(context, ref, group, item, dayIdx),
                              onCellTap: (weekIdx, target) => _editCell(
                                context,
                                ref,
                                weekIdx: weekIdx,
                                item: item,
                                group: group,
                                target: target,
                              ),
                            );
                          }).toList(),
                        ),
                        loading: () => Text('Loading...',
                            style: SGText.body(12, color: p.textFaint)),
                        error: (err, _) => Text('Error: $err',
                            style: SGText.body(12, color: p.warn)),
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

  String _dayName(int dayIdx, {bool full = false}) {
    const shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const fullDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return full ? fullDays[dayIdx] : shortDays[dayIdx];
  }

  Future<void> _handleSwap(
      WidgetRef ref, String mesoId, int dayA, int dayB) async {
    final db = ref.read(dbProvider);
    await db.swapDays(mesoId, dayA, dayB);
    ref.invalidate(programDayExercisesProvider);
    ref.invalidate(dayPlanProvider);
    ref.invalidate(dayGroupProvider);
    ref.invalidate(programDayProvider);
    ref.invalidate(mesoSessionLogsProvider(mesoId));
  }

  Future<void> _showSwapPicker(
      BuildContext context, WidgetRef ref, String mesoId, int sourceIdx) async {
    final p = pal(context);
    final targetIdx = await showSGSheet<int>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Swap With', style: SGText.display(18, color: p.text)),
          const SizedBox(height: 16),
          ...List.generate(7, (i) {
            if (i == sourceIdx) return const SizedBox.shrink();
            return Consumer(builder: (context, ref, _) {
              final daySettingsAsync =
                  ref.watch(programDayProvider(ProgramDayKey(mesoId, i)));
              final label = daySettingsAsync.valueOrNull?.label;
              final hasLabel = label != null && label.isNotEmpty;

              return ListTile(
                title: RichText(
                  text: TextSpan(
                    style: SGText.body(16, color: p.text),
                    children: [
                      TextSpan(text: _dayName(i, full: true)),
                      if (hasLabel) ...[
                        const TextSpan(text: ' → '),
                        TextSpan(
                          text: label,
                          style: SGText.mono(14, color: p.textDim),
                        ),
                      ],
                    ],
                  ),
                ),
                onTap: () => Navigator.pop(context, i),
              );
            });
          }),
          const SizedBox(height: 12),
          SGButton.ghost(
            label: 'Cancel',
            color: p.textDim,
            fullWidth: true,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );

    if (targetIdx != null) {
      await _handleSwap(ref, mesoId, sourceIdx, targetIdx);
    }
  }

  void _programSwap(BuildContext context, WidgetRef ref, MuscleGroup group,
      ExerciseSlotWithExercise item, int dayIdx) {
    showSGSheet(
      context,
      maxHeightFraction: 0.8,
      child: ExercisePicker(
        defaultGroup: group,
        excludeIds: const {}, // Allow duplicate exercises in a program swap too
        onSelected: (newEx) async {
          final db = ref.read(dbProvider);
          final key = ProgramDayKey(widget.meso.id, dayIdx);

          // Create a NEW slot for the new exercise
          final newSlot = await db.createExerciseSlot(widget.meso.id, newEx.id);

          // Baseline targets from the old slot (Week 1 usually has them in a program swap)
          final oldTarget = await db.getWeekTarget(widget.meso.id, 0, item.slot.id);
          if (oldTarget != null) {
            await db.applyWeekTargetForward(
              mesoId: widget.meso.id,
              fromWeekIdx: 0,
              numWeeks: widget.meso.numWeeks,
              slotId: newSlot.id,
              reps: oldTarget.reps,
              rir: oldTarget.rir,
            );
          }

          // Fetch current program slots and replace the ID
          final current =
              await ref.read(programDayExercisesProvider(key).future);
          final slotIds = current
              .map((e) => e.slot.id == item.slot.id ? newSlot.id : e.slot.id)
              .toList();

          await db.setWeekForwardOverride(
            widget.meso.id,
            0,
            widget.meso.numWeeks,
            dayIdx,
            slotIds,
          );
          await db.setDayOverride(widget.meso.id, -1, dayIdx, slotIds);

          ref.invalidate(programDayExercisesProvider(key));
          for (int w = 0; w < widget.meso.numWeeks; w++) {
            ref.invalidate(dayPlanProvider(DayKey(widget.meso.id, w, dayIdx)));
            ref.invalidate(weekTargetsProvider(WeekKey(widget.meso.id, w)));
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
    required ExerciseSlotWithExercise item,
    required MuscleGroup group,
    required WeekTarget? target,
  }) {
    showSGSheet(
      context,
      isScrollControlled: true,
      maxHeightFraction: 0.9,
      child: MesoEditSheet(
        mesoId: widget.meso.id,
        weekIdx: weekIdx,
        numWeeks: widget.meso.numWeeks,
        slotId: item.slot.id,
        exerciseName: item.name,
        group: group,
        initialTarget: target,
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final ExerciseSlotWithExercise item;
  final String mesoId;
  final MuscleGroup group;
  final int numWeeks;
  final Map<int, Map<String, WeekTarget>> allTargets;
  final SGPalette palette;
  final Brightness brightness;
  final int? highlightedWeekIdx;
  final Animation<double> highlightAnimation;
  final VoidCallback onNameTap;
  final void Function(int weekIdx, WeekTarget? target) onCellTap;

  const _TimelineRow({
    required this.item,
    required this.mesoId,
    required this.group,
    required this.numWeeks,
    required this.allTargets,
    required this.palette,
    required this.brightness,
    required this.highlightedWeekIdx,
    required this.highlightAnimation,
    required this.onNameTap,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
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
                item.name,
                style: SGText.body(12,
                    weight: FontWeight.w500, color: palette.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Week cells
          ...List.generate(numWeeks, (w) {
            final target = allTargets[w]?[item.slot.id];
            final isHighlighted = highlightedWeekIdx == w;
            return Consumer(builder: (context, ref, _) {
              final isDeload =
                  ref.watch(isDeloadWeekProvider(WeekKey(mesoId, w)));
              return GestureDetector(
                onTap: () => onCellTap(w, target),
                child: AnimatedBuilder(
                  animation: highlightAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 68,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isDeload
                            ? palette.warn.withValues(alpha: 0.08)
                            : group.tint(brightness).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isHighlighted
                                ? palette.accent.withValues(
                                    alpha: 0.8 * highlightAnimation.value)
                                : palette.border,
                            width: isHighlighted
                                ? 1.5 * highlightAnimation.value
                                : 0.5),
                      ),
                      child: child,
                    );
                  },
                  child: target == null
                      ? Icon(Icons.add, size: 14, color: palette.textFaint)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatReps(target),
                              style: SGText.display(10, color: palette.text),
                            ),
                            Text(
                              _formatRir(target),
                              style: SGText.mono(7, color: palette.textDim),
                            ),
                          ],
                        ),
                ),
              );
            });
          }),
        ],
      ),
    );
  }

  String _formatReps(WeekTarget t) {
    final reps = t.reps;
    if (reps.isEmpty) return '—';

    final allSame = reps.every((r) => r == reps.first);
    if (allSame) return '${reps.length}×${reps.first}';

    // Check for "Top Set + Backoffs" pattern (e.g., 6, 12, 12)
    if (reps.length > 1) {
      final top = reps.first;
      final backoffs = reps.sublist(1);
      final allBackoffsSame = backoffs.every((r) => r == backoffs.first);
      if (allBackoffsSame) {
        return '$top + ${backoffs.length}×${backoffs.first}';
      }
    }

    // Otherwise, show as comma-separated list
    final list = reps.join(',');
    if (list.length > 10) {
      // If too long, show first and last with ellipsis
      return '${reps.first}..${reps.last}';
    }
    return list;
  }

  String _formatRir(WeekTarget t) {
    if (t.rir.isEmpty) return '—';
    final allSame = t.rir.every((r) => r == t.rir.first);
    if (allSame) return 'RIR ${t.rir.first}';
    return 'RIR ${t.rir.join(',')}';
  }
}

// ── Day action menu ────────────────────────────────────────────────────────────

class _DayActionMenu extends ConsumerWidget {
  final Mesocycle meso;
  final int dayIdx;

  const _DayActionMenu({required this.meso, required this.dayIdx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: p.textFaint),
      onSelected: (val) => _handleAction(context, ref, val),
      color: p.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SGRadius.btn),
        side: BorderSide(color: p.borderStrong, width: 0.5),
      ),
      offset: const Offset(0, 36),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'dup',
          child: Text('Duplicate To...', style: SGText.body(14, color: p.text)),
        ),
        PopupMenuItem(
          value: 'clear',
          child: Text('Clear Day', style: SGText.body(14, color: p.accent)),
        ),
      ],
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    final db = ref.read(dbProvider);
    final p = pal(context);

    if (action == 'up' || action == 'down') {
      final other = action == 'up' ? dayIdx - 1 : dayIdx + 1;
      await db.swapDays(meso.id, dayIdx, other);
    } else if (action == 'dup') {
      final targetIdx = await _showTargetPicker(context, ref);
      if (targetIdx != null) {
        await db.duplicateDay(meso.id, dayIdx, targetIdx);
      }
    } else if (action == 'clear') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: p.surface,
          title: Text('Clear Day?', style: SGText.display(20, color: p.text)),
          content: Text(
            'Exercises and targets for this day will be removed across all weeks.',
            style: SGText.body(15, color: p.textDim),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: SGText.body(14, color: p.textDim)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Clear',
                  style: SGText.body(14, color: p.accent, weight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await db.clearDay(meso.id, dayIdx);
      }
    }

    // Refresh everything
    ref.invalidate(programDayExercisesProvider);
    ref.invalidate(dayPlanProvider);
    ref.invalidate(dayGroupProvider);
    ref.invalidate(programDayProvider);
    ref.invalidate(mesoSessionLogsProvider(meso.id));
  }

  Future<int?> _showTargetPicker(BuildContext context, WidgetRef ref) async {
    final p = pal(context);
    
    // Find rest days (days with no exercises in ProgramDayKey(meso.id, dayIdx))
    final restDays = <int>[];
    for (int i = 0; i < 7; i++) {
      if (i == dayIdx) continue;
      final items = await ref.read(programDayExercisesProvider(ProgramDayKey(meso.id, i)).future);
      if (items.isEmpty) restDays.add(i);
    }

    if (restDays.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No rest days available to duplicate into.')),
        );
      }
      return null;
    }

    return showSGSheet<int>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select Rest Day', style: SGText.display(18, color: p.text)),
          const SizedBox(height: 16),
          ...restDays.map((idx) => Consumer(builder: (context, ref, _) {
                final daySettingsAsync = ref.watch(
                    programDayProvider(ProgramDayKey(meso.id, idx)));
                final label = daySettingsAsync.valueOrNull?.label;
                final hasLabel = label != null && label.isNotEmpty;

                return ListTile(
                  title: RichText(
                    text: TextSpan(
                      style: SGText.body(16, color: p.text),
                      children: [
                        TextSpan(text: _dayName(idx)),
                        if (hasLabel) ...[
                          const TextSpan(text: ' → '),
                          TextSpan(
                            text: label,
                            style: SGText.mono(14, color: p.textDim),
                          ),
                        ],
                      ],
                    ),
                  ),
                  onTap: () => Navigator.pop(context, idx),
                );
              })),
          const SizedBox(height: 12),
          SGButton.ghost(
            label: 'Cancel',
            color: p.textDim,
            fullWidth: true,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _dayName(int dayIdx) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[dayIdx];
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
      ],
    );
  }

  Future<void> _reseed(BuildContext context, WidgetRef ref) async {
    final p = pal(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Re-seed?', style: SGText.display(20, color: p.text)),
        content: Text('Wipes all data and recreates the starter mesocycle.',
            style: SGText.body(15, color: p.textDim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: SGText.body(14, color: p.textDim))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Re-seed',
                  style: SGText.body(14,
                      color: p.accent, weight: FontWeight.bold))),
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
    final p = pal(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Wipe all data?', style: SGText.display(20, color: p.text)),
        content: Text('Permanently deletes everything. Cannot undo.',
            style: SGText.body(15, color: p.textDim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: SGText.body(14, color: p.textDim))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Wipe',
                  style: SGText.body(14,
                      color: p.accent, weight: FontWeight.bold))),
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

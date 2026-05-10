import 'dart:math' show max;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/sg_atoms.dart';
import '../theme/tokens.dart';
import '../widgets/guide_sheet.dart';
import '../widgets/set_row_active.dart';
import '../widgets/set_row_done.dart';
import '../widgets/set_row_inactive.dart';
import '../widgets/swap_menu.dart';

class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  ({String slotId, int setIndex})? _userActiveSet;
  DayKey? _lastDayKey;
  final Map<String, int> _extraSetsBySlotId = {};
  final Set<String> _locallyDeletedSetIds = {};
  final Set<String> _locallySkippedSetKeys = {};

  late PageController _pageController;
  bool _isAnimatingPage = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _ensureSession(DayKey effective) async {
    final db = ref.read(dbProvider);
    await db.getOrCreateSessionLog(
        effective.mesoId, effective.weekIdx, effective.dayIdx);
    ref.invalidate(sessionLogProvider(effective));
  }

  Future<void> _logSet({
    required DayKey effective,
    required String? sessionId,
    required String exerciseId,
    required String slotId,
    required int setIndex,
    double? weight,
    int? reps,
    int? rir,
  }) async {
    if (sessionId == null) {
      await _ensureSession(effective);
      // Re-read sessionId after creation
      final session = await ref.read(sessionLogProvider(effective).future);
      sessionId = session?.id;
    }
    if (sessionId == null) return;

    final db = ref.read(dbProvider);
    await db.upsertSetEntry(
      sessionId: sessionId,
      exerciseId: exerciseId,
      slotId: slotId,
      setIndex: setIndex,
      weight: weight,
      reps: reps,
      rir: rir,
      done: true,
    );
    ref.invalidate(suggestedWeightProvider(exerciseId));

    if (mounted &&
        _userActiveSet?.slotId == slotId &&
        _userActiveSet?.setIndex == setIndex) {
      setState(() => _userActiveSet = null);
    }
  }

  void _onPageChanged(int page, Mesocycle meso) {
    if (_isAnimatingPage) return;
    final weekIdx = page ~/ 7;
    final dayIdx = page % 7;
    // Defer the provider update to avoid 'modifying provider during build' if triggered by layout
    Future.microtask(() {
      if (mounted) {
        ref.read(selectedLogDayProvider.notifier).state =
            DayKey(meso.id, weekIdx, dayIdx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad =
        MediaQuery.of(context).padding.bottom + SGTabBar.kBaseHeight + 16;

    final mesoAsync = ref.watch(activeMesoProvider);
    final today = ref.watch(todayKeyProvider);
    final selected = ref.watch(selectedLogDayProvider);
    final effective = selected ?? today;

    if (mesoAsync.isLoading) {
      return Scaffold(
          backgroundColor: p.bg,
          body: Center(child: CircularProgressIndicator(color: p.accent)));
    }

    final meso = mesoAsync.valueOrNull;
    if (meso == null || effective == null) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Center(
          child: Text('No active mesocycle.',
              style: SGText.display(22, color: p.text)),
        ),
      );
    }

    // Sync PageController with effective DayKey AFTER build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetPage = effective.weekIdx * 7 + effective.dayIdx;
      if (_pageController.hasClients &&
          _pageController.page?.round() != targetPage &&
          !_isAnimatingPage) {
        _pageController.jumpToPage(targetPage);
      }
    });

    // Reset user selections when day changes
    if (effective != _lastDayKey) {
      _userActiveSet = null;
      _extraSetsBySlotId.clear();
      _locallyDeletedSetIds.clear();
      _locallySkippedSetKeys.clear();
      _lastDayKey = effective;
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          _SessionHeader(
            group: ref.watch(dayGroupProvider(effective)).valueOrNull ?? MuscleGroup.rest,
            title: ref.watch(programDayProvider(ProgramDayKey(meso.id, effective.dayIdx)))
                    .valueOrNull
                    ?.label ??
                '${(ref.watch(dayGroupProvider(effective)).valueOrNull ?? MuscleGroup.rest).label} Session',
            plateLabel: (ref.watch(programDayProvider(ProgramDayKey(meso.id, effective.dayIdx)))
                        .valueOrNull
                        ?.label ??
                    (ref.watch(dayGroupProvider(effective)).valueOrNull ?? MuscleGroup.rest).label)
                .toUpperCase(),
            meso: meso,
            effective: effective,
            topPad: topPad,
            isToday: today != null &&
                effective.weekIdx == today.weekIdx &&
                effective.dayIdx == today.dayIdx,
            onTapToday: () {
              if (today == null) return;
              final page = today.weekIdx * 7 + today.dayIdx;
              _isAnimatingPage = true;
              _pageController
                  .animateToPage(page,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut)
                  .then((_) => _isAnimatingPage = false);
              ref.read(selectedLogDayProvider.notifier).state = null;
            },
          ),
          _DayPickerStrip(
            meso: meso,
            effective: effective,
            onDaySelected: (weekIdx, dayIdx) {
              final page = weekIdx * 7 + dayIdx;
              _isAnimatingPage = true;
              _pageController
                  .animateToPage(page,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut)
                  .then((_) => _isAnimatingPage = false);
              ref.read(selectedLogDayProvider.notifier).state =
                  DayKey(meso.id, weekIdx, dayIdx);
            },
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => _onPageChanged(page, meso),
              itemCount: meso.numWeeks * 7,
              itemBuilder: (context, index) {
                final pageWeekIdx = index ~/ 7;
                final pageDayIdx = index % 7;
                final pageKey = DayKey(meso.id, pageWeekIdx, pageDayIdx);

                return _DayView(
                  meso: meso,
                  dayKey: pageKey,
                  bottomPad: bottomPad,
                  userActiveSet: pageKey == effective ? _userActiveSet : null,
                  extraSetsBySlotId: pageKey == effective ? _extraSetsBySlotId : {},
                  locallyDeletedSetIds: pageKey == effective ? _locallyDeletedSetIds : {},
                  locallySkippedSetKeys: pageKey == effective ? _locallySkippedSetKeys : {},
                  onLogSet: (exId, slotId, si, w, r, ri) => _logSet(
                    effective: pageKey,
                    sessionId: ref.read(sessionLogProvider(pageKey)).valueOrNull?.id,
                    exerciseId: exId,
                    slotId: slotId,
                    setIndex: si,
                    weight: w,
                    reps: r,
                    rir: ri,
                  ),
                  onActivate: (slotId, si) => setState(
                    () => _userActiveSet = (slotId: slotId, setIndex: si),
                  ),
                  onAddSet: (slotId) => setState(
                    () => _extraSetsBySlotId[slotId] = (_extraSetsBySlotId[slotId] ?? 0) + 1,
                  ),
                  onRemoveSet: (slotId) => setState(
                    () => _extraSetsBySlotId[slotId] = max(0, (_extraSetsBySlotId[slotId] ?? 0) - 1),
                  ),
                  onDeleteSet: (exId, entryId) {
                    setState(() => _locallyDeletedSetIds.add(entryId));
                    ref.read(dbProvider).deleteSetEntry(entryId);
                    ref.invalidate(suggestedWeightProvider(exId));
                  },
                  onSkipSet: (slotId, setIndex) {
                    setState(() => _locallySkippedSetKeys.add('$slotId-$setIndex'));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day View ──────────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  final Mesocycle meso;
  final DayKey dayKey;
  final double bottomPad;
  final ({String slotId, int setIndex})? userActiveSet;
  final Map<String, int> extraSetsBySlotId;
  final Set<String> locallyDeletedSetIds;
  final Set<String> locallySkippedSetKeys;

  final Future<void> Function(String exId, String slotId, int setIndex, double? weight, int reps, int rir) onLogSet;
  final void Function(String slotId, int setIndex) onActivate;
  final void Function(String slotId) onAddSet;
  final void Function(String slotId) onRemoveSet;
  final void Function(String exId, String entryId) onDeleteSet;
  final void Function(String slotId, int setIndex) onSkipSet;

  const _DayView({
    required this.meso,
    required this.dayKey,
    required this.bottomPad,
    required this.userActiveSet,
    required this.extraSetsBySlotId,
    required this.locallyDeletedSetIds,
    required this.locallySkippedSetKeys,
    required this.onLogSet,
    required this.onActivate,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onDeleteSet,
    required this.onSkipSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    final planAsync = ref.watch(dayPlanProvider(dayKey));
    final targetsAsync =
        ref.watch(weekTargetsProvider(WeekKey(meso.id, dayKey.weekIdx)));
    final sessionAsync = ref.watch(sessionLogProvider(dayKey));
    final sessionLog = sessionAsync.valueOrNull;

    final items = planAsync.valueOrNull ?? [];
    final targets = targetsAsync.valueOrNull ?? {};

    final entriesList = sessionLog != null
        ? ref.watch(setsForLogProvider(sessionLog.id)).valueOrNull ?? []
        : <SetEntry>[];

    final filteredEntries = entriesList
        .where((e) => !locallyDeletedSetIds.contains(e.id))
        .toList();

    final entriesBySlot = <String, List<SetEntry>>{};
    for (final e in filteredEntries) {
      final key = e.slotId ?? e.exerciseId;
      (entriesBySlot[key] ??= []).add(e);
    }

    final isRestDay = items.isEmpty;
    final implicitActive = _computeActiveSet(items, entriesBySlot, targets);
    final effectiveActiveSet = userActiveSet ?? implicitActive;

    if (isRestDay) {
      return Center(
        child: Text('Recovery day.', style: SGText.display(24, color: p.text)),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final item = items[i];
                final ex = item.exercise;
                final target = targets[item.slot.id];
                final exGroup = MuscleGroupX.fromString(ex.group);
                final exEntries = entriesBySlot[item.slot.id] ?? [];
                final suggestedW =
                    ref.watch(suggestedWeightProvider(ex.id)).valueOrNull;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _ExerciseCard(
                    item: item,
                    group: exGroup,
                    target: target,
                    entries: exEntries,
                    activeSet: effectiveActiveSet,
                    extraSets: extraSetsBySlotId[item.slot.id] ?? 0,
                    sessionId: sessionLog?.id,
                    suggestedWeight: suggestedW,
                    meso: meso,
                    dayKey: dayKey,
                    onLogSet: (si, w, r, ri) => onLogSet(ex.id, item.slot.id, si, w, r, ri),
                    onActivate: (si) => onActivate(item.slot.id, si),
                    onAddSet: () => onAddSet(item.slot.id),
                    onRemoveSet: () => onRemoveSet(item.slot.id),
                    onDeleteSet: (entryId) => onDeleteSet(ex.id, entryId),
                    onSkipSet: (setIndex) => onSkipSet(item.slot.id, setIndex),
                    skippedSetIndices: locallySkippedSetKeys
                        .where((k) => k.startsWith('${item.slot.id}-'))
                        .map((k) => int.parse(k.split('-').last))
                        .toSet(),
                    onSwapped: () => ref.invalidate(dayPlanProvider(dayKey)),
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
      ],
    );
  }

  static ({String slotId, int setIndex})? _computeActiveSet(
    List<ExerciseSlotWithExercise> items,
    Map<String, List<SetEntry>> entriesBySlot,
    Map<String, WeekTarget> targets,
  ) {
    for (final item in items) {
      final target = targets[item.slot.id];
      if (target == null) continue;
      final entries = entriesBySlot[item.slot.id] ?? [];
      for (var i = 0; i < target.sets; i++) {
        final done = entries.firstWhereOrNull((e) => e.setIndex == i && e.done);
        if (done == null) return (slotId: item.slot.id, setIndex: i);
      }
    }
    return null;
  }
}

// ── Day picker strip ──────────────────────────────────────────────────────────

class _DayPickerStrip extends ConsumerStatefulWidget {
  final Mesocycle meso;
  final DayKey effective;
  final void Function(int weekIdx, int dayIdx) onDaySelected;

  const _DayPickerStrip({
    required this.meso,
    required this.effective,
    required this.onDaySelected,
  });

  @override
  ConsumerState<_DayPickerStrip> createState() => _DayPickerStripState();
}

class _DayPickerStripState extends ConsumerState<_DayPickerStrip> {
  final List<GlobalKey> _weekKeys = [];

  @override
  void initState() {
    super.initState();
    _updateKeys();
    _scrollToActive();
  }

  @override
  void didUpdateWidget(_DayPickerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldScroll = false;
    if (widget.meso.numWeeks != oldWidget.meso.numWeeks) {
      _updateKeys();
      shouldScroll = true;
    }
    if (widget.effective.weekIdx != oldWidget.effective.weekIdx) {
      shouldScroll = true;
    }
    if (shouldScroll) {
      _scrollToActive();
    }
  }

  void _updateKeys() {
    _weekKeys.clear();
    for (int i = 0; i < widget.meso.numWeeks; i++) {
      _weekKeys.add(GlobalKey());
    }
  }

  void _scrollToActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _weekKeys[widget.effective.weekIdx];
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: 0.5, // Center it if possible
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);

    return Column(
      children: [
        // Weeks
        Stack(
          children: [
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: widget.meso.numWeeks,
                itemBuilder: (ctx, i) {
                  final active = widget.effective.weekIdx == i;
                  return GestureDetector(
                    key: _weekKeys[i],
                    onTap: () => widget.onDaySelected(i, widget.effective.dayIdx),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: active ? p.text : p.chipBg,
                        borderRadius: BorderRadius.circular(SGRadius.chip),
                      ),
                      child: Center(
                        child: Text(
                          'WEEK ${i + 1}',
                          style: SGText.mono(11,
                              color: active ? p.bg : p.textDim,
                              weight: active ? FontWeight.bold : FontWeight.normal),
                        ),
                      ),
                    ),
                  );
                },
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
        ),
        // Days
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _dayChip(context, i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayChip(BuildContext context, int dayIdx) {
    final p = pal(context);
    final active = widget.effective.dayIdx == dayIdx;
    final groupAsync = ref.watch(dayGroupProvider(
        DayKey(widget.meso.id, widget.effective.weekIdx, dayIdx)));
    final group = groupAsync.valueOrNull ?? MuscleGroup.rest;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return GestureDetector(
      onTap: () => widget.onDaySelected(widget.effective.weekIdx, dayIdx),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? group.color : group.tint(Theme.of(context).brightness),
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Colors.transparent : p.border,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            days[dayIdx],
            style: SGText.mono(13,
                color: active ? Colors.black : p.textDim,
                weight: active ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
    );
  }
}

// ── Session header ────────────────────────────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  final MuscleGroup group;
  final String title;
  final String plateLabel;
  final Mesocycle meso;
  final DayKey effective;
  final double topPad;
  final bool isToday;
  final VoidCallback? onTapToday;

  const _SessionHeader({
    required this.group,
    required this.title,
    required this.plateLabel,
    required this.meso,
    required this.effective,
    required this.topPad,
    required this.isToday,
    this.onTapToday,
  });

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final brightness = Theme.of(context).brightness;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return Container(
      color: p.bg,
      padding: EdgeInsets.only(top: topPad),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: group.tint(brightness),
          borderRadius: BorderRadius.circular(SGRadius.card),
          border: Border.all(color: p.borderStrong, width: 0.5),
        ),
        child: Row(
          children: [
            SGPlateDisc(size: 32, label: plateLabel, color: group.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title.endsWith('Session') ? title : '$title Session',
                      style: SGText.display(15, color: p.text),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                  Text(
                    'WEEK ${effective.weekIdx + 1} · '
                    '${days[effective.dayIdx]}',
                    style: SGText.mono(10, color: p.textDim),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (!isToday && onTapToday != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onTapToday,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Today', style: SGText.mono(10, color: p.accent)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends ConsumerWidget {
  final ExerciseSlotWithExercise item;
  final MuscleGroup group;
  final WeekTarget? target;
  final List<SetEntry> entries;
  final ({String slotId, int setIndex})? activeSet;
  final int extraSets;
  final String? sessionId;
  final double? suggestedWeight;
  final Mesocycle meso;
  final DayKey dayKey;
  final Future<void> Function(int setIndex, double? weight, int reps, int rir)
      onLogSet;
  final void Function(int setIndex) onActivate;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;
  final void Function(String entryId) onDeleteSet;
  final void Function(int setIndex) onSkipSet;
  final Set<int> skippedSetIndices;
  final VoidCallback onSwapped;

  const _ExerciseCard({
    required this.item,
    required this.group,
    required this.target,
    required this.entries,
    required this.activeSet,
    required this.extraSets,
    required this.sessionId,
    required this.suggestedWeight,
    required this.meso,
    required this.dayKey,
    required this.onLogSet,
    required this.onActivate,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onDeleteSet,
    required this.onSkipSet,
    required this.skippedSetIndices,
    required this.onSwapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    final baseNumSets = target?.sets ?? 3;
    final exercise = item.exercise;
    final entriesMaxIdx = entries.isEmpty
        ? -1
        : entries.map((e) => e.setIndex).reduce(max);
    final numSets = max(baseNumSets + extraSets, entriesMaxIdx + 1);
    final doneCount = entries.where((e) => e.done).length;
    final isDone = doneCount >= numSets;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(SGRadius.card),
        border: Border.all(
          color: isDone ? p.success.withValues(alpha: 0.3) : p.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                SGGroupDot(group, size: 8),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(exercise.name,
                      style: SGText.body(15,
                          weight: FontWeight.w700, color: p.text)),
                ),
                IconButton(
                  icon: Icon(Icons.play_circle_outline, color: p.textFaint, size: 20),
                  onPressed: () => GuideSheet.show(context, exercise.name),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                if (isDone) const SGChip('Done', tone: ChipTone.success),
                GestureDetector(
                  onTap: () => _showSwapMenu(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child:
                        Icon(Icons.swap_horiz, size: 20, color: p.textDim),
                  ),
                ),
              ],
            ),
          ),
          if (target != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'TARGET · ${target!.sets}×${target!.reps} · RIR ${target!.rir}',
                style: SGText.mono(10, color: p.textDim),
              ),
            ),
          // Set rows
          ...List.generate(numSets, (i) {
            if (skippedSetIndices.contains(i)) return const SizedBox.shrink();

            final entry =
                entries.firstWhereOrNull((e) => e.setIndex == i && e.done);
            final isActive = activeSet?.slotId == item.slot.id &&
                activeSet?.setIndex == i;

            if (isActive) {
              final recentSessionEntry = entries
                  .where((e) => e.done && e.setIndex < i)
                  .sortedBy<num>((e) => e.setIndex)
                  .lastOrNull;

              return SetRowActive(
                key: ValueKey('active-${item.slot.id}-$i'),
                setIndex: i,
                exerciseId: exercise.id,
                slotId: item.slot.id,
                sessionId: sessionId,
                targetReps: target?.reps ?? 8,
                targetRir: target?.rir ?? 3,
                suggestedWeight: suggestedWeight,
                initialEntry: entry,
                recentSessionEntry: recentSessionEntry,
                group: group,
                onLogSet: (w, r, ri) => onLogSet(i, w, r, ri),
              );
            } else if (entry != null) {
              return SetRowDone(
                setIndex: i,
                entry: entry,
                targetRir: target?.rir ?? 3,
                groupColor: group.color,
                onTap: () => onActivate(i),
              );
            } else {
              return SetRowInactive(
                setIndex: i,
                targetReps: target?.reps ?? 8,
                targetRir: target?.rir ?? 3,
                onTap: () => onActivate(i),
              );
            }
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SGButton.soft(
              label: '+ Add set',
              fullWidth: true,
              onTap: onAddSet,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showSwapMenu(BuildContext context, WidgetRef ref) {
    showSGSheet(
      context,
      isScrollControlled: true,
      maxHeightFraction: 0.78,
      child: SwapMenu(
        currentExercise: item.exercise,
        slotId: item.slot.id,
        dayKey: dayKey,
        meso: meso,
        onSwapped: onSwapped,
      ),
    );
  }
}

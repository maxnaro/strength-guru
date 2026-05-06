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
  ({String exerciseId, int setIndex})? _userActiveSet;
  DayKey? _lastDayKey;
  final Map<String, int> _extraSetsByExId = {};
  final Set<String> _locallyDeletedSetIds = {};
  final Set<String> _locallySkippedSetKeys = {};

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
      setIndex: setIndex,
      weight: weight,
      reps: reps,
      rir: rir,
      done: true,
    );
    ref.invalidate(suggestedWeightProvider(exerciseId));

    if (mounted &&
        _userActiveSet?.exerciseId == exerciseId &&
        _userActiveSet?.setIndex == setIndex) {
      setState(() => _userActiveSet = null);
    }
  }

  void _navigateDay(Mesocycle meso, DayKey current, int delta) {
    int newDay = current.dayIdx + delta;
    int newWeek = current.weekIdx;
    if (newDay < 0) {
      newWeek--;
      newDay = 6;
    } else if (newDay > 6) {
      newWeek++;
      newDay = 0;
    }
    if (newWeek < 0 || newWeek >= meso.numWeeks) return;
    ref.read(selectedLogDayProvider.notifier).state =
        DayKey(meso.id, newWeek, newDay);
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

    final planAsync = ref.watch(dayPlanProvider(effective));
    final targetsAsync =
        ref.watch(weekTargetsProvider(WeekKey(meso.id, effective.weekIdx)));
    final sessionAsync = ref.watch(sessionLogProvider(effective));
    final sessionLog = sessionAsync.valueOrNull;

    final groupAsync = ref.watch(dayGroupProvider(effective));
    final group = groupAsync.valueOrNull ?? MuscleGroup.rest;
    final daySettingsAsync =
        ref.watch(programDayProvider(ProgramDayKey(meso.id, effective.dayIdx)));
    final splitName =
        daySettingsAsync.valueOrNull?.label ?? '${group.label} Session';

    final exercises = planAsync.valueOrNull ?? [];
    final targets = targetsAsync.valueOrNull ?? {};

    // Reset user selections when day changes
    if (effective != _lastDayKey) {
      _userActiveSet = null;
      _extraSetsByExId.clear();
      _locallyDeletedSetIds.clear();
      _locallySkippedSetKeys.clear();
      _lastDayKey = effective;
    }

    final entriesList = sessionLog != null
        ? ref.watch(setsForLogProvider(sessionLog.id)).valueOrNull ?? []
        : <SetEntry>[];

    final filteredEntries = entriesList
        .where((e) => !_locallyDeletedSetIds.contains(e.id))
        .toList();

    final entriesByEx = <String, List<SetEntry>>{};
    for (final e in filteredEntries) {
      (entriesByEx[e.exerciseId] ??= []).add(e);
    }

    final isRestDay = exercises.isEmpty;
    final implicitActive = _computeActiveSet(exercises, entriesByEx, targets);
    final effectiveActiveSet = _userActiveSet ?? implicitActive;

    // Header height: base content + top safe area
    const kHeaderContent = 68.0;
    final headerH = kHeaderContent + topPad;

    return Scaffold(
      backgroundColor: p.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          const threshold = 250.0;
          final v = details.primaryVelocity;
          if (v == null) return;
          if (v > threshold) {
            _navigateDay(meso, effective, -1); // swipe right = prev day
          } else if (v < -threshold) {
            _navigateDay(meso, effective, 1); // swipe left = next day
          }
        },
        child: CustomScrollView(
          slivers: [
            // Sticky session header
            SliverPersistentHeader(
              pinned: true,
              delegate: _FixedHeaderDelegate(
                height: headerH,
                child: _SessionHeader(
                  group: group,
                  title: splitName,
                  plateLabel: (daySettingsAsync.valueOrNull?.label ?? group.label)
                      .toUpperCase(),
                  meso: meso,
                  effective: effective,
                  topPad: topPad,
                  isToday: today != null &&
                      effective.weekIdx == today.weekIdx &&
                      effective.dayIdx == today.dayIdx,
                  onTapToday: () =>
                      ref.read(selectedLogDayProvider.notifier).state = null,
                ),
              ),
            ),

          // Day picker strip
          SliverToBoxAdapter(
            child: _DayPickerStrip(
              meso: meso,
              effective: effective,
            ),
          ),

          // Exercise cards or rest message
          if (isRestDay)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('Recovery day.',
                    style: SGText.display(24, color: p.text)),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.only(top: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final ex = exercises[i];
                    final target = targets[ex.id];
                    final exGroup = MuscleGroupX.fromString(ex.group);
                    final exEntries = entriesByEx[ex.id] ?? [];
                    final suggestedW =
                        ref.watch(suggestedWeightProvider(ex.id)).valueOrNull;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ExerciseCard(
                        exercise: ex,
                        group: exGroup,
                        target: target,
                        entries: exEntries,
                        activeSet: effectiveActiveSet,
                        extraSets: _extraSetsByExId[ex.id] ?? 0,
                        sessionId: sessionLog?.id,
                        suggestedWeight: suggestedW,
                        meso: meso,
                        dayKey: effective,
                        onLogSet: (si, w, r, ri) => _logSet(
                          effective: effective,
                          sessionId: sessionLog?.id,
                          exerciseId: ex.id,
                          setIndex: si,
                          weight: w,
                          reps: r,
                          rir: ri,
                        ),
                        onActivate: (si) => setState(
                          () => _userActiveSet = (exerciseId: ex.id, setIndex: si),
                        ),
                        onAddSet: () => setState(
                          () => _extraSetsByExId[ex.id] = (_extraSetsByExId[ex.id] ?? 0) + 1,
                        ),
                        onRemoveSet: () => setState(
                          () => _extraSetsByExId[ex.id] = max(0, (_extraSetsByExId[ex.id] ?? 0) - 1),
                        ),
                        onDeleteSet: (entryId) {
                          setState(() => _locallyDeletedSetIds.add(entryId));
                          ref.read(dbProvider).deleteSetEntry(entryId);
                          ref.invalidate(suggestedWeightProvider(ex.id));
                        },
                        onSkipSet: (setIndex) {
                          setState(() => _locallySkippedSetKeys.add('${ex.id}-$setIndex'));
                        },
                        skippedSetIndices: _locallySkippedSetKeys
                            .where((k) => k.startsWith('${ex.id}-'))
                            .map((k) => int.parse(k.split('-').last))
                            .toSet(),
                        onSwapped: () => ref.invalidate(dayPlanProvider(effective)),
                      ),
                    );
                  },
                  childCount: exercises.length,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
        ],
      ),
    ),
    );
  }

  static ({String exerciseId, int setIndex})? _computeActiveSet(
    List<Exercise> exercises,
    Map<String, List<SetEntry>> entriesByEx,
    Map<String, WeekTarget> targets,
  ) {
    for (final ex in exercises) {
      final target = targets[ex.id];
      if (target == null) continue;
      final entries = entriesByEx[ex.id] ?? [];
      for (var i = 0; i < target.sets; i++) {
        final done = entries.firstWhereOrNull((e) => e.setIndex == i && e.done);
        if (done == null) return (exerciseId: ex.id, setIndex: i);
      }
    }
    return null;
  }
}

// ── Day picker strip ──────────────────────────────────────────────────────────

class _DayPickerStrip extends ConsumerWidget {
  final Mesocycle meso;
  final DayKey effective;

  const _DayPickerStrip({
    required this.meso,
    required this.effective,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                itemCount: meso.numWeeks,
                itemBuilder: (ctx, i) {
                  final active = effective.weekIdx == i;
                  return GestureDetector(
                    onTap: () {
                      ref.read(selectedLogDayProvider.notifier).state =
                          DayKey(meso.id, i, effective.dayIdx);
                    },
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
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (int i = 0; i < 7; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _dayChip(context, ref, i),
                      ),
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
          ),
        ),
      ],
    );
  }

  Widget _dayChip(BuildContext context, WidgetRef ref, int dayIdx) {
    final p = pal(context);
    final active = effective.dayIdx == dayIdx;
    final groupAsync = ref
        .watch(dayGroupProvider(DayKey(meso.id, effective.weekIdx, dayIdx)));
    final group = groupAsync.valueOrNull ?? MuscleGroup.rest;
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return GestureDetector(
      onTap: () {
        ref.read(selectedLogDayProvider.notifier).state =
            DayKey(meso.id, effective.weekIdx, dayIdx);
      },
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

// ── Fixed sliver header delegate ──────────────────────────────────────────────

class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _FixedHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_FixedHeaderDelegate old) =>
      old.height != height || old.child != child;
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
  final Exercise exercise;
  final MuscleGroup group;
  final WeekTarget? target;
  final List<SetEntry> entries;
  final ({String exerciseId, int setIndex})? activeSet;
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
    required this.exercise,
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
            final isActive = activeSet?.exerciseId == exercise.id &&
                activeSet?.setIndex == i;

            Widget row;
            if (isActive) {
              row = SetRowActive(
                key: ValueKey('active-${exercise.id}-$i'),
                setIndex: i,
                exerciseId: exercise.id,
                sessionId: sessionId,
                targetReps: target?.reps ?? 8,
                targetRir: target?.rir ?? 3,
                suggestedWeight: suggestedWeight,
                initialEntry: entry,
                group: group,
                onLogSet: (w, r, ri) => onLogSet(i, w, r, ri),
              );
            } else if (entry != null) {
              row = SetRowDone(
                setIndex: i,
                entry: entry,
                targetRir: target?.rir ?? 3,
                groupColor: group.color,
                onTap: () => onActivate(i),
              );
            } else {
              row = SetRowInactive(
                setIndex: i,
                targetReps: target?.reps ?? 8,
                targetRir: target?.rir ?? 3,
                onTap: () => onActivate(i),
              );
            }

            return Dismissible(
              key: ValueKey('dismiss-${exercise.id}-$i-${entry?.id}-$numSets'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) {
                if (entry != null) {
                  onDeleteSet(entry.id);
                } else if (i >= baseNumSets) {
                  onRemoveSet();
                } else {
                  onSkipSet(i);
                }
              },
              background: Container(
                color: p.warn,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              child: row,
            );
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
        currentExercise: exercise,
        dayKey: dayKey,
        meso: meso,
        onSwapped: onSwapped,
      ),
    );
  }
}

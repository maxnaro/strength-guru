import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../providers.dart';
import '../theme/groups.dart';
import '../theme/tokens.dart';
import '../theme/sg_atoms.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesoAsync = ref.watch(activeMesoProvider);

    return mesoAsync.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _ErrorView(e.toString()),
      data: (meso) {
        if (meso == null) return const _EmptyMesoView();
        final heroKey = ref.watch(heroKeyProvider);
        if (heroKey == null) return const _MesoFinishedView();
        return _DayView(meso: meso, heroKey: heroKey);
      },
    );
  }
}

// ── Sub-views ─────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
        backgroundColor: p.bg,
        body: Center(child: CircularProgressIndicator(color: p.accent)));
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView(this.message);
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
        backgroundColor: p.bg,
        body: Center(
            child: Text(message, style: SGText.body(14, color: p.textDim))));
  }
}

class _EmptyMesoView extends StatelessWidget {
  const _EmptyMesoView();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('No active mesocycle.',
                style: SGText.display(22, color: p.text)),
            const SizedBox(height: 8),
            Text('Create one in the Meso tab.',
                style: SGText.body(14, color: p.textDim)),
          ]),
        ),
      ),
    );
  }
}

class _MesoFinishedView extends StatelessWidget {
  const _MesoFinishedView();
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Mesocycle complete!', style: SGText.display(22, color: p.text)),
            const SizedBox(height: 8),
            Text('Start a new one in the Meso tab.',
                style: SGText.body(14, color: p.textDim)),
          ]),
        ),
      ),
    );
  }
}

// ── Main day view ─────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  final Mesocycle meso;
  final DayKey heroKey;

  const _DayView({required this.meso, required this.heroKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    final brightness = Theme.of(context).brightness;

    final planAsync = ref.watch(dayPlanProvider(heroKey));
    final exercises = planAsync.valueOrNull ?? [];
    final group = MuscleGroupX.primaryFromGroups(
        exercises.map((e) => e.group).toList());
    final isRest = exercises.isEmpty;

    final targetsAsync =
        ref.watch(weekTargetsProvider(WeekKey(meso.id, heroKey.weekIdx)));
    final sessionAsync = ref.watch(sessionLogProvider(heroKey));

    final bottomPad = MediaQuery.of(context).padding.bottom + SGTabBar.kBaseHeight + 16;

    return Scaffold(
      backgroundColor: p.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // ── Hero card ──────────────────────────────────────────
                  _HeroCard(
                    meso: meso,
                    heroKey: heroKey,
                    group: group,
                    isRest: isRest,
                    brightness: brightness,
                    planAsync: planAsync,
                    targetsAsync: targetsAsync,
                    sessionAsync: sessionAsync,
                  ),
                  const SizedBox(height: 12),
                  // ── Quick stats ────────────────────────────────────────
                  if (!isRest)
                    _QuickStats(
                        meso: meso, heroKey: heroKey, group: group,
                        targetsAsync: targetsAsync),
                  const SizedBox(height: 20),
                  // ── Today's plan ───────────────────────────────────────
                  if (!isRest) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "TODAY'S PLAN",
                        style: SGText.mono(11, color: p.textFaint, ls: 1.2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PlanList(
                      heroKey: heroKey,
                      group: group,
                      planAsync: planAsync,
                      targetsAsync: targetsAsync,
                      sessionAsync: sessionAsync,
                    ),
                  ],
                  const SizedBox(height: 20),
                  // ── Meso strip ─────────────────────────────────────────
                  _MesoStrip(meso: meso, currentWeekIdx: heroKey.weekIdx, group: group),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
        ],
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends ConsumerWidget {
  final Mesocycle meso;
  final DayKey heroKey;
  final MuscleGroup group;
  final bool isRest;
  final Brightness brightness;
  final AsyncValue<List<Exercise>> planAsync;
  final AsyncValue<Map<String, WeekTarget>> targetsAsync;
  final AsyncValue<SessionLog?> sessionAsync;

  const _HeroCard({
    required this.meso,
    required this.heroKey,
    required this.group,
    required this.isRest,
    required this.brightness,
    required this.planAsync,
    required this.targetsAsync,
    required this.sessionAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    final exercises = planAsync.valueOrNull ?? [];
    final targets = targetsAsync.valueOrNull ?? {};
    final session = sessionAsync.valueOrNull;
    final daySettingsAsync = ref.watch(programDayProvider(ProgramDayKey(meso.id, heroKey.dayIdx)));
    final customLabel = daySettingsAsync.valueOrNull?.label;
    final isDeloadWeek = ref.watch(isDeloadWeekProvider(WeekKey(meso.id, heroKey.weekIdx)));

    // Compute progress from set entries if session exists.
    final setsAsync = session != null
        ? ref.watch(setsForLogProvider(session.id))
        : const AsyncData<List<SetEntry>>([]);
    final allEntries = setsAsync.valueOrNull ?? [];
    final doneCount = allEntries.where((e) => e.done).length;

    final totalSets = exercises.fold<int>(
        0, (sum, ex) => sum + (targets[ex.id]?.sets ?? 0));

    final dayLabel = _dayLabel(heroKey.dayIdx);
    final splitName = customLabel ?? group.title;
    final hasEntries = doneCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: group.tint(brightness),
          borderRadius: BorderRadius.circular(SGRadius.hero),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Eyebrow chips
                      Row(children: [
                        SGChip('WEEK ${heroKey.weekIdx + 1}'),
                        const SizedBox(width: 6),
                        SGChip(dayLabel.toUpperCase()),
                        if (isDeloadWeek) ...[
                          const SizedBox(width: 6),
                          const SGChip('DELOAD', tone: ChipTone.warn),
                        ],
                      ]),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        splitName,
                        style: SGText.display(30, lh: 1.05, color: p.text),
                      ),
                      const SizedBox(height: 4),
                      // Subtitle
                      if (isRest)
                        Text(
                          'Rest up.',
                          style: SGText.body(14, color: p.textDim),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SGPlateDisc(
                  size: 72,
                  label: isRest ? 'REST' : (customLabel ?? group.label).toUpperCase(),
                  color: group.color,
                ),
              ],
            ),
            // CTA
            if (!isRest) ...[
              const SizedBox(height: 16),
              SGButton.solid(
                label: hasEntries ? 'Resume Log' : 'Open Log',
                trailingIcon:
                    Icon(Icons.arrow_forward, size: 16, color: p.bg),
                color: group.color,
                fullWidth: true,
                onTap: () => _startSession(context, ref),
              ),
              if (totalSets > 0) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Text(
                    '$doneCount / $totalSets SETS',
                    style: SGText.mono(11, color: p.textDim),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SGProgressRail(
                      progress:
                          totalSets == 0 ? 0 : doneCount / totalSets,
                      color: group.color,
                      height: 6,
                    ),
                  ),
                ]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    final db = ref.read(dbProvider);
    await db.getOrCreateSessionLog(
        heroKey.mesoId, heroKey.weekIdx, heroKey.dayIdx);
    ref.invalidate(sessionLogProvider(heroKey));
    ref.read(tabIndexProvider.notifier).state = 1;
  }

  static String _dayLabel(int dayIdx) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayIdx % 7];
  }
}

// ── Quick stats ───────────────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  final Mesocycle meso;
  final DayKey heroKey;
  final MuscleGroup group;
  final AsyncValue<Map<String, WeekTarget>> targetsAsync;

  const _QuickStats({
    required this.meso,
    required this.heroKey,
    required this.group,
    required this.targetsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SGStat(
              label: 'WEEK',
              value: '${heroKey.weekIdx + 1}/${meso.numWeeks}',
              accentBar: group.color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SGStat(
              label: 'STARTED',
              value: DateFormat('MMM d').format(meso.startDate),
              accentBar: group.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan list ─────────────────────────────────────────────────────────────────

class _PlanList extends ConsumerWidget {
  final DayKey heroKey;
  final MuscleGroup group;
  final AsyncValue<List<Exercise>> planAsync;
  final AsyncValue<Map<String, WeekTarget>> targetsAsync;
  final AsyncValue<SessionLog?> sessionAsync;

  const _PlanList({
    required this.heroKey,
    required this.group,
    required this.planAsync,
    required this.targetsAsync,
    required this.sessionAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    final brightness = Theme.of(context).brightness;
    final exercises = planAsync.valueOrNull ?? [];
    final targets = targetsAsync.valueOrNull ?? {};
    final session = sessionAsync.valueOrNull;

    final setsAsync = session != null
        ? ref.watch(setsForLogProvider(session.id))
        : const AsyncData<List<SetEntry>>([]);
    final allEntries = setsAsync.valueOrNull ?? [];

    if (exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('No exercises.', style: SGText.body(14, color: p.textDim)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(SGRadius.card),
          border: Border.all(color: p.border, width: 0.5),
        ),
        child: Column(
          children: exercises.indexed.map((item) {
            final (idx, ex) = item;
            final target = targets[ex.id];
            final exEntries = allEntries.where((e) => e.exerciseId == ex.id);
            final doneCount = exEntries.where((e) => e.done).length;
            final totalSets = target?.sets ?? 0;
            final isDone = totalSets > 0 && doneCount >= totalSets;
            final exGroup = MuscleGroupX.fromString(ex.group);

            return Column(
              children: [
                InkWell(
                  onTap: () => ref.read(tabIndexProvider.notifier).state = 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Number tile
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: exGroup.tint(brightness),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              (idx + 1).toString().padLeft(2, '0'),
                              style: SGText.display(13,
                                  color: exGroup.color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name + meta
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex.name,
                                  style: SGText.body(15,
                                      weight: FontWeight.w600,
                                      color: p.text)),
                              if (target != null)
                                Text(
                                  '${target.sets}×${target.reps} · RIR ${target.rir}',
                                  style: SGText.mono(11, color: p.textDim),
                                ),
                            ],
                          ),
                        ),
                        // Done indicator
                        if (totalSets > 0)
                          Text(
                            '$doneCount/$totalSets',
                            style: SGText.mono(12,
                                color: isDone ? p.success : p.textDim),
                          ),
                      ],
                    ),
                  ),
                ),
                if (idx < exercises.length - 1)
                  Divider(
                      height: 1, indent: 64, endIndent: 0, color: p.border),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Meso strip ────────────────────────────────────────────────────────────────

class _MesoStrip extends ConsumerWidget {
  final Mesocycle meso;
  final int currentWeekIdx;
  final MuscleGroup group;

  const _MesoStrip({
    required this.meso,
    required this.currentWeekIdx,
    required this.group,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pal(context);
    final brightness = Theme.of(context).brightness;
    bool isDeload(int w) => ref.watch(isDeloadWeekProvider(WeekKey(meso.id, w)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('MESOCYCLE',
                style: SGText.mono(11, color: p.textFaint, ls: 1.2)),
            const Spacer(),
            GestureDetector(
              onTap: () => ref.read(tabIndexProvider.notifier).state = 2,
              child: Text('Edit →',
                  style: SGText.body(13, color: p.accent, weight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: List.generate(meso.numWeeks, (w) {
                    final isCurrent = w == currentWeekIdx;
                    final isPast = w < currentWeekIdx;
                    return Opacity(
                      opacity: isPast ? 0.55 : 1.0,
                      child: Container(
                        width: 64,
                        margin: EdgeInsets.only(right: w < meso.numWeeks - 1 ? 6 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isCurrent ? group.tint(brightness) : p.chipBg,
                          borderRadius: BorderRadius.circular(10),
                          border: isCurrent
                              ? Border.all(color: p.borderStrong, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'W${w + 1}',
                              style: SGText.mono(9, color: p.textFaint),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDeload(w) ? 'D' : 'RIR ${[3, 2, 2, 1, 4][w % 5]}',
                              style: SGText.display(11,
                                  color: isDeload(w) ? p.warn : p.text),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
        ],
      ),
    );
  }
}

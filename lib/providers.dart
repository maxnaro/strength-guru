import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'db/queries.dart';
import 'theme/groups.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ExerciseSlotWithExercise {
  final ExerciseSlot slot;
  final Exercise exercise;
  ExerciseSlotWithExercise(this.slot, this.exercise);

  String get id => slot.id;
  String get exerciseId => exercise.id;
  String get name => exercise.name;
  String get group => exercise.group;
}

// ── Provider keys ─────────────────────────────────────────────────────────────

@immutable
class DayKey {
  final String mesoId;
  final int weekIdx;
  final int dayIdx;
  const DayKey(this.mesoId, this.weekIdx, this.dayIdx);

  @override
  bool operator ==(Object other) =>
      other is DayKey &&
      mesoId == other.mesoId &&
      weekIdx == other.weekIdx &&
      dayIdx == other.dayIdx;

  @override
  int get hashCode => Object.hash(mesoId, weekIdx, dayIdx);
}

@immutable
class WeekKey {
  final String mesoId;
  final int weekIdx;
  const WeekKey(this.mesoId, this.weekIdx);

  @override
  bool operator ==(Object other) =>
      other is WeekKey && mesoId == other.mesoId && weekIdx == other.weekIdx;

  @override
  int get hashCode => Object.hash(mesoId, weekIdx);
}

@immutable
class PrevSetKey {
  final String exerciseId;
  final int setIndex;
  final String? excludingSessionId;
  const PrevSetKey(this.exerciseId, this.setIndex, [this.excludingSessionId]);

  @override
  bool operator ==(Object other) =>
      other is PrevSetKey &&
      exerciseId == other.exerciseId &&
      setIndex == other.setIndex &&
      excludingSessionId == other.excludingSessionId;

  @override
  int get hashCode => Object.hash(exerciseId, setIndex, excludingSessionId);
}

@immutable
class ProgramDayKey {
  final String mesoId;
  final int weekIdx;
  final int dayIdx;
  const ProgramDayKey(this.mesoId, this.weekIdx, this.dayIdx);

  @override
  bool operator ==(Object other) =>
      other is ProgramDayKey &&
      mesoId == other.mesoId &&
      weekIdx == other.weekIdx &&
      dayIdx == other.dayIdx;

  @override
  int get hashCode => Object.hash(mesoId, weekIdx, dayIdx);
}

// ── Core providers ────────────────────────────────────────────────────────────

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tabIndexProvider = StateProvider<int>((ref) => 0);

final selectedLogDayProvider = StateProvider<DayKey?>((ref) => null);

final timelineRequestedWeekProvider = StateProvider<int?>((ref) => null);

// ── Meso providers ────────────────────────────────────────────────────────────

final activeMesoProvider = StreamProvider<Mesocycle?>((ref) {
  return ref.watch(dbProvider).watchActiveMesocycle();
});

final allMesosProvider = StreamProvider<List<Mesocycle>>((ref) {
  return ref.watch(dbProvider).watchAllMesocycles();
});

final allExercisesProvider = FutureProvider<List<Exercise>>((ref) {
  return ref.watch(dbProvider).allExercises();
});

final phasesProvider =
    StreamProvider.family<List<MesoPhase>, String>((ref, mesoId) {
  return ref.watch(dbProvider).watchPhases(mesoId);
});

final programDayProvider =
    StreamProvider.family<ProgramDay?, ProgramDayKey>((ref, k) {
  return ref.watch(dbProvider).watchProgramDay(k.mesoId, k.weekIdx, k.dayIdx);
});

final isDeloadWeekProvider = Provider.family<bool, WeekKey>((ref, k) {
  final mesoAsync = ref.watch(activeMesoProvider);
  final meso = mesoAsync.valueOrNull;
  if (meso == null) return false;
  final deloads =
      meso.deloadWeeks.split(',').where((s) => s.isNotEmpty).toSet();
  return deloads.contains(k.weekIdx.toString());
});

// ── Today key (derived from active meso + DateTime.now) ───────────────────────

final todayKeyProvider = Provider<DayKey?>((ref) {
  final mesoAsync = ref.watch(activeMesoProvider);
  return mesoAsync.whenOrNull(
    data: (meso) => meso == null ? null : _computeTodayKey(meso),
  );
});

DayKey? _computeTodayKey(Mesocycle meso) {
  final now = DateTime.now();
  final start = meso.startDate;
  // Normalize to date-only (no time component) for day difference calc.
  final startDay = DateTime(start.year, start.month, start.day);
  final today = DateTime(now.year, now.month, now.day);
  final daysSince = today.difference(startDay).inDays;
  if (daysSince < 0) return null; // meso hasn't started yet
  final weekIdx = daysSince ~/ 7;
  if (weekIdx >= meso.numWeeks) return null; // meso finished
  final dayIdx = (now.weekday - 1) % 7; // 0=Mon, 6=Sun
  return DayKey(meso.id, weekIdx, dayIdx);
}

// ── Hero key (Sticky to today) ───────────────────────────────────────────────

final heroKeyProvider = Provider<DayKey?>((ref) {
  final selectedLogDay = ref.watch(selectedLogDayProvider);
  if (selectedLogDay != null) return selectedLogDay;

  return ref.watch(todayKeyProvider);
});

// ── Day plan provider ─────────────────────────────────────────────────────────

final dayPlanProvider =
    FutureProvider.family<List<ExerciseSlotWithExercise>, DayKey>((ref, key) async {
  final db = ref.read(dbProvider);
  var override = await db.getDayOverride(key.mesoId, key.weekIdx, key.dayIdx);
  override ??= await db.getDayOverride(key.mesoId, -1, key.dayIdx);
  if (override != null) {
    final slotIds = override.exerciseIdsCsv.split(',').where((s) => s.isNotEmpty).toList();
    final slots = await db.getSlotsByIds(slotIds);
    final exIds = slots.map((s) => s.exerciseId).toList();
    final exs = await db.exercisesByIds(exIds);

    final slotMap = {for (final s in slots) s.id: s};
    final exMap = {for (final e in exs) e.id: e};

    return [
      for (final sId in slotIds)
        if (slotMap[sId] != null && exMap[slotMap[sId]!.exerciseId] != null)
          ExerciseSlotWithExercise(slotMap[sId]!, exMap[slotMap[sId]!.exerciseId]!)
    ];
  }
  return [];
});

final dayGroupProvider =
    FutureProvider.family<MuscleGroup, DayKey>((ref, key) async {
  final items = await ref.watch(dayPlanProvider(key).future);
  return MuscleGroupX.primaryFromGroups(
      items.map((e) => e.group).toList());
});

final programDayExercisesProvider =
    FutureProvider.family<List<ExerciseSlotWithExercise>, ProgramDayKey>((ref, k) async {
  final db = ref.read(dbProvider);
  var ov = await db.getDayOverride(k.mesoId, k.weekIdx, k.dayIdx);
  if (ov == null && k.weekIdx != -1) {
    ov = await db.getDayOverride(k.mesoId, -1, k.dayIdx);
  }
  
  if (ov == null) {
    final allOvs = await db.getOverridesForDay(k.mesoId, k.dayIdx);
    if (allOvs.isEmpty) return [];
    final counts = <String, int>{};
    for (final o in allOvs) {
      if (o.weekIdx >= 0) {
        counts[o.exerciseIdsCsv] = (counts[o.exerciseIdsCsv] ?? 0) + 1;
      }
    }
    if (counts.isNotEmpty) {
      final bestCsv = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      await db.setDayOverride(k.mesoId, -1, k.dayIdx, bestCsv.split(','));
      ov = await db.getDayOverride(k.mesoId, -1, k.dayIdx);
    }
  }
  if (ov != null) {
    final slotIds = ov.exerciseIdsCsv.split(',').where((s) => s.isNotEmpty).toList();
    final slots = await db.getSlotsByIds(slotIds);
    final exIds = slots.map((s) => s.exerciseId).toList();
    final exs = await db.exercisesByIds(exIds);

    final slotMap = {for (final s in slots) s.id: s};
    final exMap = {for (final e in exs) e.id: e};

    return [
      for (final sId in slotIds)
        if (slotMap[sId] != null && exMap[slotMap[sId]!.exerciseId] != null)
          ExerciseSlotWithExercise(slotMap[sId]!, exMap[slotMap[sId]!.exerciseId]!)
    ];
  }
  return [];
});

// ── Session log provider ──────────────────────────────────────────────────────

final sessionLogProvider =
    FutureProvider.family<SessionLog?, DayKey>((ref, key) async {
  final db = ref.read(dbProvider);
  return db.getSessionLog(key.mesoId, key.weekIdx, key.dayIdx);
});

// ── Set entries stream (keyed by session ID) ──────────────────────────────────

final setsForLogProvider =
    StreamProvider.family<List<SetEntry>, String>((ref, sessionId) {
  return ref.watch(dbProvider).watchSetsForSession(sessionId);
});

// ── Week targets ──────────────────────────────────────────────────────────────

final weekTargetsProvider =
    FutureProvider.family<Map<String, WeekTarget>, WeekKey>((ref, key) async {
  final db = ref.read(dbProvider);
  return db.getWeekTargets(key.mesoId, key.weekIdx);
});

// ── Suggested weight (first set of last completion) ───────────────────────────

final suggestedSetProvider =
    StreamProvider.family<SetEntry?, PrevSetKey>((ref, key) {
  final db = ref.read(dbProvider);
  return db.watchLastCompletionFirstSet(key.exerciseId,
      excludingSessionId: key.excludingSessionId);
});

final suggestedWeightProvider =
    StreamProvider.family<double?, String>((ref, exerciseId) {
  final db = ref.read(dbProvider);
  return db
      .watchLastCompletionFirstSet(exerciseId)
      .map((entry) => entry?.weight);
});

// ── Previous set entry (for placeholder hint text) ────────────────────────────

final prevSetProvider =
    StreamProvider.family<SetEntry?, PrevSetKey>((ref, key) {
  final db = ref.read(dbProvider);
  return db.watchLastCompletionFirstSet(key.exerciseId,
      excludingSessionId: key.excludingSessionId);
});

// ── All session logs for a meso (powers calendar done-indicators) ─────────────

final mesoSessionLogsProvider =
    FutureProvider.family<List<SessionLog>, String>((ref, mesoId) async {
  final db = ref.read(dbProvider);
  return (db.select(db.sessionLogs)
        ..where((t) => t.mesocycleId.equals(mesoId)))
      .get();
});

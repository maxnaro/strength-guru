import 'package:drift/drift.dart';
import '../models/meso_import_data.dart';
import '../util/ids.dart';
import 'database.dart';

// ── Exercise queries ──────────────────────────────────────────────────────────

extension ExerciseQueries on AppDatabase {
  Future<List<Exercise>> exercisesByNames(List<String> names) {
    if (names.isEmpty) return Future.value([]);
    return (select(exercises)
          ..where((t) => t.name.isIn(names))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: CustomExpression(
                    'CASE name '
                    '${names.indexed.map((e) => "WHEN '${e.$2.replaceAll("'", "''")}' THEN ${e.$1}").join(' ')} '
                    'ELSE ${names.length} END',
                  ),
                )
          ]))
        .get();
  }

  Future<List<Exercise>> exercisesByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(exercises)..where((t) => t.id.isIn(ids))).get();
  }

  Future<List<Exercise>> allExercises() {
    return (select(exercises)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<Exercise> findOrCreateExerciseByName(String name, String group) async {
    final existing = await (select(exercises)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) return existing;
    final id = newId();
    await into(exercises).insert(
        ExercisesCompanion.insert(id: id, name: name, group: group));
    return (select(exercises)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<ExerciseSlot> findOrCreateExerciseSlot(
      String mesoId, String exerciseId) async {
    final existing = await (select(exerciseSlots)
          ..where((t) =>
              t.mesocycleId.equals(mesoId) & t.exerciseId.equals(exerciseId)))
        .getSingleOrNull();
    if (existing != null) return existing;

    return createExerciseSlot(mesoId, exerciseId);
  }

  Future<ExerciseSlot> createExerciseSlot(
      String mesoId, String exerciseId) async {
    final id = newId();
    await into(exerciseSlots).insert(ExerciseSlotsCompanion.insert(
      id: id,
      mesocycleId: mesoId,
      exerciseId: exerciseId,
    ));
    return (select(exerciseSlots)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<List<ExerciseSlot>> getSlotsByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value([]);
    return (select(exerciseSlots)..where((t) => t.id.isIn(ids))).get();
  }
}

// ── Mesocycle queries ─────────────────────────────────────────────────────────

extension MesoQueries on AppDatabase {
  Stream<Mesocycle?> watchActiveMesocycle() {
    return (select(mesocycles)
          ..where((t) => t.isActive.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<Mesocycle?> getActiveMesocycle() {
    return (select(mesocycles)
          ..where((t) => t.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<List<Mesocycle>> watchAllMesocycles() {
    return (select(mesocycles)
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .watch();
  }

  Future<void> activateMeso(String id) async {
    await transaction(() async {
      await (update(mesocycles)..where((t) => t.isActive.equals(true)))
          .write(const MesocyclesCompanion(isActive: Value(false)));
      await (update(mesocycles)..where((t) => t.id.equals(id)))
          .write(const MesocyclesCompanion(isActive: Value(true)));
    });
  }

  Future<Mesocycle> createMeso(String name) async {
    final id = newId();
    await transaction(() async {
      await (update(mesocycles)..where((t) => t.isActive.equals(true)))
          .write(const MesocyclesCompanion(isActive: Value(false)));
      await into(mesocycles).insert(MesocyclesCompanion.insert(
        id: id,
        name: name,
        startDate: DateTime.now(),
        isActive: const Value(true),
      ));
    });
    return (select(mesocycles)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> deleteMeso(String id) async {
    await transaction(() async {
      final meso =
          await (select(mesocycles)..where((t) => t.id.equals(id))).getSingle();
      await (delete(mesocycles)..where((t) => t.id.equals(id))).go();

      if (meso.isActive) {
        final next = await (select(mesocycles)
              ..orderBy([(t) => OrderingTerm.desc(t.startDate)])
              ..limit(1))
            .getSingleOrNull();
        if (next != null) {
          await (update(mesocycles)..where((t) => t.id.equals(next.id)))
              .write(const MesocyclesCompanion(isActive: Value(true)));
        }
      }
    });
  }

  Future<void> renameMeso(String id, String name) async {
    await (update(mesocycles)..where((t) => t.id.equals(id)))
        .write(MesocyclesCompanion(name: Value(name)));
  }

  Future<void> duplicateMeso(String id, String newName) async {
    final meso =
        await (select(mesocycles)..where((t) => t.id.equals(id))).getSingle();
    final pDays = await (select(programDays)
          ..where((t) => t.mesocycleId.equals(id)))
        .get();
    final slots = await (select(exerciseSlots)
          ..where((t) => t.mesocycleId.equals(id)))
        .get();
    final wTargets = await (select(weekTargets)
          ..where((t) => t.mesocycleId.equals(id)))
        .get();
    final dOverrides = await (select(dayOverrides)
          ..where((t) => t.mesocycleId.equals(id)))
        .get();

    final newId_ = newId();
    await transaction(() async {
      await (update(mesocycles)..where((t) => t.isActive.equals(true)))
          .write(const MesocyclesCompanion(isActive: Value(false)));

      await into(mesocycles).insert(MesocyclesCompanion.insert(
        id: newId_,
        name: newName,
        startDate: DateTime.now(),
        isActive: const Value(true),
        numWeeks: Value(meso.numWeeks),
        deloadWeeks: Value(meso.deloadWeeks),
      ));

      for (final r in pDays) {
        await into(programDays).insert(ProgramDaysCompanion.insert(
          mesocycleId: newId_,
          dayIdx: r.dayIdx,
          label: Value(r.label),
        ));
      }

      final slotMap = <String, String>{};
      for (final r in slots) {
        final newSlotId = newId();
        await into(exerciseSlots).insert(ExerciseSlotsCompanion.insert(
          id: newSlotId,
          mesocycleId: newId_,
          exerciseId: r.exerciseId,
        ));
        slotMap[r.id] = newSlotId;
      }

      for (final r in wTargets) {
        await into(weekTargets).insert(WeekTargetsCompanion.insert(
          mesocycleId: newId_,
          weekIdx: r.weekIdx,
          slotId: slotMap[r.slotId]!,
          sets: r.sets,
          reps: r.reps,
          rir: r.rir,
        ));
      }

      for (final r in dOverrides) {
        final slotIds = r.exerciseIdsCsv
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((s) => slotMap[s]!)
            .join(',');
        await into(dayOverrides).insert(DayOverridesCompanion.insert(
          mesocycleId: newId_,
          weekIdx: r.weekIdx,
          dayIdx: r.dayIdx,
          exerciseIdsCsv: slotIds,
        ));
      }
    });
  }

  Future<void> setMesoCurrentWeek(String id, int targetWeekIdx) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDayIdx = (now.weekday - 1) % 7;
    final daysSince = (targetWeekIdx * 7) + todayDayIdx;
    final newStartDate = today.subtract(Duration(days: daysSince));

    await (update(mesocycles)..where((t) => t.id.equals(id)))
        .write(MesocyclesCompanion(startDate: Value(newStartDate)));
  }
}

// ── WeekTarget queries ────────────────────────────────────────────────────────

extension WeekTargetQueries on AppDatabase {
  Future<Map<String, WeekTarget>> getWeekTargets(String mesoId, int weekIdx) async {
    final rows = await (select(weekTargets)
          ..where((t) =>
              t.mesocycleId.equals(mesoId) & t.weekIdx.equals(weekIdx)))
        .get();
    return {for (final r in rows) r.slotId: r};
  }

  Future<WeekTarget?> getWeekTarget(String mesoId, int weekIdx, String slotId) {
    return (select(weekTargets)
          ..where((t) =>
              t.mesocycleId.equals(mesoId) &
              t.weekIdx.equals(weekIdx) &
              t.slotId.equals(slotId)))
        .getSingleOrNull();
  }

  Future<void> upsertWeekTarget({
    required String mesoId,
    required int weekIdx,
    required String slotId,
    required int sets,
    required int reps,
    required int rir,
  }) {
    return into(weekTargets).insertOnConflictUpdate(WeekTargetsCompanion.insert(
      mesocycleId: mesoId,
      weekIdx: weekIdx,
      slotId: slotId,
      sets: sets,
      reps: reps,
      rir: rir,
    ));
  }

  Future<void> applyWeekTargetForward({
    required String mesoId,
    required int fromWeekIdx,
    required int numWeeks,
    required String slotId,
    required int sets,
    required int reps,
    required int rir,
  }) async {
    for (var w = fromWeekIdx; w < numWeeks; w++) {
      await upsertWeekTarget(
        mesoId: mesoId,
        weekIdx: w,
        slotId: slotId,
        sets: sets,
        reps: reps,
        rir: rir,
      );
    }
  }
}

// ── DayOverride queries ───────────────────────────────────────────────────────

extension DayOverrideQueries on AppDatabase {
  Future<DayOverride?> getDayOverride(String mesoId, int weekIdx, int dayIdx) {
    return (select(dayOverrides)
          ..where((t) =>
              t.mesocycleId.equals(mesoId) &
              t.weekIdx.equals(weekIdx) &
              t.dayIdx.equals(dayIdx)))
        .getSingleOrNull();
  }

  Future<void> setDayOverride(
      String mesoId, int weekIdx, int dayIdx, List<String> slotIds) {
    return into(dayOverrides).insertOnConflictUpdate(
      DayOverridesCompanion.insert(
        mesocycleId: mesoId,
        weekIdx: weekIdx,
        dayIdx: dayIdx,
        exerciseIdsCsv: slotIds.join(','),
      ),
    );
  }

  Future<void> setWeekForwardOverride(
      String mesoId, int fromWeek, int numWeeks, int dayIdx, List<String> slotIds) async {
    for (var w = fromWeek; w < numWeeks; w++) {
      await setDayOverride(mesoId, w, dayIdx, slotIds);
    }
  }

  Future<void> clearProgramDay(String mesoId, int dayIdx) {
    return (delete(dayOverrides)
          ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayIdx)))
        .go();
  }
}

// ── SessionLog queries ────────────────────────────────────────────────────────

extension SessionLogQueries on AppDatabase {
  Future<SessionLog?> getSessionLog(String mesoId, int weekIdx, int dayIdx) {
    return (select(sessionLogs)
          ..where((t) =>
              t.mesocycleId.equals(mesoId) &
              t.weekIdx.equals(weekIdx) &
              t.dayIdx.equals(dayIdx)))
        .getSingleOrNull();
  }

  Future<SessionLog> getOrCreateSessionLog(
      String mesoId, int weekIdx, int dayIdx) async {
    final existing = await getSessionLog(mesoId, weekIdx, dayIdx);
    if (existing != null) return existing;
    final id = newId();
    await into(sessionLogs).insert(SessionLogsCompanion.insert(
      id: id,
      mesocycleId: mesoId,
      weekIdx: weekIdx,
      dayIdx: dayIdx,
      startedAt: Value(DateTime.now()),
    ));
    return (select(sessionLogs)..where((t) => t.id.equals(id))).getSingle();
  }

  Stream<SessionLog?> watchLatestLoggedSession(String mesoId) {
    return (select(sessionLogs)
          ..where((t) => t.mesocycleId.equals(mesoId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }
}

// ── SetEntry queries ──────────────────────────────────────────────────────────

extension SetEntryQueries on AppDatabase {
  Stream<List<SetEntry>> watchSetsForSession(String sessionId) {
    return (select(setEntries)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.slotId),
            (t) => OrderingTerm.asc(t.setIndex),
          ]))
        .watch();
  }

  Future<List<SetEntry>> getSetsForSession(String sessionId) {
    return (select(setEntries)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.slotId),
            (t) => OrderingTerm.asc(t.setIndex),
          ]))
        .get();
  }

  Future<void> upsertSetEntry({
    required String sessionId,
    required String exerciseId,
    required String slotId,
    required int setIndex,
    double? weight,
    int? reps,
    int? rir,
    required bool done,
  }) async {
    final existing = await (select(setEntries)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.slotId.equals(slotId) &
              t.setIndex.equals(setIndex)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(setEntries)..where((t) => t.id.equals(existing.id))).write(
        SetEntriesCompanion(
          weight: Value(weight),
          reps: Value(reps),
          rir: Value(rir),
          done: Value(done),
          loggedAt: Value(done ? DateTime.now() : null),
        ),
      );
    } else {
      await into(setEntries).insert(SetEntriesCompanion.insert(
        id: newId(),
        sessionId: sessionId,
        exerciseId: exerciseId,
        slotId: Value(slotId),
        setIndex: setIndex,
        weight: Value(weight),
        reps: Value(reps),
        rir: Value(rir),
        done: Value(done),
        loggedAt: Value(done ? DateTime.now() : null),
      ));
    }
  }

  Future<double?> lastLoggedWeight(String exerciseId) async {
    final entry = await (select(setEntries)
          ..where((t) =>
              t.exerciseId.equals(exerciseId) &
              t.done.equals(true) &
              t.weight.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
          ..limit(1))
        .getSingleOrNull();
    return entry?.weight;
  }

  Stream<SetEntry?> watchLastCompletionFirstSet(String exerciseId,
      {String? excludingSessionId}) {
    return (select(setEntries)
          ..where((t) =>
              t.exerciseId.equals(exerciseId) &
              t.setIndex.equals(0) &
              t.done.equals(true) &
              (excludingSessionId == null
                  ? const Constant<bool>(true)
                  : t.sessionId.equals(excludingSessionId).not()))
          ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> deleteSetEntry(String id) {
    return (delete(setEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<SetEntry?> previousSetEntry({
    required String exerciseId,
    required int setIndex,
    String? excludingSessionId,
  }) {
    final q = select(setEntries)
      ..where((t) =>
          t.exerciseId.equals(exerciseId) &
          t.setIndex.equals(setIndex) &
          t.done.equals(true) &
          (excludingSessionId == null
              ? const Constant<bool>(true)
              : t.sessionId.equals(excludingSessionId).not()))
      ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)])
      ..limit(1);
    return q.getSingleOrNull();
  }
}

// ── ProgramDay queries ────────────────────────────────────────────────────────

extension ProgramDayQueries on AppDatabase {
  Stream<ProgramDay?> watchProgramDay(String mesoId, int dayIdx) {
    return (select(programDays)
          ..where((t) =>
              t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayIdx)))
        .watchSingleOrNull();
  }

  Future<void> upsertProgramDay(String mesoId, int dayIdx, String? label) {
    return into(programDays).insertOnConflictUpdate(ProgramDaysCompanion.insert(
      mesocycleId: mesoId,
      dayIdx: dayIdx,
      label: Value(label),
    ));
  }
}

// ── Meso mutation queries ─────────────────────────────────────────────────────

extension MesoMutationQueries on AppDatabase {
  Future<void> toggleDeloadWeek(String mesoId, int weekIdx) async {
    final meso =
        await (select(mesocycles)..where((t) => t.id.equals(mesoId))).getSingle();
    final deloads =
        meso.deloadWeeks.split(',').where((s) => s.isNotEmpty).toSet();
    final key = weekIdx.toString();
    if (deloads.contains(key)) {
      deloads.remove(key);
    } else {
      deloads.add(key);
    }
    await (update(mesocycles)..where((t) => t.id.equals(mesoId)))
        .write(MesocyclesCompanion(deloadWeeks: Value(deloads.join(','))));
  }

  Future<void> deleteWeek(String mesoId, int weekIdx) async {
    await transaction(() async {
      // 1. Delete data for the target week
      await (delete(weekTargets)
            ..where((t) =>
                t.mesocycleId.equals(mesoId) & t.weekIdx.equals(weekIdx)))
          .go();
      await (delete(dayOverrides)
            ..where((t) =>
                t.mesocycleId.equals(mesoId) & t.weekIdx.equals(weekIdx)))
          .go();
      await (delete(sessionLogs)
            ..where((t) =>
                t.mesocycleId.equals(mesoId) & t.weekIdx.equals(weekIdx)))
          .go();

      // 2. Shift subsequent weeks down
      const shiftTarget = 'UPDATE week_targets SET week_idx = week_idx - 1 '
          'WHERE mesocycle_id = ? AND week_idx > ?';
      await customUpdate(shiftTarget, variables: [
        Variable<String>(mesoId),
        Variable<int>(weekIdx),
      ], updates: {
        weekTargets
      });

      const shiftOverrides = 'UPDATE day_overrides SET week_idx = week_idx - 1 '
          'WHERE mesocycle_id = ? AND week_idx > ?';
      await customUpdate(shiftOverrides, variables: [
        Variable<String>(mesoId),
        Variable<int>(weekIdx),
      ], updates: {
        dayOverrides
      });

      // Shifting session logs requires care due to unique index on (mesocycle_id, week_idx, day_idx).
      // We update them in descending order to avoid collisions.
      final logsToShift = await (select(sessionLogs)
            ..where((t) =>
                t.mesocycleId.equals(mesoId) & t.weekIdx.isBiggerThanValue(weekIdx))
            ..orderBy([(t) => OrderingTerm(expression: t.weekIdx, mode: OrderingMode.desc)]))
          .get();

      for (final log in logsToShift) {
        await (update(sessionLogs)..where((t) => t.id.equals(log.id))).write(
          SessionLogsCompanion(weekIdx: Value(log.weekIdx - 1)),
        );
      }

      // 3. Update Mesocycle metadata
      final meso = await (select(mesocycles)..where((t) => t.id.equals(mesoId)))
          .getSingle();

      final oldDeloads =
          meso.deloadWeeks.split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
      final newDeloads = <int>{};
      for (final d in oldDeloads) {
        if (d < weekIdx) {
          newDeloads.add(d);
        } else if (d > weekIdx) {
          newDeloads.add(d - 1);
        }
        // if d == weekIdx, it's removed
      }

      await (update(mesocycles)..where((t) => t.id.equals(mesoId))).write(
        MesocyclesCompanion(
          numWeeks: Value(meso.numWeeks - 1),
          deloadWeeks: Value(newDeloads.join(',')),
        ),
      );
    });
  }
}

// ── Import ────────────────────────────────────────────────────────────────────

extension MesoImportQueries on AppDatabase {
  Future<Mesocycle> importMesoFromPlan(MesoImportData data) async {
    final mesoId = newId();

    await transaction(() async {
      await (update(mesocycles)..where((t) => t.isActive.equals(true)))
          .write(const MesocyclesCompanion(isActive: Value(false)));

      await into(mesocycles).insert(MesocyclesCompanion.insert(
        id: mesoId,
        name: data.name,
        startDate: DateTime.now(),
        isActive: const Value(true),
        numWeeks: Value(data.numWeeks),
      ));

      // Resolve / create all exercises and slots up-front
      final exIdByName = <String, String>{};
      final slotIdByExName = <String, String>{};
      for (final day in data.days) {
        for (final ex in day.exercises) {
          if (exIdByName.containsKey(ex.name)) continue;
          final e = await findOrCreateExerciseByName(ex.name, ex.muscleGroup);
          exIdByName[ex.name] = e.id;

          final slot = await findOrCreateExerciseSlot(mesoId, e.id);
          slotIdByExName[ex.name] = slot.id;
        }
      }

      // ProgramDays
      for (final day in data.days) {
        await into(programDays).insert(ProgramDaysCompanion.insert(
          mesocycleId: mesoId,
          dayIdx: day.dayIdx,
          label: Value(day.label.isEmpty ? null : day.label),
        ));
      }

      // DayOverrides + WeekTargets per week
      for (var w = 0; w < data.numWeeks; w++) {
        for (final day in data.days) {
          final slotIds = day.exercises
              .map((e) => slotIdByExName[e.name]!)
              .toList();

          await into(dayOverrides).insertOnConflictUpdate(
            DayOverridesCompanion.insert(
              mesocycleId: mesoId,
              weekIdx: w,
              dayIdx: day.dayIdx,
              exerciseIdsCsv: slotIds.join(','),
            ),
          );

          for (final ex in day.exercises) {
            final t = ex.targetForWeek(w);
            await into(weekTargets).insertOnConflictUpdate(
              WeekTargetsCompanion.insert(
                mesocycleId: mesoId,
                weekIdx: w,
                slotId: slotIdByExName[ex.name]!,
                sets: t.sets,
                reps: t.reps,
                rir: t.rir,
              ),
            );
          }
        }
      }
    });

    return (select(mesocycles)..where((t) => t.id.equals(mesoId))).getSingle();
  }
}

// ── Wipe ──────────────────────────────────────────────────────────────────────

extension WipeQueries on AppDatabase {
  Future<void> wipeAllData() async {
    await transaction(() async {
      await delete(setEntries).go();
      await delete(sessionLogs).go();
      await delete(dayOverrides).go();
      await delete(weekTargets).go();
      await delete(mesocycles).go();
      await delete(exercises).go();
    });
  }
}

// ── Settings queries ──────────────────────────────────────────────────────────

extension SettingsQueries on AppDatabase {
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: value),
    );
  }
}

// ── Day mutation queries ──────────────────────────────────────────────────────

extension DayMutationQueries on AppDatabase {
  Future<void> clearDay(String mesoId, int dayIdx) async {
    await transaction(() async {
      await (update(programDays)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayIdx)))
          .write(const ProgramDaysCompanion(label: Value(null)));
      await (delete(dayOverrides)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayIdx)))
          .go();
      await (delete(sessionLogs)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayIdx)))
          .go();
    });
  }

  Future<void> duplicateDay(String mesoId, int fromIdx, int toIdx) async {
    await transaction(() async {
      await clearDay(mesoId, toIdx);

      final sourceP = await (select(programDays)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(fromIdx)))
          .getSingleOrNull();
      if (sourceP != null) {
        await upsertProgramDay(mesoId, toIdx, sourceP.label);
      }

      final overrides = await (select(dayOverrides)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(fromIdx)))
          .get();
      for (final ov in overrides) {
        await into(dayOverrides).insertOnConflictUpdate(DayOverridesCompanion.insert(
          mesocycleId: mesoId,
          weekIdx: ov.weekIdx,
          dayIdx: toIdx,
          exerciseIdsCsv: ov.exerciseIdsCsv,
        ));
      }
    });
  }

  Future<void> swapDays(String mesoId, int dayA, int dayB) async {
    if (dayA == dayB) return;
    await transaction(() async {
      // 1. Swap ProgramDays labels
      final pA = await (select(programDays)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayA)))
          .getSingleOrNull();
      final pB = await (select(programDays)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayB)))
          .getSingleOrNull();

      await (update(programDays)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayA)))
          .write(ProgramDaysCompanion(label: Value(pB?.label)));
      await (update(programDays)
            ..where((t) => t.mesocycleId.equals(mesoId) & t.dayIdx.equals(dayB)))
          .write(ProgramDaysCompanion(label: Value(pA?.label)));

      // 2. Swap DayOverrides (all weeks)
      await customUpdate(
          'UPDATE day_overrides SET day_idx = -1 WHERE mesocycle_id = ? AND day_idx = ?',
          variables: [Variable(mesoId), Variable(dayA)]);
      await customUpdate(
          'UPDATE day_overrides SET day_idx = ? WHERE mesocycle_id = ? AND day_idx = ?',
          variables: [Variable(dayA), Variable(mesoId), Variable(dayB)]);
      await customUpdate(
          'UPDATE day_overrides SET day_idx = ? WHERE mesocycle_id = ? AND day_idx = -1',
          variables: [Variable(dayB), Variable(mesoId)]);

      // 3. Swap SessionLogs (all weeks)
      await customUpdate(
          'UPDATE session_logs SET day_idx = -1 WHERE mesocycle_id = ? AND day_idx = ?',
          variables: [Variable(mesoId), Variable(dayA)]);
      await customUpdate(
          'UPDATE session_logs SET day_idx = ? WHERE mesocycle_id = ? AND day_idx = ?',
          variables: [Variable(dayA), Variable(mesoId), Variable(dayB)]);
      await customUpdate(
          'UPDATE session_logs SET day_idx = ? WHERE mesocycle_id = ? AND day_idx = -1',
          variables: [Variable(dayB), Variable(mesoId)]);
    });
  }
}

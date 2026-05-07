import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../util/ids.dart';

part 'database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

class Mesocycles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get numWeeks => integer().withDefault(const Constant(5))();
  TextColumn get deloadWeeks => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get group => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExerciseSlots extends Table {
  TextColumn get id => text()();
  TextColumn get mesocycleId =>
      text().references(Mesocycles, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {id};
}

class WeekTargets extends Table {
  TextColumn get mesocycleId =>
      text().references(Mesocycles, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekIdx => integer()();
  TextColumn get slotId =>
      text().references(ExerciseSlots, #id, onDelete: KeyAction.cascade)();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();
  IntColumn get rir => integer()();

  @override
  Set<Column> get primaryKey => {mesocycleId, weekIdx, slotId};
}

class ProgramDays extends Table {
  TextColumn get mesocycleId =>
      text().references(Mesocycles, #id, onDelete: KeyAction.cascade)();
  IntColumn get dayIdx => integer()();
  TextColumn get label => text().nullable()();

  @override
  Set<Column> get primaryKey => {mesocycleId, dayIdx};
}

class DayOverrides extends Table {
  TextColumn get mesocycleId =>
      text().references(Mesocycles, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekIdx => integer()();
  IntColumn get dayIdx => integer()();
  // Comma-separated slot IDs in display order.
  TextColumn get exerciseIdsCsv => text()();

  @override
  Set<Column> get primaryKey => {mesocycleId, weekIdx, dayIdx};
}

class SessionLogs extends Table {
  TextColumn get id => text()();
  TextColumn get mesocycleId =>
      text().references(Mesocycles, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekIdx => integer()();
  IntColumn get dayIdx => integer()();
  DateTimeColumn get startedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SetEntries extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(SessionLogs, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get slotId =>
      text().nullable().references(ExerciseSlots, #id, onDelete: KeyAction.cascade)();
  IntColumn get setIndex => integer()();
  RealColumn get weight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get rir => integer().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get loggedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Mesocycles,
  Exercises,
  ExerciseSlots,
  WeekTargets,
  ProgramDays,
  DayOverrides,
  SessionLogs,
  SetEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Drop old v1 tables (IF EXISTS handles missing tables gracefully).
            for (final t in const [
              'set_entries',
              'workout_sessions',
              'exercise_slots',
              'days',
              'weeks',
              'mesocycles',
              'exercises',
            ]) {
              await customStatement('DROP TABLE IF EXISTS "$t"');
            }
            await customStatement('DROP INDEX IF EXISTS idx_setentries_lookup');
            await m.createAll();
            await _createIndexes();
          }

          if (from < 3) {
            // v2 -> v3: Drop session completion columns.
            // We use a table migration to handle column deletion safely.
            // ignore: experimental_member_use
            await m.alterTable(TableMigration(sessionLogs));

            // Data heal: Dedup DayOverrides exercise IDs.
            final allOverrides = await select(dayOverrides).get();
            for (final row in allOverrides) {
              final ids = row.exerciseIdsCsv.split(',');
              final seen = <String>{};
              final unique = ids.where((id) => id.isNotEmpty && seen.add(id)).toList();
              if (unique.length < ids.length) {
                await (update(dayOverrides)
                      ..where((t) =>
                          t.mesocycleId.equals(row.mesocycleId) &
                          t.weekIdx.equals(row.weekIdx) &
                          t.dayIdx.equals(row.dayIdx)))
                    .write(DayOverridesCompanion(
                        exerciseIdsCsv: Value(unique.join(','))));
              }
            }
          }

          if (from < 4) {
            // v3 -> v4: Add deload_weeks to Mesocycles and create ProgramDays table.
            await m.addColumn(mesocycles, mesocycles.deloadWeeks);
            await m.createTable(programDays);

            // Data heal: Initialize deloadWeeks for existing mesos (default to last week).
            final allMesos = await select(mesocycles).get();
            for (final row in allMesos) {
              await (update(mesocycles)..where((t) => t.id.equals(row.id)))
                  .write(MesocyclesCompanion(
                      deloadWeeks: Value((row.numWeeks - 1).toString())));
            }
          }

          if (from < 5) {
            // v4 -> v5: Remove unique constraint from Exercises.name.
            // ignore: experimental_member_use
            await m.alterTable(TableMigration(exercises));
          }

          if (from < 6) {
            // v5 -> v6: Introduce ExerciseSlots and decouple targets/logs.
            await m.createTable(exerciseSlots);
            await m.addColumn(setEntries, setEntries.slotId);

            final allMesos = await select(mesocycles).get();
            for (final meso in allMesos) {
              final exerciseToSlot = <String, String>{};

              // Identify used exercises in this meso.
              // We use customSelect because week_targets table still has exercise_id at this point in the DB,
              // but the Dart class WeekTarget already had it removed/renamed.
              final targetRows = await customSelect(
                'SELECT exercise_id FROM week_targets WHERE mesocycle_id = ?',
                variables: [Variable.withString(meso.id)],
              ).get();

              final overrides = await (select(dayOverrides)
                    ..where((t) => t.mesocycleId.equals(meso.id)))
                  .get();

              final usedExIds = <String>{};
              for (final row in targetRows) {
                usedExIds.add(row.read<String>('exercise_id'));
              }
              for (final o in overrides) {
                usedExIds.addAll(
                    o.exerciseIdsCsv.split(',').where((s) => s.isNotEmpty));
              }

              for (final exId in usedExIds) {
                final sId = newId();
                await into(exerciseSlots).insert(ExerciseSlotsCompanion.insert(
                  id: sId,
                  mesocycleId: meso.id,
                  exerciseId: exId,
                ));
                exerciseToSlot[exId] = sId;
              }

              // Update Overrides (CSV now contains slotIds).
              for (final o in overrides) {
                final slotIds = o.exerciseIdsCsv
                    .split(',')
                    .where((s) => s.isNotEmpty)
                    .map((exId) => exerciseToSlot[exId]!)
                    .join(',');
                await (update(dayOverrides)
                      ..where((t) =>
                          t.mesocycleId.equals(o.mesocycleId) &
                          t.weekIdx.equals(o.weekIdx) &
                          t.dayIdx.equals(o.dayIdx)))
                    .write(
                        DayOverridesCompanion(exerciseIdsCsv: Value(slotIds)));
              }

              // Update SetEntries.
              final sessions = await (select(sessionLogs)
                    ..where((t) => t.mesocycleId.equals(meso.id)))
                  .get();
              for (final s in sessions) {
                final sessionSets = await (select(setEntries)
                      ..where((t) => t.sessionId.equals(s.id)))
                    .get();
                for (final set in sessionSets) {
                  final sId = exerciseToSlot[set.exerciseId];
                  if (sId != null) {
                    await (update(setEntries)
                          ..where((t) => t.id.equals(set.id)))
                        .write(SetEntriesCompanion(slotId: Value(sId)));
                  }
                }
              }
            }

            // Transform WeekTargets table.
            // ignore: experimental_member_use
            await m.alterTable(TableMigration(weekTargets, columnTransformer: {
              weekTargets.slotId: const CustomExpression<String>('exercise_id'),
            }));

            // Fix WeekTargets data: map exercise_id (which was copied to slot_id) to actual slot_id.
            final allTargets = await select(weekTargets).get();
            for (final t in allTargets) {
              // At this point t.slotId contains the old exerciseId because of the transformer.
              final exId = t.slotId;
              final slot = await (select(exerciseSlots)
                    ..where((s) =>
                        s.mesocycleId.equals(t.mesocycleId) &
                        s.exerciseId.equals(exId)))
                  .getSingleOrNull();
              if (slot != null) {
                await (update(weekTargets)
                      ..where((w) =>
                          w.mesocycleId.equals(t.mesocycleId) &
                          w.weekIdx.equals(t.weekIdx) &
                          w.slotId.equals(exId)))
                    .write(WeekTargetsCompanion(slotId: Value(slot.id)));
              }
            }
          }
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_setentries_exercise '
      'ON set_entries (exercise_id, logged_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_setentries_slot '
      'ON set_entries (slot_id, logged_at DESC)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sessionlogs_day '
      'ON session_logs (mesocycle_id, week_idx, day_idx)',
    );
  }
}


QueryExecutor _open() => driftDatabase(name: 'strength_guru');

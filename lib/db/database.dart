import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  TextColumn get name => text().unique()();
  TextColumn get group => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class WeekTargets extends Table {
  TextColumn get mesocycleId =>
      text().references(Mesocycles, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekIdx => integer()();
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();
  IntColumn get rir => integer()();

  @override
  Set<Column> get primaryKey => {mesocycleId, weekIdx, exerciseId};
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
  // Comma-separated exercise IDs in display order.
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
  WeekTargets,
  ProgramDays,
  DayOverrides,
  SessionLogs,
  SetEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 4;

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
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_setentries_exercise '
      'ON set_entries (exercise_id, logged_at DESC)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sessionlogs_day '
      'ON session_logs (mesocycle_id, week_idx, day_idx)',
    );
  }
}

QueryExecutor _open() => driftDatabase(name: 'strength_guru');

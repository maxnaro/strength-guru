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

class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();
  @override
  List<int> fromSql(String fromDb) =>
      fromDb.split(',').where((s) => s.isNotEmpty).map(int.parse).toList();
  @override
  String toSql(List<int> value) => value.join(',');
}

class WeekTargets extends Table {
  TextColumn get mesocycleId =>
      text().references(Mesocycles, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekIdx => integer()();
  TextColumn get slotId =>
      text().references(ExerciseSlots, #id, onDelete: KeyAction.cascade)();
  TextColumn get reps => text().map(const IntListConverter())();
  TextColumn get rir => text().map(const IntListConverter())();

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

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
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
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 8;

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

          if (from < 7) {
            await m.createTable(settings);
          }

          if (from < 8) {
            // v7 -> v8: Migrate WeekTargets to array-based reps/rir and drop sets.
            await customStatement(
                'ALTER TABLE week_targets RENAME TO week_targets_old');
            await m.createTable(weekTargets);

            final rows = await customSelect('SELECT * FROM week_targets_old').get();
            for (final r in rows) {
              final meso = r.read<String>('mesocycle_id');
              final week = r.read<int>('week_idx');
              final slot = r.read<String>('slot_id');
              final sets = r.read<int>('sets');
              final reps = r.read<int>('reps');
              final rir = r.read<int>('rir');

              final repsList = List.filled(sets, reps);
              final rirList = List.filled(sets, rir);

              await into(weekTargets).insert(WeekTargetsCompanion.insert(
                mesocycleId: meso,
                weekIdx: week,
                slotId: slot,
                reps: repsList,
                rir: rirList,
              ));
            }
            await customStatement('DROP TABLE week_targets_old');

            // Data heal: Merge exercises with the same name (e.g. Pull-ups Top/Backoff)
            await _healRedundantExercises();
          }
        },
      );

  Future<void> _healRedundantExercises() async {
    final allMesos = await select(mesocycles).get();
    for (final meso in allMesos) {
      // 1. Get all slots for this meso with their exercise names
      final slots = await (select(exerciseSlots).join([
        innerJoin(exercises, exercises.id.equalsExp(exerciseSlots.exerciseId)),
      ])
            ..where(exerciseSlots.mesocycleId.equals(meso.id)))
          .get();

      // Map from name -> list of slot IDs
      final nameToSlots = <String, List<String>>{};
      for (final row in slots) {
        final name = row.readTable(exercises).name;
        final slotId = row.readTable(exerciseSlots).id;
        (nameToSlots[name] ??= []).add(slotId);
      }

      // 2. Process groups with > 1 slot (the duplicates)
      for (final entry in nameToSlots.entries) {
        final dupIds = entry.value;
        if (dupIds.length <= 1) continue;

        final primaryId = dupIds.first;
        final secondaryIds = dupIds.sublist(1);

        // Merge targets week by week
        for (var w = 0; w < meso.numWeeks; w++) {
          final primaryTarget = await (select(weekTargets)
                ..where((t) =>
                    t.mesocycleId.equals(meso.id) &
                    t.weekIdx.equals(w) &
                    t.slotId.equals(primaryId)))
              .getSingleOrNull();

          if (primaryTarget == null) continue;

          var mergedReps = List<int>.from(primaryTarget.reps);
          var mergedRir = List<int>.from(primaryTarget.rir);
          final offsets = <String, int>{}; // secondaryId -> offset

          for (final secId in secondaryIds) {
            final secTarget = await (select(weekTargets)
                  ..where((t) =>
                      t.mesocycleId.equals(meso.id) &
                      t.weekIdx.equals(w) &
                      t.slotId.equals(secId)))
                .getSingleOrNull();

            if (secTarget != null) {
              offsets[secId] = mergedReps.length;
              mergedReps.addAll(secTarget.reps);
              mergedRir.addAll(secTarget.rir);
            }
          }

          // Update primary target
          await (update(weekTargets)
                ..where((t) =>
                    t.mesocycleId.equals(meso.id) &
                    t.weekIdx.equals(w) &
                    t.slotId.equals(primaryId)))
              .write(WeekTargetsCompanion(
            reps: Value(mergedReps),
            rir: Value(mergedRir),
          ));

          // 3. Move Session Logs / Set Entries
          // We need to find set entries for each week/day that used the secondary slots.
          for (final secId in secondaryIds) {
            final offset = offsets[secId] ?? 0;
            // Update set entries to point to primary slot and offset their index
            await customUpdate(
              'UPDATE set_entries SET slot_id = ?, set_index = set_index + ? '
              'WHERE slot_id = ? AND session_id IN '
              '(SELECT id FROM session_logs WHERE mesocycle_id = ? AND week_idx = ?)',
              variables: [
                Variable.withString(primaryId),
                Variable.withInt(offset),
                Variable.withString(secId),
                Variable.withString(meso.id),
                Variable.withInt(w),
              ],
            );
          }
        }

        // 4. Update DayOverrides (Schedules)
        // Remove the secondary IDs from the CSV strings and ensure primary is there only once.
        final overrides = await (select(dayOverrides)
              ..where((t) => t.mesocycleId.equals(meso.id)))
            .get();

        for (final o in overrides) {
          final ids = o.exerciseIdsCsv.split(',').where((s) => s.isNotEmpty).toList();
          if (ids.any((id) => secondaryIds.contains(id))) {
            final newIds = <String>[];
            bool primarySeen = false;
            for (final id in ids) {
              if (id == primaryId) {
                if (!primarySeen) {
                  newIds.add(id);
                  primarySeen = true;
                }
              } else if (secondaryIds.contains(id)) {
                if (!primarySeen) {
                  newIds.add(primaryId);
                  primarySeen = true;
                }
              } else {
                newIds.add(id);
              }
            }
            await (update(dayOverrides)
                  ..where((t) =>
                      t.mesocycleId.equals(o.mesocycleId) &
                      t.weekIdx.equals(o.weekIdx) &
                      t.dayIdx.equals(o.dayIdx)))
                .write(DayOverridesCompanion(
                    exerciseIdsCsv: Value(newIds.join(','))));
          }
        }

        // 5. Delete secondary slots
        for (final secId in secondaryIds) {
          await (delete(exerciseSlots)..where((t) => t.id.equals(secId))).go();
        }
      }
    }
  }

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

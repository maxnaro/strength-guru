import '../db/database.dart';
import '../db/queries.dart';
import '../models/meso_import_data.dart';

const loggingCommands = {
  'getOrCreateSessionLog',
  'upsertSetEntry',
  'deleteSetEntry',
};

class ProtocolException implements Exception {
  final String code;
  final String message;
  final int status;
  const ProtocolException(this.code, this.message, [this.status = 400]);
  @override
  String toString() => message;
}

Future<String> commandResource(
  AppDatabase db,
  String type,
  Map<String, dynamic> p,
) async {
  if (type == 'getOrCreateSessionLog')
    return 'session:${p['mesoId']}:${p['weekIdx']}:${p['dayIdx']}';
  if (type == 'upsertSetEntry')
    return 'set:${p['sessionId']}:${p['slotId']}:${p['setIndex']}';
  if (type == 'deleteSetEntry') {
    final row = await (db.select(
      db.setEntries,
    )..where((t) => t.id.equals(p['id'] as String))).getSingleOrNull();
    if (row == null) return p['resource'] as String? ?? 'deleted:${p['id']}';
    return 'set:${row.sessionId}:${row.slotId}:${row.setIndex}';
  }
  return 'program';
}

Future<dynamic> executeCommand(
  AppDatabase db,
  String type,
  Map<String, dynamic> p,
) => db.local(() async {
  String s(String k) => p[k] as String;
  int n(String k) => (p[k] as num).toInt();
  List<int> ints(String k) =>
      (p[k] as List).map((v) => (v as num).toInt()).toList();
  List<String> strings(String k) => (p[k] as List).cast<String>();
  switch (type) {
    case 'findOrCreateExerciseByName':
      return (await db.findOrCreateExerciseByName(
        s('name'),
        s('group'),
      )).toJson();
    case 'findOrCreateExerciseSlot':
      return (await db.findOrCreateExerciseSlot(
        s('mesoId'),
        s('exerciseId'),
      )).toJson();
    case 'createExerciseSlot':
      return (await db.createExerciseSlot(
        s('mesoId'),
        s('exerciseId'),
      )).toJson();
    case 'activateMeso':
      await db.activateMeso(s('id'));
    case 'createMeso':
      return (await db.createMeso(s('name'))).toJson();
    case 'deleteMeso':
      await db.deleteMeso(s('id'));
    case 'renameMeso':
      await db.renameMeso(s('id'), s('name'));
    case 'duplicateMeso':
      await db.duplicateMeso(s('id'), s('newName'));
    case 'setMesoCurrentWeek':
      await db.setMesoCurrentWeek(s('id'), n('targetWeekIdx'));
    case 'setMesoNumWeeks':
      await db.setMesoNumWeeks(s('id'), n('numWeeks'));
    case 'upsertWeekTarget':
      await db.upsertWeekTarget(
        mesoId: s('mesoId'),
        weekIdx: n('weekIdx'),
        slotId: s('slotId'),
        reps: ints('reps'),
        rir: ints('rir'),
      );
    case 'applyWeekTargetForward':
      await db.applyWeekTargetForward(
        mesoId: s('mesoId'),
        fromWeekIdx: n('fromWeekIdx'),
        numWeeks: n('numWeeks'),
        slotId: s('slotId'),
        reps: ints('reps'),
        rir: ints('rir'),
      );
    case 'applyExerciseProgression':
      await db.applyExerciseProgression(
        mesoId: s('mesoId'),
        numWeeks: n('numWeeks'),
        slotId: s('slotId'),
        sets: (p['sets'] as List)
            .map(
              (v) => (
                startReps: v['startReps'] as int,
                endReps: v['endReps'] as int,
                startRir: v['startRir'] as int,
                endRir: v['endRir'] as int,
              ),
            )
            .toList(),
        deloadWeeks: ints('deloadWeeks').toSet(),
      );
    case 'setDayOverride':
      await db.setDayOverride(
        s('mesoId'),
        n('weekIdx'),
        n('dayIdx'),
        strings('slotIds'),
      );
    case 'setWeekForwardOverride':
      await db.setWeekForwardOverride(
        s('mesoId'),
        n('fromWeek'),
        n('numWeeks'),
        n('dayIdx'),
        strings('slotIds'),
      );
    case 'clearProgramDay':
      await db.clearProgramDay(s('mesoId'), n('dayIdx'));
    case 'getOrCreateSessionLog':
      return (await db.getOrCreateSessionLog(
        s('mesoId'),
        n('weekIdx'),
        n('dayIdx'),
        startedAt: p['startedAt'] == null
            ? null
            : DateTime.parse(s('startedAt')),
      )).toJson();
    case 'upsertSetEntry':
      await db.upsertSetEntry(
        sessionId: s('sessionId'),
        exerciseId: s('exerciseId'),
        slotId: s('slotId'),
        setIndex: n('setIndex'),
        weight: (p['weight'] as num?)?.toDouble(),
        reps: p['reps'] as int?,
        rir: p['rir'] as int?,
        done: p['done'] as bool,
        loggedAt: p['loggedAt'] == null ? null : DateTime.parse(s('loggedAt')),
      );
    case 'deleteSetEntry':
      await db.deleteSetEntry(s('id'));
    case 'upsertProgramDay':
      await db.upsertProgramDay(
        s('mesoId'),
        n('dayIdx'),
        p['label'] as String?,
      );
    case 'toggleDeloadWeek':
      await db.toggleDeloadWeek(s('mesoId'), n('weekIdx'));
    case 'deleteWeek':
      await db.deleteWeek(s('mesoId'), n('weekIdx'));
    case 'importMesoFromPlan':
      return (await db.importMesoFromPlan(
        MesoImportData.fromJson(Map<String, dynamic>.from(p['data'] as Map)),
      )).toJson();
    case 'wipeAllData':
      await db.wipeAllData();
    case 'setSetting':
      if (s('key').startsWith('llm_')) return null;
      await db.setSetting(s('key'), s('value'));
    case 'clearDay':
      await db.clearDay(s('mesoId'), n('dayIdx'));
    case 'duplicateDay':
      await db.duplicateDay(s('mesoId'), n('fromIdx'), n('toIdx'));
    case 'swapDays':
      await db.swapDays(s('mesoId'), n('dayA'), n('dayB'));
    default:
      throw const ProtocolException(
        'unknown_command',
        'Unknown training command.',
      );
  }
  return null;
});

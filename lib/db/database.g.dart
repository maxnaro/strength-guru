// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MesocyclesTable extends Mesocycles
    with TableInfo<$MesocyclesTable, Mesocycle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MesocyclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startDateMeta =
      const VerificationMeta('startDate');
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
      'start_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _numWeeksMeta =
      const VerificationMeta('numWeeks');
  @override
  late final GeneratedColumn<int> numWeeks = GeneratedColumn<int>(
      'num_weeks', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _deloadWeeksMeta =
      const VerificationMeta('deloadWeeks');
  @override
  late final GeneratedColumn<String> deloadWeeks = GeneratedColumn<String>(
      'deload_weeks', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, startDate, isActive, numWeeks, deloadWeeks];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mesocycles';
  @override
  VerificationContext validateIntegrity(Insertable<Mesocycle> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(_startDateMeta,
          startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta));
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('num_weeks')) {
      context.handle(_numWeeksMeta,
          numWeeks.isAcceptableOrUnknown(data['num_weeks']!, _numWeeksMeta));
    }
    if (data.containsKey('deload_weeks')) {
      context.handle(
          _deloadWeeksMeta,
          deloadWeeks.isAcceptableOrUnknown(
              data['deload_weeks']!, _deloadWeeksMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mesocycle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mesocycle(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      startDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_date'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      numWeeks: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}num_weeks'])!,
      deloadWeeks: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}deload_weeks'])!,
    );
  }

  @override
  $MesocyclesTable createAlias(String alias) {
    return $MesocyclesTable(attachedDatabase, alias);
  }
}

class Mesocycle extends DataClass implements Insertable<Mesocycle> {
  final String id;
  final String name;
  final DateTime startDate;
  final bool isActive;
  final int numWeeks;
  final String deloadWeeks;
  const Mesocycle(
      {required this.id,
      required this.name,
      required this.startDate,
      required this.isActive,
      required this.numWeeks,
      required this.deloadWeeks});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['start_date'] = Variable<DateTime>(startDate);
    map['is_active'] = Variable<bool>(isActive);
    map['num_weeks'] = Variable<int>(numWeeks);
    map['deload_weeks'] = Variable<String>(deloadWeeks);
    return map;
  }

  MesocyclesCompanion toCompanion(bool nullToAbsent) {
    return MesocyclesCompanion(
      id: Value(id),
      name: Value(name),
      startDate: Value(startDate),
      isActive: Value(isActive),
      numWeeks: Value(numWeeks),
      deloadWeeks: Value(deloadWeeks),
    );
  }

  factory Mesocycle.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mesocycle(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      numWeeks: serializer.fromJson<int>(json['numWeeks']),
      deloadWeeks: serializer.fromJson<String>(json['deloadWeeks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'startDate': serializer.toJson<DateTime>(startDate),
      'isActive': serializer.toJson<bool>(isActive),
      'numWeeks': serializer.toJson<int>(numWeeks),
      'deloadWeeks': serializer.toJson<String>(deloadWeeks),
    };
  }

  Mesocycle copyWith(
          {String? id,
          String? name,
          DateTime? startDate,
          bool? isActive,
          int? numWeeks,
          String? deloadWeeks}) =>
      Mesocycle(
        id: id ?? this.id,
        name: name ?? this.name,
        startDate: startDate ?? this.startDate,
        isActive: isActive ?? this.isActive,
        numWeeks: numWeeks ?? this.numWeeks,
        deloadWeeks: deloadWeeks ?? this.deloadWeeks,
      );
  Mesocycle copyWithCompanion(MesocyclesCompanion data) {
    return Mesocycle(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      numWeeks: data.numWeeks.present ? data.numWeeks.value : this.numWeeks,
      deloadWeeks:
          data.deloadWeeks.present ? data.deloadWeeks.value : this.deloadWeeks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mesocycle(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('isActive: $isActive, ')
          ..write('numWeeks: $numWeeks, ')
          ..write('deloadWeeks: $deloadWeeks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, startDate, isActive, numWeeks, deloadWeeks);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mesocycle &&
          other.id == this.id &&
          other.name == this.name &&
          other.startDate == this.startDate &&
          other.isActive == this.isActive &&
          other.numWeeks == this.numWeeks &&
          other.deloadWeeks == this.deloadWeeks);
}

class MesocyclesCompanion extends UpdateCompanion<Mesocycle> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> startDate;
  final Value<bool> isActive;
  final Value<int> numWeeks;
  final Value<String> deloadWeeks;
  final Value<int> rowid;
  const MesocyclesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.startDate = const Value.absent(),
    this.isActive = const Value.absent(),
    this.numWeeks = const Value.absent(),
    this.deloadWeeks = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MesocyclesCompanion.insert({
    required String id,
    required String name,
    required DateTime startDate,
    this.isActive = const Value.absent(),
    this.numWeeks = const Value.absent(),
    this.deloadWeeks = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        startDate = Value(startDate);
  static Insertable<Mesocycle> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? startDate,
    Expression<bool>? isActive,
    Expression<int>? numWeeks,
    Expression<String>? deloadWeeks,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (startDate != null) 'start_date': startDate,
      if (isActive != null) 'is_active': isActive,
      if (numWeeks != null) 'num_weeks': numWeeks,
      if (deloadWeeks != null) 'deload_weeks': deloadWeeks,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MesocyclesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime>? startDate,
      Value<bool>? isActive,
      Value<int>? numWeeks,
      Value<String>? deloadWeeks,
      Value<int>? rowid}) {
    return MesocyclesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
      numWeeks: numWeeks ?? this.numWeeks,
      deloadWeeks: deloadWeeks ?? this.deloadWeeks,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (numWeeks.present) {
      map['num_weeks'] = Variable<int>(numWeeks.value);
    }
    if (deloadWeeks.present) {
      map['deload_weeks'] = Variable<String>(deloadWeeks.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MesocyclesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startDate: $startDate, ')
          ..write('isActive: $isActive, ')
          ..write('numWeeks: $numWeeks, ')
          ..write('deloadWeeks: $deloadWeeks, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
      'group', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, group];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(Insertable<Exercise> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('group')) {
      context.handle(
          _groupMeta, group.isAcceptableOrUnknown(data['group']!, _groupMeta));
    } else if (isInserting) {
      context.missing(_groupMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      group: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group'])!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final String id;
  final String name;
  final String group;
  const Exercise({required this.id, required this.name, required this.group});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['group'] = Variable<String>(group);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      group: Value(group),
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      group: serializer.fromJson<String>(json['group']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'group': serializer.toJson<String>(group),
    };
  }

  Exercise copyWith({String? id, String? name, String? group}) => Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        group: group ?? this.group,
      );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      group: data.group.present ? data.group.value : this.group,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('group: $group')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, group);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.name == this.name &&
          other.group == this.group);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> group;
  final Value<int> rowid;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.group = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisesCompanion.insert({
    required String id,
    required String name,
    required String group,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        group = Value(group);
  static Insertable<Exercise> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? group,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (group != null) 'group': group,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? group,
      Value<int>? rowid}) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('group: $group, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseSlotsTable extends ExerciseSlots
    with TableInfo<$ExerciseSlotsTable, ExerciseSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mesocycleIdMeta =
      const VerificationMeta('mesocycleId');
  @override
  late final GeneratedColumn<String> mesocycleId = GeneratedColumn<String>(
      'mesocycle_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES mesocycles (id) ON DELETE CASCADE'));
  static const VerificationMeta _exerciseIdMeta =
      const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
      'exercise_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES exercises (id) ON DELETE CASCADE'));
  @override
  List<GeneratedColumn> get $columns => [id, mesocycleId, exerciseId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_slots';
  @override
  VerificationContext validateIntegrity(Insertable<ExerciseSlot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mesocycle_id')) {
      context.handle(
          _mesocycleIdMeta,
          mesocycleId.isAcceptableOrUnknown(
              data['mesocycle_id']!, _mesocycleIdMeta));
    } else if (isInserting) {
      context.missing(_mesocycleIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
          _exerciseIdMeta,
          exerciseId.isAcceptableOrUnknown(
              data['exercise_id']!, _exerciseIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseSlot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      mesocycleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mesocycle_id'])!,
      exerciseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_id'])!,
    );
  }

  @override
  $ExerciseSlotsTable createAlias(String alias) {
    return $ExerciseSlotsTable(attachedDatabase, alias);
  }
}

class ExerciseSlot extends DataClass implements Insertable<ExerciseSlot> {
  final String id;
  final String mesocycleId;
  final String exerciseId;
  const ExerciseSlot(
      {required this.id, required this.mesocycleId, required this.exerciseId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mesocycle_id'] = Variable<String>(mesocycleId);
    map['exercise_id'] = Variable<String>(exerciseId);
    return map;
  }

  ExerciseSlotsCompanion toCompanion(bool nullToAbsent) {
    return ExerciseSlotsCompanion(
      id: Value(id),
      mesocycleId: Value(mesocycleId),
      exerciseId: Value(exerciseId),
    );
  }

  factory ExerciseSlot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseSlot(
      id: serializer.fromJson<String>(json['id']),
      mesocycleId: serializer.fromJson<String>(json['mesocycleId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mesocycleId': serializer.toJson<String>(mesocycleId),
      'exerciseId': serializer.toJson<String>(exerciseId),
    };
  }

  ExerciseSlot copyWith(
          {String? id, String? mesocycleId, String? exerciseId}) =>
      ExerciseSlot(
        id: id ?? this.id,
        mesocycleId: mesocycleId ?? this.mesocycleId,
        exerciseId: exerciseId ?? this.exerciseId,
      );
  ExerciseSlot copyWithCompanion(ExerciseSlotsCompanion data) {
    return ExerciseSlot(
      id: data.id.present ? data.id.value : this.id,
      mesocycleId:
          data.mesocycleId.present ? data.mesocycleId.value : this.mesocycleId,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSlot(')
          ..write('id: $id, ')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('exerciseId: $exerciseId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mesocycleId, exerciseId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseSlot &&
          other.id == this.id &&
          other.mesocycleId == this.mesocycleId &&
          other.exerciseId == this.exerciseId);
}

class ExerciseSlotsCompanion extends UpdateCompanion<ExerciseSlot> {
  final Value<String> id;
  final Value<String> mesocycleId;
  final Value<String> exerciseId;
  final Value<int> rowid;
  const ExerciseSlotsCompanion({
    this.id = const Value.absent(),
    this.mesocycleId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseSlotsCompanion.insert({
    required String id,
    required String mesocycleId,
    required String exerciseId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        mesocycleId = Value(mesocycleId),
        exerciseId = Value(exerciseId);
  static Insertable<ExerciseSlot> custom({
    Expression<String>? id,
    Expression<String>? mesocycleId,
    Expression<String>? exerciseId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mesocycleId != null) 'mesocycle_id': mesocycleId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseSlotsCompanion copyWith(
      {Value<String>? id,
      Value<String>? mesocycleId,
      Value<String>? exerciseId,
      Value<int>? rowid}) {
    return ExerciseSlotsCompanion(
      id: id ?? this.id,
      mesocycleId: mesocycleId ?? this.mesocycleId,
      exerciseId: exerciseId ?? this.exerciseId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mesocycleId.present) {
      map['mesocycle_id'] = Variable<String>(mesocycleId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSlotsCompanion(')
          ..write('id: $id, ')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeekTargetsTable extends WeekTargets
    with TableInfo<$WeekTargetsTable, WeekTarget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeekTargetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mesocycleIdMeta =
      const VerificationMeta('mesocycleId');
  @override
  late final GeneratedColumn<String> mesocycleId = GeneratedColumn<String>(
      'mesocycle_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES mesocycles (id) ON DELETE CASCADE'));
  static const VerificationMeta _weekIdxMeta =
      const VerificationMeta('weekIdx');
  @override
  late final GeneratedColumn<int> weekIdx = GeneratedColumn<int>(
      'week_idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _slotIdMeta = const VerificationMeta('slotId');
  @override
  late final GeneratedColumn<String> slotId = GeneratedColumn<String>(
      'slot_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES exercise_slots (id) ON DELETE CASCADE'));
  static const VerificationMeta _setsMeta = const VerificationMeta('sets');
  @override
  late final GeneratedColumn<int> sets = GeneratedColumn<int>(
      'sets', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
      'reps', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rirMeta = const VerificationMeta('rir');
  @override
  late final GeneratedColumn<int> rir = GeneratedColumn<int>(
      'rir', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [mesocycleId, weekIdx, slotId, sets, reps, rir];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'week_targets';
  @override
  VerificationContext validateIntegrity(Insertable<WeekTarget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mesocycle_id')) {
      context.handle(
          _mesocycleIdMeta,
          mesocycleId.isAcceptableOrUnknown(
              data['mesocycle_id']!, _mesocycleIdMeta));
    } else if (isInserting) {
      context.missing(_mesocycleIdMeta);
    }
    if (data.containsKey('week_idx')) {
      context.handle(_weekIdxMeta,
          weekIdx.isAcceptableOrUnknown(data['week_idx']!, _weekIdxMeta));
    } else if (isInserting) {
      context.missing(_weekIdxMeta);
    }
    if (data.containsKey('slot_id')) {
      context.handle(_slotIdMeta,
          slotId.isAcceptableOrUnknown(data['slot_id']!, _slotIdMeta));
    } else if (isInserting) {
      context.missing(_slotIdMeta);
    }
    if (data.containsKey('sets')) {
      context.handle(
          _setsMeta, sets.isAcceptableOrUnknown(data['sets']!, _setsMeta));
    } else if (isInserting) {
      context.missing(_setsMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
          _repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('rir')) {
      context.handle(
          _rirMeta, rir.isAcceptableOrUnknown(data['rir']!, _rirMeta));
    } else if (isInserting) {
      context.missing(_rirMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mesocycleId, weekIdx, slotId};
  @override
  WeekTarget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeekTarget(
      mesocycleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mesocycle_id'])!,
      weekIdx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_idx'])!,
      slotId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slot_id'])!,
      sets: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sets'])!,
      reps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reps'])!,
      rir: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rir'])!,
    );
  }

  @override
  $WeekTargetsTable createAlias(String alias) {
    return $WeekTargetsTable(attachedDatabase, alias);
  }
}

class WeekTarget extends DataClass implements Insertable<WeekTarget> {
  final String mesocycleId;
  final int weekIdx;
  final String slotId;
  final int sets;
  final int reps;
  final int rir;
  const WeekTarget(
      {required this.mesocycleId,
      required this.weekIdx,
      required this.slotId,
      required this.sets,
      required this.reps,
      required this.rir});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mesocycle_id'] = Variable<String>(mesocycleId);
    map['week_idx'] = Variable<int>(weekIdx);
    map['slot_id'] = Variable<String>(slotId);
    map['sets'] = Variable<int>(sets);
    map['reps'] = Variable<int>(reps);
    map['rir'] = Variable<int>(rir);
    return map;
  }

  WeekTargetsCompanion toCompanion(bool nullToAbsent) {
    return WeekTargetsCompanion(
      mesocycleId: Value(mesocycleId),
      weekIdx: Value(weekIdx),
      slotId: Value(slotId),
      sets: Value(sets),
      reps: Value(reps),
      rir: Value(rir),
    );
  }

  factory WeekTarget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeekTarget(
      mesocycleId: serializer.fromJson<String>(json['mesocycleId']),
      weekIdx: serializer.fromJson<int>(json['weekIdx']),
      slotId: serializer.fromJson<String>(json['slotId']),
      sets: serializer.fromJson<int>(json['sets']),
      reps: serializer.fromJson<int>(json['reps']),
      rir: serializer.fromJson<int>(json['rir']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mesocycleId': serializer.toJson<String>(mesocycleId),
      'weekIdx': serializer.toJson<int>(weekIdx),
      'slotId': serializer.toJson<String>(slotId),
      'sets': serializer.toJson<int>(sets),
      'reps': serializer.toJson<int>(reps),
      'rir': serializer.toJson<int>(rir),
    };
  }

  WeekTarget copyWith(
          {String? mesocycleId,
          int? weekIdx,
          String? slotId,
          int? sets,
          int? reps,
          int? rir}) =>
      WeekTarget(
        mesocycleId: mesocycleId ?? this.mesocycleId,
        weekIdx: weekIdx ?? this.weekIdx,
        slotId: slotId ?? this.slotId,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        rir: rir ?? this.rir,
      );
  WeekTarget copyWithCompanion(WeekTargetsCompanion data) {
    return WeekTarget(
      mesocycleId:
          data.mesocycleId.present ? data.mesocycleId.value : this.mesocycleId,
      weekIdx: data.weekIdx.present ? data.weekIdx.value : this.weekIdx,
      slotId: data.slotId.present ? data.slotId.value : this.slotId,
      sets: data.sets.present ? data.sets.value : this.sets,
      reps: data.reps.present ? data.reps.value : this.reps,
      rir: data.rir.present ? data.rir.value : this.rir,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeekTarget(')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('weekIdx: $weekIdx, ')
          ..write('slotId: $slotId, ')
          ..write('sets: $sets, ')
          ..write('reps: $reps, ')
          ..write('rir: $rir')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(mesocycleId, weekIdx, slotId, sets, reps, rir);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeekTarget &&
          other.mesocycleId == this.mesocycleId &&
          other.weekIdx == this.weekIdx &&
          other.slotId == this.slotId &&
          other.sets == this.sets &&
          other.reps == this.reps &&
          other.rir == this.rir);
}

class WeekTargetsCompanion extends UpdateCompanion<WeekTarget> {
  final Value<String> mesocycleId;
  final Value<int> weekIdx;
  final Value<String> slotId;
  final Value<int> sets;
  final Value<int> reps;
  final Value<int> rir;
  final Value<int> rowid;
  const WeekTargetsCompanion({
    this.mesocycleId = const Value.absent(),
    this.weekIdx = const Value.absent(),
    this.slotId = const Value.absent(),
    this.sets = const Value.absent(),
    this.reps = const Value.absent(),
    this.rir = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeekTargetsCompanion.insert({
    required String mesocycleId,
    required int weekIdx,
    required String slotId,
    required int sets,
    required int reps,
    required int rir,
    this.rowid = const Value.absent(),
  })  : mesocycleId = Value(mesocycleId),
        weekIdx = Value(weekIdx),
        slotId = Value(slotId),
        sets = Value(sets),
        reps = Value(reps),
        rir = Value(rir);
  static Insertable<WeekTarget> custom({
    Expression<String>? mesocycleId,
    Expression<int>? weekIdx,
    Expression<String>? slotId,
    Expression<int>? sets,
    Expression<int>? reps,
    Expression<int>? rir,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mesocycleId != null) 'mesocycle_id': mesocycleId,
      if (weekIdx != null) 'week_idx': weekIdx,
      if (slotId != null) 'slot_id': slotId,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (rir != null) 'rir': rir,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeekTargetsCompanion copyWith(
      {Value<String>? mesocycleId,
      Value<int>? weekIdx,
      Value<String>? slotId,
      Value<int>? sets,
      Value<int>? reps,
      Value<int>? rir,
      Value<int>? rowid}) {
    return WeekTargetsCompanion(
      mesocycleId: mesocycleId ?? this.mesocycleId,
      weekIdx: weekIdx ?? this.weekIdx,
      slotId: slotId ?? this.slotId,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      rir: rir ?? this.rir,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mesocycleId.present) {
      map['mesocycle_id'] = Variable<String>(mesocycleId.value);
    }
    if (weekIdx.present) {
      map['week_idx'] = Variable<int>(weekIdx.value);
    }
    if (slotId.present) {
      map['slot_id'] = Variable<String>(slotId.value);
    }
    if (sets.present) {
      map['sets'] = Variable<int>(sets.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (rir.present) {
      map['rir'] = Variable<int>(rir.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeekTargetsCompanion(')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('weekIdx: $weekIdx, ')
          ..write('slotId: $slotId, ')
          ..write('sets: $sets, ')
          ..write('reps: $reps, ')
          ..write('rir: $rir, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgramDaysTable extends ProgramDays
    with TableInfo<$ProgramDaysTable, ProgramDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mesocycleIdMeta =
      const VerificationMeta('mesocycleId');
  @override
  late final GeneratedColumn<String> mesocycleId = GeneratedColumn<String>(
      'mesocycle_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES mesocycles (id) ON DELETE CASCADE'));
  static const VerificationMeta _dayIdxMeta = const VerificationMeta('dayIdx');
  @override
  late final GeneratedColumn<int> dayIdx = GeneratedColumn<int>(
      'day_idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [mesocycleId, dayIdx, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'program_days';
  @override
  VerificationContext validateIntegrity(Insertable<ProgramDay> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mesocycle_id')) {
      context.handle(
          _mesocycleIdMeta,
          mesocycleId.isAcceptableOrUnknown(
              data['mesocycle_id']!, _mesocycleIdMeta));
    } else if (isInserting) {
      context.missing(_mesocycleIdMeta);
    }
    if (data.containsKey('day_idx')) {
      context.handle(_dayIdxMeta,
          dayIdx.isAcceptableOrUnknown(data['day_idx']!, _dayIdxMeta));
    } else if (isInserting) {
      context.missing(_dayIdxMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mesocycleId, dayIdx};
  @override
  ProgramDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramDay(
      mesocycleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mesocycle_id'])!,
      dayIdx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_idx'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label']),
    );
  }

  @override
  $ProgramDaysTable createAlias(String alias) {
    return $ProgramDaysTable(attachedDatabase, alias);
  }
}

class ProgramDay extends DataClass implements Insertable<ProgramDay> {
  final String mesocycleId;
  final int dayIdx;
  final String? label;
  const ProgramDay(
      {required this.mesocycleId, required this.dayIdx, this.label});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mesocycle_id'] = Variable<String>(mesocycleId);
    map['day_idx'] = Variable<int>(dayIdx);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    return map;
  }

  ProgramDaysCompanion toCompanion(bool nullToAbsent) {
    return ProgramDaysCompanion(
      mesocycleId: Value(mesocycleId),
      dayIdx: Value(dayIdx),
      label:
          label == null && nullToAbsent ? const Value.absent() : Value(label),
    );
  }

  factory ProgramDay.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramDay(
      mesocycleId: serializer.fromJson<String>(json['mesocycleId']),
      dayIdx: serializer.fromJson<int>(json['dayIdx']),
      label: serializer.fromJson<String?>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mesocycleId': serializer.toJson<String>(mesocycleId),
      'dayIdx': serializer.toJson<int>(dayIdx),
      'label': serializer.toJson<String?>(label),
    };
  }

  ProgramDay copyWith(
          {String? mesocycleId,
          int? dayIdx,
          Value<String?> label = const Value.absent()}) =>
      ProgramDay(
        mesocycleId: mesocycleId ?? this.mesocycleId,
        dayIdx: dayIdx ?? this.dayIdx,
        label: label.present ? label.value : this.label,
      );
  ProgramDay copyWithCompanion(ProgramDaysCompanion data) {
    return ProgramDay(
      mesocycleId:
          data.mesocycleId.present ? data.mesocycleId.value : this.mesocycleId,
      dayIdx: data.dayIdx.present ? data.dayIdx.value : this.dayIdx,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramDay(')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('dayIdx: $dayIdx, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mesocycleId, dayIdx, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramDay &&
          other.mesocycleId == this.mesocycleId &&
          other.dayIdx == this.dayIdx &&
          other.label == this.label);
}

class ProgramDaysCompanion extends UpdateCompanion<ProgramDay> {
  final Value<String> mesocycleId;
  final Value<int> dayIdx;
  final Value<String?> label;
  final Value<int> rowid;
  const ProgramDaysCompanion({
    this.mesocycleId = const Value.absent(),
    this.dayIdx = const Value.absent(),
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgramDaysCompanion.insert({
    required String mesocycleId,
    required int dayIdx,
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : mesocycleId = Value(mesocycleId),
        dayIdx = Value(dayIdx);
  static Insertable<ProgramDay> custom({
    Expression<String>? mesocycleId,
    Expression<int>? dayIdx,
    Expression<String>? label,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mesocycleId != null) 'mesocycle_id': mesocycleId,
      if (dayIdx != null) 'day_idx': dayIdx,
      if (label != null) 'label': label,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgramDaysCompanion copyWith(
      {Value<String>? mesocycleId,
      Value<int>? dayIdx,
      Value<String?>? label,
      Value<int>? rowid}) {
    return ProgramDaysCompanion(
      mesocycleId: mesocycleId ?? this.mesocycleId,
      dayIdx: dayIdx ?? this.dayIdx,
      label: label ?? this.label,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mesocycleId.present) {
      map['mesocycle_id'] = Variable<String>(mesocycleId.value);
    }
    if (dayIdx.present) {
      map['day_idx'] = Variable<int>(dayIdx.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramDaysCompanion(')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('dayIdx: $dayIdx, ')
          ..write('label: $label, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayOverridesTable extends DayOverrides
    with TableInfo<$DayOverridesTable, DayOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mesocycleIdMeta =
      const VerificationMeta('mesocycleId');
  @override
  late final GeneratedColumn<String> mesocycleId = GeneratedColumn<String>(
      'mesocycle_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES mesocycles (id) ON DELETE CASCADE'));
  static const VerificationMeta _weekIdxMeta =
      const VerificationMeta('weekIdx');
  @override
  late final GeneratedColumn<int> weekIdx = GeneratedColumn<int>(
      'week_idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dayIdxMeta = const VerificationMeta('dayIdx');
  @override
  late final GeneratedColumn<int> dayIdx = GeneratedColumn<int>(
      'day_idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _exerciseIdsCsvMeta =
      const VerificationMeta('exerciseIdsCsv');
  @override
  late final GeneratedColumn<String> exerciseIdsCsv = GeneratedColumn<String>(
      'exercise_ids_csv', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [mesocycleId, weekIdx, dayIdx, exerciseIdsCsv];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_overrides';
  @override
  VerificationContext validateIntegrity(Insertable<DayOverride> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mesocycle_id')) {
      context.handle(
          _mesocycleIdMeta,
          mesocycleId.isAcceptableOrUnknown(
              data['mesocycle_id']!, _mesocycleIdMeta));
    } else if (isInserting) {
      context.missing(_mesocycleIdMeta);
    }
    if (data.containsKey('week_idx')) {
      context.handle(_weekIdxMeta,
          weekIdx.isAcceptableOrUnknown(data['week_idx']!, _weekIdxMeta));
    } else if (isInserting) {
      context.missing(_weekIdxMeta);
    }
    if (data.containsKey('day_idx')) {
      context.handle(_dayIdxMeta,
          dayIdx.isAcceptableOrUnknown(data['day_idx']!, _dayIdxMeta));
    } else if (isInserting) {
      context.missing(_dayIdxMeta);
    }
    if (data.containsKey('exercise_ids_csv')) {
      context.handle(
          _exerciseIdsCsvMeta,
          exerciseIdsCsv.isAcceptableOrUnknown(
              data['exercise_ids_csv']!, _exerciseIdsCsvMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdsCsvMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mesocycleId, weekIdx, dayIdx};
  @override
  DayOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayOverride(
      mesocycleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mesocycle_id'])!,
      weekIdx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_idx'])!,
      dayIdx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_idx'])!,
      exerciseIdsCsv: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}exercise_ids_csv'])!,
    );
  }

  @override
  $DayOverridesTable createAlias(String alias) {
    return $DayOverridesTable(attachedDatabase, alias);
  }
}

class DayOverride extends DataClass implements Insertable<DayOverride> {
  final String mesocycleId;
  final int weekIdx;
  final int dayIdx;
  final String exerciseIdsCsv;
  const DayOverride(
      {required this.mesocycleId,
      required this.weekIdx,
      required this.dayIdx,
      required this.exerciseIdsCsv});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mesocycle_id'] = Variable<String>(mesocycleId);
    map['week_idx'] = Variable<int>(weekIdx);
    map['day_idx'] = Variable<int>(dayIdx);
    map['exercise_ids_csv'] = Variable<String>(exerciseIdsCsv);
    return map;
  }

  DayOverridesCompanion toCompanion(bool nullToAbsent) {
    return DayOverridesCompanion(
      mesocycleId: Value(mesocycleId),
      weekIdx: Value(weekIdx),
      dayIdx: Value(dayIdx),
      exerciseIdsCsv: Value(exerciseIdsCsv),
    );
  }

  factory DayOverride.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayOverride(
      mesocycleId: serializer.fromJson<String>(json['mesocycleId']),
      weekIdx: serializer.fromJson<int>(json['weekIdx']),
      dayIdx: serializer.fromJson<int>(json['dayIdx']),
      exerciseIdsCsv: serializer.fromJson<String>(json['exerciseIdsCsv']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mesocycleId': serializer.toJson<String>(mesocycleId),
      'weekIdx': serializer.toJson<int>(weekIdx),
      'dayIdx': serializer.toJson<int>(dayIdx),
      'exerciseIdsCsv': serializer.toJson<String>(exerciseIdsCsv),
    };
  }

  DayOverride copyWith(
          {String? mesocycleId,
          int? weekIdx,
          int? dayIdx,
          String? exerciseIdsCsv}) =>
      DayOverride(
        mesocycleId: mesocycleId ?? this.mesocycleId,
        weekIdx: weekIdx ?? this.weekIdx,
        dayIdx: dayIdx ?? this.dayIdx,
        exerciseIdsCsv: exerciseIdsCsv ?? this.exerciseIdsCsv,
      );
  DayOverride copyWithCompanion(DayOverridesCompanion data) {
    return DayOverride(
      mesocycleId:
          data.mesocycleId.present ? data.mesocycleId.value : this.mesocycleId,
      weekIdx: data.weekIdx.present ? data.weekIdx.value : this.weekIdx,
      dayIdx: data.dayIdx.present ? data.dayIdx.value : this.dayIdx,
      exerciseIdsCsv: data.exerciseIdsCsv.present
          ? data.exerciseIdsCsv.value
          : this.exerciseIdsCsv,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayOverride(')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('weekIdx: $weekIdx, ')
          ..write('dayIdx: $dayIdx, ')
          ..write('exerciseIdsCsv: $exerciseIdsCsv')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mesocycleId, weekIdx, dayIdx, exerciseIdsCsv);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayOverride &&
          other.mesocycleId == this.mesocycleId &&
          other.weekIdx == this.weekIdx &&
          other.dayIdx == this.dayIdx &&
          other.exerciseIdsCsv == this.exerciseIdsCsv);
}

class DayOverridesCompanion extends UpdateCompanion<DayOverride> {
  final Value<String> mesocycleId;
  final Value<int> weekIdx;
  final Value<int> dayIdx;
  final Value<String> exerciseIdsCsv;
  final Value<int> rowid;
  const DayOverridesCompanion({
    this.mesocycleId = const Value.absent(),
    this.weekIdx = const Value.absent(),
    this.dayIdx = const Value.absent(),
    this.exerciseIdsCsv = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayOverridesCompanion.insert({
    required String mesocycleId,
    required int weekIdx,
    required int dayIdx,
    required String exerciseIdsCsv,
    this.rowid = const Value.absent(),
  })  : mesocycleId = Value(mesocycleId),
        weekIdx = Value(weekIdx),
        dayIdx = Value(dayIdx),
        exerciseIdsCsv = Value(exerciseIdsCsv);
  static Insertable<DayOverride> custom({
    Expression<String>? mesocycleId,
    Expression<int>? weekIdx,
    Expression<int>? dayIdx,
    Expression<String>? exerciseIdsCsv,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mesocycleId != null) 'mesocycle_id': mesocycleId,
      if (weekIdx != null) 'week_idx': weekIdx,
      if (dayIdx != null) 'day_idx': dayIdx,
      if (exerciseIdsCsv != null) 'exercise_ids_csv': exerciseIdsCsv,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayOverridesCompanion copyWith(
      {Value<String>? mesocycleId,
      Value<int>? weekIdx,
      Value<int>? dayIdx,
      Value<String>? exerciseIdsCsv,
      Value<int>? rowid}) {
    return DayOverridesCompanion(
      mesocycleId: mesocycleId ?? this.mesocycleId,
      weekIdx: weekIdx ?? this.weekIdx,
      dayIdx: dayIdx ?? this.dayIdx,
      exerciseIdsCsv: exerciseIdsCsv ?? this.exerciseIdsCsv,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mesocycleId.present) {
      map['mesocycle_id'] = Variable<String>(mesocycleId.value);
    }
    if (weekIdx.present) {
      map['week_idx'] = Variable<int>(weekIdx.value);
    }
    if (dayIdx.present) {
      map['day_idx'] = Variable<int>(dayIdx.value);
    }
    if (exerciseIdsCsv.present) {
      map['exercise_ids_csv'] = Variable<String>(exerciseIdsCsv.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayOverridesCompanion(')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('weekIdx: $weekIdx, ')
          ..write('dayIdx: $dayIdx, ')
          ..write('exerciseIdsCsv: $exerciseIdsCsv, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionLogsTable extends SessionLogs
    with TableInfo<$SessionLogsTable, SessionLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mesocycleIdMeta =
      const VerificationMeta('mesocycleId');
  @override
  late final GeneratedColumn<String> mesocycleId = GeneratedColumn<String>(
      'mesocycle_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES mesocycles (id) ON DELETE CASCADE'));
  static const VerificationMeta _weekIdxMeta =
      const VerificationMeta('weekIdx');
  @override
  late final GeneratedColumn<int> weekIdx = GeneratedColumn<int>(
      'week_idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dayIdxMeta = const VerificationMeta('dayIdx');
  @override
  late final GeneratedColumn<int> dayIdx = GeneratedColumn<int>(
      'day_idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, mesocycleId, weekIdx, dayIdx, startedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_logs';
  @override
  VerificationContext validateIntegrity(Insertable<SessionLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mesocycle_id')) {
      context.handle(
          _mesocycleIdMeta,
          mesocycleId.isAcceptableOrUnknown(
              data['mesocycle_id']!, _mesocycleIdMeta));
    } else if (isInserting) {
      context.missing(_mesocycleIdMeta);
    }
    if (data.containsKey('week_idx')) {
      context.handle(_weekIdxMeta,
          weekIdx.isAcceptableOrUnknown(data['week_idx']!, _weekIdxMeta));
    } else if (isInserting) {
      context.missing(_weekIdxMeta);
    }
    if (data.containsKey('day_idx')) {
      context.handle(_dayIdxMeta,
          dayIdx.isAcceptableOrUnknown(data['day_idx']!, _dayIdxMeta));
    } else if (isInserting) {
      context.missing(_dayIdxMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      mesocycleId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mesocycle_id'])!,
      weekIdx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_idx'])!,
      dayIdx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_idx'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at']),
    );
  }

  @override
  $SessionLogsTable createAlias(String alias) {
    return $SessionLogsTable(attachedDatabase, alias);
  }
}

class SessionLog extends DataClass implements Insertable<SessionLog> {
  final String id;
  final String mesocycleId;
  final int weekIdx;
  final int dayIdx;
  final DateTime? startedAt;
  const SessionLog(
      {required this.id,
      required this.mesocycleId,
      required this.weekIdx,
      required this.dayIdx,
      this.startedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mesocycle_id'] = Variable<String>(mesocycleId);
    map['week_idx'] = Variable<int>(weekIdx);
    map['day_idx'] = Variable<int>(dayIdx);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    return map;
  }

  SessionLogsCompanion toCompanion(bool nullToAbsent) {
    return SessionLogsCompanion(
      id: Value(id),
      mesocycleId: Value(mesocycleId),
      weekIdx: Value(weekIdx),
      dayIdx: Value(dayIdx),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
    );
  }

  factory SessionLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionLog(
      id: serializer.fromJson<String>(json['id']),
      mesocycleId: serializer.fromJson<String>(json['mesocycleId']),
      weekIdx: serializer.fromJson<int>(json['weekIdx']),
      dayIdx: serializer.fromJson<int>(json['dayIdx']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mesocycleId': serializer.toJson<String>(mesocycleId),
      'weekIdx': serializer.toJson<int>(weekIdx),
      'dayIdx': serializer.toJson<int>(dayIdx),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
    };
  }

  SessionLog copyWith(
          {String? id,
          String? mesocycleId,
          int? weekIdx,
          int? dayIdx,
          Value<DateTime?> startedAt = const Value.absent()}) =>
      SessionLog(
        id: id ?? this.id,
        mesocycleId: mesocycleId ?? this.mesocycleId,
        weekIdx: weekIdx ?? this.weekIdx,
        dayIdx: dayIdx ?? this.dayIdx,
        startedAt: startedAt.present ? startedAt.value : this.startedAt,
      );
  SessionLog copyWithCompanion(SessionLogsCompanion data) {
    return SessionLog(
      id: data.id.present ? data.id.value : this.id,
      mesocycleId:
          data.mesocycleId.present ? data.mesocycleId.value : this.mesocycleId,
      weekIdx: data.weekIdx.present ? data.weekIdx.value : this.weekIdx,
      dayIdx: data.dayIdx.present ? data.dayIdx.value : this.dayIdx,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionLog(')
          ..write('id: $id, ')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('weekIdx: $weekIdx, ')
          ..write('dayIdx: $dayIdx, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mesocycleId, weekIdx, dayIdx, startedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionLog &&
          other.id == this.id &&
          other.mesocycleId == this.mesocycleId &&
          other.weekIdx == this.weekIdx &&
          other.dayIdx == this.dayIdx &&
          other.startedAt == this.startedAt);
}

class SessionLogsCompanion extends UpdateCompanion<SessionLog> {
  final Value<String> id;
  final Value<String> mesocycleId;
  final Value<int> weekIdx;
  final Value<int> dayIdx;
  final Value<DateTime?> startedAt;
  final Value<int> rowid;
  const SessionLogsCompanion({
    this.id = const Value.absent(),
    this.mesocycleId = const Value.absent(),
    this.weekIdx = const Value.absent(),
    this.dayIdx = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionLogsCompanion.insert({
    required String id,
    required String mesocycleId,
    required int weekIdx,
    required int dayIdx,
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        mesocycleId = Value(mesocycleId),
        weekIdx = Value(weekIdx),
        dayIdx = Value(dayIdx);
  static Insertable<SessionLog> custom({
    Expression<String>? id,
    Expression<String>? mesocycleId,
    Expression<int>? weekIdx,
    Expression<int>? dayIdx,
    Expression<DateTime>? startedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mesocycleId != null) 'mesocycle_id': mesocycleId,
      if (weekIdx != null) 'week_idx': weekIdx,
      if (dayIdx != null) 'day_idx': dayIdx,
      if (startedAt != null) 'started_at': startedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionLogsCompanion copyWith(
      {Value<String>? id,
      Value<String>? mesocycleId,
      Value<int>? weekIdx,
      Value<int>? dayIdx,
      Value<DateTime?>? startedAt,
      Value<int>? rowid}) {
    return SessionLogsCompanion(
      id: id ?? this.id,
      mesocycleId: mesocycleId ?? this.mesocycleId,
      weekIdx: weekIdx ?? this.weekIdx,
      dayIdx: dayIdx ?? this.dayIdx,
      startedAt: startedAt ?? this.startedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mesocycleId.present) {
      map['mesocycle_id'] = Variable<String>(mesocycleId.value);
    }
    if (weekIdx.present) {
      map['week_idx'] = Variable<int>(weekIdx.value);
    }
    if (dayIdx.present) {
      map['day_idx'] = Variable<int>(dayIdx.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionLogsCompanion(')
          ..write('id: $id, ')
          ..write('mesocycleId: $mesocycleId, ')
          ..write('weekIdx: $weekIdx, ')
          ..write('dayIdx: $dayIdx, ')
          ..write('startedAt: $startedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetEntriesTable extends SetEntries
    with TableInfo<$SetEntriesTable, SetEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES session_logs (id) ON DELETE CASCADE'));
  static const VerificationMeta _exerciseIdMeta =
      const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
      'exercise_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES exercises (id) ON DELETE CASCADE'));
  static const VerificationMeta _slotIdMeta = const VerificationMeta('slotId');
  @override
  late final GeneratedColumn<String> slotId = GeneratedColumn<String>(
      'slot_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES exercise_slots (id) ON DELETE CASCADE'));
  static const VerificationMeta _setIndexMeta =
      const VerificationMeta('setIndex');
  @override
  late final GeneratedColumn<int> setIndex = GeneratedColumn<int>(
      'set_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
      'weight', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
      'reps', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _rirMeta = const VerificationMeta('rir');
  @override
  late final GeneratedColumn<int> rir = GeneratedColumn<int>(
      'rir', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
      'done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("done" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _loggedAtMeta =
      const VerificationMeta('loggedAt');
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
      'logged_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        exerciseId,
        slotId,
        setIndex,
        weight,
        reps,
        rir,
        done,
        loggedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SetEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
          _exerciseIdMeta,
          exerciseId.isAcceptableOrUnknown(
              data['exercise_id']!, _exerciseIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('slot_id')) {
      context.handle(_slotIdMeta,
          slotId.isAcceptableOrUnknown(data['slot_id']!, _slotIdMeta));
    }
    if (data.containsKey('set_index')) {
      context.handle(_setIndexMeta,
          setIndex.isAcceptableOrUnknown(data['set_index']!, _setIndexMeta));
    } else if (isInserting) {
      context.missing(_setIndexMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    if (data.containsKey('reps')) {
      context.handle(
          _repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    }
    if (data.containsKey('rir')) {
      context.handle(
          _rirMeta, rir.isAcceptableOrUnknown(data['rir']!, _rirMeta));
    }
    if (data.containsKey('done')) {
      context.handle(
          _doneMeta, done.isAcceptableOrUnknown(data['done']!, _doneMeta));
    }
    if (data.containsKey('logged_at')) {
      context.handle(_loggedAtMeta,
          loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      exerciseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_id'])!,
      slotId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slot_id']),
      setIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}set_index'])!,
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight']),
      reps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reps']),
      rir: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rir']),
      done: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}done'])!,
      loggedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}logged_at']),
    );
  }

  @override
  $SetEntriesTable createAlias(String alias) {
    return $SetEntriesTable(attachedDatabase, alias);
  }
}

class SetEntry extends DataClass implements Insertable<SetEntry> {
  final String id;
  final String sessionId;
  final String exerciseId;
  final String? slotId;
  final int setIndex;
  final double? weight;
  final int? reps;
  final int? rir;
  final bool done;
  final DateTime? loggedAt;
  const SetEntry(
      {required this.id,
      required this.sessionId,
      required this.exerciseId,
      this.slotId,
      required this.setIndex,
      this.weight,
      this.reps,
      this.rir,
      required this.done,
      this.loggedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['exercise_id'] = Variable<String>(exerciseId);
    if (!nullToAbsent || slotId != null) {
      map['slot_id'] = Variable<String>(slotId);
    }
    map['set_index'] = Variable<int>(setIndex);
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<double>(weight);
    }
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || rir != null) {
      map['rir'] = Variable<int>(rir);
    }
    map['done'] = Variable<bool>(done);
    if (!nullToAbsent || loggedAt != null) {
      map['logged_at'] = Variable<DateTime>(loggedAt);
    }
    return map;
  }

  SetEntriesCompanion toCompanion(bool nullToAbsent) {
    return SetEntriesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      exerciseId: Value(exerciseId),
      slotId:
          slotId == null && nullToAbsent ? const Value.absent() : Value(slotId),
      setIndex: Value(setIndex),
      weight:
          weight == null && nullToAbsent ? const Value.absent() : Value(weight),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      rir: rir == null && nullToAbsent ? const Value.absent() : Value(rir),
      done: Value(done),
      loggedAt: loggedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(loggedAt),
    );
  }

  factory SetEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetEntry(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      slotId: serializer.fromJson<String?>(json['slotId']),
      setIndex: serializer.fromJson<int>(json['setIndex']),
      weight: serializer.fromJson<double?>(json['weight']),
      reps: serializer.fromJson<int?>(json['reps']),
      rir: serializer.fromJson<int?>(json['rir']),
      done: serializer.fromJson<bool>(json['done']),
      loggedAt: serializer.fromJson<DateTime?>(json['loggedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'slotId': serializer.toJson<String?>(slotId),
      'setIndex': serializer.toJson<int>(setIndex),
      'weight': serializer.toJson<double?>(weight),
      'reps': serializer.toJson<int?>(reps),
      'rir': serializer.toJson<int?>(rir),
      'done': serializer.toJson<bool>(done),
      'loggedAt': serializer.toJson<DateTime?>(loggedAt),
    };
  }

  SetEntry copyWith(
          {String? id,
          String? sessionId,
          String? exerciseId,
          Value<String?> slotId = const Value.absent(),
          int? setIndex,
          Value<double?> weight = const Value.absent(),
          Value<int?> reps = const Value.absent(),
          Value<int?> rir = const Value.absent(),
          bool? done,
          Value<DateTime?> loggedAt = const Value.absent()}) =>
      SetEntry(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        exerciseId: exerciseId ?? this.exerciseId,
        slotId: slotId.present ? slotId.value : this.slotId,
        setIndex: setIndex ?? this.setIndex,
        weight: weight.present ? weight.value : this.weight,
        reps: reps.present ? reps.value : this.reps,
        rir: rir.present ? rir.value : this.rir,
        done: done ?? this.done,
        loggedAt: loggedAt.present ? loggedAt.value : this.loggedAt,
      );
  SetEntry copyWithCompanion(SetEntriesCompanion data) {
    return SetEntry(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      slotId: data.slotId.present ? data.slotId.value : this.slotId,
      setIndex: data.setIndex.present ? data.setIndex.value : this.setIndex,
      weight: data.weight.present ? data.weight.value : this.weight,
      reps: data.reps.present ? data.reps.value : this.reps,
      rir: data.rir.present ? data.rir.value : this.rir,
      done: data.done.present ? data.done.value : this.done,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetEntry(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('slotId: $slotId, ')
          ..write('setIndex: $setIndex, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('rir: $rir, ')
          ..write('done: $done, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, exerciseId, slotId, setIndex,
      weight, reps, rir, done, loggedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetEntry &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exerciseId == this.exerciseId &&
          other.slotId == this.slotId &&
          other.setIndex == this.setIndex &&
          other.weight == this.weight &&
          other.reps == this.reps &&
          other.rir == this.rir &&
          other.done == this.done &&
          other.loggedAt == this.loggedAt);
}

class SetEntriesCompanion extends UpdateCompanion<SetEntry> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> exerciseId;
  final Value<String?> slotId;
  final Value<int> setIndex;
  final Value<double?> weight;
  final Value<int?> reps;
  final Value<int?> rir;
  final Value<bool> done;
  final Value<DateTime?> loggedAt;
  final Value<int> rowid;
  const SetEntriesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.slotId = const Value.absent(),
    this.setIndex = const Value.absent(),
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.rir = const Value.absent(),
    this.done = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetEntriesCompanion.insert({
    required String id,
    required String sessionId,
    required String exerciseId,
    this.slotId = const Value.absent(),
    required int setIndex,
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.rir = const Value.absent(),
    this.done = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        exerciseId = Value(exerciseId),
        setIndex = Value(setIndex);
  static Insertable<SetEntry> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? exerciseId,
    Expression<String>? slotId,
    Expression<int>? setIndex,
    Expression<double>? weight,
    Expression<int>? reps,
    Expression<int>? rir,
    Expression<bool>? done,
    Expression<DateTime>? loggedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (slotId != null) 'slot_id': slotId,
      if (setIndex != null) 'set_index': setIndex,
      if (weight != null) 'weight': weight,
      if (reps != null) 'reps': reps,
      if (rir != null) 'rir': rir,
      if (done != null) 'done': done,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? exerciseId,
      Value<String?>? slotId,
      Value<int>? setIndex,
      Value<double?>? weight,
      Value<int?>? reps,
      Value<int?>? rir,
      Value<bool>? done,
      Value<DateTime?>? loggedAt,
      Value<int>? rowid}) {
    return SetEntriesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseId: exerciseId ?? this.exerciseId,
      slotId: slotId ?? this.slotId,
      setIndex: setIndex ?? this.setIndex,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      rir: rir ?? this.rir,
      done: done ?? this.done,
      loggedAt: loggedAt ?? this.loggedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (slotId.present) {
      map['slot_id'] = Variable<String>(slotId.value);
    }
    if (setIndex.present) {
      map['set_index'] = Variable<int>(setIndex.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (rir.present) {
      map['rir'] = Variable<int>(rir.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetEntriesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('slotId: $slotId, ')
          ..write('setIndex: $setIndex, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('rir: $rir, ')
          ..write('done: $done, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MesocyclesTable mesocycles = $MesocyclesTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $ExerciseSlotsTable exerciseSlots = $ExerciseSlotsTable(this);
  late final $WeekTargetsTable weekTargets = $WeekTargetsTable(this);
  late final $ProgramDaysTable programDays = $ProgramDaysTable(this);
  late final $DayOverridesTable dayOverrides = $DayOverridesTable(this);
  late final $SessionLogsTable sessionLogs = $SessionLogsTable(this);
  late final $SetEntriesTable setEntries = $SetEntriesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        mesocycles,
        exercises,
        exerciseSlots,
        weekTargets,
        programDays,
        dayOverrides,
        sessionLogs,
        setEntries,
        settings
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('mesocycles',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('exercise_slots', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('exercises',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('exercise_slots', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('mesocycles',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('week_targets', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('exercise_slots',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('week_targets', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('mesocycles',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('program_days', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('mesocycles',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('day_overrides', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('mesocycles',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('session_logs', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('session_logs',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('set_entries', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('exercises',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('set_entries', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('exercise_slots',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('set_entries', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$MesocyclesTableCreateCompanionBuilder = MesocyclesCompanion Function({
  required String id,
  required String name,
  required DateTime startDate,
  Value<bool> isActive,
  Value<int> numWeeks,
  Value<String> deloadWeeks,
  Value<int> rowid,
});
typedef $$MesocyclesTableUpdateCompanionBuilder = MesocyclesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> startDate,
  Value<bool> isActive,
  Value<int> numWeeks,
  Value<String> deloadWeeks,
  Value<int> rowid,
});

final class $$MesocyclesTableReferences
    extends BaseReferences<_$AppDatabase, $MesocyclesTable, Mesocycle> {
  $$MesocyclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ExerciseSlotsTable, List<ExerciseSlot>>
      _exerciseSlotsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.exerciseSlots,
              aliasName: $_aliasNameGenerator(
                  db.mesocycles.id, db.exerciseSlots.mesocycleId));

  $$ExerciseSlotsTableProcessedTableManager get exerciseSlotsRefs {
    final manager = $$ExerciseSlotsTableTableManager($_db, $_db.exerciseSlots)
        .filter((f) => f.mesocycleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_exerciseSlotsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$WeekTargetsTable, List<WeekTarget>>
      _weekTargetsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.weekTargets,
              aliasName: $_aliasNameGenerator(
                  db.mesocycles.id, db.weekTargets.mesocycleId));

  $$WeekTargetsTableProcessedTableManager get weekTargetsRefs {
    final manager = $$WeekTargetsTableTableManager($_db, $_db.weekTargets)
        .filter((f) => f.mesocycleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_weekTargetsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ProgramDaysTable, List<ProgramDay>>
      _programDaysRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.programDays,
              aliasName: $_aliasNameGenerator(
                  db.mesocycles.id, db.programDays.mesocycleId));

  $$ProgramDaysTableProcessedTableManager get programDaysRefs {
    final manager = $$ProgramDaysTableTableManager($_db, $_db.programDays)
        .filter((f) => f.mesocycleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_programDaysRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$DayOverridesTable, List<DayOverride>>
      _dayOverridesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.dayOverrides,
              aliasName: $_aliasNameGenerator(
                  db.mesocycles.id, db.dayOverrides.mesocycleId));

  $$DayOverridesTableProcessedTableManager get dayOverridesRefs {
    final manager = $$DayOverridesTableTableManager($_db, $_db.dayOverrides)
        .filter((f) => f.mesocycleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dayOverridesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SessionLogsTable, List<SessionLog>>
      _sessionLogsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.sessionLogs,
              aliasName: $_aliasNameGenerator(
                  db.mesocycles.id, db.sessionLogs.mesocycleId));

  $$SessionLogsTableProcessedTableManager get sessionLogsRefs {
    final manager = $$SessionLogsTableTableManager($_db, $_db.sessionLogs)
        .filter((f) => f.mesocycleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionLogsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MesocyclesTableFilterComposer
    extends Composer<_$AppDatabase, $MesocyclesTable> {
  $$MesocyclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get numWeeks => $composableBuilder(
      column: $table.numWeeks, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deloadWeeks => $composableBuilder(
      column: $table.deloadWeeks, builder: (column) => ColumnFilters(column));

  Expression<bool> exerciseSlotsRefs(
      Expression<bool> Function($$ExerciseSlotsTableFilterComposer f) f) {
    final $$ExerciseSlotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableFilterComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> weekTargetsRefs(
      Expression<bool> Function($$WeekTargetsTableFilterComposer f) f) {
    final $$WeekTargetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.weekTargets,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WeekTargetsTableFilterComposer(
              $db: $db,
              $table: $db.weekTargets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> programDaysRefs(
      Expression<bool> Function($$ProgramDaysTableFilterComposer f) f) {
    final $$ProgramDaysTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.programDays,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProgramDaysTableFilterComposer(
              $db: $db,
              $table: $db.programDays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> dayOverridesRefs(
      Expression<bool> Function($$DayOverridesTableFilterComposer f) f) {
    final $$DayOverridesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dayOverrides,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DayOverridesTableFilterComposer(
              $db: $db,
              $table: $db.dayOverrides,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> sessionLogsRefs(
      Expression<bool> Function($$SessionLogsTableFilterComposer f) f) {
    final $$SessionLogsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionLogs,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionLogsTableFilterComposer(
              $db: $db,
              $table: $db.sessionLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MesocyclesTableOrderingComposer
    extends Composer<_$AppDatabase, $MesocyclesTable> {
  $$MesocyclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
      column: $table.startDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get numWeeks => $composableBuilder(
      column: $table.numWeeks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deloadWeeks => $composableBuilder(
      column: $table.deloadWeeks, builder: (column) => ColumnOrderings(column));
}

class $$MesocyclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MesocyclesTable> {
  $$MesocyclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get numWeeks =>
      $composableBuilder(column: $table.numWeeks, builder: (column) => column);

  GeneratedColumn<String> get deloadWeeks => $composableBuilder(
      column: $table.deloadWeeks, builder: (column) => column);

  Expression<T> exerciseSlotsRefs<T extends Object>(
      Expression<T> Function($$ExerciseSlotsTableAnnotationComposer a) f) {
    final $$ExerciseSlotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableAnnotationComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> weekTargetsRefs<T extends Object>(
      Expression<T> Function($$WeekTargetsTableAnnotationComposer a) f) {
    final $$WeekTargetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.weekTargets,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WeekTargetsTableAnnotationComposer(
              $db: $db,
              $table: $db.weekTargets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> programDaysRefs<T extends Object>(
      Expression<T> Function($$ProgramDaysTableAnnotationComposer a) f) {
    final $$ProgramDaysTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.programDays,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProgramDaysTableAnnotationComposer(
              $db: $db,
              $table: $db.programDays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> dayOverridesRefs<T extends Object>(
      Expression<T> Function($$DayOverridesTableAnnotationComposer a) f) {
    final $$DayOverridesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.dayOverrides,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$DayOverridesTableAnnotationComposer(
              $db: $db,
              $table: $db.dayOverrides,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> sessionLogsRefs<T extends Object>(
      Expression<T> Function($$SessionLogsTableAnnotationComposer a) f) {
    final $$SessionLogsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionLogs,
        getReferencedColumn: (t) => t.mesocycleId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionLogsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MesocyclesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MesocyclesTable,
    Mesocycle,
    $$MesocyclesTableFilterComposer,
    $$MesocyclesTableOrderingComposer,
    $$MesocyclesTableAnnotationComposer,
    $$MesocyclesTableCreateCompanionBuilder,
    $$MesocyclesTableUpdateCompanionBuilder,
    (Mesocycle, $$MesocyclesTableReferences),
    Mesocycle,
    PrefetchHooks Function(
        {bool exerciseSlotsRefs,
        bool weekTargetsRefs,
        bool programDaysRefs,
        bool dayOverridesRefs,
        bool sessionLogsRefs})> {
  $$MesocyclesTableTableManager(_$AppDatabase db, $MesocyclesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MesocyclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MesocyclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MesocyclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> startDate = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> numWeeks = const Value.absent(),
            Value<String> deloadWeeks = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MesocyclesCompanion(
            id: id,
            name: name,
            startDate: startDate,
            isActive: isActive,
            numWeeks: numWeeks,
            deloadWeeks: deloadWeeks,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required DateTime startDate,
            Value<bool> isActive = const Value.absent(),
            Value<int> numWeeks = const Value.absent(),
            Value<String> deloadWeeks = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MesocyclesCompanion.insert(
            id: id,
            name: name,
            startDate: startDate,
            isActive: isActive,
            numWeeks: numWeeks,
            deloadWeeks: deloadWeeks,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MesocyclesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {exerciseSlotsRefs = false,
              weekTargetsRefs = false,
              programDaysRefs = false,
              dayOverridesRefs = false,
              sessionLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (exerciseSlotsRefs) db.exerciseSlots,
                if (weekTargetsRefs) db.weekTargets,
                if (programDaysRefs) db.programDays,
                if (dayOverridesRefs) db.dayOverrides,
                if (sessionLogsRefs) db.sessionLogs
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (exerciseSlotsRefs)
                    await $_getPrefetchedData<Mesocycle, $MesocyclesTable,
                            ExerciseSlot>(
                        currentTable: table,
                        referencedTable: $$MesocyclesTableReferences
                            ._exerciseSlotsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MesocyclesTableReferences(db, table, p0)
                                .exerciseSlotsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mesocycleId == item.id),
                        typedResults: items),
                  if (weekTargetsRefs)
                    await $_getPrefetchedData<Mesocycle, $MesocyclesTable,
                            WeekTarget>(
                        currentTable: table,
                        referencedTable: $$MesocyclesTableReferences
                            ._weekTargetsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MesocyclesTableReferences(db, table, p0)
                                .weekTargetsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mesocycleId == item.id),
                        typedResults: items),
                  if (programDaysRefs)
                    await $_getPrefetchedData<Mesocycle, $MesocyclesTable,
                            ProgramDay>(
                        currentTable: table,
                        referencedTable: $$MesocyclesTableReferences
                            ._programDaysRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MesocyclesTableReferences(db, table, p0)
                                .programDaysRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mesocycleId == item.id),
                        typedResults: items),
                  if (dayOverridesRefs)
                    await $_getPrefetchedData<Mesocycle, $MesocyclesTable,
                            DayOverride>(
                        currentTable: table,
                        referencedTable: $$MesocyclesTableReferences
                            ._dayOverridesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MesocyclesTableReferences(db, table, p0)
                                .dayOverridesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mesocycleId == item.id),
                        typedResults: items),
                  if (sessionLogsRefs)
                    await $_getPrefetchedData<Mesocycle, $MesocyclesTable,
                            SessionLog>(
                        currentTable: table,
                        referencedTable: $$MesocyclesTableReferences
                            ._sessionLogsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MesocyclesTableReferences(db, table, p0)
                                .sessionLogsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mesocycleId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$MesocyclesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MesocyclesTable,
    Mesocycle,
    $$MesocyclesTableFilterComposer,
    $$MesocyclesTableOrderingComposer,
    $$MesocyclesTableAnnotationComposer,
    $$MesocyclesTableCreateCompanionBuilder,
    $$MesocyclesTableUpdateCompanionBuilder,
    (Mesocycle, $$MesocyclesTableReferences),
    Mesocycle,
    PrefetchHooks Function(
        {bool exerciseSlotsRefs,
        bool weekTargetsRefs,
        bool programDaysRefs,
        bool dayOverridesRefs,
        bool sessionLogsRefs})>;
typedef $$ExercisesTableCreateCompanionBuilder = ExercisesCompanion Function({
  required String id,
  required String name,
  required String group,
  Value<int> rowid,
});
typedef $$ExercisesTableUpdateCompanionBuilder = ExercisesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> group,
  Value<int> rowid,
});

final class $$ExercisesTableReferences
    extends BaseReferences<_$AppDatabase, $ExercisesTable, Exercise> {
  $$ExercisesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ExerciseSlotsTable, List<ExerciseSlot>>
      _exerciseSlotsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.exerciseSlots,
              aliasName: $_aliasNameGenerator(
                  db.exercises.id, db.exerciseSlots.exerciseId));

  $$ExerciseSlotsTableProcessedTableManager get exerciseSlotsRefs {
    final manager = $$ExerciseSlotsTableTableManager($_db, $_db.exerciseSlots)
        .filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_exerciseSlotsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SetEntriesTable, List<SetEntry>>
      _setEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.setEntries,
          aliasName:
              $_aliasNameGenerator(db.exercises.id, db.setEntries.exerciseId));

  $$SetEntriesTableProcessedTableManager get setEntriesRefs {
    final manager = $$SetEntriesTableTableManager($_db, $_db.setEntries)
        .filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get group => $composableBuilder(
      column: $table.group, builder: (column) => ColumnFilters(column));

  Expression<bool> exerciseSlotsRefs(
      Expression<bool> Function($$ExerciseSlotsTableFilterComposer f) f) {
    final $$ExerciseSlotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.exerciseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableFilterComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> setEntriesRefs(
      Expression<bool> Function($$SetEntriesTableFilterComposer f) f) {
    final $$SetEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.setEntries,
        getReferencedColumn: (t) => t.exerciseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SetEntriesTableFilterComposer(
              $db: $db,
              $table: $db.setEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get group => $composableBuilder(
      column: $table.group, builder: (column) => ColumnOrderings(column));
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get group =>
      $composableBuilder(column: $table.group, builder: (column) => column);

  Expression<T> exerciseSlotsRefs<T extends Object>(
      Expression<T> Function($$ExerciseSlotsTableAnnotationComposer a) f) {
    final $$ExerciseSlotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.exerciseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableAnnotationComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> setEntriesRefs<T extends Object>(
      Expression<T> Function($$SetEntriesTableAnnotationComposer a) f) {
    final $$SetEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.setEntries,
        getReferencedColumn: (t) => t.exerciseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SetEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.setEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ExercisesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExercisesTable,
    Exercise,
    $$ExercisesTableFilterComposer,
    $$ExercisesTableOrderingComposer,
    $$ExercisesTableAnnotationComposer,
    $$ExercisesTableCreateCompanionBuilder,
    $$ExercisesTableUpdateCompanionBuilder,
    (Exercise, $$ExercisesTableReferences),
    Exercise,
    PrefetchHooks Function({bool exerciseSlotsRefs, bool setEntriesRefs})> {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> group = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExercisesCompanion(
            id: id,
            name: name,
            group: group,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String group,
            Value<int> rowid = const Value.absent(),
          }) =>
              ExercisesCompanion.insert(
            id: id,
            name: name,
            group: group,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ExercisesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {exerciseSlotsRefs = false, setEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (exerciseSlotsRefs) db.exerciseSlots,
                if (setEntriesRefs) db.setEntries
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (exerciseSlotsRefs)
                    await $_getPrefetchedData<Exercise, $ExercisesTable,
                            ExerciseSlot>(
                        currentTable: table,
                        referencedTable: $$ExercisesTableReferences
                            ._exerciseSlotsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ExercisesTableReferences(db, table, p0)
                                .exerciseSlotsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.exerciseId == item.id),
                        typedResults: items),
                  if (setEntriesRefs)
                    await $_getPrefetchedData<Exercise, $ExercisesTable,
                            SetEntry>(
                        currentTable: table,
                        referencedTable:
                            $$ExercisesTableReferences._setEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ExercisesTableReferences(db, table, p0)
                                .setEntriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.exerciseId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ExercisesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExercisesTable,
    Exercise,
    $$ExercisesTableFilterComposer,
    $$ExercisesTableOrderingComposer,
    $$ExercisesTableAnnotationComposer,
    $$ExercisesTableCreateCompanionBuilder,
    $$ExercisesTableUpdateCompanionBuilder,
    (Exercise, $$ExercisesTableReferences),
    Exercise,
    PrefetchHooks Function({bool exerciseSlotsRefs, bool setEntriesRefs})>;
typedef $$ExerciseSlotsTableCreateCompanionBuilder = ExerciseSlotsCompanion
    Function({
  required String id,
  required String mesocycleId,
  required String exerciseId,
  Value<int> rowid,
});
typedef $$ExerciseSlotsTableUpdateCompanionBuilder = ExerciseSlotsCompanion
    Function({
  Value<String> id,
  Value<String> mesocycleId,
  Value<String> exerciseId,
  Value<int> rowid,
});

final class $$ExerciseSlotsTableReferences
    extends BaseReferences<_$AppDatabase, $ExerciseSlotsTable, ExerciseSlot> {
  $$ExerciseSlotsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $MesocyclesTable _mesocycleIdTable(_$AppDatabase db) =>
      db.mesocycles.createAlias(
          $_aliasNameGenerator(db.exerciseSlots.mesocycleId, db.mesocycles.id));

  $$MesocyclesTableProcessedTableManager get mesocycleId {
    final $_column = $_itemColumn<String>('mesocycle_id')!;

    final manager = $$MesocyclesTableTableManager($_db, $_db.mesocycles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mesocycleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias(
          $_aliasNameGenerator(db.exerciseSlots.exerciseId, db.exercises.id));

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $$ExercisesTableTableManager($_db, $_db.exercises)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$WeekTargetsTable, List<WeekTarget>>
      _weekTargetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.weekTargets,
          aliasName:
              $_aliasNameGenerator(db.exerciseSlots.id, db.weekTargets.slotId));

  $$WeekTargetsTableProcessedTableManager get weekTargetsRefs {
    final manager = $$WeekTargetsTableTableManager($_db, $_db.weekTargets)
        .filter((f) => f.slotId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_weekTargetsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$SetEntriesTable, List<SetEntry>>
      _setEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.setEntries,
          aliasName:
              $_aliasNameGenerator(db.exerciseSlots.id, db.setEntries.slotId));

  $$SetEntriesTableProcessedTableManager get setEntriesRefs {
    final manager = $$SetEntriesTableTableManager($_db, $_db.setEntries)
        .filter((f) => f.slotId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ExerciseSlotsTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseSlotsTable> {
  $$ExerciseSlotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  $$MesocyclesTableFilterComposer get mesocycleId {
    final $$MesocyclesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableFilterComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $db.exercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExercisesTableFilterComposer(
              $db: $db,
              $table: $db.exercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> weekTargetsRefs(
      Expression<bool> Function($$WeekTargetsTableFilterComposer f) f) {
    final $$WeekTargetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.weekTargets,
        getReferencedColumn: (t) => t.slotId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WeekTargetsTableFilterComposer(
              $db: $db,
              $table: $db.weekTargets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> setEntriesRefs(
      Expression<bool> Function($$SetEntriesTableFilterComposer f) f) {
    final $$SetEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.setEntries,
        getReferencedColumn: (t) => t.slotId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SetEntriesTableFilterComposer(
              $db: $db,
              $table: $db.setEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ExerciseSlotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseSlotsTable> {
  $$ExerciseSlotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  $$MesocyclesTableOrderingComposer get mesocycleId {
    final $$MesocyclesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableOrderingComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $db.exercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExercisesTableOrderingComposer(
              $db: $db,
              $table: $db.exercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExerciseSlotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseSlotsTable> {
  $$ExerciseSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  $$MesocyclesTableAnnotationComposer get mesocycleId {
    final $$MesocyclesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableAnnotationComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $db.exercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExercisesTableAnnotationComposer(
              $db: $db,
              $table: $db.exercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> weekTargetsRefs<T extends Object>(
      Expression<T> Function($$WeekTargetsTableAnnotationComposer a) f) {
    final $$WeekTargetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.weekTargets,
        getReferencedColumn: (t) => t.slotId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WeekTargetsTableAnnotationComposer(
              $db: $db,
              $table: $db.weekTargets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> setEntriesRefs<T extends Object>(
      Expression<T> Function($$SetEntriesTableAnnotationComposer a) f) {
    final $$SetEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.setEntries,
        getReferencedColumn: (t) => t.slotId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SetEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.setEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ExerciseSlotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExerciseSlotsTable,
    ExerciseSlot,
    $$ExerciseSlotsTableFilterComposer,
    $$ExerciseSlotsTableOrderingComposer,
    $$ExerciseSlotsTableAnnotationComposer,
    $$ExerciseSlotsTableCreateCompanionBuilder,
    $$ExerciseSlotsTableUpdateCompanionBuilder,
    (ExerciseSlot, $$ExerciseSlotsTableReferences),
    ExerciseSlot,
    PrefetchHooks Function(
        {bool mesocycleId,
        bool exerciseId,
        bool weekTargetsRefs,
        bool setEntriesRefs})> {
  $$ExerciseSlotsTableTableManager(_$AppDatabase db, $ExerciseSlotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> mesocycleId = const Value.absent(),
            Value<String> exerciseId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseSlotsCompanion(
            id: id,
            mesocycleId: mesocycleId,
            exerciseId: exerciseId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String mesocycleId,
            required String exerciseId,
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseSlotsCompanion.insert(
            id: id,
            mesocycleId: mesocycleId,
            exerciseId: exerciseId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ExerciseSlotsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {mesocycleId = false,
              exerciseId = false,
              weekTargetsRefs = false,
              setEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (weekTargetsRefs) db.weekTargets,
                if (setEntriesRefs) db.setEntries
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mesocycleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mesocycleId,
                    referencedTable:
                        $$ExerciseSlotsTableReferences._mesocycleIdTable(db),
                    referencedColumn:
                        $$ExerciseSlotsTableReferences._mesocycleIdTable(db).id,
                  ) as T;
                }
                if (exerciseId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.exerciseId,
                    referencedTable:
                        $$ExerciseSlotsTableReferences._exerciseIdTable(db),
                    referencedColumn:
                        $$ExerciseSlotsTableReferences._exerciseIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (weekTargetsRefs)
                    await $_getPrefetchedData<ExerciseSlot, $ExerciseSlotsTable,
                            WeekTarget>(
                        currentTable: table,
                        referencedTable: $$ExerciseSlotsTableReferences
                            ._weekTargetsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ExerciseSlotsTableReferences(db, table, p0)
                                .weekTargetsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.slotId == item.id),
                        typedResults: items),
                  if (setEntriesRefs)
                    await $_getPrefetchedData<ExerciseSlot, $ExerciseSlotsTable,
                            SetEntry>(
                        currentTable: table,
                        referencedTable: $$ExerciseSlotsTableReferences
                            ._setEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ExerciseSlotsTableReferences(db, table, p0)
                                .setEntriesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.slotId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ExerciseSlotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExerciseSlotsTable,
    ExerciseSlot,
    $$ExerciseSlotsTableFilterComposer,
    $$ExerciseSlotsTableOrderingComposer,
    $$ExerciseSlotsTableAnnotationComposer,
    $$ExerciseSlotsTableCreateCompanionBuilder,
    $$ExerciseSlotsTableUpdateCompanionBuilder,
    (ExerciseSlot, $$ExerciseSlotsTableReferences),
    ExerciseSlot,
    PrefetchHooks Function(
        {bool mesocycleId,
        bool exerciseId,
        bool weekTargetsRefs,
        bool setEntriesRefs})>;
typedef $$WeekTargetsTableCreateCompanionBuilder = WeekTargetsCompanion
    Function({
  required String mesocycleId,
  required int weekIdx,
  required String slotId,
  required int sets,
  required int reps,
  required int rir,
  Value<int> rowid,
});
typedef $$WeekTargetsTableUpdateCompanionBuilder = WeekTargetsCompanion
    Function({
  Value<String> mesocycleId,
  Value<int> weekIdx,
  Value<String> slotId,
  Value<int> sets,
  Value<int> reps,
  Value<int> rir,
  Value<int> rowid,
});

final class $$WeekTargetsTableReferences
    extends BaseReferences<_$AppDatabase, $WeekTargetsTable, WeekTarget> {
  $$WeekTargetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MesocyclesTable _mesocycleIdTable(_$AppDatabase db) =>
      db.mesocycles.createAlias(
          $_aliasNameGenerator(db.weekTargets.mesocycleId, db.mesocycles.id));

  $$MesocyclesTableProcessedTableManager get mesocycleId {
    final $_column = $_itemColumn<String>('mesocycle_id')!;

    final manager = $$MesocyclesTableTableManager($_db, $_db.mesocycles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mesocycleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ExerciseSlotsTable _slotIdTable(_$AppDatabase db) =>
      db.exerciseSlots.createAlias(
          $_aliasNameGenerator(db.weekTargets.slotId, db.exerciseSlots.id));

  $$ExerciseSlotsTableProcessedTableManager get slotId {
    final $_column = $_itemColumn<String>('slot_id')!;

    final manager = $$ExerciseSlotsTableTableManager($_db, $_db.exerciseSlots)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WeekTargetsTableFilterComposer
    extends Composer<_$AppDatabase, $WeekTargetsTable> {
  $$WeekTargetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get weekIdx => $composableBuilder(
      column: $table.weekIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sets => $composableBuilder(
      column: $table.sets, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rir => $composableBuilder(
      column: $table.rir, builder: (column) => ColumnFilters(column));

  $$MesocyclesTableFilterComposer get mesocycleId {
    final $$MesocyclesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableFilterComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExerciseSlotsTableFilterComposer get slotId {
    final $$ExerciseSlotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableFilterComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WeekTargetsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeekTargetsTable> {
  $$WeekTargetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get weekIdx => $composableBuilder(
      column: $table.weekIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sets => $composableBuilder(
      column: $table.sets, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rir => $composableBuilder(
      column: $table.rir, builder: (column) => ColumnOrderings(column));

  $$MesocyclesTableOrderingComposer get mesocycleId {
    final $$MesocyclesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableOrderingComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExerciseSlotsTableOrderingComposer get slotId {
    final $$ExerciseSlotsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableOrderingComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WeekTargetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeekTargetsTable> {
  $$WeekTargetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get weekIdx =>
      $composableBuilder(column: $table.weekIdx, builder: (column) => column);

  GeneratedColumn<int> get sets =>
      $composableBuilder(column: $table.sets, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get rir =>
      $composableBuilder(column: $table.rir, builder: (column) => column);

  $$MesocyclesTableAnnotationComposer get mesocycleId {
    final $$MesocyclesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableAnnotationComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExerciseSlotsTableAnnotationComposer get slotId {
    final $$ExerciseSlotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableAnnotationComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WeekTargetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WeekTargetsTable,
    WeekTarget,
    $$WeekTargetsTableFilterComposer,
    $$WeekTargetsTableOrderingComposer,
    $$WeekTargetsTableAnnotationComposer,
    $$WeekTargetsTableCreateCompanionBuilder,
    $$WeekTargetsTableUpdateCompanionBuilder,
    (WeekTarget, $$WeekTargetsTableReferences),
    WeekTarget,
    PrefetchHooks Function({bool mesocycleId, bool slotId})> {
  $$WeekTargetsTableTableManager(_$AppDatabase db, $WeekTargetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeekTargetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeekTargetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeekTargetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> mesocycleId = const Value.absent(),
            Value<int> weekIdx = const Value.absent(),
            Value<String> slotId = const Value.absent(),
            Value<int> sets = const Value.absent(),
            Value<int> reps = const Value.absent(),
            Value<int> rir = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WeekTargetsCompanion(
            mesocycleId: mesocycleId,
            weekIdx: weekIdx,
            slotId: slotId,
            sets: sets,
            reps: reps,
            rir: rir,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String mesocycleId,
            required int weekIdx,
            required String slotId,
            required int sets,
            required int reps,
            required int rir,
            Value<int> rowid = const Value.absent(),
          }) =>
              WeekTargetsCompanion.insert(
            mesocycleId: mesocycleId,
            weekIdx: weekIdx,
            slotId: slotId,
            sets: sets,
            reps: reps,
            rir: rir,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WeekTargetsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({mesocycleId = false, slotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mesocycleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mesocycleId,
                    referencedTable:
                        $$WeekTargetsTableReferences._mesocycleIdTable(db),
                    referencedColumn:
                        $$WeekTargetsTableReferences._mesocycleIdTable(db).id,
                  ) as T;
                }
                if (slotId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.slotId,
                    referencedTable:
                        $$WeekTargetsTableReferences._slotIdTable(db),
                    referencedColumn:
                        $$WeekTargetsTableReferences._slotIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WeekTargetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WeekTargetsTable,
    WeekTarget,
    $$WeekTargetsTableFilterComposer,
    $$WeekTargetsTableOrderingComposer,
    $$WeekTargetsTableAnnotationComposer,
    $$WeekTargetsTableCreateCompanionBuilder,
    $$WeekTargetsTableUpdateCompanionBuilder,
    (WeekTarget, $$WeekTargetsTableReferences),
    WeekTarget,
    PrefetchHooks Function({bool mesocycleId, bool slotId})>;
typedef $$ProgramDaysTableCreateCompanionBuilder = ProgramDaysCompanion
    Function({
  required String mesocycleId,
  required int dayIdx,
  Value<String?> label,
  Value<int> rowid,
});
typedef $$ProgramDaysTableUpdateCompanionBuilder = ProgramDaysCompanion
    Function({
  Value<String> mesocycleId,
  Value<int> dayIdx,
  Value<String?> label,
  Value<int> rowid,
});

final class $$ProgramDaysTableReferences
    extends BaseReferences<_$AppDatabase, $ProgramDaysTable, ProgramDay> {
  $$ProgramDaysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MesocyclesTable _mesocycleIdTable(_$AppDatabase db) =>
      db.mesocycles.createAlias(
          $_aliasNameGenerator(db.programDays.mesocycleId, db.mesocycles.id));

  $$MesocyclesTableProcessedTableManager get mesocycleId {
    final $_column = $_itemColumn<String>('mesocycle_id')!;

    final manager = $$MesocyclesTableTableManager($_db, $_db.mesocycles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mesocycleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ProgramDaysTableFilterComposer
    extends Composer<_$AppDatabase, $ProgramDaysTable> {
  $$ProgramDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get dayIdx => $composableBuilder(
      column: $table.dayIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  $$MesocyclesTableFilterComposer get mesocycleId {
    final $$MesocyclesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableFilterComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProgramDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgramDaysTable> {
  $$ProgramDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get dayIdx => $composableBuilder(
      column: $table.dayIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  $$MesocyclesTableOrderingComposer get mesocycleId {
    final $$MesocyclesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableOrderingComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProgramDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgramDaysTable> {
  $$ProgramDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get dayIdx =>
      $composableBuilder(column: $table.dayIdx, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  $$MesocyclesTableAnnotationComposer get mesocycleId {
    final $$MesocyclesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableAnnotationComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProgramDaysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProgramDaysTable,
    ProgramDay,
    $$ProgramDaysTableFilterComposer,
    $$ProgramDaysTableOrderingComposer,
    $$ProgramDaysTableAnnotationComposer,
    $$ProgramDaysTableCreateCompanionBuilder,
    $$ProgramDaysTableUpdateCompanionBuilder,
    (ProgramDay, $$ProgramDaysTableReferences),
    ProgramDay,
    PrefetchHooks Function({bool mesocycleId})> {
  $$ProgramDaysTableTableManager(_$AppDatabase db, $ProgramDaysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgramDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgramDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgramDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> mesocycleId = const Value.absent(),
            Value<int> dayIdx = const Value.absent(),
            Value<String?> label = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramDaysCompanion(
            mesocycleId: mesocycleId,
            dayIdx: dayIdx,
            label: label,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String mesocycleId,
            required int dayIdx,
            Value<String?> label = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProgramDaysCompanion.insert(
            mesocycleId: mesocycleId,
            dayIdx: dayIdx,
            label: label,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ProgramDaysTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({mesocycleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mesocycleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mesocycleId,
                    referencedTable:
                        $$ProgramDaysTableReferences._mesocycleIdTable(db),
                    referencedColumn:
                        $$ProgramDaysTableReferences._mesocycleIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ProgramDaysTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProgramDaysTable,
    ProgramDay,
    $$ProgramDaysTableFilterComposer,
    $$ProgramDaysTableOrderingComposer,
    $$ProgramDaysTableAnnotationComposer,
    $$ProgramDaysTableCreateCompanionBuilder,
    $$ProgramDaysTableUpdateCompanionBuilder,
    (ProgramDay, $$ProgramDaysTableReferences),
    ProgramDay,
    PrefetchHooks Function({bool mesocycleId})>;
typedef $$DayOverridesTableCreateCompanionBuilder = DayOverridesCompanion
    Function({
  required String mesocycleId,
  required int weekIdx,
  required int dayIdx,
  required String exerciseIdsCsv,
  Value<int> rowid,
});
typedef $$DayOverridesTableUpdateCompanionBuilder = DayOverridesCompanion
    Function({
  Value<String> mesocycleId,
  Value<int> weekIdx,
  Value<int> dayIdx,
  Value<String> exerciseIdsCsv,
  Value<int> rowid,
});

final class $$DayOverridesTableReferences
    extends BaseReferences<_$AppDatabase, $DayOverridesTable, DayOverride> {
  $$DayOverridesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MesocyclesTable _mesocycleIdTable(_$AppDatabase db) =>
      db.mesocycles.createAlias(
          $_aliasNameGenerator(db.dayOverrides.mesocycleId, db.mesocycles.id));

  $$MesocyclesTableProcessedTableManager get mesocycleId {
    final $_column = $_itemColumn<String>('mesocycle_id')!;

    final manager = $$MesocyclesTableTableManager($_db, $_db.mesocycles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mesocycleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$DayOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $DayOverridesTable> {
  $$DayOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get weekIdx => $composableBuilder(
      column: $table.weekIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayIdx => $composableBuilder(
      column: $table.dayIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exerciseIdsCsv => $composableBuilder(
      column: $table.exerciseIdsCsv,
      builder: (column) => ColumnFilters(column));

  $$MesocyclesTableFilterComposer get mesocycleId {
    final $$MesocyclesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableFilterComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DayOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $DayOverridesTable> {
  $$DayOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get weekIdx => $composableBuilder(
      column: $table.weekIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayIdx => $composableBuilder(
      column: $table.dayIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exerciseIdsCsv => $composableBuilder(
      column: $table.exerciseIdsCsv,
      builder: (column) => ColumnOrderings(column));

  $$MesocyclesTableOrderingComposer get mesocycleId {
    final $$MesocyclesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableOrderingComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DayOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayOverridesTable> {
  $$DayOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get weekIdx =>
      $composableBuilder(column: $table.weekIdx, builder: (column) => column);

  GeneratedColumn<int> get dayIdx =>
      $composableBuilder(column: $table.dayIdx, builder: (column) => column);

  GeneratedColumn<String> get exerciseIdsCsv => $composableBuilder(
      column: $table.exerciseIdsCsv, builder: (column) => column);

  $$MesocyclesTableAnnotationComposer get mesocycleId {
    final $$MesocyclesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableAnnotationComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$DayOverridesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DayOverridesTable,
    DayOverride,
    $$DayOverridesTableFilterComposer,
    $$DayOverridesTableOrderingComposer,
    $$DayOverridesTableAnnotationComposer,
    $$DayOverridesTableCreateCompanionBuilder,
    $$DayOverridesTableUpdateCompanionBuilder,
    (DayOverride, $$DayOverridesTableReferences),
    DayOverride,
    PrefetchHooks Function({bool mesocycleId})> {
  $$DayOverridesTableTableManager(_$AppDatabase db, $DayOverridesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayOverridesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayOverridesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayOverridesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> mesocycleId = const Value.absent(),
            Value<int> weekIdx = const Value.absent(),
            Value<int> dayIdx = const Value.absent(),
            Value<String> exerciseIdsCsv = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DayOverridesCompanion(
            mesocycleId: mesocycleId,
            weekIdx: weekIdx,
            dayIdx: dayIdx,
            exerciseIdsCsv: exerciseIdsCsv,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String mesocycleId,
            required int weekIdx,
            required int dayIdx,
            required String exerciseIdsCsv,
            Value<int> rowid = const Value.absent(),
          }) =>
              DayOverridesCompanion.insert(
            mesocycleId: mesocycleId,
            weekIdx: weekIdx,
            dayIdx: dayIdx,
            exerciseIdsCsv: exerciseIdsCsv,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$DayOverridesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({mesocycleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mesocycleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mesocycleId,
                    referencedTable:
                        $$DayOverridesTableReferences._mesocycleIdTable(db),
                    referencedColumn:
                        $$DayOverridesTableReferences._mesocycleIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$DayOverridesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DayOverridesTable,
    DayOverride,
    $$DayOverridesTableFilterComposer,
    $$DayOverridesTableOrderingComposer,
    $$DayOverridesTableAnnotationComposer,
    $$DayOverridesTableCreateCompanionBuilder,
    $$DayOverridesTableUpdateCompanionBuilder,
    (DayOverride, $$DayOverridesTableReferences),
    DayOverride,
    PrefetchHooks Function({bool mesocycleId})>;
typedef $$SessionLogsTableCreateCompanionBuilder = SessionLogsCompanion
    Function({
  required String id,
  required String mesocycleId,
  required int weekIdx,
  required int dayIdx,
  Value<DateTime?> startedAt,
  Value<int> rowid,
});
typedef $$SessionLogsTableUpdateCompanionBuilder = SessionLogsCompanion
    Function({
  Value<String> id,
  Value<String> mesocycleId,
  Value<int> weekIdx,
  Value<int> dayIdx,
  Value<DateTime?> startedAt,
  Value<int> rowid,
});

final class $$SessionLogsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionLogsTable, SessionLog> {
  $$SessionLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MesocyclesTable _mesocycleIdTable(_$AppDatabase db) =>
      db.mesocycles.createAlias(
          $_aliasNameGenerator(db.sessionLogs.mesocycleId, db.mesocycles.id));

  $$MesocyclesTableProcessedTableManager get mesocycleId {
    final $_column = $_itemColumn<String>('mesocycle_id')!;

    final manager = $$MesocyclesTableTableManager($_db, $_db.mesocycles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mesocycleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$SetEntriesTable, List<SetEntry>>
      _setEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.setEntries,
          aliasName:
              $_aliasNameGenerator(db.sessionLogs.id, db.setEntries.sessionId));

  $$SetEntriesTableProcessedTableManager get setEntriesRefs {
    final manager = $$SetEntriesTableTableManager($_db, $_db.setEntries)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setEntriesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weekIdx => $composableBuilder(
      column: $table.weekIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayIdx => $composableBuilder(
      column: $table.dayIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  $$MesocyclesTableFilterComposer get mesocycleId {
    final $$MesocyclesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableFilterComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> setEntriesRefs(
      Expression<bool> Function($$SetEntriesTableFilterComposer f) f) {
    final $$SetEntriesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.setEntries,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SetEntriesTableFilterComposer(
              $db: $db,
              $table: $db.setEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weekIdx => $composableBuilder(
      column: $table.weekIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayIdx => $composableBuilder(
      column: $table.dayIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  $$MesocyclesTableOrderingComposer get mesocycleId {
    final $$MesocyclesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableOrderingComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionLogsTable> {
  $$SessionLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get weekIdx =>
      $composableBuilder(column: $table.weekIdx, builder: (column) => column);

  GeneratedColumn<int> get dayIdx =>
      $composableBuilder(column: $table.dayIdx, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  $$MesocyclesTableAnnotationComposer get mesocycleId {
    final $$MesocyclesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mesocycleId,
        referencedTable: $db.mesocycles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MesocyclesTableAnnotationComposer(
              $db: $db,
              $table: $db.mesocycles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> setEntriesRefs<T extends Object>(
      Expression<T> Function($$SetEntriesTableAnnotationComposer a) f) {
    final $$SetEntriesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.setEntries,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SetEntriesTableAnnotationComposer(
              $db: $db,
              $table: $db.setEntries,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionLogsTable,
    SessionLog,
    $$SessionLogsTableFilterComposer,
    $$SessionLogsTableOrderingComposer,
    $$SessionLogsTableAnnotationComposer,
    $$SessionLogsTableCreateCompanionBuilder,
    $$SessionLogsTableUpdateCompanionBuilder,
    (SessionLog, $$SessionLogsTableReferences),
    SessionLog,
    PrefetchHooks Function({bool mesocycleId, bool setEntriesRefs})> {
  $$SessionLogsTableTableManager(_$AppDatabase db, $SessionLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> mesocycleId = const Value.absent(),
            Value<int> weekIdx = const Value.absent(),
            Value<int> dayIdx = const Value.absent(),
            Value<DateTime?> startedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionLogsCompanion(
            id: id,
            mesocycleId: mesocycleId,
            weekIdx: weekIdx,
            dayIdx: dayIdx,
            startedAt: startedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String mesocycleId,
            required int weekIdx,
            required int dayIdx,
            Value<DateTime?> startedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionLogsCompanion.insert(
            id: id,
            mesocycleId: mesocycleId,
            weekIdx: weekIdx,
            dayIdx: dayIdx,
            startedAt: startedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SessionLogsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {mesocycleId = false, setEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (setEntriesRefs) db.setEntries],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mesocycleId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mesocycleId,
                    referencedTable:
                        $$SessionLogsTableReferences._mesocycleIdTable(db),
                    referencedColumn:
                        $$SessionLogsTableReferences._mesocycleIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (setEntriesRefs)
                    await $_getPrefetchedData<SessionLog, $SessionLogsTable,
                            SetEntry>(
                        currentTable: table,
                        referencedTable: $$SessionLogsTableReferences
                            ._setEntriesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionLogsTableReferences(db, table, p0)
                                .setEntriesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SessionLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionLogsTable,
    SessionLog,
    $$SessionLogsTableFilterComposer,
    $$SessionLogsTableOrderingComposer,
    $$SessionLogsTableAnnotationComposer,
    $$SessionLogsTableCreateCompanionBuilder,
    $$SessionLogsTableUpdateCompanionBuilder,
    (SessionLog, $$SessionLogsTableReferences),
    SessionLog,
    PrefetchHooks Function({bool mesocycleId, bool setEntriesRefs})>;
typedef $$SetEntriesTableCreateCompanionBuilder = SetEntriesCompanion Function({
  required String id,
  required String sessionId,
  required String exerciseId,
  Value<String?> slotId,
  required int setIndex,
  Value<double?> weight,
  Value<int?> reps,
  Value<int?> rir,
  Value<bool> done,
  Value<DateTime?> loggedAt,
  Value<int> rowid,
});
typedef $$SetEntriesTableUpdateCompanionBuilder = SetEntriesCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> exerciseId,
  Value<String?> slotId,
  Value<int> setIndex,
  Value<double?> weight,
  Value<int?> reps,
  Value<int?> rir,
  Value<bool> done,
  Value<DateTime?> loggedAt,
  Value<int> rowid,
});

final class $$SetEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $SetEntriesTable, SetEntry> {
  $$SetEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionLogsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionLogs.createAlias(
          $_aliasNameGenerator(db.setEntries.sessionId, db.sessionLogs.id));

  $$SessionLogsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionLogsTableTableManager($_db, $_db.sessionLogs)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias(
          $_aliasNameGenerator(db.setEntries.exerciseId, db.exercises.id));

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $$ExercisesTableTableManager($_db, $_db.exercises)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ExerciseSlotsTable _slotIdTable(_$AppDatabase db) =>
      db.exerciseSlots.createAlias(
          $_aliasNameGenerator(db.setEntries.slotId, db.exerciseSlots.id));

  $$ExerciseSlotsTableProcessedTableManager? get slotId {
    final $_column = $_itemColumn<String>('slot_id');
    if ($_column == null) return null;
    final manager = $$ExerciseSlotsTableTableManager($_db, $_db.exerciseSlots)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SetEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get setIndex => $composableBuilder(
      column: $table.setIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rir => $composableBuilder(
      column: $table.rir, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get done => $composableBuilder(
      column: $table.done, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnFilters(column));

  $$SessionLogsTableFilterComposer get sessionId {
    final $$SessionLogsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionLogs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionLogsTableFilterComposer(
              $db: $db,
              $table: $db.sessionLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $db.exercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExercisesTableFilterComposer(
              $db: $db,
              $table: $db.exercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExerciseSlotsTableFilterComposer get slotId {
    final $$ExerciseSlotsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableFilterComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SetEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get setIndex => $composableBuilder(
      column: $table.setIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rir => $composableBuilder(
      column: $table.rir, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get done => $composableBuilder(
      column: $table.done, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnOrderings(column));

  $$SessionLogsTableOrderingComposer get sessionId {
    final $$SessionLogsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionLogs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionLogsTableOrderingComposer(
              $db: $db,
              $table: $db.sessionLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $db.exercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExercisesTableOrderingComposer(
              $db: $db,
              $table: $db.exercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExerciseSlotsTableOrderingComposer get slotId {
    final $$ExerciseSlotsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableOrderingComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SetEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetEntriesTable> {
  $$SetEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get setIndex =>
      $composableBuilder(column: $table.setIndex, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get rir =>
      $composableBuilder(column: $table.rir, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  $$SessionLogsTableAnnotationComposer get sessionId {
    final $$SessionLogsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessionLogs,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionLogsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.exerciseId,
        referencedTable: $db.exercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExercisesTableAnnotationComposer(
              $db: $db,
              $table: $db.exercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ExerciseSlotsTableAnnotationComposer get slotId {
    final $$ExerciseSlotsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.exerciseSlots,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExerciseSlotsTableAnnotationComposer(
              $db: $db,
              $table: $db.exerciseSlots,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SetEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SetEntriesTable,
    SetEntry,
    $$SetEntriesTableFilterComposer,
    $$SetEntriesTableOrderingComposer,
    $$SetEntriesTableAnnotationComposer,
    $$SetEntriesTableCreateCompanionBuilder,
    $$SetEntriesTableUpdateCompanionBuilder,
    (SetEntry, $$SetEntriesTableReferences),
    SetEntry,
    PrefetchHooks Function({bool sessionId, bool exerciseId, bool slotId})> {
  $$SetEntriesTableTableManager(_$AppDatabase db, $SetEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> exerciseId = const Value.absent(),
            Value<String?> slotId = const Value.absent(),
            Value<int> setIndex = const Value.absent(),
            Value<double?> weight = const Value.absent(),
            Value<int?> reps = const Value.absent(),
            Value<int?> rir = const Value.absent(),
            Value<bool> done = const Value.absent(),
            Value<DateTime?> loggedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SetEntriesCompanion(
            id: id,
            sessionId: sessionId,
            exerciseId: exerciseId,
            slotId: slotId,
            setIndex: setIndex,
            weight: weight,
            reps: reps,
            rir: rir,
            done: done,
            loggedAt: loggedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String exerciseId,
            Value<String?> slotId = const Value.absent(),
            required int setIndex,
            Value<double?> weight = const Value.absent(),
            Value<int?> reps = const Value.absent(),
            Value<int?> rir = const Value.absent(),
            Value<bool> done = const Value.absent(),
            Value<DateTime?> loggedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SetEntriesCompanion.insert(
            id: id,
            sessionId: sessionId,
            exerciseId: exerciseId,
            slotId: slotId,
            setIndex: setIndex,
            weight: weight,
            reps: reps,
            rir: rir,
            done: done,
            loggedAt: loggedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SetEntriesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {sessionId = false, exerciseId = false, slotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$SetEntriesTableReferences._sessionIdTable(db),
                    referencedColumn:
                        $$SetEntriesTableReferences._sessionIdTable(db).id,
                  ) as T;
                }
                if (exerciseId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.exerciseId,
                    referencedTable:
                        $$SetEntriesTableReferences._exerciseIdTable(db),
                    referencedColumn:
                        $$SetEntriesTableReferences._exerciseIdTable(db).id,
                  ) as T;
                }
                if (slotId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.slotId,
                    referencedTable:
                        $$SetEntriesTableReferences._slotIdTable(db),
                    referencedColumn:
                        $$SetEntriesTableReferences._slotIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SetEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SetEntriesTable,
    SetEntry,
    $$SetEntriesTableFilterComposer,
    $$SetEntriesTableOrderingComposer,
    $$SetEntriesTableAnnotationComposer,
    $$SetEntriesTableCreateCompanionBuilder,
    $$SetEntriesTableUpdateCompanionBuilder,
    (SetEntry, $$SetEntriesTableReferences),
    SetEntry,
    PrefetchHooks Function({bool sessionId, bool exerciseId, bool slotId})>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MesocyclesTableTableManager get mesocycles =>
      $$MesocyclesTableTableManager(_db, _db.mesocycles);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$ExerciseSlotsTableTableManager get exerciseSlots =>
      $$ExerciseSlotsTableTableManager(_db, _db.exerciseSlots);
  $$WeekTargetsTableTableManager get weekTargets =>
      $$WeekTargetsTableTableManager(_db, _db.weekTargets);
  $$ProgramDaysTableTableManager get programDays =>
      $$ProgramDaysTableTableManager(_db, _db.programDays);
  $$DayOverridesTableTableManager get dayOverrides =>
      $$DayOverridesTableTableManager(_db, _db.dayOverrides);
  $$SessionLogsTableTableManager get sessionLogs =>
      $$SessionLogsTableTableManager(_db, _db.sessionLogs);
  $$SetEntriesTableTableManager get setEntries =>
      $$SetEntriesTableTableManager(_db, _db.setEntries);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}

class MesoImportData {
  String name;
  int numWeeks;
  final List<ImportPhase> phases;
  final List<ImportDay> days;
  final List<String> skippedDayLabels;

  MesoImportData({
    required this.name,
    required this.numWeeks,
    required this.phases,
    required this.days,
    this.skippedDayLabels = const [],
  });

  factory MesoImportData.fromJson(Map<String, dynamic> json) {
    return MesoImportData(
      name: (json['name'] as String?)?.trim().isEmpty == true
          ? 'Imported Block'
          : ((json['name'] as String?) ?? 'Imported Block'),
      numWeeks: (json['numWeeks'] as int?) ?? 4,
      phases: (json['phases'] as List<dynamic>? ?? [])
          .map((p) => ImportPhase.fromJson(p as Map<String, dynamic>))
          .toList(),
      days: (json['days'] as List<dynamic>? ?? [])
          .map((d) => ImportDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'numWeeks': numWeeks,
        'phases': phases.map((p) => p.toJson()).toList(),
        'days': days.map((d) => d.toJson()).toList(),
      };
}

class ImportPhase {
  final String name;
  final int startWeekIdx;
  final int endWeekIdx;

  const ImportPhase({
    required this.name,
    required this.startWeekIdx,
    required this.endWeekIdx,
  });

  factory ImportPhase.fromJson(Map<String, dynamic> json) {
    return ImportPhase(
      name: (json['name'] as String?) ?? 'Phase',
      startWeekIdx: (json['startWeekIdx'] as int?) ?? 0,
      endWeekIdx: (json['endWeekIdx'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'startWeekIdx': startWeekIdx,
        'endWeekIdx': endWeekIdx,
      };
}

class ImportDay {
  int dayIdx;
  String label;
  final Map<int, String> weekLabels;
  final List<ImportExercise> exercises;

  ImportDay({
    required this.dayIdx,
    required this.label,
    required this.exercises,
    this.weekLabels = const {},
  });

  String labelForWeek(int weekIdx) => weekLabels[weekIdx] ?? label;

  factory ImportDay.fromJson(Map<String, dynamic> json) {
    return ImportDay(
      dayIdx: (json['dayIdx'] as int?) ?? 0,
      label: (json['label'] as String?) ?? '',
      weekLabels: (json['weekLabels'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(int.parse(k), v as String),
      ),
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => ImportExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dayIdx': dayIdx,
        'label': label,
        'weekLabels': weekLabels.map((k, v) => MapEntry(k.toString(), v)),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

class ImportExercise {
  String name;
  String muscleGroup;
  final List<ImportWeekTarget> weekTargets;
  bool isExistingInDb;

  ImportExercise({
    required this.name,
    required this.muscleGroup,
    required this.weekTargets,
    this.isExistingInDb = false,
  });

  factory ImportExercise.fromJson(Map<String, dynamic> json) {
    final rawTargets = json['weekTargets'] as List<dynamic>?;
    final List<ImportWeekTarget> weekTargets;

    if (rawTargets != null && rawTargets.isNotEmpty) {
      weekTargets = rawTargets
          .map((t) => ImportWeekTarget.fromJson(t as Map<String, dynamic>))
          .toList();
    } else {
      final sets = (json['sets'] as int?) ?? 3;
      weekTargets = [
        ImportWeekTarget(
          weekIdx: 0,
          reps: List.filled(sets, (json['reps'] as int?) ?? 8),
          rir: List.filled(sets, (json['rir'] as int?) ?? 2),
        ),
      ];
    }

    return ImportExercise(
      name: (json['name'] as String?) ?? 'Unknown',
      muscleGroup: (json['group'] as String?) ?? (json['muscleGroup'] as String?) ?? 'other',
      weekTargets: weekTargets,
    );
  }

  ImportWeekTarget? targetForWeek(int weekIdx) {
    for (final t in weekTargets) {
      if (t.weekIdx == weekIdx) return t;
    }
    return null;
  }

  void setWeekTarget(ImportWeekTarget t) {
    final idx = weekTargets.indexWhere((e) => e.weekIdx == t.weekIdx);
    if (idx >= 0) {
      weekTargets[idx] = t;
    } else {
      weekTargets.add(t);
      weekTargets.sort((a, b) => a.weekIdx.compareTo(b.weekIdx));
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'muscleGroup': muscleGroup,
        'weekTargets': weekTargets.map((t) => t.toJson()).toList(),
      };
}

class ImportWeekTarget {
  final int weekIdx;
  final List<int> reps;
  final List<int> rir;

  const ImportWeekTarget({
    required this.weekIdx,
    required this.reps,
    required this.rir,
  });

  factory ImportWeekTarget.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('sets')) {
      final sets = json['sets'] as int;
      return ImportWeekTarget(
        weekIdx: (json['weekIdx'] as int?) ?? 0,
        reps: List.filled(sets, (json['reps'] as int?) ?? 8),
        rir: List.filled(sets, (json['rir'] as int?) ?? 2),
      );
    }
    return ImportWeekTarget(
      weekIdx: (json['weekIdx'] as num?)?.toInt() ?? 0,
      reps: (json['reps'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ??
          [8, 8, 8],
      rir: (json['rir'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ??
          [2, 2, 2],
    );
  }

  Map<String, dynamic> toJson() => {
        'weekIdx': weekIdx,
        'reps': reps,
        'rir': rir,
      };
}

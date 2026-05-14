class RawDaySegment {
  final int weekIdx;
  final int dayIdx;
  final String label;
  final String csvLines;

  const RawDaySegment({
    required this.weekIdx,
    required this.dayIdx,
    required this.label,
    required this.csvLines,
  });
}

class CsvSegmenter {
  static final _weekHeader = RegExp(r'^\s*Week\s*\d+', caseSensitive: false);
  static final _dayHeader = RegExp(
    r'^(DAY\s*\d+|REST\s*DAY|UPPER|LOWER|FULL\s*BODY|PUSH|PULL|LEGS)',
    caseSensitive: false,
  );

  static List<RawDaySegment> segment(String csv) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final headerLine = lines.first;
    final headerCells = _splitCsvLine(headerLine);

    // Look for structural columns typical of flat CSVs
    final weekColIdx = headerCells.indexWhere(
        (c) => c.trim().toLowerCase() == 'week' || c.trim().toLowerCase() == 'wk');
    final workoutColIdx = headerCells.indexWhere((c) =>
        c.trim().toLowerCase() == 'workout' ||
        c.trim().toLowerCase() == 'day' ||
        c.trim().toLowerCase() == 'training day');

    if (weekColIdx >= 0 && workoutColIdx >= 0) {
      return _segmentFlat(lines, weekColIdx, workoutColIdx);
    }

    return _segmentVertical(lines);
  }

  static List<RawDaySegment> _segmentFlat(
      List<String> lines, int weekColIdx, int workoutColIdx) {
    final segments = <RawDaySegment>[];
    if (lines.length < 2) return [];

    final headerLine = lines.first;
    final headerCells = _splitCsvLine(headerLine);
    final phaseColIdx = headerCells
        .indexWhere((c) => c.trim().toLowerCase().contains('phase'));

    String? currentKey;
    final currentLines = <String>[];
    int weekCounter = -1;
    int dayCounter = -1;
    String? lastWeekVal;
    String? lastWorkoutVal;

    final weekMap = <String, int>{};
    final dayMap = <String, int>{};

    void flush() {
      if (currentKey != null && currentLines.isNotEmpty) {
        // Prepend header so LLM knows column meanings
        final csvWithHeader = [headerLine, ...currentLines].join('\n');

        // Extract label from the lastWorkoutVal
        final label = lastWorkoutVal ?? '';

        segments.add(RawDaySegment(
          weekIdx: weekMap[lastWeekVal!] ?? 0,
          dayIdx: dayMap[currentKey!] ?? 0,
          label: label,
          csvLines: csvWithHeader,
        ));
      }
      currentLines.clear();
    }

    // Skip header
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      final cells = _splitCsvLine(line);
      if (cells.length <= weekColIdx || cells.length <= workoutColIdx) continue;

      final phaseVal = phaseColIdx >= 0 && cells.length > phaseColIdx
          ? cells[phaseColIdx].trim()
          : '';
      final weekVal = cells[weekColIdx].trim();
      final workoutVal = cells[workoutColIdx].trim();

      if (weekVal.isEmpty && workoutVal.isEmpty) continue;

      final key = '$phaseVal|$weekVal|$workoutVal';

      if (key != currentKey) {
        flush();

        if (weekVal != lastWeekVal) {
          weekCounter++;
          weekMap[weekVal] = weekCounter;
          dayCounter = -1;
        }

        if (key != currentKey) {
          dayCounter++;
          dayMap[key] = dayCounter;
        }

        currentKey = key;
        lastWeekVal = weekVal;
        lastWorkoutVal = workoutVal;
      }

      currentLines.add(line);
    }

    flush();
    return segments;
  }

  static List<RawDaySegment> _segmentVertical(List<String> lines) {
    final segments = <RawDaySegment>[];
    int weekIdx = -1;
    int dayIdx = -1;
    String dayLabel = '';
    final currentLines = <String>[];
    bool foundAnyMarker = false;

    void flushSegment() {
      if (dayIdx >= 0 && currentLines.isNotEmpty) {
        segments.add(RawDaySegment(
          weekIdx: weekIdx < 0 ? 0 : weekIdx,
          dayIdx: dayIdx,
          label: dayLabel,
          csvLines: currentLines.join('\n'),
        ));
      }
      currentLines.clear();
    }

    for (final line in lines) {
      final firstCell = line.split(',').first.trim();

      if (_weekHeader.hasMatch(firstCell)) {
        flushSegment();
        weekIdx++;
        dayIdx = -1;
        foundAnyMarker = true;
        continue;
      }

      if (_dayHeader.hasMatch(firstCell)) {
        flushSegment();
        dayIdx++;
        dayLabel = firstCell;
        foundAnyMarker = true;
        currentLines.add(line);
        continue;
      }

      if (dayIdx >= 0) {
        currentLines.add(line);
      }
    }

    flushSegment();

    if (!foundAnyMarker || segments.isEmpty) {
      return [
        RawDaySegment(
            weekIdx: 0, dayIdx: 0, label: '', csvLines: lines.join('\n')),
      ];
    }

    return segments;
  }

  static List<String> _splitCsvLine(String line) {
    // Quote-aware split
    final regex = RegExp(r',(?=(?:[^"]*"[^"]*")*[^"]*$)');
    return line.split(regex);
  }
}

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
    final lines = csv.split('\n');
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
        // Include the header line in the segment so the LLM sees the day label
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
        RawDaySegment(weekIdx: 0, dayIdx: 0, label: '', csvLines: csv),
      ];
    }

    return segments;
  }
}

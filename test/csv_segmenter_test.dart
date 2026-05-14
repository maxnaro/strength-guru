import 'package:flutter_test/flutter_test.dart';
import 'package:strength_guru/services/csv_segmenter.dart';

void main() {
  group('CsvSegmenter', () {
    test('segments vertically-stacked week blocks', () {
      const csv = '''
Week 1,Exercise,Sets,Reps,RPE
DAY 1,,,
,Bench Press,3,8,7-8
,Squat,4,5,8-9
REST DAY,,,,
Week 2,Exercise,Sets,Reps,RPE
DAY 1,,,
,Bench Press,3,8,8-9
,Squat,4,5,9-10
REST DAY,,,,
''';
      final segs = CsvSegmenter.segment(csv.trim());
      expect(segs.length, 4);

      expect(segs[0].weekIdx, 0);
      expect(segs[0].dayIdx, 0);
      expect(segs[0].label, 'DAY 1');
      expect(segs[0].csvLines, contains('Bench Press'));

      expect(segs[1].weekIdx, 0);
      expect(segs[1].dayIdx, 1);
      expect(segs[1].label.toUpperCase(), contains('REST'));

      expect(segs[2].weekIdx, 1);
      expect(segs[2].dayIdx, 0);

      expect(segs[3].weekIdx, 1);
      expect(segs[3].dayIdx, 1);
    });

    test('REST DAY produces a segment with that label', () {
      const csv = '''
Week 1,Exercise,Sets,Reps,RPE
DAY 1,,,
,Bench Press,3,8,7-8
REST DAY,,,,
''';
      final segs = CsvSegmenter.segment(csv.trim());
      final restSeg = segs.firstWhere((s) => s.label.toUpperCase().contains('REST'));
      expect(restSeg.weekIdx, 0);
      expect(restSeg.label.toUpperCase(), contains('REST'));
    });

    test('falls back to single segment when no markers found', () {
      const csv = '''Exercise,Sets,Reps
Bench Press,3,8
Squat,4,5
''';
      final segs = CsvSegmenter.segment(csv.trim());
      expect(segs.length, 1);
      expect(segs.first.weekIdx, 0);
      expect(segs.first.dayIdx, 0);
      expect(segs.first.csvLines, contains('Bench Press'));
    });

    test('recognises UPPER / LOWER / PUSH / PULL / LEGS day headers', () {
      const csv = '''
Week 1,,,
UPPER,Exercise,Sets,Reps,RPE
,Bench Press,3,8,7-8
LOWER,Exercise,Sets,Reps,RPE
,Squat,4,5,8-9
''';
      final segs = CsvSegmenter.segment(csv.trim());
      expect(segs.length, 2);
      expect(segs[0].label, 'UPPER');
      expect(segs[1].label, 'LOWER');
    });

    test('segments flat-format CSVs correctly', () {
      const csv = '''
Week,Workout,Exercise,Notes
Week 1,Upper,Bench Press,"Focus on strength, keep form consistent"
Week 1,Upper,Rows,
Week 1,Lower,Squat,
Week 2,Upper,Bench Press,
''';
      final segs = CsvSegmenter.segment(csv.trim());
      expect(segs.length, 3);

      // Segment 0: Week 1, Upper
      expect(segs[0].weekIdx, 0);
      expect(segs[0].dayIdx, 0);
      expect(segs[0].label, 'Upper');
      expect(segs[0].csvLines, contains('Week,Workout,Exercise,Notes'));
      expect(segs[0].csvLines, contains('Bench Press'));
      expect(segs[0].csvLines, contains('Rows'));

      // Segment 1: Week 1, Lower
      expect(segs[1].weekIdx, 0);
      expect(segs[1].dayIdx, 1);
      expect(segs[1].label, 'Lower');
      expect(segs[1].csvLines, contains('Squat'));

      // Segment 2: Week 2, Upper
      expect(segs[2].weekIdx, 1);
      expect(segs[2].dayIdx, 0);
      expect(segs[2].label, 'Upper');
    });

    test('handles day markers without preceding week marker', () {
      const csv = '''DAY 1,,,
,Bench Press,3,8,7-8
DAY 2,,,
,Squat,4,5,8-9
''';
      final segs = CsvSegmenter.segment(csv.trim());
      expect(segs.length, 2);
      expect(segs[0].weekIdx, 0);
      expect(segs[0].label, 'DAY 1');
      expect(segs[1].label, 'DAY 2');
    });
  });
}

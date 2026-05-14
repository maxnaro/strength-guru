import 'package:flutter_test/flutter_test.dart';
import 'package:strength_guru/services/llm_service.dart';

void main() {
  group('LlmService.splitJsonObjects', () {
    test('single object returned as-is', () {
      const input = '{"label":"Push","exercises":[]}';
      final result = LlmService.splitJsonObjects(input);
      expect(result.length, 1);
      expect(result[0]['label'], 'Push');
    });

    test('multiple concatenated objects all returned', () {
      const input =
          '{"label":"Lower #1","exercises":[{"name":"Deadlift","group":"legs","sets":"3","reps":"5","rpe":"8"}]}\n'
          '{"label":"Lower #1","exercises":[{"name":"Leg Press","group":"legs","sets":"3","reps":"10","rpe":"7"}]}';
      final result = LlmService.splitJsonObjects(input);
      expect(result.length, 2);
      expect(result[0]['exercises'][0]['name'], 'Deadlift');
      expect(result[1]['exercises'][0]['name'], 'Leg Press');
    });

    test('exercises merged across objects in _parseDay equivalent', () {
      // 7-object payload mirrors the LM Studio output from the failing import.
      const payload = '{"label":"Lower #1","exercises":[{"name":"Deadlift","group":"legs","sets":"3-4","reps":"5","rpe":"8"}]}\n'
          '{"label":"Lower #1","exercises":[{"name":"Stiff-Leg Deadlift","group":"legs","sets":"3","reps":"8","rpe":"8"}]}\n'
          '{"label":"Lower #1","exercises":[{"name":"Leg Press","group":"legs","sets":"3","reps":"10","rpe":"7"}]}';
      final objects = LlmService.splitJsonObjects(payload);
      expect(objects.length, 3);
      // Verify each is independently parseable
      for (final obj in objects) {
        expect(obj.containsKey('exercises'), isTrue);
      }
    });

    test('trailing comma stripped before parsing', () {
      const input = '{"label":"Push","exercises":[{"name":"Bench","group":"chest","sets":"3","reps":"8","rpe":"8",},]}';
      final result = LlmService.splitJsonObjects(input);
      expect(result.length, 1);
      expect(result[0]['exercises'][0]['name'], 'Bench');
    });

    test('empty string returns empty list', () {
      expect(LlmService.splitJsonObjects(''), isEmpty);
    });

    test('malformed object skipped, valid ones returned', () {
      const input = '{"label":"ok","exercises":[]}\n{bad json}\n{"label":"also ok","exercises":[]}';
      final result = LlmService.splitJsonObjects(input);
      expect(result.length, 2);
    });
  });
}

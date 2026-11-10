import 'dart:async';
import 'package:strength_guru_core/services/llm_service.dart' as core;
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/sync/storage.dart';
import '../models/meso_import_data.dart';
import '../models/plan_advisory.dart';
import 'api.dart';
export 'package:strength_guru_core/services/llm_service.dart' show LlmException;

class LlmService {
  static const defaultUrl = '/api/v1';
  static AppDatabase? database;
  static List<Map<String, dynamic>> splitJsonObjects(String text) =>
      core.LlmService.splitJsonObjects(text);
  static MesoImportData mergeFixedDaysForTest(
    MesoImportData original,
    MesoImportData fixed,
  ) => core.LlmService.mergeFixedDaysForTest(original, fixed);

  Future<MesoImportData> interpretPlan(
    String csvContent, {
    String? apiUrl,
    void Function(int, int)? onProgress,
  }) => _start('csv', {'csv': csvContent}, onProgress: onProgress);
  Future<MesoImportData> interpretDescription(
    String description,
    int numWeeks, {
    required String apiUrl,
    String experienceLevel = 'intermediate',
    String goal = 'mix',
    int? trainingDays,
    String sportContext = '',
    List<({String name, String group})> exerciseLibrary = const [],
    MesoImportData? priorMeso,
    String basisMode = 'inspiration',
    void Function(int, int)? onProgress,
    void Function(String)? onReasoning,
  }) => _start(
    'generate',
    {
      'description': description,
      'numWeeks': numWeeks,
      'experienceLevel': experienceLevel,
      'goal': goal,
      'trainingDays': trainingDays,
      'sportContext': sportContext,
      'exerciseLibrary': [
        for (final e in exerciseLibrary) {'name': e.name, 'group': e.group},
      ],
      'priorMeso': priorMeso?.toJson(),
      'basisMode': basisMode,
    },
    onProgress: onProgress,
    onReasoning: onReasoning,
  );
  Future<MesoImportData> fixPlanAdvisories(
    MesoImportData data,
    List<PlanAdvisory> advisories, {
    required String apiUrl,
    String experienceLevel = 'intermediate',
    String goal = 'mix',
    String sportContext = '',
    String description = '',
    List<({String name, String group})> exerciseLibrary = const [],
    void Function(String)? onReasoning,
  }) => _start('fix', {
    'data': data.toJson(),
    'advisories': [
      for (final a in advisories)
        {'severity': a.severity.name, 'scope': a.scope, 'message': a.message},
    ],
    'experienceLevel': experienceLevel,
    'goal': goal,
    'sportContext': sportContext,
    'description': description,
    'exerciseLibrary': [
      for (final e in exerciseLibrary) {'name': e.name, 'group': e.group},
    ],
  }, onReasoning: onReasoning);

  Future<MesoImportData> _start(
    String kind,
    Map<String, dynamic> input, {
    void Function(int, int)? onProgress,
    void Function(String)? onReasoning,
  }) async {
    final job = await appApi.json(
      'POST',
      'jobs',
      body: {'kind': kind, 'input': input},
    );
    final db = database;
    if (db != null) {
      final ids = (await readMeta(db, 'ai_jobs') ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList();
      ids.insert(0, job['id'] as String);
      await writeMeta(db, 'ai_jobs', ids.take(30).join(','));
    }
    return resumeJob(
      job['id'] as String,
      onProgress: onProgress,
      onReasoning: onReasoning,
    );
  }

  Future<MesoImportData> resumeJob(
    String id, {
    void Function(int, int)? onProgress,
    void Function(String)? onReasoning,
  }) async {
    String? lastStatus;
    while (true) {
      final job = await appApi.json('GET', 'jobs/$id');
      final status = job['progress'] as String;
      if (status != lastStatus) {
        onReasoning?.call('$status\n');
        final match = RegExp(r'(\d+)/(\d+)').firstMatch(status);
        if (match != null)
          onProgress?.call(int.parse(match[1]!), int.parse(match[2]!));
        lastStatus = status;
      }
      if (job['state'] == 'complete') {
        final raw = Map<String, dynamic>.from(job['result'] as Map);
        final plan = MesoImportData.fromJson(raw);
        plan.advisories.addAll(
          (raw['advisories'] as List? ?? []).map(
            (v) => PlanAdvisory(
              severity: AdvisorySeverity.values.byName(v['severity'] as String),
              scope: v['scope'] as String,
              message: v['message'] as String,
              source: v['source'] as String?,
            ),
          ),
        );
        return plan;
      }
      if (job['state'] == 'failed' || job['state'] == 'cancelled')
        throw core.LlmException(job['error'] as String? ?? 'AI job cancelled.');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}

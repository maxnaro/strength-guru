import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/models/meso_import_data.dart';
import 'package:strength_guru_core/models/plan_advisory.dart';
import 'package:strength_guru_core/services/llm_service.dart';
import 'package:strength_guru_core/sync/protocol.dart';
import 'package:uuid/uuid.dart';

class Jobs {
  final AppDatabase db;
  final String baseUrl;
  final String model;
  bool _running = false;
  bool _closed = false;
  Timer? _timer;
  String? _activeId;
  http.Client? _activeClient;
  Jobs(this.db, this.baseUrl, this.model);

  Future<void> start() async {
    await db.customStatement(
      "UPDATE sg_jobs SET state = 'queued' WHERE state = 'running'",
    );
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_drain()),
    );
    unawaited(_drain());
  }

  Future<bool> available() async {
    try {
      return (await http
                  .get(Uri.parse('$baseUrl/health'))
                  .timeout(const Duration(seconds: 2)))
              .statusCode ==
          200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final kind = body['kind'];
    if (!['csv', 'generate', 'fix'].contains(kind))
      throw const ProtocolException(
        'invalid_job',
        'Choose CSV import, generation or advisory fixes.',
      );
    if (!await available())
      throw const ProtocolException(
        'ai_unavailable',
        'AI is unavailable. Workout logging still works.',
        503,
      );
    final input = body['input'];
    if (input is! Map<String, dynamic>)
      throw const ProtocolException(
        'invalid_job',
        'AI job input must be an object.',
      );
    if (kind == 'csv' &&
        (input['csv'] is! String || (input['csv'] as String).trim().isEmpty))
      throw const ProtocolException(
        'invalid_job',
        'Choose a non-empty CSV file.',
      );
    if (kind == 'generate' &&
        (input['description'] is! String ||
            (input['description'] as String).trim().isEmpty ||
            input['numWeeks'] is! int ||
            (input['numWeeks'] as int) < 1 ||
            (input['numWeeks'] as int) > 104))
      throw const ProtocolException(
        'invalid_job',
        'Provide a description and 1–104 training weeks.',
      );
    if (kind == 'fix' &&
        (input['data'] is! Map || input['advisories'] is! List))
      throw const ProtocolException(
        'invalid_job',
        'Provide a plan and its advisories.',
      );
    final id = const Uuid().v4();
    await db.customStatement(
      'INSERT INTO sg_jobs (id, kind, request, state, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        id,
        kind,
        jsonEncode(body['input']),
        'queued',
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    unawaited(_drain());
    return get(id);
  }

  Future<Map<String, dynamic>> get(String id) async {
    final row = await db
        .customSelect(
          'SELECT id, kind, state, progress, result, error, created_at FROM sg_jobs WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    if (row == null)
      throw const ProtocolException('not_found', 'Job not found.', 404);
    return {
      ...row.data,
      'result': row.data['result'] == null
          ? null
          : jsonDecode(row.read<String>('result')),
    };
  }

  Future<void> cancel(String id) async {
    await get(id);
    await db.customStatement(
      "UPDATE sg_jobs SET state = 'cancelled', progress = 'Cancelled' WHERE id = ? AND state IN ('queued', 'running')",
      [id],
    );
    if (_activeId == id) _activeClient?.close();
  }

  Future<void> _drain() async {
    if (_running || _closed) return;
    _running = true;
    try {
      final row = await db
          .customSelect(
            "SELECT * FROM sg_jobs WHERE state = 'queued' ORDER BY created_at LIMIT 1",
          )
          .getSingleOrNull();
      if (row == null) return;
      final id = row.read<String>('id');
      _activeId = id;
      _activeClient = http.Client();
      try {
        final input = Map<String, dynamic>.from(
          jsonDecode(row.read<String>('request')) as Map,
        );
        final checkpoints = Map<String, dynamic>.from(
          jsonDecode(row.read<String>('checkpoints')) as Map,
        );
        await db.customStatement(
          "UPDATE sg_jobs SET state = 'running', progress = 'Working' WHERE id = ? AND state = 'queued'",
          [id],
        );
        final llm = LlmService(
          model: model,
          client: _activeClient,
          checkpoint: (key, request) async {
            if ((await get(id))['state'] == 'cancelled' || _closed)
              throw StateError('Cancelled');
            if (checkpoints.containsKey(key)) return checkpoints[key] as String;
            final text = await request().timeout(const Duration(minutes: 5));
            checkpoints[key] = text;
            await db.customStatement(
              'UPDATE sg_jobs SET checkpoints = ? WHERE id = ?',
              [jsonEncode(checkpoints), id],
            );
            return text;
          },
        );
        void progress(int done, int total) => unawaited(
          db.customStatement('UPDATE sg_jobs SET progress = ? WHERE id = ?', [
            'Processing day $done/$total',
            id,
          ]),
        );
        final library = (input['exerciseLibrary'] as List? ?? [])
            .map(
              (e) => (name: e['name'] as String, group: e['group'] as String),
            )
            .toList();
        final prior = input['priorMeso'] == null
            ? null
            : MesoImportData.fromJson(
                Map<String, dynamic>.from(input['priorMeso'] as Map),
              );
        final url = '$baseUrl/v1/chat/completions';
        final MesoImportData result;
        switch (row.read<String>('kind')) {
          case 'csv':
            result = await llm.interpretPlan(
              input['csv'] as String,
              apiUrl: url,
              onProgress: progress,
            );
          case 'generate':
            result = await llm.interpretDescription(
              input['description'] as String,
              input['numWeeks'] as int,
              apiUrl: url,
              experienceLevel:
                  input['experienceLevel'] as String? ?? 'intermediate',
              goal: input['goal'] as String? ?? 'mix',
              trainingDays: input['trainingDays'] as int?,
              sportContext: input['sportContext'] as String? ?? '',
              basisMode: input['basisMode'] as String? ?? 'inspiration',
              priorMeso: prior,
              exerciseLibrary: library,
              onProgress: progress,
            );
          case 'fix':
            result = await llm.fixPlanAdvisories(
              MesoImportData.fromJson(
                Map<String, dynamic>.from(input['data'] as Map),
              ),
              (input['advisories'] as List)
                  .map(
                    (v) => PlanAdvisory(
                      severity: AdvisorySeverity.values.byName(
                        v['severity'] as String,
                      ),
                      scope: v['scope'] as String,
                      message: v['message'] as String,
                    ),
                  )
                  .toList(),
              apiUrl: url,
              experienceLevel:
                  input['experienceLevel'] as String? ?? 'intermediate',
              goal: input['goal'] as String? ?? 'mix',
              sportContext: input['sportContext'] as String? ?? '',
              description: input['description'] as String? ?? '',
              exerciseLibrary: library,
            );
          default:
            throw StateError('Invalid job kind');
        }
        final encoded = {
          ...result.toJson(),
          'skippedDayLabels': result.skippedDayLabels,
          'advisories': [
            for (final a in result.advisories)
              {
                'severity': a.severity.name,
                'scope': a.scope,
                'message': a.message,
                'source': a.source,
              },
          ],
        };
        await db.customStatement(
          "UPDATE sg_jobs SET state = 'complete', progress = 'Ready for review', result = ? WHERE id = ? AND state = 'running'",
          [jsonEncode(encoded), id],
        );
      } catch (e) {
        if (_closed)
          return; // Leave running work resumable after graceful shutdown.
        await db.customStatement(
          "UPDATE sg_jobs SET state = 'failed', error = ? WHERE id = ? AND state IN ('running', 'queued')",
          ['$e', id],
        );
      }
    } finally {
      _activeClient?.close();
      _activeClient = null;
      _activeId = null;
      _running = false;
    }
  }

  void close() {
    _closed = true;
    _activeClient?.close();
    _timer?.cancel();
  }
}

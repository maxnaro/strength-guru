import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_server/store.dart';
import 'package:strength_guru_server/jobs.dart';
import 'package:strength_guru_core/sync/storage.dart';
import 'package:strength_guru_core/sync/protocol.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late HttpServer inference;
  late Jobs jobs;
  var requests = 0;
  var ready = true;
  const content =
      '{"label":"Push","exercises":[{"name":"Bench Press","group":"chest","sets":"3","reps":"8","rpe":"8"}]}';
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    requests = 0;
    ready = true;
    db = AppDatabase(NativeDatabase.memory());
    await Store(db).initialize();
    inference = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    inference.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/health') {
        request.response.statusCode = ready ? 200 : 503;
        request.response.write('{}');
      } else {
        requests++;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': content},
              },
            ],
          }),
        );
      }
      await request.response.close();
    });
    jobs = Jobs(db, 'http://127.0.0.1:${inference.port}', 'test');
  });
  tearDown(() async {
    jobs.close();
    await inference.close(force: true);
    await db.close();
  });
  Future<Map<String, dynamic>> finish(String id) async {
    for (var i = 0; i < 100; i++) {
      final row = await jobs.get(id);
      if (['complete', 'failed', 'cancelled'].contains(row['state']))
        return row;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    fail('Job did not finish');
  }

  test(
    'CSV job persists results independently of the creating request',
    () async {
      final job = await jobs.create({
        'kind': 'csv',
        'input': {'csv': 'Bench Press,3,8,8'},
      });
      final result = await finish(job['id'] as String);
      expect(result['state'], 'complete');
      expect((result['result'] as Map)['days'], isNotEmpty);
      expect(requests, 1);
    },
  );
  test('restart resumes from the last persisted model response', () async {
    await db.customStatement(
      'INSERT INTO sg_jobs (id, kind, request, state, checkpoints, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [
        'restart',
        'csv',
        jsonEncode({'csv': 'Bench Press,3,8,8'}),
        'running',
        jsonEncode({'0': content}),
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    await jobs.start();
    expect((await finish('restart'))['state'], 'complete');
    expect(requests, 0);
  });
  test('queued job can be cancelled without inference', () async {
    await db.customStatement(
      'INSERT INTO sg_jobs (id, kind, request, state, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        'cancel',
        'csv',
        '{}',
        'queued',
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    await jobs.cancel('cancel');
    await jobs.start();
    expect((await jobs.get('cancel'))['state'], 'cancelled');
    expect(requests, 0);
  });

  test('disabled inference rejects new jobs and keeps saved jobs', () async {
    const body = {
      'id': 'disabled',
      'kind': 'csv',
      'input': {'csv': 'Bench Press,3,8,8'},
    };
    await db.customStatement(
      'INSERT INTO sg_jobs (id, kind, request, state, created_at) VALUES (?, ?, ?, ?, ?)',
      ['disabled', 'csv', jsonEncode(body['input']), 'running', 'now'],
    );
    jobs = Jobs(db, null, 'test');
    await jobs.start();
    expect(await jobs.available(), isFalse);
    expect((await jobs.create(body))['state'], 'queued');
    await expectLater(
      jobs.create({...body, 'id': 'new'}),
      throwsA(
        isA<ProtocolException>().having(
          (e) => e.code,
          'code',
          'ai_unavailable',
        ),
      ),
    );
    await jobs.cancel('disabled');
    expect((await jobs.get('disabled'))['state'], 'cancelled');
    expect(requests, 0);
  });

  test('persisted jobs wait for inference to become ready', () async {
    ready = false;
    await db.customStatement(
      'INSERT INTO sg_jobs (id, kind, request, state, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        'warmup',
        'csv',
        jsonEncode({'csv': 'Bench Press,3,8,8'}),
        'queued',
        'now',
      ],
    );
    await jobs.start();
    expect(await jobs.available(), isFalse);
    expect((await jobs.get('warmup'))['state'], 'queued');
    ready = true;
    expect((await finish('warmup'))['state'], 'complete');
    expect(requests, 1);
  });

  test('graceful shutdown leaves active work resumable', () async {
    await inference.close(force: true);
    inference = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final entered = Completer<void>();
    inference.listen((request) async {
      await request.drain<void>();
      if (request.uri.path == '/health') {
        request.response.write('{}');
        await request.response.close();
      } else {
        if (!entered.isCompleted) entered.complete();
        // The active client will be closed during shutdown.
      }
    });
    jobs = Jobs(db, 'http://127.0.0.1:${inference.port}', 'test');
    final job = await jobs.create({
      'kind': 'csv',
      'input': {'csv': 'Bench Press,3,8,8'},
    });
    await entered.future.timeout(const Duration(seconds: 2));
    jobs.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((await jobs.get(job['id'] as String))['state'], 'running');
  });

  test('malformed persisted job fails rather than starving the queue', () async {
    await db.customStatement(
      'INSERT INTO sg_jobs (id, kind, request, state, created_at) VALUES (?, ?, ?, ?, ?)',
      ['bad', 'csv', '[]', 'queued', DateTime.now().toUtc().toIso8601String()],
    );
    await jobs.start();
    expect((await finish('bad'))['state'], 'failed');
  });

  test(
    'job IDs retry without duplicate work and reject different input',
    () async {
      final body = {
        'id': 'same-id',
        'kind': 'csv',
        'input': {'csv': 'Bench Press,3,8,8'},
      };
      final first = await jobs.create(body);
      final result = await finish(first['id'] as String);
      expect(result['state'], 'complete');
      await inference.close(force: true);
      expect((await jobs.create(body))['id'], 'same-id');
      await expectLater(
        jobs.create({
          ...body,
          'input': {'csv': 'Different'},
        }),
        throwsA(anything),
      );
      expect((await jobs.list())['jobs'], hasLength(1));
      expect(requests, 1);
    },
  );
  test('jobs reject a stale dataset and paginate equal timestamps', () async {
    final epoch = (await readMeta(db, 'epoch'))!;
    await expectLater(
      jobs.create({
        'id': 'stale',
        'epoch': '$epoch-old',
        'kind': 'csv',
        'input': {'csv': 'x'},
      }),
      throwsA(
        isA<ProtocolException>().having(
          (e) => e.code,
          'code',
          'dataset_changed',
        ),
      ),
    );
    for (var i = 0; i < 101; i++) {
      await db.customStatement(
        'INSERT INTO sg_jobs (id, kind, request, state, created_at) VALUES (?, ?, ?, ?, ?)',
        [
          'job-${i.toString().padLeft(3, '0')}',
          'csv',
          '{}',
          'complete',
          'same',
        ],
      );
    }
    final first = await jobs.list();
    expect(first['jobs'], hasLength(100));
    final cursor = first['nextCursor'] as Map;
    final second = await jobs.list(
      beforeCreated: cursor['createdAt'] as String,
      beforeId: cursor['id'] as String,
    );
    expect(second['jobs'], hasLength(1));
    expect(second['nextCursor'], isNull);
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/db/queries.dart';
import 'package:strength_guru_core/seed/seeder.dart';
import 'package:strength_guru_core/sync/client.dart';
import 'package:strength_guru_core/sync/storage.dart';
import 'package:strength_guru_core/sync/protocol.dart';
import 'package:strength_guru_server/application.dart';
import 'package:strength_guru_server/store.dart';
import 'package:strength_guru_server/jobs.dart';
import 'package:strength_guru_server/backups.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase server;
  late Store store;
  late Directory temporary;
  late Handler handler;
  var online = true;
  var loseAcknowledgement = false;
  final clients = <SyncClient>[];

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    temporary = await Directory.systemTemp.createTemp('sg-test-');
    server = AppDatabase(NativeDatabase.memory());
    store = Store(server);
    await store.initialize();
    await Seeder.seedIfEmpty(server);
    handler = application(
      store: store,
      jobs: Jobs(server, 'http://127.0.0.1:1', 'test'),
      backups: Backups(store, temporary),
      origin: 'https://gym.example',
      webRoot: temporary.path,
    );
    online = true;
    loseAcknowledgement = false;
  });
  tearDown(() async {
    for (final c in clients) {
      c.close();
      await c.db.close();
    }
    clients.clear();
    await server.close();
    await temporary.delete(recursive: true);
  });

  Future<SyncClient> device([String? path]) async {
    final local = AppDatabase(
      path == null ? NativeDatabase.memory() : NativeDatabase(File(path)),
    );
    final client = SyncClient(
      local,
      ApiClient(
        Uri.parse('https://gym.example'),
        client: MockClient((request) async {
          if (!online) throw const SocketException('Offline');
          final response = await handler(
            Request(
              request.method,
              request.url,
              headers: request.headers,
              body: request.bodyBytes,
            ),
          );
          final body = await response.readAsString();
          if (loseAcknowledgement && request.url.path.endsWith('/commands')) {
            loseAcknowledgement = false;
            throw const SocketException('Acknowledgement lost');
          }
          return http.Response(
            body,
            response.statusCode,
            headers: response.headers,
          );
        }),
      ),
    );
    clients.add(client);
    await client.initialize();
    return client;
  }

  test(
    'bootstrap preserves IDs and logging works offline then syncs once',
    () async {
      final client = await device();
      final meso = (await client.db.getActiveMesocycle())!;
      final slot =
          (await client.db.select(client.db.exerciseSlots).get()).first;
      online = false;
      final session = await client.db.getOrCreateSessionLog(meso.id, 0, 0);
      await client.db.upsertSetEntry(
        sessionId: session.id,
        exerciseId: slot.exerciseId,
        slotId: slot.id,
        setIndex: 0,
        weight: 80,
        reps: 8,
        rir: 2,
        done: true,
      );
      await client.synchronize().catchError((Object _) {});
      expect((await client.db.getSetsForSession(session.id)).single.weight, 80);
      expect(client.pending, 2);
      expect(await server.getSessionLog(meso.id, 0, 0), isNull);
      online = true;
      loseAcknowledgement = true;
      await client.synchronize().catchError((Object _) {});
      await client.synchronize();
      await client.synchronize();
      expect(client.pending, 0);
      expect((await server.getSetsForSession(session.id)).length, 1);
      expect((await server.getSetsForSession(session.id)).single.weight, 80);
    },
  );

  test(
    'concurrent edits retain the local version until explicitly resolved',
    () async {
      final first = await device();
      final meso = (await first.db.getActiveMesocycle())!;
      final slot = (await first.db.select(first.db.exerciseSlots).get()).first;
      final session = await first.db.getOrCreateSessionLog(meso.id, 0, 0);
      await first.synchronize();
      await first.db.upsertSetEntry(
        sessionId: session.id,
        exerciseId: slot.exerciseId,
        slotId: slot.id,
        setIndex: 0,
        weight: 80,
        reps: 8,
        rir: 2,
        done: true,
      );
      await first.synchronize();
      final second = await device();
      online = false;
      await second.db.upsertSetEntry(
        sessionId: session.id,
        exerciseId: slot.exerciseId,
        slotId: slot.id,
        setIndex: 0,
        weight: 90,
        reps: 8,
        rir: 2,
        done: true,
      );
      await second.synchronize().catchError((Object _) {});
      online = true;
      await first.db.upsertSetEntry(
        sessionId: session.id,
        exerciseId: slot.exerciseId,
        slotId: slot.id,
        setIndex: 0,
        weight: 85,
        reps: 8,
        rir: 2,
        done: true,
      );
      await first.synchronize();
      await second.synchronize();
      expect(second.conflicts, 1);
      expect((await second.db.getSetsForSession(session.id)).single.weight, 90);
      expect((await server.getSetsForSession(session.id)).single.weight, 85);
      final conflict = (await second.conflictRows()).single;
      await second.keepLocal(conflict['id'] as String);
      expect((await server.getSetsForSession(session.id)).single.weight, 90);
    },
  );

  test(
    'restoring server dataset never replays pending edits automatically',
    () async {
      final client = await device();
      final meso = (await client.db.getActiveMesocycle())!;
      online = false;
      await client.db.getOrCreateSessionLog(meso.id, 0, 0);
      await client.synchronize().catchError((Object _) {});
      await writeMeta(server, 'epoch', 'restored');
      online = true;
      await expectLater(
        client.synchronize(),
        throwsA(isA<ProtocolException>()),
      );
      expect(client.pending, 1);
      expect(jsonDecode(await client.exportPending()), hasLength(1));
      expect(await server.getSessionLog(meso.id, 0, 0), isNull);
    },
  );

  test(
    'program changes require connectivity and are not applied locally offline',
    () async {
      final client = await device();
      final meso = (await client.db.getActiveMesocycle())!;
      online = false;
      await expectLater(
        client.db.renameMeso(meso.id, 'Unsaved'),
        throwsA(isA<SocketException>()),
      );
      expect((await client.db.getActiveMesocycle())!.name, meso.name);
    },
  );

  test('cross-origin mutations and malformed JSON are rejected', () async {
    var response = await handler(
      Request(
        'POST',
        Uri.parse('https://gym.example/api/v1/commands'),
        headers: {
          'origin': 'https://evil.example',
          'content-type': 'application/json',
        },
        body: '{}',
      ),
    );
    expect(response.statusCode, 403);
    response = await handler(
      Request(
        'POST',
        Uri.parse('https://gym.example/api/v1/commands'),
        headers: {
          'origin': 'https://gym.example',
          'content-type': 'application/json',
        },
        body: '{',
      ),
    );
    expect(response.statusCode, 400);
  });

  test(
    'day swaps and week deletion replicate primary-key moves without stale rows',
    () async {
      final client = await device();
      final meso = (await client.db.getActiveMesocycle())!;
      await server.getOrCreateSessionLog(meso.id, 1, 0);
      await server.getOrCreateSessionLog(meso.id, 2, 0);
      await client.synchronize();
      await client.db.swapDays(meso.id, 0, 1);
      expect(await trainingSnapshot(client.db), await trainingSnapshot(server));
      await client.db.deleteWeek(meso.id, 0);
      expect(await trainingSnapshot(client.db), await trainingSnapshot(server));
      expect(
        (await server.select(server.sessionLogs).get())
            .map((r) => r.weekIdx)
            .toList(),
        [0, 1],
      );
    },
  );

  test(
    'deleted offline session becomes a conflict without blocking later valid work',
    () async {
      final first = await device();
      final old = (await first.db.getActiveMesocycle())!;
      final other = await server.createMeso('Other program');
      await first.synchronize();
      online = false;
      await first.db.getOrCreateSessionLog(old.id, 0, 0);
      await first.db.getOrCreateSessionLog(other.id, 0, 0);
      await first.synchronize().catchError((Object _) {});
      await server.deleteMeso(old.id);
      online = true;
      await first.synchronize();
      expect(first.conflicts, 1);
      expect(await server.getSessionLog(other.id, 0, 0), isNotNull);
      expect(await first.exportPending(), contains(old.id));
    },
  );

  test(
    'pending edits survive database close and cached initialization does not await the network',
    () async {
      final path = '${temporary.path}/device.sqlite';
      final first = await device(path);
      final meso = (await first.db.getActiveMesocycle())!;
      online = false;
      await first.db.getOrCreateSessionLog(meso.id, 0, 0);
      await first.synchronize().catchError((Object _) {});
      first.close();
      await first.db.close();
      clients.remove(first);
      final resumed = await device(path).timeout(const Duration(seconds: 1));
      expect(resumed.pending, 1);
      expect(await resumed.db.getSessionLog(meso.id, 0, 0), isNotNull);
      await resumed.synchronize().catchError((Object _) {});
      online = true;
      await resumed.synchronize();
      expect(resumed.pending, 0);
    },
  );

  test('an outbox write failure rolls back the local set atomically', () async {
    final client = await device();
    final meso = (await client.db.getActiveMesocycle())!;
    final slot = (await client.db.select(client.db.exerciseSlots).get()).first;
    final session = await client.db.getOrCreateSessionLog(meso.id, 0, 0);
    await client.synchronize();
    await client.db.customStatement(
      "CREATE TRIGGER full_disk BEFORE INSERT ON sg_outbox BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await expectLater(
      client.db.upsertSetEntry(
        sessionId: session.id,
        exerciseId: slot.exerciseId,
        slotId: slot.id,
        setIndex: 0,
        weight: 80,
        reps: 8,
        rir: 2,
        done: true,
      ),
      throwsA(anything),
    );
    expect(await client.db.getSetsForSession(session.id), isEmpty);
    expect(client.pending, 0);
  });
}

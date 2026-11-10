import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../db/database.dart';
import '../db/queries.dart';
import 'protocol.dart';
import 'storage.dart';

class ApiClient {
  final Uri origin;
  final http.Client httpClient;
  ApiClient(this.origin, {http.Client? client})
    : httpClient = client ?? http.Client();
  Uri uri(String path) => origin.resolve('/api/v1/$path');
  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
    List<int>? bytes,
  }) async {
    final request = http.Request(method, uri(path));
    request.headers['origin'] = origin.origin;
    request.headers['content-type'] = bytes == null
        ? 'application/json'
        : 'application/octet-stream';
    if (bytes != null) {
      request.bodyBytes = bytes;
    } else if (body != null) {
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await httpClient.send(request).timeout(const Duration(seconds: 15)),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      } catch (_) {
        data = {};
      }
      throw ProtocolException(
        data['code'] as String? ?? 'server_error',
        data['message'] as String? ??
            'Server request failed (${response.statusCode}).',
        response.statusCode,
      );
    }
    return response;
  }

  Future<Map<String, dynamic>> json(
    String method,
    String path, {
    Object? body,
  }) async => Map<String, dynamic>.from(
    jsonDecode((await request(method, path, body: body)).body) as Map,
  );
  void close() => httpClient.close();
}

class SyncClient {
  final AppDatabase db;
  final ApiClient api;
  final events = StreamController<void>.broadcast();
  bool connected = false;
  int dataVersion = 0;
  void Function(Object)? onError;
  bool closed = false;
  int pending = 0;
  int conflicts = 0;
  String? message;
  Future<void>? _flight;
  bool _again = false;
  Timer? _timer;
  SyncClient(this.db, this.api);

  Future<void> initialize() async {
    await initializeSyncStorage(db);
    db.mutationDispatcher = dispatch;
    await refreshStatus();
    if (await readMeta(db, 'epoch') == null) {
      await synchronize();
    } else {
      unawaited(synchronize().catchError((Object _) {}));
    }
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(synchronize().catchError((Object _) {})),
    );
  }

  Future<dynamic> dispatch(String type, Map<String, dynamic> payload) async {
    try {
      return await _dispatch(type, payload);
    } catch (error) {
      onError?.call(error);
      rethrow;
    }
  }

  Future<dynamic> _dispatch(String type, Map<String, dynamic> payload) async {
    if (loggingCommands.contains(type)) {
      if (type == 'getOrCreateSessionLog') {
        final existing = await db.getSessionLog(
          payload['mesoId'] as String,
          payload['weekIdx'] as int,
          payload['dayIdx'] as int,
        );
        if (existing != null) return existing.toJson();
        payload['startedAt'] ??= DateTime.now().toUtc().toIso8601String();
      }
      if (type == 'upsertSetEntry')
        payload['loggedAt'] ??= DateTime.now().toUtc().toIso8601String();
      final result = await db.transaction(() async {
        final resource = await commandResource(db, type, payload);
        if (type == 'deleteSetEntry') payload['resource'] = resource;
        final epoch = await readMeta(db, 'epoch');
        if (epoch == null)
          throw const ProtocolException(
            'not_initialized',
            'Connect once to download your training data.',
          );
        final body = {
          'operationId': const Uuid().v4(),
          'epoch': epoch,
          'type': type,
          'payload': payload,
          'expectedRevision': await revisionFor(db, resource),
        };
        final result = await executeCommand(db, type, payload);
        await db.customStatement(
          'INSERT INTO sg_outbox (id, resource, body) VALUES (?, ?, ?)',
          [body['operationId'], resource, jsonEncode(body)],
        );
        return result;
      });
      await refreshStatus();
      unawaited(synchronize(afterCurrent: true).catchError((Object _) {}));
      return result;
    }
    await synchronize();
    if (pending > 0 || conflicts > 0)
      throw const ProtocolException(
        'pending_changes',
        'Sync or resolve pending workout changes before editing programs.',
      );
    final body = {
      'operationId': const Uuid().v4(),
      'epoch': await readMeta(db, 'epoch'),
      'type': type,
      'payload': payload,
      'expectedRevision': await revisionFor(db, 'program'),
    };
    // Persist online commands too: a lost acknowledgement must not repeat an edit.
    await db.customStatement(
      'INSERT INTO sg_outbox (id, resource, body) VALUES (?, ?, ?)',
      [body['operationId'], 'program', jsonEncode(body)],
    );
    await refreshStatus();
    await synchronize();
    final result = await readMeta(db, 'result:${body['operationId']}');
    if (result == null)
      throw const ProtocolException(
        'pending_changes',
        'The change is pending. Reconnect to confirm its result.',
      );
    await db.customStatement('DELETE FROM sg_meta WHERE key = ?', [
      'result:${body['operationId']}',
    ]);
    return jsonDecode(result);
  }

  Future<void> synchronize({bool afterCurrent = false}) {
    if (_flight != null) {
      _again = _again || afterCurrent;
      return _flight!;
    }
    return _flight = _sync().whenComplete(() {
      _flight = null;
      if (_again && !closed) {
        _again = false;
        unawaited(synchronize().catchError((Object _) {}));
      }
    });
  }

  Future<void> _sync() async {
    if (closed) return;
    try {
      await _pull();
      while (!closed) {
        final row = await db
            .customSelect(
              "SELECT * FROM sg_outbox WHERE state = 'pending' ORDER BY rowid LIMIT 1",
            )
            .getSingleOrNull();
        if (row == null) break;
        final body = Map<String, dynamic>.from(
          jsonDecode(row.read<String>('body')) as Map,
        );
        try {
          final response = await api.json('POST', 'commands', body: body);
          await db.transaction(() async {
            await upsertRawRow(db, 'sg_revisions', {
              'resource': response['resource'],
              'revision': response['revision'],
            });
            await db.customStatement('DELETE FROM sg_outbox WHERE id = ?', [
              row.read<String>('id'),
            ]);
            if (row.read<String>('resource') == 'program')
              await writeMeta(
                db,
                'result:${body['operationId']}',
                jsonEncode(response['result']),
              );
            // Sequential edits to one set build on this device's acknowledged edit.
            final following = await db
                .customSelect(
                  "SELECT * FROM sg_outbox WHERE resource = ? AND state = 'pending'",
                  variables: [Variable(row.read<String>('resource'))],
                )
                .get();
            for (final next in following) {
              final value = Map<String, dynamic>.from(
                jsonDecode(next.read<String>('body')) as Map,
              );
              if (value['expectedRevision'] == body['expectedRevision']) {
                value['expectedRevision'] = response['revision'];
                await db.customStatement(
                  'UPDATE sg_outbox SET body = ? WHERE id = ?',
                  [jsonEncode(value), next.read<String>('id')],
                );
              }
            }
          });
        } on ProtocolException catch (e) {
          if (e.status != 409 && e.status != 400) rethrow;
          await db.customStatement(
            "UPDATE sg_outbox SET state = 'conflict', error = ? WHERE id = ?",
            [e.message, row.read<String>('id')],
          );
        }
      }
      await _pull();
      connected = true;
      message = null;
    } catch (e) {
      connected = false;
      message = '$e';
      rethrow;
    } finally {
      await refreshStatus();
    }
  }

  Future<void> _pull() async {
    Map<String, dynamic> page;
    do {
      final epoch = await readMeta(db, 'epoch');
      final cursor = await readMeta(db, 'cursor');
      final query = Uri(
        queryParameters: {
          if (epoch != null) 'epoch': epoch,
          if (cursor != null) 'cursor': cursor,
        },
      ).query;
      page = await api.json('GET', 'sync?$query');
      final queued = await db
          .customSelect('SELECT * FROM sg_outbox ORDER BY rowid')
          .get();
      if (epoch != null && page['epoch'] != epoch && queued.isNotEmpty) {
        throw const ProtocolException(
          'dataset_changed',
          'The server database was restored. Export or discard pending changes before reloading it.',
          409,
        );
      }
      if (page['snapshot'] == null && (page['changes'] as List? ?? []).isEmpty)
        continue;
      await db.transaction(() async {
        await applySyncPage(db, page);
        // Keep unsynced edits visible after server changes are materialized.
        for (final row
            in await db
                .customSelect('SELECT * FROM sg_outbox ORDER BY rowid')
                .get()) {
          final body = Map<String, dynamic>.from(
            jsonDecode(row.read<String>('body')) as Map,
          );
          if (!loggingCommands.contains(body['type'])) continue;
          try {
            await executeCommand(
              db,
              body['type'] as String,
              Map<String, dynamic>.from(body['payload'] as Map),
            );
          } catch (_) {
            await db.customStatement(
              "UPDATE sg_outbox SET state = 'conflict', error = 'The referenced program changed. Export this edit before discarding it.' WHERE id = ?",
              [row.read<String>('id')],
            );
          }
        }
      });
      dataVersion++;
    } while (page['hasMore'] == true);
  }

  Future<List<Map<String, dynamic>>> conflictRows() async => [
    for (final r
        in await db
            .customSelect(
              "SELECT * FROM sg_outbox WHERE state = 'conflict' ORDER BY rowid",
            )
            .get())
      r.data,
  ];
  Future<String> exportPending() async => jsonEncode([
    for (final r
        in await db
            .customSelect('SELECT * FROM sg_outbox ORDER BY rowid')
            .get())
      {...r.data, 'body': jsonDecode(r.read<String>('body'))},
  ]);
  Future<void> discard(String id) async {
    await db.customStatement('DELETE FROM sg_outbox WHERE id = ?', [id]);
    // Full refresh removes the locally overlaid version while preserving other edits.
    await db.customStatement("DELETE FROM sg_meta WHERE key = 'cursor'");
    await synchronize();
  }

  Future<void> keepLocal(String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM sg_outbox WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingle();
    final body = Map<String, dynamic>.from(
      jsonDecode(row.read<String>('body')) as Map,
    );
    if (body['epoch'] != await readMeta(db, 'epoch'))
      throw const ProtocolException(
        'dataset_changed',
        'Export this edit before discarding it.',
      );
    body['operationId'] = const Uuid().v4();
    body['expectedRevision'] = await revisionFor(
      db,
      row.read<String>('resource'),
    );
    await db.customStatement(
      "UPDATE sg_outbox SET id = ?, body = ?, state = 'pending', error = NULL WHERE id = ?",
      [body['operationId'], jsonEncode(body), id],
    );
    await synchronize();
  }

  Future<void> refreshStatus() async {
    final counts = await db
        .customSelect(
          "SELECT COUNT(*) AS n, COALESCE(SUM(state = 'conflict'), 0) AS c FROM sg_outbox",
        )
        .getSingle();
    pending = counts.read<int>('n');
    conflicts = counts.read<int>('c');
    if (!events.isClosed) events.add(null);
  }

  void close() {
    closed = true;
    _timer?.cancel();
    db.mutationDispatcher = null;
    api.close();
    unawaited(events.close());
  }
}

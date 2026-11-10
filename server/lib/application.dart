import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:strength_guru_core/sync/protocol.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'store.dart';
import 'jobs.dart';
import 'backups.dart';

Response jsonResponse(Object value, [int status = 200]) => Response(
  status,
  body: jsonEncode(value),
  headers: {'content-type': 'application/json', 'cache-control': 'no-store'},
);

Future<List<int>> readBytes(
  Request request, [
  int limit = 2 * 1024 * 1024,
]) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    if (bytes.length + chunk.length > limit)
      throw const ProtocolException(
        'too_large',
        'The upload exceeds the size limit.',
        413,
      );
    bytes.addAll(chunk);
  }
  return bytes;
}

Future<Map<String, dynamic>> readJson(Request request) async =>
    Map<String, dynamic>.from(
      jsonDecode(utf8.decode(await readBytes(request))) as Map,
    );

Handler application({
  required Store store,
  required Jobs jobs,
  required Backups backups,
  required String origin,
  required String webRoot,
}) {
  final router = Router();
  router.get(
    '/api/v1/health',
    (_) async =>
        jsonResponse({'ok': true, 'aiAvailable': await jobs.available()}),
  );
  router.get(
    '/api/v1/sync',
    (Request r) async => jsonResponse(
      await store.sync(
        since: int.tryParse(r.url.queryParameters['cursor'] ?? ''),
        epoch: r.url.queryParameters['epoch'],
      ),
    ),
  );
  router.post(
    '/api/v1/commands',
    (Request r) async => jsonResponse(await store.command(await readJson(r))),
  );
  router.post(
    '/api/v1/jobs',
    (Request r) async =>
        jsonResponse(await jobs.create(await readJson(r)), 202),
  );
  router.get(
    '/api/v1/jobs/<id>',
    (Request r, String id) async => jsonResponse(await jobs.get(id)),
  );
  router.delete('/api/v1/jobs/<id>', (Request r, String id) async {
    await jobs.cancel(id);
    return jsonResponse({'ok': true});
  });
  router.get('/api/v1/jobs/<id>/events', (Request r, String id) async {
    await jobs.get(id);
    Stream<List<int>> events() async* {
      String? previous;
      while (true) {
        final job = await jobs.get(id);
        final encoded = jsonEncode(job);
        if (encoded != previous) {
          yield utf8.encode('data: $encoded\n\n');
          previous = encoded;
        } else {
          yield utf8.encode(': heartbeat\n\n');
        }
        if (['complete', 'failed', 'cancelled'].contains(job['state'])) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    return Response.ok(
      events(),
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache, no-transform',
        'x-accel-buffering': 'no',
      },
    );
  });
  router.get('/api/v1/backups', (Request r) async {
    final file = await backups.snapshot();
    return Response.ok(
      await file.readAsBytes(),
      headers: {
        'content-type': 'application/vnd.sqlite3',
        'content-disposition': 'attachment; filename="strength-guru.sqlite"',
        'cache-control': 'no-store',
      },
    );
  });
  router.post(
    '/api/v1/backups/inspect',
    (Request r) async => jsonResponse(
      await backups.inspect(await readBytes(r, 64 * 1024 * 1024)),
    ),
  );
  router.post('/api/v1/backups/restore', (Request r) async {
    final body = await readJson(r);
    if (body['confirmed'] != true)
      throw const ProtocolException(
        'confirmation_required',
        'Confirm the preview before restoring.',
      );
    await backups.restore(body['token'] as String);
    return jsonResponse({'ok': true});
  });
  router.get('/api/v1/guides', (Request r) async {
    final query = r.url.queryParameters['exercise'] ?? '';
    if (query.isEmpty || query.length > 200)
      throw const ProtocolException('invalid_query', 'Choose an exercise.');
    final yt = YoutubeExplode();
    try {
      final found = await yt.search
          .search('$query exercise form tutorial')
          .timeout(const Duration(seconds: 15));
      return jsonResponse({
        'videos': [
          for (final v in found.take(3)) {'id': v.id.value, 'title': v.title},
        ],
      });
    } finally {
      yt.close();
    }
  });
  router.get('/guide/<id>', (Request r, String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id))
      return Response.notFound('Video not found');
    return Response.ok(
      '<!doctype html><html><meta name="viewport" content="width=device-width, initial-scale=1"><title>Exercise guide</title><body style="margin:0;background:#0e0f12;color:white;font:16px system-ui"><iframe title="Exercise guide" style="width:100%;height:80vh;border:0" src="https://www.youtube-nocookie.com/embed/$id" allow="fullscreen; encrypted-media; picture-in-picture" allowfullscreen></iframe><p><a style="color:white" href="https://www.youtube.com/watch?v=$id">Open in YouTube</a></p></body></html>',
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-store',
      },
    );
  });
  final static = createStaticHandler(webRoot, defaultDocument: 'index.html');
  return (Request request) async {
    try {
      if (!['GET', 'HEAD'].contains(request.method)) {
        if (request.headers['origin'] != origin)
          return jsonResponse({
            'code': 'origin_rejected',
            'message': 'Untrusted request origin.',
          }, 403);
        if (!request.url.path.startsWith('api/v1/backups/inspect') &&
            !request.headers['content-type'].toString().startsWith(
              'application/json',
            ))
          return jsonResponse({'message': 'JSON required.'}, 415);
      }
      var response = await router.call(request);
      if (response.statusCode == 404 && !request.url.path.startsWith('api/'))
        response = await static(request);
      // Missing compiled assets must stay 404, rather than becoming HTML.
      if (response.statusCode == 404 &&
          !request.url.path.startsWith('api/') &&
          !request.url.path.contains('.'))
        response = Response.ok(
          await File('$webRoot/index.html').readAsBytes(),
          headers: {'content-type': 'text/html'},
        );
      final headers = <String, String>{
        'x-content-type-options': 'nosniff',
        'referrer-policy': 'strict-origin-when-cross-origin',
      };
      if (!request.url.path.startsWith('guide/'))
        headers.addAll({
          'cross-origin-opener-policy': 'same-origin',
          'cross-origin-embedder-policy': 'credentialless',
        });
      if (!request.url.path.startsWith('api/') &&
          !request.url.path.startsWith('guide/'))
        headers['cache-control'] = 'no-cache';
      return response.change(headers: headers);
    } on ProtocolException catch (e) {
      return jsonResponse({'code': e.code, 'message': e.message}, e.status);
    } on FormatException {
      return jsonResponse({
        'code': 'invalid_json',
        'message': 'Invalid JSON request.',
      }, 400);
    } on TypeError {
      return jsonResponse({
        'code': 'invalid_request',
        'message': 'Invalid request fields.',
      }, 400);
    } catch (e, stack) {
      stderr.writeln('$e\n$stack');
      return jsonResponse({
        'code': 'request_failed',
        'message':
            'The request could not be completed. Your pending changes have been retained.',
      }, 500);
    }
  };
}

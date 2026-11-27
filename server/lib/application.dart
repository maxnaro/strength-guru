import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:strength_guru_core/sync/protocol.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'store.dart';
import 'accounts.dart';
import 'auth.dart';
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

Handler accountApplication({
  Store? store,
  Jobs? jobs,
  Backups? backups,
  Future<bool> Function()? sessionActive,
  required String origin,
  required String webRoot,
}) {
  final router = Router();
  router.get('/api/v1/health', (_) => jsonResponse({'ok': true}));
  router.get(
    '/api/v1/ai/status',
    (_) async => jsonResponse({'aiAvailable': await jobs!.available()}),
  );
  router.get(
    '/api/v1/sync',
    (Request r) async => jsonResponse(
      await store!.sync(
        since: int.tryParse(r.url.queryParameters['cursor'] ?? ''),
        epoch: r.url.queryParameters['epoch'],
      ),
    ),
  );
  router.post(
    '/api/v1/commands',
    (Request r) async => jsonResponse(await store!.command(await readJson(r))),
  );
  router.post(
    '/api/v1/jobs',
    (Request r) async =>
        jsonResponse(await jobs!.create(await readJson(r)), 202),
  );
  router.get(
    '/api/v1/jobs',
    (Request r) async => jsonResponse(
      await jobs!.list(
        beforeCreated: r.url.queryParameters['beforeCreated'],
        beforeId: r.url.queryParameters['beforeId'],
      ),
    ),
  );
  router.get(
    '/api/v1/jobs/<id>',
    (Request r, String id) async => jsonResponse(await jobs!.get(id)),
  );
  router.delete('/api/v1/jobs/<id>', (Request r, String id) async {
    await jobs!.cancel(id);
    return jsonResponse({'ok': true});
  });
  router.get('/api/v1/jobs/<id>/events', (Request r, String id) async {
    await jobs!.get(id);
    Stream<List<int>> events() async* {
      String? previous;
      while (await sessionActive?.call() ?? true) {
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
        'cache-control': 'no-store, no-transform',
        'x-accel-buffering': 'no',
      },
    );
  });
  router.get('/api/v1/backups', (Request r) async {
    final file = await backups!.snapshot();
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
      await backups!.inspect(await readBytes(r, 64 * 1024 * 1024)),
    ),
  );
  router.post('/api/v1/backups/restore', (Request r) async {
    final body = await readJson(r);
    if (body['confirmed'] != true)
      throw const ProtocolException(
        'confirmation_required',
        'Confirm the preview before restoring.',
      );
    await backups!.restore(
      body['token'] as String,
      expectedEpoch: body['expectedEpoch'] as String?,
    );
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
        headers['cache-control'] =
            response.statusCode == 200 &&
                request.url.path.startsWith('_app/immutable/')
            ? 'public, max-age=31536000, immutable'
            : 'no-cache';
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

Handler application({
  required Accounts accounts,
  required AuthRegistry auth,
  required String origin,
  required String webRoot,
}) {
  final secure = Uri.parse(origin).scheme == 'https';
  final sessionCookie = secure ? '__Host-sg_session' : 'sg_session';
  final flowCookie = secure ? '__Host-sg_oidc' : 'sg_oidc';
  final public = accountApplication(origin: origin, webRoot: webRoot);
  const privatePaths = {'sync', 'commands', 'jobs', 'backups', 'guides', 'ai'};
  const accountHeader = 'x-strength-guru-account';

  String? cookie(Request request, String name) {
    for (final part in (request.headers['cookie'] ?? '').split(';')) {
      final prefix = '$name=';
      final value = part.trim();
      if (value.startsWith(prefix)) return value.substring(prefix.length);
    }
    return null;
  }

  String setCookie(String name, String value, int seconds) =>
      '$name=$value; Path=/; HttpOnly; SameSite=Lax; Max-Age=$seconds'
      '${secure ? '; Secure' : ''}';

  String safeReturn(Object? value) {
    if (value is! String ||
        !value.startsWith('/') ||
        value.startsWith('//') ||
        value.contains('\\') ||
        value.contains(RegExp(r'[\x00-\x20]')))
      return '/';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasAuthority ||
        uri.hasScheme ||
        !{
          '/',
          '/today',
          '/log',
          '/meso',
          '/import',
          '/generate',
        }.contains(uri.path)) {
      return '/';
    }
    return value;
  }

  Response authError(String code, String message, int status) =>
      jsonResponse({'code': code, 'message': message}, status);

  return (request) async {
    final segments = request.url.pathSegments;
    if (segments.length < 3 || segments[0] != 'api' || segments[1] != 'v1') {
      return public(request);
    }
    final resource = segments[2];
    if (resource != 'auth' && !privatePaths.contains(resource)) {
      return public(request);
    }
    final method = request.method;
    if (method != 'GET' && method != 'HEAD') {
      if (request.headers['origin'] != origin) {
        return authError('origin_rejected', 'Untrusted request origin.', 403);
      }
      if (request.url.path != 'api/v1/backups/inspect' &&
          !(request.headers['content-type'] ?? '').startsWith(
            'application/json',
          )) {
        return authError('invalid_content_type', 'JSON required.', 415);
      }
    }
    final route = request.url.path;
    final token = cookie(request, sessionCookie);
    try {
      if (method == 'POST' && route == 'api/v1/auth/login') {
        final body = await readJson(request);
        final start = await auth.begin(
          invite: body['invite'] as String?,
          returnTo: safeReturn(body['returnTo']),
        );
        return jsonResponse({'authorizationUrl': start.url.toString()}).change(
          headers: {'set-cookie': setCookie(flowCookie, start.binding, 600)},
        );
      }
      if (method == 'GET' && route == 'api/v1/auth/callback') {
        final query = request.url.queryParameters;
        try {
          final login = await auth.finish(
            state: query['state'],
            code: query['code'],
            binding: cookie(request, flowCookie),
          );
          auth.logout(token);
          return Response.seeOther(
            safeReturn(login.returnTo),
            headers: {
              'cache-control': 'no-store',
              'referrer-policy': 'no-referrer',
              'set-cookie': [
                setCookie(
                  sessionCookie,
                  login.token,
                  sessionLifetime.inSeconds,
                ),
                setCookie(flowCookie, '', 0),
              ],
            },
          );
        } on AuthFailure catch (error) {
          return Response.seeOther(
            '/?authError=${Uri.encodeQueryComponent(error.code)}',
            headers: {
              'cache-control': 'no-store',
              'referrer-policy': 'no-referrer',
              'set-cookie': setCookie(flowCookie, '', 0),
            },
          );
        }
      }

      final session = auth.session(token);
      if (session == null) {
        return authError('sign_in_required', 'Sign in to Strength Guru.', 401);
      }
      final account = session.account;
      if (method == 'GET' && route == 'api/v1/auth/session') {
        return jsonResponse({
          'accountId': account.id,
          'owner': account.owner,
          'legacyOwner': accounts.isLegacy(account.id),
          'expiresAt': session.expiresAt.toUtc().toIso8601String(),
        });
      }
      if (request.headers[accountHeader] != account.id) {
        return authError('account_changed', 'The active account changed.', 409);
      }
      if (method == 'POST' && route == 'api/v1/auth/logout') {
        auth.logout(token);
        return jsonResponse({
          'ok': true,
        }).change(headers: {'set-cookie': setCookie(sessionCookie, '', 0)});
      }
      if (route == 'api/v1/auth/invites') {
        if (method == 'GET')
          return jsonResponse({'invites': auth.listInvites(account)});
        if (method == 'POST') {
          final invite = auth.invite(account);
          return jsonResponse({'url': '$origin/invite#$invite'}, 201);
        }
      }
      if (method == 'DELETE' &&
          segments.length == 5 &&
          segments[3] == 'invites' &&
          resource == 'auth') {
        auth.revokeInvite(account, segments[4]);
        return jsonResponse({'ok': true});
      }
      if (resource == 'auth') return Response.notFound('Not found');
      final data = await accounts.open(account.id);
      return await accountApplication(
        store: data.store,
        jobs: data.jobs,
        backups: data.backups,
        origin: origin,
        webRoot: webRoot,
        sessionActive: () async =>
            auth.session(token)?.account.id == account.id,
      )(request);
    } on AuthFailure catch (error) {
      return authError(error.code, error.message, error.status);
    } on ProtocolException catch (error) {
      return authError(error.code, error.message, error.status);
    } on FormatException {
      return authError('invalid_json', 'Invalid JSON request.', 400);
    } on TypeError {
      return authError('invalid_request', 'Invalid request fields.', 400);
    } catch (error, stack) {
      stderr.writeln('$error\n$stack');
      return authError(
        'request_failed',
        'The request could not be completed.',
        500,
      );
    }
  };
}

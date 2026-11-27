import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:strength_guru_server/accounts.dart';
import 'package:strength_guru_server/application.dart';
import 'package:strength_guru_server/auth.dart';

Future<void> main() async {
  final env = Platform.environment;
  final appUri = Uri.tryParse(env['APP_ORIGIN'] ?? '');
  if (appUri == null ||
      !{'https', 'http'}.contains(appUri.scheme) ||
      appUri.host.isEmpty ||
      appUri.userInfo.isNotEmpty ||
      appUri.hasQuery ||
      appUri.hasFragment ||
      (appUri.path.isNotEmpty && appUri.path != '/')) {
    throw ArgumentError('Set APP_ORIGIN to the public application origin.');
  }
  final origin = appUri.origin;
  final config = AuthConfig.fromEnvironment(env, origin);
  final data = Directory(env['DATA_DIR'] ?? '/data');
  await data.create(recursive: true);

  final auth = AuthRegistry(
    '${data.path}/auth.sqlite',
    config,
    legacyDataset: File('${data.path}/strength_guru.sqlite').existsSync(),
  );
  final accounts = Accounts(
    data,
    auth,
    env['LLM_BASE_URL']?.trim(),
    env['LLM_MODEL'] ?? 'strength-guru',
  );
  await accounts.start();
  final server = await shelf_io.serve(
    application(
      accounts: accounts,
      auth: auth,
      origin: origin,
      webRoot: env['WEB_ROOT'] ?? '/app/web',
    ),
    InternetAddress.anyIPv4,
    int.parse(env['PORT'] ?? '8080'),
  );
  server.autoCompress = true;
  stdout.writeln('Strength Guru listening on ${server.port}');
  ProcessSignal.sigterm.watch().listen((_) async {
    await server.close(force: true);
    await accounts.close();
    auth.close();
    exit(0);
  });
}

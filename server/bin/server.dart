import 'dart:io';
import 'package:drift/native.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/seed/seeder.dart';
import 'package:strength_guru_server/store.dart';
import 'package:strength_guru_server/jobs.dart';
import 'package:strength_guru_server/backups.dart';
import 'package:strength_guru_server/application.dart';

Future<void> main() async {
  final env = Platform.environment;
  final origin = env['APP_ORIGIN'];
  if (origin == null || !Uri.parse(origin).hasAuthority)
    throw ArgumentError(
      'Set APP_ORIGIN to the public HTTPS origin of your private proxy.',
    );
  final data = Directory(env['DATA_DIR'] ?? '/data');
  await data.create(recursive: true);
  final db = AppDatabase(
    NativeDatabase.createInBackground(
      File('${data.path}/strength_guru.sqlite'),
    ),
  );
  final store = Store(db);
  await store.initialize();
  await Seeder.seedIfEmpty(db);
  final jobs = Jobs(
    db,
    env['LLM_BASE_URL'] ?? 'http://inference:8080',
    env['LLM_MODEL'] ?? 'strength-guru',
  );
  await jobs.start();
  final server = await shelf_io.serve(
    application(
      store: store,
      jobs: jobs,
      backups: Backups(store, Directory('${data.path}/backups')),
      origin: origin,
      webRoot: env['WEB_ROOT'] ?? '/app/web',
    ),
    InternetAddress.anyIPv4,
    int.parse(env['PORT'] ?? '8080'),
  );
  server.autoCompress = true;
  stdout.writeln('Strength Guru listening on ${server.port}');
  ProcessSignal.sigterm.watch().listen((_) async {
    jobs.close();
    await server.close();
    await db.close();
    exit(0);
  });
}

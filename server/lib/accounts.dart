import 'dart:io';

import 'package:drift/native.dart';
import 'package:strength_guru_core/db/database.dart';
import 'package:strength_guru_core/seed/seeder.dart';
import 'package:strength_guru_core/sync/storage.dart';

import 'auth.dart';
import 'backups.dart';
import 'jobs.dart';
import 'store.dart';

class AccountData {
  final Store store;
  final Jobs jobs;
  final Backups backups;

  AccountData(this.store, this.jobs, this.backups);
}

class Accounts {
  final Directory directory;
  final AuthRegistry registry;
  final String? baseUrl;
  final String model;
  final JobWorker _worker = JobWorker();
  final Map<String, Future<AccountData>> _open = {};
  bool _closed = false;

  Accounts(this.directory, this.registry, this.baseUrl, this.model);

  bool isLegacy(String accountId) {
    final owner = registry.owner;
    return owner != null && owner.id == accountId && owner.legacyOwner;
  }

  Directory _directoryFor(String accountId) {
    if (isLegacy(accountId)) return directory;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(accountId)) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    return Directory('${directory.path}/accounts/$accountId');
  }

  File _databaseFile(Directory location) =>
      File('${location.path}/strength_guru.sqlite');

  Future<void> start() async {
    // Open existing databases at startup so their queued jobs can resume even
    // when the corresponding account has not visited since the restart.
    for (final account in registry.accounts) {
      if (await _databaseFile(_directoryFor(account.id)).exists()) {
        await open(account.id);
      }
    }
  }

  Future<AccountData> open(String accountId) {
    if (_closed) throw StateError('Account storage is closed.');
    return _open.putIfAbsent(accountId, () async {
      try {
        return await _openAccount(accountId);
      } catch (_) {
        _open.remove(accountId);
        rethrow;
      }
    });
  }

  Future<AccountData> _openAccount(String accountId) async {
    final location = _directoryFor(accountId);
    await location.create(recursive: true);
    final db = AppDatabase(
      NativeDatabase.createInBackground(_databaseFile(location)),
    );
    try {
      final store = Store(db);
      await store.initialize();
      if (!isLegacy(accountId)) {
        await db.transaction(() async {
          if (await readMeta(db, 'exercise_library_seeded') != null) return;
          await Seeder.seedExerciseLibrary(db);
          await writeMeta(db, 'exercise_library_seeded', '1');
        });
      }
      final jobs = Jobs(db, baseUrl, model, worker: _worker);
      await jobs.start();
      return AccountData(
        store,
        jobs,
        Backups(store, Directory('${location.path}/backups')),
      );
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<void> close() async {
    _closed = true;
    await _worker.close();
    for (final pending in _open.values.toList()) {
      final account = await pending;
      await account.store.db.close();
    }
  }
}

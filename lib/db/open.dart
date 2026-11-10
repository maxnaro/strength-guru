import 'package:drift_flutter/drift_flutter.dart';
import 'database.dart';

AppDatabase openDatabase() => AppDatabase(
  driftDatabase(
    name: 'strength_guru',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('/sqlite3.wasm'),
      driftWorker: Uri.parse('/drift_worker.dart.js'),
      onResult: (result) {
        if (result.chosenImplementation.toString().toLowerCase().contains(
          'memory',
        )) {
          throw StateError(
            'Persistent browser storage is unavailable. Open the app outside private browsing to save workouts.',
          );
        }
      },
    ),
  ),
);

import 'package:strength_guru_core/sync/client.dart';

final appApi = ApiClient(
  Uri.base.hasAuthority
      ? Uri.base
      : Uri.parse(
          const String.fromEnvironment(
            'SERVER_URL',
            defaultValue: 'http://localhost:8080',
          ),
        ),
);

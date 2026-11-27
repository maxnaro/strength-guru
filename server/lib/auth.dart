import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

const sessionLifetime = Duration(days: 7);
const invitationLifetime = Duration(days: 7);
const signInLifetime = Duration(minutes: 10);

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message, this.status);

  final String code;
  final String message;
  final int status;
}

const _signInFailed = AuthFailure(
  'sign_in_failed',
  'Sign-in could not be completed. Please try again.',
  400,
);
const _invitationRequired = AuthFailure(
  'invitation_required',
  'An invitation is required to create an account.',
  403,
);
const _invalidInvitation = AuthFailure(
  'invalid_invitation',
  'This invitation has expired or is no longer available.',
  403,
);
const _ownerRequired = AuthFailure(
  'owner_required',
  'Only the owner can manage invitations.',
  403,
);

class AuthConfig {
  AuthConfig({
    required this.issuer,
    required this.clientId,
    required this.clientSecret,
    required this.ownerSubject,
    required String origin,
  }) : callback = Uri.parse(origin).resolve('/api/v1/auth/callback') {
    final issuerUri = Uri.parse(issuer);
    if (!_secureEndpoint(issuerUri) ||
        issuerUri.hasQuery ||
        !_secureEndpoint(callback) ||
        clientId.isEmpty ||
        clientSecret.isEmpty ||
        !_validSubject(ownerSubject)) {
      throw ArgumentError('Invalid OIDC configuration.');
    }
  }

  factory AuthConfig.fromEnvironment(Map<String, String> env, String origin) {
    String requiredValue(String key) {
      final value = env[key];
      if (value == null || value.isEmpty) {
        throw ArgumentError('$key must be configured.');
      }
      return value;
    }

    return AuthConfig(
      issuer: requiredValue('OIDC_ISSUER'),
      clientId: requiredValue('OIDC_CLIENT_ID'),
      clientSecret: requiredValue('OIDC_CLIENT_SECRET'),
      ownerSubject: requiredValue('OIDC_OWNER_SUBJECT'),
      origin: origin,
    );
  }

  final String issuer;
  final String clientId;
  final String clientSecret;
  final String ownerSubject;
  final Uri callback;
}

class AuthAccount {
  const AuthAccount(this.id, this.owner, this.legacyOwner);

  final String id;
  final bool owner;
  final bool legacyOwner;
}

class AuthSession {
  const AuthSession(this.account, this.expiresAt);

  final AuthAccount account;
  final DateTime expiresAt;
}

class AuthStart {
  const AuthStart(this.url, this.binding);

  final Uri url;
  final String binding;
}

class AuthLogin {
  const AuthLogin(this.account, this.token, this.expiresAt, this.returnTo);

  final AuthAccount account;
  final String token;
  final DateTime expiresAt;
  final String returnTo;
}

class AuthRegistry {
  AuthRegistry(
    String path,
    this.config, {
    http.Client? client,
    DateTime Function()? clock,
    bool legacyDataset = false,
  }) : _db = sqlite3.open(path),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now {
    try {
      _db.execute('PRAGMA foreign_keys = ON');
      _db.execute('PRAGMA journal_mode = WAL');
      _db.execute('PRAGMA busy_timeout = 5000');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id TEXT PRIMARY KEY NOT NULL,
          issuer TEXT NOT NULL,
          subject TEXT NOT NULL,
          owner INTEGER NOT NULL DEFAULT 0 CHECK (owner IN (0, 1)),
          legacy_owner INTEGER NOT NULL DEFAULT 0 CHECK (legacy_owner IN (0, 1)),
          UNIQUE (issuer, subject)
        )
      ''');
      _db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS one_owner ON accounts (owner)
        WHERE owner = 1
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS invitations (
          id TEXT PRIMARY KEY NOT NULL,
          token_hash TEXT UNIQUE NOT NULL,
          created_at INTEGER NOT NULL,
          expires_at INTEGER NOT NULL,
          used_at INTEGER,
          revoked_at INTEGER
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          token_hash TEXT PRIMARY KEY NOT NULL,
          account_id TEXT NOT NULL REFERENCES accounts (id),
          expires_at INTEGER NOT NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS sign_in_attempts (
          state_hash TEXT PRIMARY KEY NOT NULL,
          binding_hash TEXT NOT NULL,
          nonce TEXT NOT NULL,
          verifier TEXT NOT NULL,
          invitation_hash TEXT,
          return_to TEXT NOT NULL,
          expires_at INTEGER NOT NULL
        )
      ''');
      _reserveOwner(legacyDataset);
    } catch (_) {
      close();
      rethrow;
    }
  }

  final Database _db;
  final http.Client _client;
  final DateTime Function() _clock;
  final AuthConfig config;
  Future<Map<String, dynamic>>? _discovery;

  void close() {
    _client.close();
    _db.close();
  }

  List<AuthAccount> get accounts =>
      _db.select('SELECT * FROM accounts').map(_readAccount).toList();

  AuthAccount? get owner {
    final rows = _db.select('SELECT * FROM accounts WHERE owner = 1');
    return rows.isEmpty ? null : _readAccount(rows.single);
  }

  void _reserveOwner(bool legacyDataset) => _transaction(() {
    final subject = config.ownerSubject;
    final existingOwner = _db.select('SELECT * FROM accounts WHERE owner = 1');
    if (existingOwner.isNotEmpty) {
      final row = existingOwner.single;
      if (row['issuer'] != config.issuer || row['subject'] != subject) {
        throw StateError(
          'The configured OIDC identity conflicts with the existing owner.',
        );
      }
      return;
    }
    _db.execute(
      'INSERT INTO accounts (id, issuer, subject, owner, legacy_owner) '
      'VALUES (?, ?, ?, 1, ?)',
      [const Uuid().v4(), config.issuer, subject, legacyDataset ? 1 : 0],
    );
  });

  AuthSession? session(String? token) {
    if (token == null) return null;
    final rows = _db.select(
      'SELECT accounts.*, sessions.expires_at FROM sessions '
      'JOIN accounts ON accounts.id = sessions.account_id '
      'WHERE sessions.token_hash = ? AND sessions.expires_at > ?',
      [_hash(token), _clock().millisecondsSinceEpoch],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return AuthSession(_readAccount(row), _date(row['expires_at'] as int));
  }

  void logout(String? token) {
    if (token == null) return;
    _db.execute('DELETE FROM sessions WHERE token_hash = ?', [_hash(token)]);
  }

  String invite(AuthAccount account) {
    _requireOwner(account);
    final now = _clock();
    final token = _randomToken();
    _db.execute(
      'INSERT INTO invitations (id, token_hash, created_at, expires_at) '
      'VALUES (?, ?, ?, ?)',
      [
        const Uuid().v4(),
        _hash(token),
        now.millisecondsSinceEpoch,
        now.add(invitationLifetime).millisecondsSinceEpoch,
      ],
    );
    return token;
  }

  List<Map<String, dynamic>> listInvites(AuthAccount account) {
    _requireOwner(account);
    final now = _clock().millisecondsSinceEpoch;
    return [
      for (final row in _db.select(
        'SELECT id, created_at, expires_at, used_at, revoked_at FROM invitations '
        'ORDER BY created_at DESC, id',
      ))
        {
          'id': row['id'],
          'createdAt': _date(row['created_at'] as int).toIso8601String(),
          'expiresAt': _date(row['expires_at'] as int).toIso8601String(),
          'status': switch (row) {
            {'used_at': int()} => 'used',
            {'revoked_at': int()} => 'revoked',
            {'expires_at': int expires} when expires <= now => 'expired',
            _ => 'active',
          },
        },
    ];
  }

  void revokeInvite(AuthAccount account, String id) {
    _requireOwner(account);
    final now = _clock().millisecondsSinceEpoch;
    _db.execute(
      'UPDATE invitations SET revoked_at = ? WHERE id = ? '
      'AND used_at IS NULL AND revoked_at IS NULL AND expires_at > ?',
      [now, id, now],
    );
  }

  void _requireOwner(AuthAccount account) {
    if (account.id != owner?.id) throw _ownerRequired;
  }

  Future<AuthStart> begin({String? invite, String returnTo = '/'}) async {
    final provider = await _provider();
    final authorization = _endpoint(provider['authorization_endpoint']);
    final state = _randomToken();
    final nonce = _randomToken();
    final verifier = _randomToken();
    final binding = _randomToken();
    final now = _clock();
    _db.execute('DELETE FROM sign_in_attempts WHERE expires_at <= ?', [
      now.millisecondsSinceEpoch,
    ]);
    _db.execute('INSERT INTO sign_in_attempts VALUES (?, ?, ?, ?, ?, ?, ?)', [
      _hash(state),
      _hash(binding),
      nonce,
      verifier,
      invite == null ? null : _hash(invite),
      returnTo,
      now.add(signInLifetime).millisecondsSinceEpoch,
    ]);
    return AuthStart(
      authorization.replace(
        queryParameters: {
          ...authorization.queryParameters,
          'response_type': 'code',
          'client_id': config.clientId,
          'scope': 'openid',
          'redirect_uri': config.callback.toString(),
          'state': state,
          'nonce': nonce,
          'code_challenge': _base64url(
            sha256.convert(ascii.encode(verifier)).bytes,
          ),
          'code_challenge_method': 'S256',
        },
      ),
      binding,
    );
  }

  Future<AuthLogin> finish({
    required String? state,
    required String? code,
    required String? binding,
  }) async {
    if (state == null || code == null || binding == null || code.isEmpty) {
      throw _signInFailed;
    }
    final attempt = _db.select(
      'DELETE FROM sign_in_attempts WHERE state_hash = ? AND binding_hash = ? '
      'AND expires_at > ? RETURNING *',
      [_hash(state), _hash(binding), _clock().millisecondsSinceEpoch],
    ).firstOrNull;
    if (attempt == null) throw _signInFailed;
    final subject = await _exchange(code, attempt);
    final now = _clock();
    final expiresAt = now.add(sessionLifetime).toUtc();
    final token = _randomToken();

    return _transaction(() {
      final prior = _db.select(
        'SELECT * FROM accounts WHERE issuer = ? AND subject = ?',
        [config.issuer, subject],
      ).firstOrNull;
      final AuthAccount account;
      if (prior != null) {
        account = _readAccount(prior);
      } else {
        final invitationHash = attempt['invitation_hash'];
        if (invitationHash == null) throw _invitationRequired;
        final used = _db.select(
          'UPDATE invitations SET used_at = ? WHERE token_hash = ? '
          'AND expires_at > ? AND used_at IS NULL AND revoked_at IS NULL '
          'RETURNING id',
          [
            now.millisecondsSinceEpoch,
            invitationHash,
            now.millisecondsSinceEpoch,
          ],
        );
        if (used.isEmpty) throw _invalidInvitation;
        account = AuthAccount(const Uuid().v4(), false, false);
        _db.execute(
          'INSERT INTO accounts (id, issuer, subject) VALUES (?, ?, ?)',
          [account.id, config.issuer, subject],
        );
      }
      _db.execute('DELETE FROM sessions WHERE expires_at <= ?', [
        now.millisecondsSinceEpoch,
      ]);
      _db.execute('INSERT INTO sessions VALUES (?, ?, ?)', [
        _hash(token),
        account.id,
        expiresAt.millisecondsSinceEpoch,
      ]);
      return AuthLogin(
        account,
        token,
        expiresAt,
        attempt['return_to'] as String,
      );
    });
  }

  T _transaction<T>(T Function() operation) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _provider() async {
    final discovery = _discovery ??= _discover();
    try {
      return await discovery;
    } catch (_) {
      if (identical(_discovery, discovery)) _discovery = null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _discover() async {
    final issuer = config.issuer.replaceFirst(RegExp(r'/$'), '');
    final provider = await _request(
      http.Request(
        'GET',
        Uri.parse('$issuer/.well-known/openid-configuration'),
      ),
    );
    if (provider['issuer'] != config.issuer) throw _signInFailed;
    return provider;
  }

  Uri _endpoint(Object? value) {
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null ||
        !_secureEndpoint(uri) ||
        (uri.scheme != 'https' && Uri.parse(config.issuer).scheme == 'https')) {
      throw _signInFailed;
    }
    return uri;
  }

  Future<String> _exchange(String code, Row attempt) async {
    final provider = await _provider();
    final methods = provider['token_endpoint_auth_methods_supported'];
    final request = http.Request('POST', _endpoint(provider['token_endpoint']));
    final fields = {
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': attempt['verifier'] as String,
      'redirect_uri': config.callback.toString(),
    };
    if (methods == null ||
        (methods is List && methods.contains('client_secret_basic'))) {
      final clientId = Uri.encodeQueryComponent(config.clientId);
      final secret = Uri.encodeQueryComponent(config.clientSecret);
      request.headers['authorization'] =
          'Basic ${base64Encode(ascii.encode('$clientId:$secret'))}';
    } else if (methods is List && methods.contains('client_secret_post')) {
      fields['client_id'] = config.clientId;
      fields['client_secret'] = config.clientSecret;
    } else {
      throw _signInFailed;
    }
    request.bodyFields = fields;
    final tokens = await _request(request);
    final token = tokens['id_token'];
    if (token is! String) throw _signInFailed;

    final keys = await _request(
      http.Request('GET', _endpoint(provider['jwks_uri'])),
    );
    return _validateIdToken(token, keys, attempt['nonce'] as String);
  }

  Future<Map<String, dynamic>> _request(http.Request request) async {
    request.followRedirects = false;
    request.headers['accept'] = 'application/json';
    try {
      return await (() async {
        final response = await _client.send(request);
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          throw _signInFailed;
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 1024 * 1024) throw _signInFailed;
          bytes.addAll(chunk);
        }
        return _json(utf8.decode(bytes));
      })().timeout(const Duration(seconds: 15));
    } on Exception {
      throw _signInFailed;
    }
  }

  Future<String> _validateIdToken(
    String token,
    Map<String, dynamic> jwks,
    String nonce,
  ) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw _signInFailed;
      final header = _json(utf8.decode(_decodeBase64(parts[0])));
      final kid = header['kid'];
      final keys = jwks['keys'];
      if (header['alg'] != 'RS256' ||
          header.containsKey('crit') ||
          header.containsKey('b64') ||
          (kid != null && kid is! String) ||
          keys is! List) {
        throw _signInFailed;
      }
      final matching = keys.whereType<Map>().where(
        (key) =>
            key['kty'] == 'RSA' &&
            (kid == null || key['kid'] == kid) &&
            (key['alg'] == null || key['alg'] == 'RS256') &&
            (key['use'] == null || key['use'] == 'sig') &&
            (key['key_ops'] == null ||
                (key['key_ops'] is List && key['key_ops'].contains('verify'))),
      );
      if (matching.length != 1) throw _signInFailed;
      final key = Map<String, dynamic>.from(matching.single);
      final modulus = key['n'];
      if (modulus is! String ||
          modulus.length > 1366 ||
          _unsignedInteger(_decodeBase64(modulus)).bitLength < 2048) {
        throw _signInFailed;
      }
      final keyStore = JsonWebKeyStore()..addKey(JsonWebKey.fromJson(key));
      final signature = JsonWebSignature.fromCompactSerialization(token);
      final payload = await signature.getPayload(
        keyStore,
        allowedAlgorithms: ['RS256'],
      );
      final claims = _json(utf8.decode(payload.data));
      final subject = claims['sub'];
      final aud = claims['aud'];
      final audiences = aud is String ? [aud] : aud;
      final authorizedParty = claims['azp'];
      final expires = claims['exp'];
      final issued = claims['iat'];
      final notBefore = claims['nbf'];
      final now = _clock().millisecondsSinceEpoch / 1000;
      if (claims['iss'] != config.issuer ||
          !_validSubject(subject) ||
          audiences is! List ||
          audiences.length != 1 ||
          audiences.single != config.clientId ||
          (authorizedParty != null && authorizedParty != config.clientId) ||
          claims['nonce'] != nonce ||
          expires is! num ||
          !expires.isFinite ||
          expires <= now ||
          issued is! num ||
          !issued.isFinite ||
          issued > now + 60 ||
          issued >= expires ||
          (notBefore != null &&
              (notBefore is! num || !notBefore.isFinite || notBefore > now))) {
        throw _signInFailed;
      }
      return subject as String;
    } on Exception {
      throw _signInFailed;
    }
  }
}

bool _validSubject(Object? value) =>
    value is String &&
    value.isNotEmpty &&
    value.length <= 255 &&
    value.codeUnits.every((byte) => byte < 128);

bool _secureEndpoint(Uri uri) =>
    uri.host.isNotEmpty &&
    !uri.hasFragment &&
    uri.userInfo.isEmpty &&
    (uri.scheme == 'https' ||
        (uri.scheme == 'http' &&
            const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)));

AuthAccount _readAccount(Row row) => AuthAccount(
  row['id'] as String,
  row['owner'] == 1,
  row['legacy_owner'] == 1,
);

DateTime _date(int value) =>
    DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

final _random = Random.secure();
String _randomToken() =>
    _base64url(List.generate(32, (_) => _random.nextInt(256)));
String _base64url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
String _hash(String token) => sha256.convert(utf8.encode(token)).toString();

List<int> _decodeBase64(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) throw _signInFailed;
  return base64Url.decode(base64Url.normalize(value));
}

Map<String, dynamic> _json(String value) {
  final parsed = jsonDecode(value);
  if (parsed is! Map<String, dynamic>) throw _signInFailed;
  return parsed;
}

BigInt _unsignedInteger(List<int> bytes) => BigInt.parse(
  bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
  radix: 16,
);

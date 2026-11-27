import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:strength_guru_server/auth.dart';
import 'package:test/test.dart';

// Disposable test key, unrelated to any configured provider.
const _modulus =
    '9551461f66a83a1940569cf745d218b78937d2d476ba94d4843b3f30bd9e826c1a0098cb5b71362ec6c4bad22f01a1d4fcfe4674adea50a49e89602c05077eea43de1f70d55162eb5a32455e7a16ddb923d7f69056de898eaa27f330f47fdc3a322dd348e54684d720eaf29edfb268d1fe55ed5a51e9c406fd2d2c5b3c8c066ab203f10dc43e6db483f71d9141518a217007e03a728e23f33b86b530f69b1787c9beda9a8bbc3fad8a0031d6aa6c8484e107e0d87fabea3366356a1195dd41bd4c6a92c5ffb3eb499611372bf646091ad284925e847f6c45359e8030e5c6d1b874daa675c22f047b59ea9be4e5d32ebc4057ba3dbf647f06f2d7ad519d4dfe4d';
const _privateExponent =
    '248d47b82a1e2652c6202dbe8e55f6fcfed72e821a2a64827d782f68d4123865141c6f4ae0b09f0de65484532d749dd410b68232cfdc1b2fa12b89e25cbcd001b2e96e12e5f54d5cc5b0a6b090fc85fc6b5cd39bd3d8181e5762fe324eb7fa06390064c76470d5d5ffd5e3dca66ffb1ee4bece229d08b796ea6523859615c4fffb7488a97bae9785cbc1816e03a45cd74cd639ec90b224a1cb758f75119284010cdb6a0d61a7c09550754474dca6f5de17fb6a1f2559309cc0cc3a9f14cff58e753cca664b498bcc45d663e4765ace073e0b78ad50f6b0126fdd685d0af9e13980624752e3d6ca0d87b79b7320be2373cd8d00b0ee660de1423df17a737dd6a1';

List<int> _bytes(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

String _base64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String _jwt(Map<String, dynamic> claims, {bool validSignature = true}) {
  final header = _base64(utf8.encode('{"alg":"RS256","kid":"key"}'));
  final payload = _base64(utf8.encode(jsonEncode(claims)));
  final digest = sha256.convert(ascii.encode('$header.$payload')).toString();
  const prefix = '3031300d060960864801650304020105000420';
  final padded = '0001${'ff' * 202}00$prefix$digest';
  final value = BigInt.parse(padded, radix: 16).modPow(
    BigInt.parse(_privateExponent, radix: 16),
    BigInt.parse(_modulus, radix: 16),
  );
  final signature = _bytes(value.toRadixString(16).padLeft(512, '0'));
  if (!validSignature) signature[0] ^= 1;
  return '$header.$payload.${_base64(signature)}';
}

void main() {
  const issuer = 'https://id.example/realm';
  const clientId = 'strength-guru';
  final config = AuthConfig(
    issuer: issuer,
    clientId: clientId,
    clientSecret: 'secret',
    ownerSubject: 'owner-subject',
    origin: 'https://app.example',
  );
  late AuthRegistry registry;
  late Directory directory;
  late DateTime now;
  late Map<String, String> query;
  late String subject;
  late Map<String, dynamic> claimsOverride;
  late bool validSignature;

  http.Client provider() => MockClient((request) async {
    if (request.url.path == '/realm/.well-known/openid-configuration') {
      return http.Response(
        jsonEncode({
          'issuer': issuer,
          'authorization_endpoint': '$issuer/authorize',
          'token_endpoint': '$issuer/token',
          'jwks_uri': '$issuer/jwks',
        }),
        200,
      );
    }
    if (request.url.path == '/realm/jwks') {
      return http.Response(
        jsonEncode({
          'keys': [
            {
              'kty': 'RSA',
              'kid': 'key',
              'n': _base64(_bytes(_modulus)),
              'e': 'AQAB',
            },
          ],
        }),
        200,
      );
    }
    expect(request.url.path, '/realm/token');
    expect(
      request.headers['authorization'],
      'Basic ${base64Encode(ascii.encode('$clientId:secret'))}',
    );
    expect(request.bodyFields['grant_type'], 'authorization_code');
    expect(request.bodyFields['code'], 'code');
    expect(request.bodyFields['redirect_uri'], query['redirect_uri']);
    expect(query['code_challenge_method'], 'S256');
    expect(
      query['code_challenge'],
      _base64(
        sha256
            .convert(ascii.encode(request.bodyFields['code_verifier']!))
            .bytes,
      ),
    );
    return http.Response(
      jsonEncode({
        'id_token': _jwt({
          'iss': issuer,
          'aud': clientId,
          'sub': subject,
          'nonce': query['nonce'],
          'iat': now.millisecondsSinceEpoch ~/ 1000,
          'exp':
              now.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/
              1000,
          ...claimsOverride,
        }, validSignature: validSignature),
      }),
      200,
    );
  });

  String getPath() => '${directory.path}/registry.sqlite';

  AuthRegistry openRegistry() => AuthRegistry(
    getPath(),
    config,
    clock: () => now,
    client: provider(),
    legacyDataset: true,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sg-auth-test');
    now = DateTime.utc(2026, 1, 1);
    subject = 'owner-subject';
    claimsOverride = {};
    validSignature = true;
    registry = openRegistry();
  });

  tearDown(() async {
    registry.close();
    await directory.delete(recursive: true);
  });

  Future<AuthStart> begin({String? invite}) async {
    final start = await registry.begin(invite: invite, returnTo: '/program');
    query = start.url.queryParameters;
    return start;
  }

  Future<AuthLogin> finish(AuthStart start, {String? binding}) =>
      registry.finish(
        state: query['state'],
        code: 'code',
        binding: binding ?? start.binding,
      );
  Matcher failure(String code) =>
      throwsA(isA<AuthFailure>().having((error) => error.code, 'code', code));

  test('reserves the owner and persists a hashed, expiring session', () async {
    final owner = registry.owner!;
    expect(owner.legacyOwner, isTrue);
    final start = await begin();
    await expectLater(
      finish(start, binding: 'different browser'),
      failure('sign_in_failed'),
    );
    final login = await finish(start);
    expect(login.account.id, owner.id);
    expect(login.returnTo, '/program');
    expect(login.expiresAt, now.add(sessionLifetime));
    await expectLater(finish(start), failure('sign_in_failed'));

    final db = sqlite3.open(getPath());
    expect(
      db.select('SELECT token_hash FROM sessions').single['token_hash'],
      sha256.convert(utf8.encode(login.token)).toString(),
    );
    db.close();

    registry.close();
    registry = openRegistry();
    expect(registry.session(login.token)?.account.id, owner.id);
    final second = await finish(await begin());
    registry.logout(second.token);
    expect(registry.session(second.token), isNull);
    expect(registry.session(login.token)?.expiresAt, login.expiresAt);
    now = now.add(sessionLifetime);
    expect(registry.session(login.token), isNull);
  });

  test('fresh owner is not associated with the legacy dataset', () {
    final path = '${directory.path}/fresh.sqlite';
    final fresh = AuthRegistry(path, config);
    final owner = fresh.owner!;
    expect(owner.legacyOwner, isFalse);
    fresh.close();

    final reopened = AuthRegistry(path, config, legacyDataset: true);
    expect(reopened.owner!.id, owner.id);
    expect(reopened.owner!.legacyOwner, isFalse);
    reopened.close();
  });

  test('only an unknown identity consumes an invitation', () async {
    final invitation = registry.invite(registry.owner!);
    await finish(await begin(invite: invitation));
    expect(registry.listInvites(registry.owner!).single['status'], 'active');

    subject = 'new-subject';
    await expectLater(finish(await begin()), failure('invitation_required'));
    final login = await finish(await begin(invite: invitation));
    expect(login.account.owner, isFalse);
    expect(login.account.id, isNot(registry.owner!.id));
    expect(registry.listInvites(registry.owner!).single['status'], 'used');
    expect(() => registry.invite(login.account), failure('owner_required'));
    expect(
      () => registry.listInvites(login.account),
      failure('owner_required'),
    );
    expect((await finish(await begin())).account.id, login.account.id);

    subject = 'other-subject';
    await expectLater(
      finish(await begin(invite: invitation)),
      failure('invalid_invitation'),
    );
  });

  test('expired and revoked invitations reject unknown identities', () async {
    final owner = registry.owner!;
    final expired = registry.invite(owner);
    now = now.add(invitationLifetime);
    expect(registry.listInvites(owner).single['status'], 'expired');
    final revoked = registry.invite(owner);
    final rows = registry.listInvites(owner);
    expect(
      rows.every(
        (row) => row.keys.toSet().containsAll({
          'id',
          'createdAt',
          'expiresAt',
          'status',
        }),
      ),
      isTrue,
    );
    registry.revokeInvite(owner, rows.first['id'] as String);
    expect(registry.listInvites(owner).first['status'], 'revoked');
    subject = 'new-subject';
    for (final token in [expired, revoked]) {
      await expectLater(
        finish(await begin(invite: token)),
        failure('invalid_invitation'),
      );
    }
  });

  test(
    'rejects invalid signatures, issuer, audience, nonce and expired attempts',
    () async {
      validSignature = false;
      await expectLater(finish(await begin()), failure('sign_in_failed'));
      validSignature = true;
      for (final claim in {
        'iss': 'https://other.example',
        'aud': 'other-client',
        'nonce': 'wrong-nonce',
        'azp': 'other-client',
        'nbf': 2000000000,
        'exp': 0,
      }.entries) {
        claimsOverride = {claim.key: claim.value};
        await expectLater(finish(await begin()), failure('sign_in_failed'));
      }
      claimsOverride = {};
      final start = await begin();
      now = now.add(signInLifetime);
      await expectLater(finish(start), failure('sign_in_failed'));
    },
  );
}

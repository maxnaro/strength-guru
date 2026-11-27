import { createHash, generateKeyPairSync, randomUUID, sign } from 'node:crypto';
import { createServer } from 'node:http';

export async function startTestIssuer(port, appOrigin) {
  const issuer = `http://127.0.0.1:${port}`;
  const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const jwk = { ...publicKey.export({ format: 'jwk' }), kid: 'fixture', alg: 'RS256', use: 'sig' };
  const callback = `${appOrigin}/api/v1/auth/callback`;
  const codes = new Map();
  const json = (response, value, status = 200) => {
    response.writeHead(status, { 'content-type': 'application/json' });
    response.end(JSON.stringify(value));
  };
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const server = createServer(async (request, response) => {
    const url = new URL(request.url, issuer);
    const params = url.searchParams;
    if (url.pathname === '/.well-known/openid-configuration') {
      return json(response, {
        issuer,
        authorization_endpoint: `${issuer}/authorize`,
        token_endpoint: `${issuer}/token`,
        jwks_uri: `${issuer}/jwks`,
        response_types_supported: ['code'],
        subject_types_supported: ['public'],
        id_token_signing_alg_values_supported: ['RS256'],
        token_endpoint_auth_methods_supported: ['client_secret_basic', 'client_secret_post'],
        code_challenge_methods_supported: ['S256'],
      });
    }
    if (url.pathname === '/jwks') return json(response, { keys: [jwk] });
    if (url.pathname === '/authorize' && params.get('redirect_uri') === callback &&
        params.get('client_id') === 'strength-guru-test' &&
        params.get('code_challenge_method') === 'S256') {
      const code = randomUUID();
      const subject = params.get('test_subject') ?? 'demo-owner';
      codes.set(code, { subject, nonce: params.get('nonce'), challenge: params.get('code_challenge') });
      const to = new URL(callback);
      to.search = new URLSearchParams({ code, state: params.get('state') });
      response.writeHead(302, { location: to.toString() });
      return response.end();
    }
    if (url.pathname === '/token' && request.method === 'POST') {
      let body = '';
      for await (const chunk of request) body += chunk;
      const form = new URLSearchParams(body);
      const credentials = Buffer.from('strength-guru-test:disposable-client-secret').toString('base64');
      if (request.headers.authorization !== `Basic ${credentials}` &&
          (form.get('client_id') !== 'strength-guru-test' ||
            form.get('client_secret') !== 'disposable-client-secret')) {
        return json(response, { error: 'invalid_client' }, 401);
      }
      const code = codes.get(form.get('code'));
      codes.delete(form.get('code'));
      if (!code || !form.has('code_verifier') || form.get('redirect_uri') !== callback ||
          createHash('sha256').update(form.get('code_verifier')).digest('base64url') !== code.challenge) {
        return json(response, { error: 'invalid_grant' }, 400);
      }
      const now = Math.floor(Date.now() / 1000);
      const unsigned = `${encode({ kid: jwk.kid, alg: jwk.alg })}.${encode({
        iss: issuer, aud: 'strength-guru-test', sub: code.subject,
        nonce: code.nonce, iat: now, exp: now + 300,
      })}`;
      const signature = sign('RSA-SHA256', Buffer.from(unsigned), privateKey).toString('base64url');
      return json(response, { id_token: `${unsigned}.${signature}`, access_token: randomUUID(), token_type: 'Bearer', expires_in: 300 });
    }
    return json(response, { error: 'not_found' }, 404);
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolve);
  });
  return issuer;
}

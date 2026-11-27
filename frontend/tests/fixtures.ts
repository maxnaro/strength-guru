import { test as base, request as playwrightRequest, type APIRequestContext } from '@playwright/test';

export async function signIn(
  request: APIRequestContext,
  origin: string,
  subject = 'demo-owner',
  invite?: string,
) {
  const start = await request.post('/api/v1/auth/login', {
    headers: { origin },
    data: { invite },
  });
  if (!start.ok()) throw new Error(`Sign-in start failed: ${await start.text()}`);
  const target = new URL((await start.json()).authorizationUrl);
  if (target.hostname !== '127.0.0.1') throw new Error('Expected disposable test issuer');
  target.searchParams.set('test_subject', subject);
  await request.get(target.toString());
  return request.get('/api/v1/auth/session');
}

export const test = base.extend({
  context: async ({ context, baseURL }, use) => {
    const session = await signIn(context.request, baseURL!);
    if (!session.ok()) throw new Error(`Browser fixture sign-in failed: ${await session.text()}`);
    await use(context);
  },
  request: async ({ baseURL }, use) => {
    const anonymous = await playwrightRequest.newContext({ baseURL });
    try {
      const session = await signIn(anonymous, baseURL!);
      if (!session.ok()) throw new Error(`API fixture sign-in failed: ${await session.text()}`);
      const authenticated = await playwrightRequest.newContext({
        baseURL,
        storageState: await anonymous.storageState(),
        extraHTTPHeaders: { 'x-strength-guru-account': (await session.json()).accountId },
      });
      try {
        await use(authenticated);
      } finally {
        await authenticated.dispose();
      }
    } finally {
      await anonymous.dispose();
    }
  },
});

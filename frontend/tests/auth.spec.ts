import { expect, test } from '@playwright/test';
import { signIn } from './fixtures';

const accountHeaders = (accountId: string, origin: string) => ({
  'x-strength-guru-account': accountId,
  origin,
});

test('sign-in gates new accounts and isolates training and backups', async ({ browser, baseURL }) => {
  const origin = baseURL!;
  const owner = await browser.newContext({ baseURL });
  const guest = await browser.newContext({ baseURL });
  try {
    expect((await guest.request.get('/api/v1/sync')).status()).toBe(401);
    expect((await signIn(guest.request, origin, 'uninvited')).status()).toBe(401);

    const ownerSession = await signIn(owner.request, origin);
    expect(ownerSession.ok()).toBeTruthy();
    const a = await ownerSession.json();
    expect(a).toMatchObject({ owner: true, legacyOwner: true });
    const ownerHeaders = accountHeaders(a.accountId, origin);
    const created = await owner.request.post('/api/v1/auth/invites', { headers: ownerHeaders, data: {} });
    expect(created.status()).toBe(201);
    const link = new URL((await created.json()).url);
    expect(link.pathname).toBe('/invite');

    await guest.route('**/authorize?*', route => {
      const destination = new URL(route.request().url());
      destination.searchParams.set('test_subject', 'invited-guest');
      return route.continue({ url: destination.toString() });
    });
    const page = await guest.newPage();
    await page.goto(link.toString());
    await expect(page.getByText('Sign in to accept your invitation.')).toBeVisible();
    await page.getByRole('button', { name: 'Sign in', exact: true }).click();
    await expect(page.getByText('No active mesocycle.')).toBeVisible();
    const guestSession = await guest.request.get('/api/v1/auth/session');
    expect(guestSession.ok()).toBeTruthy();
    const b = await guestSession.json();
    expect(b).toMatchObject({ owner: false, legacyOwner: false });
    expect(b.accountId).not.toBe(a.accountId);

    const guestHeaders = accountHeaders(b.accountId, origin);
    const guestSync = await guest.request.get('/api/v1/sync', { headers: guestHeaders });
    expect((await guestSync.json()).snapshot.mesocycles).toEqual([]);
    const ownerSync = await owner.request.get('/api/v1/sync', { headers: ownerHeaders });
    expect((await ownerSync.json()).snapshot.mesocycles.length).toBeGreaterThan(0);
    expect((await guest.request.get('/api/v1/backups', { headers: ownerHeaders })).status()).toBe(409);
    const backup = await owner.request.get('/api/v1/backups', { headers: ownerHeaders });
    expect(backup.ok()).toBeTruthy();
    const staged = await owner.request.post('/api/v1/backups/inspect', {
      headers: { ...ownerHeaders, 'content-type': 'application/vnd.sqlite3' },
      data: await backup.body(),
    });
    expect(staged.ok()).toBeTruthy();
    const foreignRestore = await guest.request.post('/api/v1/backups/restore', {
      headers: guestHeaders,
      data: { token: (await staged.json()).token, confirmed: true },
    });
    expect(await foreignRestore.json()).toMatchObject({ code: 'expired_import' });
    expect((await guest.request.get('/api/v1/auth/invites', { headers: guestHeaders })).status()).toBe(403);

    const used = await owner.request.get('/api/v1/auth/invites', { headers: ownerHeaders });
    expect((await used.json()).invites).toEqual(expect.arrayContaining([expect.objectContaining({ status: 'used' })]));

    expect((await guest.request.post('/api/v1/auth/logout', { headers: guestHeaders, data: {} })).ok()).toBeTruthy();
    expect((await signIn(guest.request, origin, 'invited-guest')).ok()).toBeTruthy();
  } finally {
    await guest.close();
    await owner.close();
  }
});

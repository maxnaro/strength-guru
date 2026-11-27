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

    const guestSession = await signIn(guest.request, origin, 'invited-guest', link.hash.slice(1));
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
    expect((await guest.request.get('/api/v1/auth/invites', { headers: guestHeaders })).status()).toBe(403);

    const used = await owner.request.get('/api/v1/auth/invites', { headers: ownerHeaders });
    expect((await used.json()).invites).toEqual(expect.arrayContaining([expect.objectContaining({ status: 'used' })]));

    const page = await guest.newPage();
    await page.goto('/meso');
    await expect(page.getByText('No active mesocycle.')).toBeVisible();
    expect((await guest.request.post('/api/v1/auth/logout', { headers: guestHeaders, data: {} })).ok()).toBeTruthy();
    expect((await signIn(guest.request, origin, 'invited-guest')).ok()).toBeTruthy();
  } finally {
    await guest.close();
    await owner.close();
  }
});

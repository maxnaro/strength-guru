import { expect } from '@playwright/test';
import { signIn, test } from './fixtures';
import { monday, ready, replica } from './helpers';

test.use({ serviceWorkers: 'block' });

test('sign-out closes training across tabs and account switching leaves pending edits scoped', async ({ context, page, baseURL }) => {
  const origin = baseURL!;
  const session = await (await context.request.get('/api/v1/auth/session')).json();
  const invitation = await context.request.post('/api/v1/auth/invites', {
    headers: { origin, 'x-strength-guru-account': session.accountId },
    data: {},
  });
  expect(invitation.status()).toBe(201);
  const token = new URL((await invitation.json()).url).hash.slice(1);

  const other = await context.newPage();
  await ready(other, '/meso');
  await monday(page);
  await context.route('**/api/v1/commands', route => route.abort());
  await page.getByRole('button', { name: /^Log set/ }).first().click();
  await expect(page.locator('.sync-banner')).toContainText('pending sync');
  const ownerOutbox = (await replica(page)).outbox;
  expect(ownerOutbox.some((change: any) => change.body.type === 'upsertSetEntry')).toBe(true);

  await page.locator('.sync-banner').click();
  await page.getByRole('button', { name: 'Account', exact: true }).click();
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Sign in', exact: true })).toBeEnabled();
  await expect(other.getByRole('button', { name: 'Sign in', exact: true })).toBeVisible();
  await expect(other.getByRole('navigation', { name: 'Main navigation' })).toHaveCount(0);

  const guestSession = await signIn(context.request, origin, 'account-switch-guest', token);
  expect(guestSession.ok()).toBeTruthy();
  await ready(other, '/meso');
  await expect(other.getByText('No active mesocycle.')).toBeVisible();
  expect((await replica(other)).outbox).toEqual([]);
  await context.unroute('**/api/v1/commands');
  await expect(page.locator('.sync-banner')).toHaveText('Synced');
  expect((await replica(page)).outbox).toEqual([]);

  const retained = await page.evaluate(accountId => new Promise((resolve, reject) => {
    const open = indexedDB.open('strength-guru-replica');
    open.onerror = () => reject(open.error);
    open.onsuccess = () => {
      const db = open.result;
      const tx = db.transaction('replica');
      const stored = tx.objectStore('replica').get(`account:${accountId}`);
      tx.oncomplete = () => {
        resolve(stored.result.outbox);
        db.close();
      };
      tx.onabort = () => {
        reject(tx.error);
        db.close();
      };
    };
  }), session.accountId);
  expect(retained).toMatchObject(ownerOutbox.map(
    ({ id, body, state }: { id: string; body: unknown; state: string }) => ({ id, body, state }),
  ));
});

test('legacy browser data is adopted only after owner confirmation', async ({ context, page }) => {
  const session = await (await context.request.get('/api/v1/auth/session')).json();
  const response = await context.request.get('/api/v1/sync', {
    headers: { 'x-strength-guru-account': session.accountId },
  });
  expect(response.ok()).toBeTruthy();
  const { epoch, cursor, snapshot, revisions } = await response.json();
  const fixtureURL = '/migration-fixture.html';
  await page.route(`**${fixtureURL}`, route => route.fulfill({
    contentType: 'text/html',
    body: '<!doctype html><title>Legacy browser fixture</title>',
  }));
  await page.goto(fixtureURL);
  await page.evaluate(({ epoch, cursor, snapshot, revisions }) => Promise.all([
    new Promise<void>((resolve, reject) => {
      const open = indexedDB.open('strength-guru-replica', 2);
      open.onupgradeneeded = () => {
        open.result.createObjectStore('replica').put({
          epoch,
          cursor,
          revisions: Object.fromEntries(revisions.map(({ resource, revision }: { resource: string; revision: number }) => [resource, revision])),
          outbox: [],
          tableGeneration: 1,
        }, 'current');
        open.result.createObjectStore('canonical').put(snapshot, 'current');
      };
      open.onsuccess = () => {
        open.result.close();
        resolve();
      };
      open.onerror = () => reject(open.error);
    }),
    new Promise<void>((resolve, reject) => {
      const open = indexedDB.open('strength-guru-workflows', 1);
      open.onupgradeneeded = () => {
        open.result.createObjectStore('drafts').put({ description: 'Legacy generation input' }, 'generation:legacy-tab');
      };
      open.onsuccess = () => {
        open.result.close();
        resolve();
      };
      open.onerror = () => reject(open.error);
    }),
    sessionStorage.setItem('sg-tab', 'legacy-tab'),
  ]), { epoch, cursor, snapshot, revisions });

  await page.goto('/log');
  await expect(page.getByRole('heading', { name: 'Import previous app data' })).toBeVisible();
  await expect(page.getByRole('navigation', { name: 'Main navigation' })).toHaveCount(0);
  expect((await replica(page)).epoch).toBeUndefined();
  await page.getByRole('button', { name: 'Import previous app data', exact: true }).click();
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  expect(await replica(page)).toMatchObject({ epoch, legacyAdopted: true });
  expect(await page.evaluate(accountId => sessionStorage.getItem(`sg-tab:${accountId}`), session.accountId)).toBe('legacy-tab');
  const generation = await page.evaluate(accountId => new Promise((resolve, reject) => {
    const open = indexedDB.open('strength-guru-workflows');
    open.onsuccess = () => {
      const db = open.result;
      const read = db.transaction('drafts').objectStore('drafts').get(`account:${accountId}:generation:legacy-tab`);
      read.onsuccess = () => {
        resolve(read.result);
        db.close();
      };
      read.onerror = () => {
        reject(read.error);
        db.close();
      };
    };
    open.onerror = () => reject(open.error);
  }), session.accountId);
  expect(generation).toMatchObject({ description: 'Legacy generation input' });
});

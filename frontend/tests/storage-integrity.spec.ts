import { test } from './fixtures';
import { expect } from '@playwright/test';
import { ready, monday, replica } from './helpers';

test('invalid fractional reps stay in the form without creating an operation', async ({ page }) => {
  await ready(page);
  await monday(page);
  const before = await replica(page);
  await page.getByRole('spinbutton', { name: 'REPS', exact: true }).fill('8.5');
  await page.getByRole('button', { name: /^Log set/ }).first().click();
  await expect(page.getByRole('alert')).toContainText('whole number of reps');
  expect((await replica(page)).outbox).toEqual(before.outbox);
});

test('a failed IndexedDB transaction never reports a successful local save', async ({ page }) => {
  await ready(page);
  await monday(page);
  const before = await replica(page);
  const completed = await page.getByRole('button', { name: /Edit saved set/ }).count();
  await page.evaluate(() => {
    const original = IDBObjectStore.prototype.put;
    (window as any).restoreStorageWrites = () => { IDBObjectStore.prototype.put = original; };
    IDBObjectStore.prototype.put = function (...args: Parameters<IDBObjectStore['put']>) {
      if (this.name === 'replica') {
        this.transaction.abort();
        throw new DOMException('Local storage is full', 'QuotaExceededError');
      }
      return original.apply(this, args);
    };
  });
  try {
    await page.getByRole('button', { name: /^Log set/ }).first().click();
    await expect(page.getByText('Local storage is full', { exact: true }).first()).toBeVisible();
    expect((await replica(page)).outbox).toEqual(before.outbox);
    expect((await replica(page)).tables.set_entries).toEqual(before.tables.set_entries);
    await expect(page.getByRole('button', { name: /Edit saved set/ })).toHaveCount(completed);
  } finally {
    await page.evaluate(() => (window as any).restoreStorageWrites());
  }
});

test.describe('Network fault injection', () => {
  test.use({ serviceWorkers: 'block' });

  test('local logging does not wait for a stalled synchronization request', async ({ page, context }) => {
    await ready(page);
    await monday(page);
    let release!: () => void;
    let intercepted = false;
    const gate = new Promise<void>(resolve => { release = resolve; });
    await context.route('**/api/v1/sync**', async route => {
      intercepted = true;
      await gate;
      await route.continue();
    });
    try {
      await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
      await expect.poll(() => intercepted).toBe(true);
      const started = Date.now();
      await page.getByRole('button', { name: /^Log set/ }).first().click();
      await expect(page.getByRole('button', { name: /Edit saved set/ }).first()).toBeVisible();
      await expect.poll(async () => (await replica(page)).outbox.some((q: any) => q.body.type === 'upsertSetEntry')).toBe(true);
      expect(Date.now() - started).toBeLessThan(1000);
      expect((await replica(page)).outbox.some((q: any) => q.body.type === 'upsertSetEntry')).toBe(true);
    } finally {
      release();
    }
    await expect(page.locator('.sync-banner')).toContainText('Synced', { timeout: 30_000 });
  });
});

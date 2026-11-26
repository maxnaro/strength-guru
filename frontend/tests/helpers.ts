import { expect, type Page } from '@playwright/test';
export async function ready(page: Page, path = '/') {
  await page.goto(path);
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  await expect(page.locator('main h1').first()).toBeVisible();
}
export async function offlineReady(page: Page) {
  await expect.poll(() => page.evaluate(() => Boolean(navigator.serviceWorker.controller)), {
    message: 'Wait for the service worker to control the page',
  }).toBe(true);
}
export async function monday(page: Page) {
  await page.goto('/log');
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  await page.getByRole('button', { name: 'Monday', exact: true }).click();
  await expect(page.locator('.exercise-card').first()).toBeVisible();
}
export async function replica(page: Page): Promise<any> {
  return page.evaluate(() => new Promise((resolve, reject) => {
    // Opening the existing version avoids changing storage while observing it.
    const request = indexedDB.open('strength-guru-replica');
    request.onsuccess = () => {
      const db = request.result;
      const split = db.objectStoreNames.contains('canonical');
      const tx = db.transaction(split ? ['replica', 'canonical'] : ['replica'], 'readonly');
      const meta = tx.objectStore('replica').get('current');
      const tables = split ? tx.objectStore('canonical').get('current') : undefined;
      tx.oncomplete = () => { resolve(split ? { ...meta.result, tables: tables!.result } : meta.result); db.close(); };
      tx.onabort = tx.onerror = () => { reject(tx.error); db.close(); };
    };
    request.onerror = () => reject(request.error);
  }));
}

// Run with NODE_PATH pointing to an installation of the playwright package.
const assert = require('node:assert/strict');
const {chromium} = require('playwright');

(async () => {
  const browser = await chromium.launch({headless: true, args: ['--no-sandbox']});
  try {
    const context = await browser.newContext({viewport: {width: 390, height: 844}, deviceScaleFactor: 1, isMobile: true, hasTouch: true});
    if (process.env.FORCE_CANVASKIT === '1') {
      await context.route('**/flutter_bootstrap.js', async route => {
        const response = await route.fetch();
        const source = (await response.text()).replace(/_flutter\.buildConfig = (\{[^\n]+\});/, (_, encoded) => {
          const config = JSON.parse(encoded);
          config.builds = config.builds.filter(build => build.compileTarget === 'dart2js');
          return '_flutter.buildConfig = ' + JSON.stringify(config) + ';';
        });
        await route.fulfill({response, body: source});
      });
    }
    const page = await context.newPage();
    const errors = [];
    page.on('response', async response => { if (response.url().endsWith('/commands') && response.status() >= 400) console.log('COMMAND', response.status(), await response.text()); });
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(() => {
      window.addEventListener('flutter-first-frame', () => { window.firstFrameAt = performance.now(); });
    });
    const origin = process.env.APP_ORIGIN || 'http://127.0.0.1:18765';
    await page.goto(origin);
    await page.waitForFunction(() => window.firstFrameAt, {timeout: 30000});
    await page.evaluate(async () => {
      await navigator.serviceWorker.ready;
      while (!(await caches.keys()).some(key => key.startsWith('strength-guru-'))) await new Promise(resolve => setTimeout(resolve, 100));
      const cache = await caches.open((await caches.keys()).find(key => key.startsWith('strength-guru-')));
      const assets = await (await fetch('/precache.json')).json();
      while ((await cache.keys()).length < assets.length) await new Promise(resolve => setTimeout(resolve, 100));
    });
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click()).catch(() => {});
    await page.getByText('Synced', {exact: true}).waitFor({timeout: 30000});
    const cold = await page.evaluate(() => performance.now());
    await page.screenshot({path: '/tmp/strength-guru-online.png'});
    const wasm = await context.request.get(`${origin}/sqlite3.wasm`);
    assert.match(wasm.headers()['content-type'], /application\/wasm/);
    assert.equal((await context.request.get(`${origin}/api/v1/health`)).status(), 200);
    assert.equal((await context.request.get(`${origin}/missing-file.js`)).status(), 404);
    assert.equal((await context.request.post(`${origin}/api/v1/commands`, {headers: {origin: 'https://untrusted.example'}, data: {}})).status(), 403);
    const before = (await (await context.request.get(`${origin}/api/v1/sync`)).json()).snapshot.set_entries.length;
    await context.setOffline(true);
    const start = Date.now();
    await page.reload({waitUntil: 'domcontentloaded'});
    await page.waitForFunction(() => window.firstFrameAt, {timeout: 10000});
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click()).catch(() => {});
    await page.getByText('Offline · saved on this device', {exact: true}).waitFor({timeout: 10000});
    assert.equal(await page.locator('#loading').count(), 0);
    const offlineReady = Date.now() - start;
    await page.screenshot({path: '/tmp/strength-guru-offline.png'});
    await page.getByRole('button', {name: 'LOG', exact: true}).click();
    const savedBefore = await page.evaluate(() => [...document.querySelectorAll('flt-semantics')].filter(element => /Set \d+ saved/.test(element.getAttribute('aria-label') || element.textContent || '')).length);
    await page.getByText('Log set', {exact: false}).first().click({timeout: 15000}).catch(async error => { await page.screenshot({path:'/tmp/sg-log-failure.png'}); console.log((await page.locator('flt-semantics-host').innerText()).slice(0,4000)); throw error; });
    await page.waitForFunction(before => [...document.querySelectorAll('flt-semantics')].filter(element => /Set \d+ saved/.test(element.getAttribute('aria-label') || element.textContent || '')).length > before, savedBefore, {timeout: 10000}).catch(async error => { await page.screenshot({path:'/tmp/sg-save-failure.png'}); console.log((await page.locator('flt-semantics-host').innerText()).slice(0,5000)); throw error; });
    await page.getByText(/changes pending sync/).waitFor({timeout: 10000});
    await page.reload({waitUntil: 'domcontentloaded'});
    await page.waitForFunction(() => window.firstFrameAt, {timeout: 10000});
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click()).catch(() => {});
    await page.getByText(/changes pending sync/).waitFor({timeout: 10000});
    await context.setOffline(false);
    await page.getByText('Synced', {exact: true}).waitFor({timeout: 30000}).catch(async error => { console.log((await page.locator('flt-semantics-host').innerText()).slice(0,4000)); await page.screenshot({path:'/tmp/sg-sync-failure.png'}); throw error; });
    const after = (await (await context.request.get(`${origin}/api/v1/sync`)).json()).snapshot.set_entries.length;
    assert.equal(after, before + 1, 'Offline set must synchronize exactly once after reload');

    console.log(JSON.stringify({coldReadyMs: Math.round(cold), offlineReloadMs: offlineReady, errors}, null, 2));
    assert.deepEqual(errors, []);
    await context.close();
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });

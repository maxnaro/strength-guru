import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { ready, monday, offlineReady, replica } from './helpers';

test('real API, direct URLs, semantic controls and missing assets', async ({ page, request }) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  for (const path of ['/', '/today', '/log', '/meso', '/generate', '/import']) {
    await ready(page, path);
    if(path==='/' || path==='/today')await expect(page).toHaveURL(/\/log$/);
    await expect(page.getByRole('navigation', {name:'Main navigation'})).toBeVisible();
  }
  await expect(page.getByRole('navigation', {name:'Main navigation'}).getByRole('link')).toHaveText(['LOG', 'MESO']);
  expect((await request.get('/missing-file.js')).status()).toBe(404);
  expect((await request.get('/api/v1/unknown')).status()).toBe(404);
  expect((await request.post('/api/v1/commands', { headers: {origin: 'https://untrusted.example'}, data: {} })).status()).toBe(403);
  expect((await request.get('/sw.js')).headers()['cache-control']).toContain('no-cache');
  const metrics=await (await request.get('/build-metrics.json')).json();
  const immutable=metrics.assets.find((a:any)=>a.path.startsWith('_app/immutable/')&&a.path.endsWith('.js'));
  expect((await request.get('/'+immutable.path)).headers()['cache-control']).toContain('immutable');
  expect((await (await request.get('/manifest.json')).json()).display).toBe('standalone');
  expect((await request.get('/icon.png')).ok()).toBeTruthy();
  await ready(page);
  await expect(page.locator('canvas, flutter-view, flt-glass-pane')).toHaveCount(0);
  const results = await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa']).analyze();
  expect(results.violations.map(v => ({id:v.id,description:v.description,nodes:v.nodes.map(n=>n.target)}))).toEqual([]);
  expect(errors).toEqual([]);
});

test('offline set survives browser page restart and synchronizes exactly once', async ({ page, context, request }) => {
  await ready(page); await monday(page); await offlineReady(page);
  const before = await (await request.get('/api/v1/sync')).json();
  const beforeCount = before.snapshot.set_entries.length;
  await context.setOffline(true);
  await page.getByRole('button', {name:/^Log set/}).first().click();
  await expect(page.getByRole('button', {name:/Edit saved set/}).first()).toBeVisible();
  await expect(page.locator('.sync-banner')).toContainText('pending sync');
  const queued = await replica(page);
  expect(queued.outbox.some((q:any)=>q.body.type==='upsertSetEntry')).toBeTruthy();
  await page.close();
  const reopened = await context.newPage();
  await reopened.goto('/log');
  await expect(reopened.locator('.sync-banner')).toContainText('pending sync');
  await reopened.getByRole('button', {name:'Monday',exact:true}).click();
  await expect(reopened.getByRole('button',{name:/Edit saved set/}).first()).toBeVisible();
  expect((await replica(reopened)).outbox.map((q:any)=>q.id)).toEqual(queued.outbox.map((q:any)=>q.id));
  await context.setOffline(false);
  await expect(reopened.locator('.sync-banner')).toContainText('Synced', {timeout:30_000});
  const after = await (await request.get('/api/v1/sync')).json();
  expect(after.snapshot.set_entries.length).toBe(beforeCount+1);
  await reopened.reload();
  await expect(reopened.locator('.sync-banner')).toContainText('Synced');
  expect((await (await request.get('/api/v1/sync')).json()).snapshot.set_entries.length).toBe(beforeCount+1);
});

test('two tabs retain concurrent offline edits and recover a lost acknowledgement', async ({ page, context, request }) => {
  await ready(page); await monday(page); await offlineReady(page);
  const other = await context.newPage(); await ready(other); await monday(other); await other.getByRole('button', {name:'Tuesday',exact:true}).click();
  const before = (await (await request.get('/api/v1/sync')).json()).snapshot.set_entries.length;
  await context.setOffline(true);
  await Promise.all([
    page.getByRole('button', {name:/^Log set/}).first().click(),
    other.getByRole('button', {name:/^Log set/}).first().click()
  ]);
  await expect.poll(async()=> (await replica(page)).outbox.filter((q:any)=>q.body.type==='upsertSetEntry').length).toBe(2);
  let lost = false;
  await context.route('**/api/v1/commands', async route => {
    if (!lost) { lost=true; await route.fetch(); await route.abort('failed'); }
    else await route.continue();
  });
  await context.setOffline(false);
  await expect.poll(()=>lost).toBe(true);
  await page.reload();
  await expect(page.locator('.sync-banner')).toContainText('Synced', {timeout:30_000});
  await expect(other.locator('.sync-banner')).toContainText('Synced', {timeout:30_000});
  expect((await (await request.get('/api/v1/sync')).json()).snapshot.set_entries.length).toBe(before+2);
  expect((await replica(page)).outbox).toEqual([]);
});

test('calculator, theme and native dialogs support keyboard focus', async ({page})=>{
  await ready(page);
  const calculator = page.getByRole('button',{name:'Rep Calculator'});
  await calculator.press('Enter');
  const dialog=page.getByRole('dialog',{name:'Rep Calculator'});
  await expect(dialog).toBeVisible();
  await page.keyboard.press('Escape'); await expect(dialog).not.toBeVisible();
  await expect(calculator).toBeFocused();
  await page.getByRole('link',{name:'MESO',exact:true}).click();
  await page.getByRole('button',{name:'About, backup and restore'}).click();
  await expect(page.getByRole('dialog',{name:'About StrengthGuru'})).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);
});

test('conflicting edits retain local data until explicitly discarded', async ({page,context,browser,baseURL,request})=>{
  await ready(page); await monday(page); await offlineReady(page);
  // Ensure this test works by itself as well as after the offline logging checks.
  if(!await page.getByRole('button',{name:/Edit saved set/}).count()) {
    await page.getByRole('button',{name:/^Log set/}).first().click();
    await expect(page.locator('.sync-banner')).toContainText('Synced');
  }
  const remote=await browser.newContext({baseURL});
  try {
    const other=await remote.newPage(); await ready(other); await monday(other);
    await context.setOffline(true);
    await page.getByRole('button',{name:/Edit saved set/}).first().click();
    await page.getByRole('spinbutton',{name:'WEIGHT (KG)',exact:true}).fill('82.5');
    await page.getByRole('button',{name:/^Log set/}).first().click();
    await expect(page.locator('.sync-banner')).toContainText('pending sync');
    await other.getByRole('button',{name:/Edit saved set/}).first().click();
    await other.getByRole('spinbutton',{name:'WEIGHT (KG)',exact:true}).fill('90');
    await other.getByRole('button',{name:/^Log set/}).first().click();
    await expect.poll(async()=>{const s=await (await request.get('/api/v1/sync')).json();return s.snapshot.set_entries.some((e:any)=>e.weight===90);}).toBe(true);
    await context.setOffline(false);
    await expect(page.locator('.sync-banner')).toContainText('need review',{timeout:30_000});
    const r=await replica(page);
    expect(r.outbox.some((q:any)=>q.state==='conflict' && q.body.payload.weight===82.5)).toBeTruthy();
    await page.locator('.sync-banner').click();
    await page.getByRole('button',{name:'Use server version'}).first().click();
    await page.getByRole('button',{name:'Confirm',exact:true}).click();
    await expect(page.locator('.sync-banner')).toContainText('Synced');
    expect((await replica(page)).outbox).toEqual([]);
  } finally { await remote.close(); }
});

test('server restore preserves pending local operations for export and discard', async ({page,context,request,baseURL})=>{
  await ready(page); await monday(page); await offlineReady(page);
  const backup=await request.get('/api/v1/backups'); expect(backup.ok()).toBeTruthy();
  await context.setOffline(true);
  await page.getByRole('button',{name:/^Log set/}).first().click();
  await expect(page.locator('.sync-banner')).toContainText('pending sync');
  const queued=await replica(page);
  const preview=await request.post('/api/v1/backups/inspect',{headers:{origin:baseURL!,'content-type':'application/vnd.sqlite3'},data:await backup.body()});
  expect(preview.ok()).toBeTruthy();
  const restored=await request.post('/api/v1/backups/restore',{headers:{origin:baseURL!},data:{token:(await preview.json()).token,confirmed:true,expectedEpoch:queued.epoch}});
  expect(restored.ok()).toBeTruthy();
  await context.setOffline(false);
  await expect(page.locator('.sync-banner')).toContainText('pending sync');
  await page.locator('.sync-banner').click();
  await expect(page.getByRole('dialog')).toContainText(/restored|replaced|Export|export/);
  expect((await replica(page)).outbox.map((q:any)=>q.id)).toEqual(queued.outbox.map((q:any)=>q.id));
  const download=page.waitForEvent('download');
  await page.getByRole('button',{name:'Export pending changes',exact:true}).click();
  expect((await download).suggestedFilename()).toBe('strength-guru-pending.json');
});

test('capture populated desktop and mobile Log evidence', async ({page,request},testInfo)=>{
  const snapshot=(await (await request.get('/api/v1/sync')).json()).snapshot;
  const meso=snapshot.mesocycles.find((m:any)=>m.is_active);
  await page.setViewportSize({width:1365,height:1000});
  await ready(page,`/?meso=${meso.id}&week=0&day=0`);
  await page.screenshot({path:testInfo.outputPath('desktop-log.png'),fullPage:true,scale:'css'});
  await page.setViewportSize({width:390,height:844});
  await ready(page,`/log?meso=${meso.id}&week=0&day=0`);
  await page.screenshot({path:testInfo.outputPath('mobile-log.png'),fullPage:true,scale:'css'});
});

test('changing weeks resets unsaved set inputs and direct session URLs survive reload',async({page})=>{
  await ready(page);await monday(page);
  await page.getByRole('spinbutton',{name:'WEIGHT (KG)',exact:true}).fill('123.5');
  await page.getByRole('spinbutton',{name:'REPS',exact:true}).fill('47');
  await page.getByRole('button',{name:'WEEK 2',exact:true}).click();
  await expect(page).toHaveURL(/week=1/);
  await expect(page.getByRole('spinbutton',{name:'WEIGHT (KG)',exact:true})).not.toHaveValue('123.5');
  await expect(page.getByRole('spinbutton',{name:'REPS',exact:true})).not.toHaveValue('47');
  const url=page.url();await page.reload();
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  expect(page.url()).toBe(url);
  await expect(page.getByRole('button',{name:'WEEK 2',exact:true})).toHaveAttribute('aria-pressed', 'true');
});

test('home and legacy Today bookmarks preserve the selected set', async ({page, request}) => {
  const snapshot = (await (await request.get('/api/v1/sync')).json()).snapshot;
  const meso = snapshot.mesocycles.find((m: any) => m.is_active);
  const monday = snapshot.day_overrides.find((day: any) =>
    day.mesocycle_id === meso.id && day.week_idx === 0 && day.day_idx === 0);
  const slot = monday.exercise_ids_csv.split(',')[0];
  const query = new URLSearchParams({meso: meso.id, week: '0', day: '0', slot: `${slot}:1`});
  for (const path of ['/', '/today']) {
    await ready(page, `${path}?${query}`);
    await expect(page).toHaveURL(url =>
      url.pathname === '/log' && [...query].every(([key, value]) => url.searchParams.get(key) === value));
    await expect(page.locator('.active-set').getByText('Set 2', {exact: true})).toBeVisible();
  }
});

test('day pager follows exercise cards and crosses week and mesocycle boundaries', async ({page}) => {
  await ready(page, '/log?week=0&day=0');
  const previous = page.getByRole('button', {name: /Previous day/});
  const next = page.getByRole('button', {name: /Next day/});
  const week = page.getByRole('button', {name: /^WEEK \d+$/});
  const sunday = page.getByRole('button', {name: 'Sunday', exact: true});
  await expect(previous).toBeDisabled();
  await expect(next).toBeEnabled();
  const lastCard = (await page.locator('.exercise-card').last().boundingBox())!;
  const nextButton = (await next.boundingBox())!;
  expect(nextButton.y).toBeGreaterThanOrEqual(lastCard.y + lastCard.height);
  expect(nextButton.height).toBeGreaterThanOrEqual(44);
  expect((await previous.boundingBox())!.height).toBeGreaterThanOrEqual(44);

  await sunday.click();
  await expect(page.getByRole('heading', {name: /Recovery day/})).toBeVisible();
  await expect(page.getByRole('button', {name: 'Rep Calculator'})).toBeVisible();
  await next.click();
  await expect(week.nth(1)).toHaveAttribute('aria-pressed', 'true');
  await expect(page.getByRole('button', {name: 'Monday', exact: true})).toHaveAttribute('aria-pressed', 'true');
  await page.locator('.exercise-card').last().scrollIntoViewIfNeeded();
  await previous.click();
  await expect(week.nth(0)).toHaveAttribute('aria-pressed', 'true');
  await expect(sunday).toHaveAttribute('aria-pressed', 'true');
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(0);

  await week.last().click();
  await expect(next).toBeDisabled();
  await expect(previous).toBeEnabled();
});

test('main screens meet automated WCAG checks in light and dark themes',async({page})=>{
  test.setTimeout(60_000);
  const violations:any[]=[];
  for(const colorScheme of ['light','dark'] as const){
    await page.emulateMedia({colorScheme});
    for(const path of ['/','/log','/meso','/generate','/import']){
      await ready(page,path);
      if(path==='/log')await page.getByRole('button', {name:'Monday',exact:true}).click();
      const results=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21aa']).analyze();
      violations.push(...results.violations.map(v=>({path,colorScheme,id:v.id,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary}))})));
    }
  }
  expect(violations).toEqual([]);
});

import { test, expect, type Page, type APIRequestContext } from '@playwright/test';
import { ready } from './helpers';

test.beforeEach(async ({ request, baseURL }) => {
  const sync = await request.get('/api/v1/sync');
  expect(sync.ok()).toBeTruthy();
  const state = await sync.json();
  const program = state.revisions.find((r: any) => r.resource === 'program')?.revision || 0;
  const reset = await request.post('/api/v1/commands', {
    headers: { origin: new URL(baseURL!).origin },
    data: { operationId: crypto.randomUUID(), epoch: state.epoch, type: 'forceReseed', payload: {}, expectedRevision: program },
  });
  expect(reset.ok(), await reset.text()).toBeTruthy();
});

async function snapshot(request: APIRequestContext) {
  const response = await request.get('/api/v1/sync');
  expect(response.ok()).toBeTruthy();
  return (await response.json()).snapshot;
}
async function switcher(page: Page) {
  await page.locator('.meso-name').click();
  await expect(page.getByRole('dialog', { name: 'Mesocycles' })).toBeVisible();
}

test('create, rename, duplicate, activate and delete mesocycles', async ({page, request}) => {
  await ready(page, '/meso');
  const initial = await snapshot(request);
  const original = initial.mesocycles.find((m: any) => m.is_active);
  await switcher(page);
  await page.getByRole('button', { name: '+ New Mesocycle' }).click();
  await page.getByLabel('Mesocycle name').fill('Browser lifecycle');
  await page.getByRole('button', {name:'Save', exact:true}).click();
  await expect.poll(async () => (await snapshot(request)).mesocycles.some((m:any) => m.name === 'Browser lifecycle')).toBe(true);
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await switcher(page);
  await page.getByRole('button', { name: 'Manage Browser lifecycle' }).click();
  await page.getByRole('button', {name:'Rename',exact:true}).click();
  await page.getByLabel('Mesocycle name').fill('Browser renamed');
  await page.getByRole('button', {name:'Save',exact:true}).click();
  await expect.poll(async () => (await snapshot(request)).mesocycles.some((m:any) => m.name === 'Browser renamed')).toBe(true);
  await switcher(page);
  await page.getByRole('button', {name:'Manage Browser renamed'}).click();
  await page.getByRole('button', {name:'Duplicate',exact:true}).click();
  await page.getByLabel('Mesocycle name').fill('Browser duplicate');
  await page.getByRole('button', {name:'Save',exact:true}).click();
  await expect.poll(async () => (await snapshot(request)).mesocycles.some((m:any) => m.name === 'Browser duplicate')).toBe(true);
  await switcher(page);
  await page.getByRole('dialog',{name:'Mesocycles'}).getByRole('button', {name:new RegExp(original.name)}).first().click();
  await expect(page.locator('.meso-name')).toContainText(original.name);
  await switcher(page);
  await page.getByRole('dialog',{name:'Mesocycles'}).getByRole('button', {name:/Browser duplicate/}).first().click();
  await expect(page.locator('.meso-name')).toContainText('Browser duplicate');
  await expect.poll(async () => (await snapshot(request)).mesocycles.find((m:any) => m.name === 'Browser duplicate')?.is_active).toBe(1);
  await switcher(page);
  await page.getByRole('button', {name:`Manage Browser duplicate`}).click();
  await page.getByRole('button', {name:'Delete mesocycle'}).click();
  await page.getByRole('button', {name:'Confirm',exact:true}).click();
  await expect.poll(async () => (await snapshot(request)).mesocycles.some((m:any) => m.name === 'Browser duplicate')).toBe(false);
  // Restore the seeded active block for the following workflows.
  await page.goto('/meso');
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  if (await page.locator('.meso-name').count()) await switcher(page);
  else await page.getByRole('button', {name:'+ New Mesocycle'}).click();
  await page.getByRole('dialog',{name:'Mesocycles'}).getByRole('button', {name:new RegExp(original.name)}).first().click();
  await expect(page.locator('.meso-name')).toContainText(original.name);
});

test('program label, forward targets and progression persist in SQLite', async ({page,request}) => {
  await ready(page,'/meso');
  await page.getByRole('button',{name:/Timeline/}).click();
  await page.getByRole('button',{name:'Edit Monday program'}).click();
  await page.getByLabel('Split name').fill('Browser training day');
  await page.getByRole('button',{name:'Save Changes'}).click();
  const confirm = page.getByRole('dialog',{name:'Overwrite week overrides?'});
  if (await confirm.isVisible()) await confirm.getByRole('button',{name:'Confirm'}).click();
  await expect(page.getByRole('heading',{name:'BROWSER TRAINING DAY'})).toBeVisible();
  const before = await snapshot(request);
  const meso = before.mesocycles.find((m:any) => m.is_active);
  expect(before.program_days.some((d:any) => d.mesocycle_id === meso.id && d.day_idx === 0 && d.label === 'Browser training day')).toBe(true);
  const row = page.locator('.timeline-day').first().locator('.timeline-row').first();
  const name = (await row.locator('.exercise-name').innerText()).trim();
  await row.locator('.timeline-cell').first().click();
  const target = page.getByRole('dialog',{name:'Week 1 target'});
  await target.getByRole('spinbutton',{name:'REPS'}).first().fill('13');
  await target.getByRole('button',{name:/Apply from week 1 onward/}).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  const after = await snapshot(request);
  const day = after.day_overrides.find((d:any) => d.mesocycle_id === meso.id && d.week_idx === 0 && d.day_idx === 0);
  const slot = day.exercise_ids_csv.split(',')[0];
  const targets = after.week_targets.filter((t:any) => t.mesocycle_id === meso.id && t.slot_id === slot && t.week_idx >= 0 && t.week_idx < meso.num_weeks);
  expect(targets.length).toBe(meso.num_weeks);
  expect(targets.every((t:any) => String(t.reps).split(',')[0] === '13')).toBe(true);
  await row.getByRole('button',{name,exact:true}).click();
  await page.getByRole('button',{name:/Set progression arc/}).click();
  const arc = page.getByRole('dialog',{name:'Progression arc'});
  await expect(arc.getByText('PREVIEW')).toBeVisible();
  await arc.getByRole('button',{name:'Apply Arc'}).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  const progressed = (await snapshot(request)).week_targets.filter((t:any) => t.mesocycle_id === meso.id && t.slot_id === slot && t.week_idx >= 0 && t.week_idx < meso.num_weeks);
  expect(progressed.length).toBe(meso.num_weeks);
});

test('download and restore a backup through the browser', async ({page,request}) => {
  await ready(page,'/meso');
  const previous = await snapshot(request);
  await page.getByRole('button',{name:'About, backup and restore'}).click();
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button',{name:/Backup/}).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe('strength-guru.sqlite');
  const file = await download.path();
  expect(file).toBeTruthy();
  await page.locator('input[type=file][accept*="sqlite"]').setInputFiles(file!);
  await expect(page.getByRole('dialog',{name:'Restore backup'})).toBeVisible();
  await page.getByRole('button',{name:'Restore this backup'}).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  const after = await snapshot(request);
  expect(after.mesocycles.map((m:any)=>m.id).sort()).toEqual(previous.mesocycles.map((m:any)=>m.id).sort());
});

test('populated log remains usable on desktop in light and dark modes', async ({page,request}) => {
  const state=await snapshot(request);
  const meso=state.mesocycles.find((m:any)=>m.is_active);
  await page.setViewportSize({width:1365,height:900});
  for (const colorScheme of ['light','dark'] as const) {
    await page.emulateMedia({colorScheme});
    await ready(page,`/log?meso=${meso.id}&week=0&day=0`);
    await expect(page.locator('.exercise-card').first()).toBeVisible();
    await expect(page.getByRole('button',{name:/^Log set/}).first()).toBeVisible();
    expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
  }
});

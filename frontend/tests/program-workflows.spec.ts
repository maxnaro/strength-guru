import { test } from './fixtures';
import { expect, type Page, type APIRequestContext } from '@playwright/test';
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

test('unavailable inference locks new AI work and leaves training controls usable', async ({ page, request }) => {
  const health = await request.get('/api/v1/ai/status');
  expect(health.ok()).toBeTruthy();
  expect(await health.json()).toMatchObject({ aiAvailable: false });
  const locked = 'AI features are locked because server inference is unavailable.';

  await ready(page, '/meso');
  await switcher(page);
  const mesos = page.getByRole('dialog', { name: 'Mesocycles' });
  await expect(mesos.getByText(locked)).toBeVisible();
  await expect(mesos.getByRole('button', { name: 'Import CSV' })).toBeDisabled();
  await expect(mesos.getByRole('button', { name: 'Generate Program' })).toBeDisabled();
  await expect(mesos.getByRole('button', { name: /New Mesocycle/ })).toBeEnabled();
  await mesos.getByRole('button', { name: 'Close dialog' }).click();

  await page.getByRole('button', { name: 'Check program volume' }).click();
  const volume = page.getByRole('dialog', { name: 'Volume Check' });
  await volume.getByRole('button', { name: 'Run Validation' }).click();
  await expect(volume.getByText(locked)).toBeVisible();
  await expect(volume.getByRole('button', { name: 'Fix with AI' })).toBeDisabled();

  await ready(page, '/generate');
  await expect(page.getByText(locked)).toBeVisible();
  await page.getByRole('textbox', { name: 'Program description' }).fill('A two-week upper block.');
  await expect(page.getByRole('button', { name: 'Generate Program →' })).toBeDisabled();

  await ready(page, '/import');
  await expect(page.getByText(locked)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Import CSV' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Generate Program' })).toBeDisabled();
  await page.getByRole('button', { name: 'AI jobs and saved results' }).click();
  await expect(page.getByRole('dialog', { name: 'AI jobs' })).toBeVisible();
});

test('create, rename, duplicate, activate and delete mesocycles', async ({page, request}) => {
  await ready(page, '/meso');
  const initial = await snapshot(request);
  const original = initial.mesocycles.find((m: any) => m.is_active);
  await switcher(page);
  await page.getByRole('button', { name: /New Mesocycle/ }).click();
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
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  // Restore the seeded active block for the following workflows.
  await page.goto('/meso');
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  if (await page.locator('.meso-name').count()) await switcher(page);
  else await page.getByRole('button', {name:/New Mesocycle/}).click();
  await page.getByRole('dialog',{name:'Mesocycles'}).getByRole('button', {name:new RegExp(original.name)}).first().click();
  await expect(page.locator('.meso-name')).toContainText(original.name);
});

test('program label, forward targets and progression persist in SQLite', async ({page,request}) => {
  await page.setViewportSize({width: 393, height: 852});
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

test('desktop Program edits an individual set target and keeps Calendar available', async ({page, request}) => {
  await page.setViewportSize({width: 1100, height: 850});
  await ready(page, '/meso');
  const sheet = page.getByRole('table', {name: 'Mesocycle program'});
  await expect(sheet).toBeVisible();
  await expect(page.getByRole('button', {name: 'Program', exact: true})).toHaveAttribute('aria-pressed', 'true');
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(1100);
  const scrollArea = page.locator('.program-sheet');
  const exerciseHeading = sheet.getByRole('columnheader', {name: 'Exercise', exact: true});
  const firstWeekHeading = sheet.getByRole('button', {name: 'Toggle deload week 1', exact: true});
  const leftBefore = (await exerciseHeading.boundingBox())!.x;
  const topBefore = (await firstWeekHeading.boundingBox())!.y;
  await scrollArea.evaluate(element => element.scrollTo(80, 180));
  await expect.poll(() => scrollArea.evaluate(element => [element.scrollLeft > 0, element.scrollTop > 0])).toEqual([true, true]);
  expect((await exerciseHeading.boundingBox())!.x).toBeCloseTo(leftBefore, 0);
  expect((await firstWeekHeading.boundingBox())!.y).toBeCloseTo(topBefore, 0);
  await scrollArea.evaluate(element => element.scrollTo(0, 0));

  const before = await snapshot(request);
  const meso = before.mesocycles.find((row: any) => row.is_active);
  const monday = before.day_overrides.find((row: any) =>
    row.mesocycle_id === meso.id && row.week_idx === 0 && row.day_idx === 0);
  const slotId = monday.exercise_ids_csv.split(',')[0];
  const slot = before.exercise_slots.find((row: any) => row.id === slotId);
  const exercise = before.exercises.find((row: any) => row.id === slot.exercise_id);
  const targetsForSlot = (state: any) => state.week_targets.filter((row: any) => row.slot_id === slotId);
  const originalTargets = targetsForSlot(before);
  const firstWeek = originalTargets.find((row: any) => row.week_idx === 0);
  const [firstRep, ...remainingReps] = String(firstWeek.reps).split(',');
  const edited = `Monday, ${exercise.name}, set 1, week 1, reps`;
  const original = sheet.getByRole('button', {name: `${edited}, ${firstRep}`, exact: true});
  const editor = sheet.getByRole('textbox', {name: edited, exact: true});

  await original.press('Enter');
  await expect(editor).toBeFocused();
  await editor.fill('0');
  await editor.press('Enter');
  await expect(editor).toHaveAttribute('aria-invalid', 'true');
  await editor.press('Escape');
  await expect(original).toBeFocused();
  await original.press('ArrowRight');
  await expect(sheet.getByRole('button', {name: `Monday, ${exercise.name}, set 1, week 1, RIR, ${String(firstWeek.rir).split(',')[0]}`, exact: true})).toBeFocused();
  await page.keyboard.press('ArrowLeft');
  await expect(original).toBeFocused();

  const nextRep = firstRep === '13' ? '14' : '13';
  const saved = sheet.getByRole('button', {name: `${edited}, ${nextRep}`, exact: true});
  await original.press('F2');
  await editor.fill(nextRep);
  await editor.press('Enter');
  await expect(saved).toBeVisible();
  await expect.poll(async () => targetsForSlot(await snapshot(request))).toEqual(
    originalTargets.map((row: any) => row.week_idx === 0
      ? {...row, reps: [nextRep, ...remainingReps].join(',')}
      : row),
  );

  await page.reload();
  await expect(saved).toBeVisible();
  await page.getByRole('button', {name: 'Calendar', exact: true}).click();
  await expect(sheet).toBeHidden();
  await page.getByRole('button', {name: /^Week 1, Monday,/}).click();
  await expect(page).toHaveURL(url => url.pathname === '/log' && url.searchParams.get('week') === '0' && url.searchParams.get('day') === '0');
  await expect(page.getByRole('button', {name: /^Log set/}).first()).toBeVisible();
});

test('desktop Program shows week-only exercises and different set counts', async ({page, request, baseURL}) => {
  async function command(type: string, payload: object) {
    const state = await (await request.get('/api/v1/sync')).json();
    const revision = state.revisions.find((row: any) => row.resource === 'program')?.revision ?? 0;
    const response = await request.post('/api/v1/commands', {
      headers: {origin: new URL(baseURL!).origin},
      data: {operationId: crypto.randomUUID(), epoch: state.epoch, type, payload, expectedRevision: revision},
    });
    expect(response.ok(), await response.text()).toBeTruthy();
  }

  const state = await snapshot(request);
  const meso = state.mesocycles.find((row: any) => row.is_active);
  const dayPlan = (day: number) => state.day_overrides.find((row: any) =>
    row.mesocycle_id === meso.id && row.week_idx === 1 && row.day_idx === day).exercise_ids_csv.split(',');
  const mondaySlots = dayPlan(0);
  const mondaySlot = mondaySlots[0];
  const tuesdaySlot = dayPlan(1)[0];
  const exerciseName = (slotId: string) => {
    const slot = state.exercise_slots.find((row: any) => row.id === slotId);
    return state.exercises.find((row: any) => row.id === slot.exercise_id).name;
  };
  const existing = state.week_targets.find((row: any) => row.slot_id === mondaySlot && row.week_idx === 1);
  const reps = String(existing.reps).split(',').map(Number);
  const rir = String(existing.rir).split(',').map(Number);
  const extraSet = reps.length + 1;
  await command('upsertWeekTarget', {mesoId: meso.id, weekIdx: 1, slotId: mondaySlot, reps: [...reps, 11], rir: [...rir, 3]});
  await command('setDayOverride', {mesoId: meso.id, weekIdx: 1, dayIdx: 0, slotIds: [...mondaySlots, tuesdaySlot]});
  await command('setMesoNumWeeks', {id: meso.id, numWeeks: 13});
  await command('setDayOverride', {mesoId: meso.id, weekIdx: 12, dayIdx: 0, slotIds: mondaySlots});

  await page.setViewportSize({width: 1280, height: 850});
  await ready(page, '/meso');
  const sheet = page.getByRole('table', {name: 'Mesocycle program'});
  const addedSet = page.getByRole('button', {name: `Monday, ${exerciseName(mondaySlot)}, set ${extraSet}, week 2, reps, 11`, exact: true});
  const addedSetRow = sheet.getByRole('row').filter({has: addedSet});
  await expect(addedSetRow).toBeVisible();
  await expect(addedSetRow.getByRole('cell', {name: 'No set', exact: true}).first()).toBeVisible();

  const overrideExercise = page.getByRole('button', {name: `${exerciseName(tuesdaySlot)} actions on Monday`, exact: true});
  const overrideRow = sheet.getByRole('row').filter({has: overrideExercise});
  await expect(overrideRow.getByRole('button', {name: `Edit ${exerciseName(tuesdaySlot)} targets for Monday, week 2`, exact: true})).toBeVisible();
  await expect(overrideRow.getByRole('cell', {name: 'Not scheduled', exact: true}).first()).toBeVisible();
  await expect(overrideRow.getByRole('button', {name: `Edit ${exerciseName(tuesdaySlot)} targets for Monday, week 1`, exact: true})).toHaveCount(0);

  await page.getByRole('button', {name: 'Next weeks', exact: true}).click();
  await expect(sheet.getByRole('button', {name: 'Toggle deload week 13', exact: true})).toBeVisible();
  const week13 = `Monday, ${exerciseName(mondaySlot)}, set 1, week 13, reps`;
  await sheet.getByRole('button', {name: `${week13}, 8`, exact: true}).press('Enter');
  const editor = sheet.getByRole('textbox', {name: week13, exact: true});
  await editor.fill('12');
  await editor.press('Enter');
  await expect(sheet.getByRole('button', {name: `${week13}, 12`, exact: true})).toBeVisible();
  await expect.poll(async () => (await snapshot(request)).week_targets.find((row: any) =>
    row.slot_id === mondaySlot && row.week_idx === 12)?.reps).toBe('12,8,8');
  await page.getByRole('button', {name: 'Previous weeks', exact: true}).click();
  await expect(addedSetRow).toBeVisible();
  await command('setMesoNumWeeks', {id: meso.id, numWeeks: meso.num_weeks});
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

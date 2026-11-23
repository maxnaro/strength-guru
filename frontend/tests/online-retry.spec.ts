import {test,expect} from '@playwright/test';
import {ready,replica} from './helpers';
test.use({ serviceWorkers: 'block' });

test('retrying an import after losing its acknowledgement does not duplicate the block',async({page,context,request})=>{
  const name=`Acknowledgement retry ${Date.now()}`;
  const plan={name,numWeeks:2,days:[{dayIdx:0,label:'Upper',exercises:[{name:'Retry Bench Press',muscleGroup:'chest',weekTargets:[{weekIdx:0,reps:[8,8],rir:[2,2]},{weekIdx:1,reps:[9,9],rir:[1,1]}]}]}],advisories:[]};
  const jobId=crypto.randomUUID();
  await context.route('**/api/v1/jobs',route=>route.fulfill({status:202,contentType:'application/json',body:JSON.stringify({id:jobId,state:'queued'})}));
  await context.route(`**/api/v1/jobs/${jobId}`,route=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({id:jobId,state:'complete',result:plan})}));
  // AI output is a fixed fixture; the import command and persistence use the real Dart API.
  await ready(page,'/generate');
  await page.getByRole('textbox',{name:'Program description'}).fill('A two-week upper block.');
  await page.getByRole('button',{name:'Generate Program →',exact:true}).click();
  await expect(page.getByRole('heading',{name:'Review training block'})).toBeVisible();
  let intercepted = false;
  let lost = false;
  await context.route('**/api/v1/commands', async route => {
    if (route.request().postDataJSON().type !== 'importMesoFromPlan' || intercepted) {
      await route.continue();
      return;
    }
    intercepted = true;
    const response = await route.fetch();
    expect(response.ok()).toBe(true);
    await route.abort('failed');
    lost = true;
  });
  await page.getByRole('button',{name:'Import Block',exact:true}).click();
  await expect.poll(()=>lost).toBe(true);
  await expect.poll(async()=>{const r=await (await request.get('/api/v1/sync')).json();return r.snapshot.mesocycles.filter((m:any)=>m.name===name).length;}).toBe(1);
  await page.locator('.sync-banner').click();
  await page.getByRole('button',{name:'Retry sync',exact:true}).click();
  await expect(page.locator('.sync-banner')).toContainText('need review');
  await expect.poll(async()=>(await replica(page)).outbox.length).toBe(0);
  await page.getByRole('button',{name:'Close dialog'}).click();
  await page.getByRole('button',{name:'Import Block',exact:true}).click();
  await expect(page).toHaveURL(/\/meso/);
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  const snapshot=(await (await request.get('/api/v1/sync')).json()).snapshot;
  expect(snapshot.mesocycles.filter((m:any)=>m.name===name)).toHaveLength(1);
  expect((await replica(page)).outbox).toEqual([]);
});

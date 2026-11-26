import {test,expect,chromium} from '@playwright/test';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {monday,offlineReady,replica} from './helpers';
test('offline queue and cached shell survive closing the entire browser process',async({baseURL,request,browserName})=>{
  test.skip(browserName!=='chromium','Persistent-profile restart fixture currently exercises Chromium.');
  const profile=await mkdtemp(join(tmpdir(),'sg-browser-restart-'));
  let browser=await chromium.launchPersistentContext(profile,{baseURL,viewport:{width:390,height:844},headless:true});
  try{
    let page=await browser.newPage();await monday(page);await offlineReady(page);
    const count=(await (await request.get('/api/v1/sync')).json()).snapshot.set_entries.length;
    await browser.setOffline(true);
    await page.getByRole('button',{name:/^Log set/}).first().click();
    await expect(page.locator('.sync-banner')).toContainText('pending sync');
    const queued=await replica(page);
    await browser.close();
    browser=await chromium.launchPersistentContext(profile,{baseURL,viewport:{width:390,height:844},headless:true,offline:true});
    page=await browser.newPage();await page.goto('/log');
    await expect(page.locator('.sync-banner')).toContainText('pending sync');
    expect((await replica(page)).outbox.map((q:any)=>q.id)).toEqual(queued.outbox.map((q:any)=>q.id));
    await browser.setOffline(false);
    await expect(page.locator('.sync-banner')).toContainText('Synced',{timeout:30_000});
    expect((await (await request.get('/api/v1/sync')).json()).snapshot.set_entries.length).toBe(count+1);
  }finally{await browser.close();await rm(profile,{recursive:true,force:true});}
});

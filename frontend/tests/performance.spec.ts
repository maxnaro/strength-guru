import { test } from './fixtures';
import { expect } from '@playwright/test';
import { readFile, writeFile } from 'node:fs/promises';
import { ready, monday, offlineReady, replica } from './helpers';

test('record throttled cold/cached readiness and p95 offline save feedback', async ({page,context,browserName,request}, testInfo)=>{
  test.skip(browserName !== 'chromium','Chromium CDP network throttling measurement.');
  const session=await context.newCDPSession(page);
  await session.send('Network.enable');
  await session.send('Network.emulateNetworkConditions',{offline:false,latency:50,downloadThroughput:1_250_000,uploadThroughput:1_250_000,connectionType:'wifi'});
  const encodings:Record<string,string>={};
  page.on('response',response=>{if(response.url().includes('/_app/immutable/'))encodings[new URL(response.url()).pathname]=response.headers()['content-encoding']||'identity';});
  const start=Date.now(); await ready(page); const coldReadyMs=Date.now()-start;
  const coldPageResources=await page.evaluate(()=>[...performance.getEntriesByType('navigation'),...performance.getEntriesByType('resource')].map(e=>{const r=e as PerformanceResourceTiming;return {url:r.name,transferBytes:r.transferSize,encodedBodyBytes:r.encodedBodySize,decodedBodyBytes:r.decodedBodySize};}));
  const initial=await replica(page);
  const datasetCounts=Object.fromEntries(Object.entries(initial.tables).map(([table,rows])=>[table,(rows as any[]).length]));
  await offlineReady(page);
  const startCached=Date.now(); await page.reload();
  await expect(page.locator('.sync-banner')).toContainText('Synced');
  const cachedReadyMs=Date.now()-startCached;
  await monday(page);
  await context.setOffline(true);
  // Network emulation is scoped to the CDP session: explicitly change the same session.
  await session.send('Network.emulateNetworkConditions',{offline:true,latency:0,downloadThroughput:-1,uploadThroughput:-1});
  expect(await page.evaluate(async()=>{try{await fetch('/api/v1/health',{signal:AbortSignal.timeout(1000)});return false;}catch{return true;}})).toBe(true);
  let successfulOfflineCommands=0;
  page.on('response',response=>{if(response.url().endsWith('/api/v1/commands')&&response.ok())successfulOfflineCommands++;});
  if(process.env.TEST_CPU_PROFILE==='1'){await session.send('Profiler.enable');await session.send('Profiler.start');}
  const samples:number[]=[];
  for(let i=0;i<20;i++){
    if(i>0)await page.getByRole('button',{name:/Edit saved set/}).first().click();
    await page.evaluate(()=>{
      const button=[...document.querySelectorAll<HTMLButtonElement>('button')].find(b=>b.textContent?.trim().startsWith('Log set'))!;
      (window as any).saveFeedback=new Promise<number>(resolve=>{
        button.addEventListener('click',()=>{
          const start=performance.now();
          const observer=new MutationObserver(()=>{
            if(!button.isConnected){observer.disconnect();resolve(performance.now()-start);}
          });
          observer.observe(document.body,{childList:true,subtree:true});
        },{once:true});
      });
    });
    await page.getByRole('button',{name:/^Log set/}).first().click();
    samples.push(await page.evaluate(()=>(window as any).saveFeedback));
  }
  if(process.env.TEST_CPU_PROFILE==='1'){const {profile}=await session.send('Profiler.stop');await writeFile(testInfo.outputPath('cpu-profile.json'),JSON.stringify(profile));}
  expect(successfulOfflineCommands).toBe(0);
  const serverAfter=await (await request.get('/api/v1/sync')).json();
  expect(serverAfter.snapshot.set_entries.length).toBe(datasetCounts.set_entries);
  const sorted=samples.toSorted((a,b)=>a-b);
  const p95LocalSaveMs=sorted[Math.ceil(sorted.length*.95)-1];
  const artifacts=JSON.parse(await readFile('build/build-metrics.json','utf8'));
  const result={network:{mbps:10,rttMs:50},coldReadyMs,cachedReadyMs,p95LocalSaveMs,samples,coldPageResources,encodings,datasetCounts,successfulOfflineCommands,rawBuildBytes:artifacts.totalBytes,assets:artifacts.assets,notes:'Chromium mobile emulation on this runner. Cold/cached readiness includes synchronization; save timing is browser click to saved-row DOM feedback. Physical iPhone validation remains required.'};
  await writeFile(testInfo.outputPath('performance.json'),JSON.stringify(result,null,2));
  await testInfo.attach('performance',{body:JSON.stringify(result,null,2),contentType:'application/json'});
  await page.screenshot({path:testInfo.outputPath('offline-log.png'),fullPage:true,scale:'css'});
  console.log(JSON.stringify({coldReadyMs,cachedReadyMs,p95LocalSaveMs,rawBuildBytes:artifacts.totalBytes}));
  expect(coldReadyMs).toBeLessThan(5000);
  expect(cachedReadyMs).toBeLessThan(2000);
  expect(p95LocalSaveMs).toBeLessThan(100);
});

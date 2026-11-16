import {readdir,readFile,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
const root=resolve('test-results/performance');
async function walk(path){const result=[];for(const e of await readdir(path,{withFileTypes:true})){const p=resolve(path,e.name);if(e.isDirectory())result.push(...await walk(p));else if(e.name==='performance.json')result.push(JSON.parse(await readFile(p,'utf8')));}return result;}
const runs=await walk(root);
if(runs.length<5)throw new Error(`Expected at least 5 performance runs, got ${runs.length}`);
const percentile=(values,p)=>values.toSorted((a,b)=>a-b)[Math.ceil(values.length*p)-1];
const metric=key=>({median:percentile(runs.map(r=>r[key]),.5),p95:percentile(runs.map(r=>r[key]),.95)});
const saves=runs.flatMap(r=>r.samples);
const assets=runs.at(-1).assets;
const totals=list=>({rawBytes:list.reduce((n,a)=>n+a.bytes,0),gzipBytes:list.reduce((n,a)=>n+a.gzipBytes,0),brotliBytes:list.reduce((n,a)=>n+a.brotliBytes,0)});
const result={assets:{all:totals(assets),javascript:totals(assets.filter(a=>a.path.endsWith('.js'))),css:totals(assets.filter(a=>a.path.endsWith('.css'))),fonts:totals(assets.filter(a=>a.path.endsWith('.woff2')))},datasetCounts:runs.at(-1).datasetCounts,responseEncodings:[...new Set(runs.flatMap(r=>Object.values(r.encodings||{})))],runs:runs.length,network:runs[0].network,coldReadyMs:metric('coldReadyMs'),cachedReadyMs:metric('cachedReadyMs'),localSaveMs:{sampleCount:saves.length,median:percentile(saves,.5),p95:percentile(saves,.95)},rawBuildBytes:runs.at(-1).rawBuildBytes,notes:runs[0].notes};
await writeFile(resolve(root,'performance-summary.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));

import {spawn} from 'node:child_process';
import {resolve} from 'node:path';
const child=spawn(process.execPath,[resolve('node_modules/@playwright/test/cli.js'),'test','tests/performance.spec.ts','--repeat-each=5','--output=test-results/performance'],{stdio:'inherit',env:{...process.env,TEST_HISTORY:'1'}});
const code=await new Promise((resolveExit,reject)=>{child.on('error',reject);child.on('exit',resolveExit);});
if(code!==0)process.exitCode=typeof code==='number'?code:1;
else await import('./summarize-performance.mjs');

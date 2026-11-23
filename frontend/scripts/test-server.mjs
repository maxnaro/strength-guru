import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawn } from 'node:child_process';
const data = await mkdtemp(join(tmpdir(), 'strength-guru-browser-'));
const port = process.env.TEST_PORT || '18765';
if(process.env.TEST_HISTORY === '1') {
  try {
    await new Promise((resolveSeed,rejectSeed)=>{
      const seed=spawn(process.env.DART_BIN || 'dart',['run','tool/seed_browser_history.dart'],{cwd:resolve('../server'),stdio:'inherit',env:{...process.env,DATA_DIR:data}});
      seed.on('error',rejectSeed);seed.on('exit',code=>code===0?resolveSeed():rejectSeed(new Error(`History fixture failed (${code})`)));
    });
  } catch(error) {await rm(data,{recursive:true,force:true});throw error;}
}
const child = spawn(process.env.DART_BIN || 'dart', ['run', 'bin/server.dart'], {
  cwd: resolve('../server'), stdio: 'inherit',
  env: { ...process.env, DATA_DIR: data, WEB_ROOT: resolve('build'), PORT: port, APP_ORIGIN: `http://127.0.0.1:${port}`, LLM_BASE_URL: 'http://127.0.0.1:1', LLM_MODEL: 'test' }
});
let stopping = false;
async function stop(signal = 'SIGTERM') {
  if(stopping) return; stopping = true;
  child.kill(signal);
}
process.on('SIGTERM', () => stop());
process.on('SIGINT', () => stop());
child.on('exit', async code => { await rm(data, {recursive:true,force:true}); process.exit(code || 0); });
child.on('error', async error => { console.error(error); await rm(data,{recursive:true,force:true}); process.exit(1); });

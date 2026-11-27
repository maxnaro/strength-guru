import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawn } from 'node:child_process';
import { startTestIssuer } from './test-oidc.mjs';

const port = process.env.TEST_PORT || '18765';
const appOrigin = `http://127.0.0.1:${port}`;
const dart = process.env.DART_BIN || 'dart';
const cwd = resolve('../server');
const data = await mkdtemp(join(tmpdir(), 'strength-guru-browser-'));
const cleanup = () => rm(data, { recursive: true, force: true });

let issuer;
try {
  issuer = await startTestIssuer(Number(port) + 1, appOrigin);
  await new Promise((done, fail) => {
    const seed = spawn(dart, ['run', 'tool/seed_browser_history.dart'], {
      cwd, stdio: 'inherit', env: { ...process.env, DATA_DIR: data },
    });
    seed.once('error', fail);
    seed.once('exit', code => {
      if (code === 0) done();
      else fail(new Error(`Demo fixture failed (${code})`));
    });
  });
} catch (error) {
  await cleanup();
  throw error;
}

const child = spawn(dart, ['run', 'bin/server.dart'], {
  cwd,
  stdio: 'inherit',
  env: {
    ...process.env,
    DATA_DIR: data,
    WEB_ROOT: resolve('build'),
    PORT: port,
    APP_ORIGIN: appOrigin,
    OIDC_ISSUER: issuer,
    OIDC_CLIENT_ID: 'strength-guru-test',
    OIDC_CLIENT_SECRET: 'disposable-client-secret',
    OIDC_OWNER_SUBJECT: 'demo-owner',
    LLM_BASE_URL: '',
  },
});
process.once('SIGTERM', () => child.kill('SIGTERM'));
process.once('SIGINT', () => child.kill('SIGTERM'));
child.once('exit', async code => {
  await cleanup();
  process.exit(code ?? 1);
});
child.once('error', async error => {
  console.error(error);
  await cleanup();
  process.exit(1);
});

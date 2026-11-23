import { copyFile, readFile, readdir, stat, writeFile } from 'node:fs/promises';
import { resolve, relative } from 'node:path';
import { gzipSync, brotliCompressSync } from 'node:zlib';
const root = resolve('build');
await copyFile(resolve(root, 'service-worker.js'), resolve(root, 'sw.js'));
async function walk(dir) {
  const out = [];
  for (const entry of await readdir(dir)) {
    const path = resolve(dir, entry);
    if ((await stat(path)).isDirectory()) out.push(...await walk(path));
    else out.push(path);
  }
  return out;
}
const artifacts = [];
for (const file of await walk(root)) {
  const bytes = await readFile(file);
  artifacts.push({ path: relative(root, file), bytes: bytes.length, gzipBytes: gzipSync(bytes).length, brotliBytes: brotliCompressSync(bytes).length });
}
await writeFile(resolve(root, 'build-metrics.json'), JSON.stringify({ assets: artifacts, totalBytes: artifacts.reduce((n, a) => n + a.bytes, 0) }, null, 2));
console.log(`Prepared ${artifacts.length} assets (${artifacts.reduce((n, a) => n + a.bytes, 0)} raw bytes).`);

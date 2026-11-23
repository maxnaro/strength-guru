/// <reference lib="webworker" />
import { immutable, assets } from '$app/manifest';
declare const __SG_BUILD_ID__: string;
const worker = self as unknown as ServiceWorkerGlobalScope;
const CACHE = `strength-guru-dom-${__SG_BUILD_ID__}`;
const ASSETS = [...new Set(['/', '/index.html', ...immutable.map(asset => '/' + asset.path.replace(/^\/+/, '')), ...assets.map(asset => '/' + asset.path.replace(/^\/+/, ''))])].filter(path => !path.endsWith('/sw.js') && !path.endsWith('/service-worker.js'));
worker.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // A failed asset keeps the existing installed app available.
    await cache.addAll(ASSETS.map(path => new Request(path, { cache: 'reload' })));
  })());
});
worker.addEventListener('message', event => {
  if (event.data === 'activate' || event.data?.type === 'SKIP_WAITING') worker.skipWaiting();
});
worker.addEventListener('activate', event => {
  event.waitUntil((async () => {
    // CacheStorage contains app binaries, never the browser's IndexedDB/OPFS data.
    for (const key of await caches.keys()) {
      if (key.startsWith('strength-guru-') && key !== CACHE) await caches.delete(key);
    }
    await worker.clients.claim();
  })());
});
worker.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== worker.location.origin || url.pathname.startsWith('/api/') || url.pathname.startsWith('/guide/')) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    if (event.request.mode === 'navigate') {
      return await cache.match('/index.html') ?? fetch(event.request);
    }
    return await cache.match(event.request, { ignoreSearch: true }) ?? fetch(event.request);
  })());
});

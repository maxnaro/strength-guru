/* The build replaces __BUILD_ID__ and writes precache.json from actual artifacts. */
const CACHE = 'strength-guru-__BUILD_ID__';
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const files = await (await fetch('/precache.json', {cache: 'no-store'})).json();
    const cache = await caches.open(CACHE);
    await cache.addAll(files);
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) if (key.startsWith('strength-guru-') && key !== CACHE) await caches.delete(key);
    await self.clients.claim();
  })());
});
self.addEventListener('message', event => { if (event.data === 'activate') self.skipWaiting(); });
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/') || url.pathname.startsWith('/guide/')) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    if (event.request.mode === 'navigate') return await cache.match('/index.html') || fetch(event.request);
    return await cache.match(event.request, {ignoreSearch: true}) || fetch(event.request);
  })());
});

const CACHE = 'connor-homelab-shell-v1';
const SHELL = ['/', '/index.html', '/manifest.json', '/icons/icon.svg'];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key)))));
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;
  // Keep live status and authentication responses fresh; cache only the app shell.
  if (new URL(request.url).pathname.startsWith('/api/') || new URL(request.url).pathname.startsWith('/.auth/')) return;
  event.respondWith(fetch(request).then(response => {
    const copy = response.clone();
    caches.open(CACHE).then(cache => cache.put(request, copy));
    return response;
  }).catch(() => caches.match(request).then(cached => cached || caches.match('/'))));
});

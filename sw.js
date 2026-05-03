/* Personal Workout · Service Worker */
const VERSION = "v1.0.0-2026-05-03";
const SHELL_CACHE = `pw-shell-${VERSION}`;
const MEDIA_CACHE = `pw-media-${VERSION}`;

// Shell minima da pre-cachare per offline immediato
const SHELL_ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icon.svg",
  "./wokout-purpose.md"
];

// Pattern URL per i media degli esercizi (cache stale-while-revalidate)
const MEDIA_PATTERNS = [
  /\/assets\/exercises\/.*\.(mp4|webm|mov|jpg|png)$/i
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE)
      .then(cache => cache.addAll(SHELL_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(k => k.startsWith("pw-") && k !== SHELL_CACHE && k !== MEDIA_CACHE)
          .map(k => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  // Asset esercizi: stale-while-revalidate su MEDIA_CACHE
  if (MEDIA_PATTERNS.some(p => p.test(url.pathname))) {
    event.respondWith(staleWhileRevalidate(req, MEDIA_CACHE));
    return;
  }

  // Shell: cache-first
  if (req.mode === "navigate" || SHELL_ASSETS.some(p => url.pathname.endsWith(p.replace("./", "/")))) {
    event.respondWith(cacheFirst(req, SHELL_CACHE));
    return;
  }

  // Default: network falling back to cache
  event.respondWith(
    fetch(req).catch(() => caches.match(req))
  );
});

async function cacheFirst(req, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  if (cached) return cached;
  try {
    const res = await fetch(req);
    if (res.ok) cache.put(req, res.clone());
    return res;
  } catch (e) {
    return cached || new Response("Offline", { status: 503 });
  }
}

async function staleWhileRevalidate(req, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(req);
  const networkPromise = fetch(req).then(res => {
    if (res.ok) cache.put(req, res.clone());
    return res;
  }).catch(() => cached);
  return cached || networkPromise;
}

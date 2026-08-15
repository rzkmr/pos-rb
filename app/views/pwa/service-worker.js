// Caches static assets (fonts, CSS, JS, icons) and exactly one HTML route:
// /offline_shell. See CLAUDE.md invariant #4 — every OTHER page must never
// be cached, because Turbo navigates via fetch and a cached bill/kitchen/
// session page would render stale money. /offline_shell is safe to cache
// because it is structurally state-free: it renders no server data at all
// and hydrates everything client-side from IndexedDB (see
// offline_shell_controller.js), so a stale cached copy can't show stale
// money — there's no money in the markup to begin with.
//
// cache.put is only ever called from putIfAllowed below, which enforces
// this as an allow-list, not a deny-list — the safer direction for a
// mistake to fail in.

const CACHE_NAME = "pos-assets-v2"
const SHELL_PATH = "/offline_shell"

function isCacheableAsset(pathname) {
  return pathname.startsWith("/assets/") || pathname.startsWith("/fonts/")
}

async function putIfAllowed(cache, request, response) {
  const pathname = new URL(request.url).pathname
  if (isCacheableAsset(pathname) || pathname === SHELL_PATH) {
    await cache.put(request, response)
  }
}

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.add(SHELL_PATH))
  )
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    )
  )
  self.clients.claim()
})

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url)

  if (event.request.mode === "navigate") {
    // Network-first: only ever fall back to the cached shell when the
    // network genuinely fails. The navigation response itself is never
    // cached — only the one-time install-time fetch of SHELL_PATH above
    // populates the cache for this route.
    event.respondWith(
      fetch(event.request).catch(() =>
        caches.open(CACHE_NAME).then((cache) => cache.match(SHELL_PATH))
      )
    )
    return
  }

  if (event.request.method !== "GET" || !isCacheableAsset(url.pathname)) return

  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(event.request)
      if (cached) return cached

      const response = await fetch(event.request)
      if (response.ok) await putIfAllowed(cache, event.request, response.clone())
      return response
    })
  )
})

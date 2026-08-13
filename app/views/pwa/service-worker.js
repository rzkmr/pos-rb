// Caches static assets only — fonts, CSS, JS, icons. Never HTML.
// See CLAUDE.md invariant #4: Turbo navigates via fetch, and a cached
// page would render a stale bill or a stale kitchen ticket. Existing
// purely so "Add to Home Screen" produces a real installable app
// (manifest requires a registered service worker) — not for offline use.

const CACHE_NAME = "pos-assets-v1"

self.addEventListener("install", (event) => {
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
  const isAsset = url.pathname.startsWith("/assets/") || url.pathname.startsWith("/fonts/")
  if (event.request.method !== "GET" || !isAsset) return

  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(event.request)
      if (cached) return cached

      const response = await fetch(event.request)
      if (response.ok) cache.put(event.request, response.clone())
      return response
    })
  )
})

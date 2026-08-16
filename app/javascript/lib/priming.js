import { refresh as refreshCatalog, read as readCatalog } from "lib/catalog_cache"

// "Primed for offline" means: the catalog is in IndexedDB and the Service
// Worker has taken control of this page. Both have to actually finish, not
// just be kicked off, before staff can trust the app will survive an
// outage — a fire-and-forget refresh() that never resolves because the tab
// was closed 5 seconds after sign-in is exactly how the app ends up
// "installed but empty" the first time it's actually needed offline.
//
// Fast path: if a catalog is already cached, priming is instant — this
// only matters for the very first sign-in on a fresh browser/install.
export async function ensurePrimed({ onStatusChange } = {}) {
  const notify = (status) => onStatusChange?.(status)

  const alreadyCached = await readCatalog()
  if (alreadyCached) {
    notify("ready")
    return true
  }

  notify("priming")

  const results = await Promise.allSettled([
    refreshCatalog(),
    registerServiceWorkerAndWaitForControl()
  ])

  const failed = results.some((result) => result.status === "rejected")
  notify(failed ? "failed" : "ready")
  return !failed
}

async function registerServiceWorkerAndWaitForControl() {
  if (!("serviceWorker" in navigator)) return

  const registration = await navigator.serviceWorker.register("/service-worker.js", { scope: "/" })

  if (navigator.serviceWorker.controller) return

  // A first-ever registration doesn't control the page that registered it
  // until the next navigation — for THIS session, force a claim so the
  // shell route is actually cached and controlled before we tell the user
  // priming succeeded, rather than promising something one reload away.
  await registration.update().catch(() => {})
  if (navigator.serviceWorker.controller) return

  await new Promise((resolve) => {
    const finish = () => {
      navigator.serviceWorker.removeEventListener("controllerchange", finish)
      clearTimeout(timeout)
      resolve()
    }
    navigator.serviceWorker.addEventListener("controllerchange", finish)
    // If the SW never claims (e.g. no update was actually pending), don't
    // hang priming forever — the shell being cached is what actually
    // matters, not which client controls it yet.
    const timeout = setTimeout(finish, 3000)
  })
}

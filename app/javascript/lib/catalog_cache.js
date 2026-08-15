import { get, put } from "lib/local_store"

// Read-through cache of the menu/shop snapshot (see
// CatalogSnapshotsController). refresh() is called on connect and on every
// online transition; read() serves whatever's cached, which is all the
// offline shell and cold-launch UI ever consult.
const CATALOG_KEY = "current"

export async function refresh() {
  const response = await fetch("/catalog_snapshot", { headers: { Accept: "application/json" } })
  if (!response.ok) throw new Error(`catalog_snapshot failed: ${response.status}`)

  const snapshot = await response.json()
  const cached = await get("catalog", CATALOG_KEY)
  if (cached && cached.version === snapshot.version) return cached

  return put("catalog", { id: CATALOG_KEY, ...snapshot })
}

export async function read() {
  return get("catalog", CATALOG_KEY)
}

import { get, put } from "lib/local_store"
import { read as readCatalog } from "lib/catalog_cache"

// Who's claimed to be working the counter on THIS device, for offline
// attribution (see Sync::ActingUser server-side) — a selection, not a
// login. No PIN is checked here; the catalog snapshot only ever carries
// id/name/role for exactly this reason (see CatalogSnapshotsController).
// Persisted in IndexedDB (not sessionStorage) so it survives a reload —
// an offline shift can span many page loads.
const IDENTITY_KEY = "acting_user"

export async function current() {
  const record = await get("catalog", IDENTITY_KEY)
  if (!record) return null

  // The selected user might have been deactivated since — re-validate
  // against the currently cached staff list rather than trusting a stale
  // pointer, so a picker never keeps offering someone who shouldn't be
  // attributed to new sales anymore.
  const catalog = await readCatalog()
  const stillValid = catalog?.users?.some((user) => user.id === record.userId)
  return stillValid ? record.userId : null
}

export async function select(userId) {
  await put("catalog", { id: IDENTITY_KEY, userId })
  return userId
}

export async function clear() {
  await put("catalog", { id: IDENTITY_KEY, userId: null })
}

export async function availableUsers() {
  const catalog = await readCatalog()
  return catalog?.users || []
}

// Thin promise wrapper over IndexedDB. localStorage is synchronous,
// 5MB-capped, string-only, and has no atomic multi-key transaction — the
// takeaway checkout overwrite bug (a second order silently clobbering a
// first one still retrying) is a direct consequence of that. Everything
// offline-related builds on this instead.
//
// Three object stores, all created up front so later phases never need a
// schema version bump: "catalog" (menu/shop snapshot), "outbox" (queued
// writes), "ledger" (offline-issued invoices + the local invoice counter).
const DB_NAME = "pos"
const DB_VERSION = 1
const STORES = ["catalog", "outbox", "ledger"]

let dbPromise = null

function openDb() {
  if (dbPromise) return dbPromise

  dbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION)

    request.onupgradeneeded = () => {
      const db = request.result
      STORES.forEach((name) => {
        if (!db.objectStoreNames.contains(name)) {
          db.createObjectStore(name, { keyPath: "id" })
        }
      })
    }

    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })

  return dbPromise
}

export async function get(storeName, id) {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, "readonly")
    const request = tx.objectStore(storeName).get(id)
    request.onsuccess = () => resolve(request.result || null)
    request.onerror = () => reject(request.error)
  })
}

export async function getAll(storeName) {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, "readonly")
    const request = tx.objectStore(storeName).getAll()
    request.onsuccess = () => resolve(request.result || [])
    request.onerror = () => reject(request.error)
  })
}

export async function put(storeName, value) {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, "readwrite")
    tx.objectStore(storeName).put(value)
    tx.oncomplete = () => resolve(value)
    tx.onerror = () => reject(tx.error)
  })
}

export async function remove(storeName, id) {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, "readwrite")
    tx.objectStore(storeName).delete(id)
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

// Runs fn with writable object stores and commits atomically — used where a
// read and a write must happen as one transaction (e.g. incrementing the
// local invoice counter and writing the invoice record together in Phase
// 3). fn must be SYNCHRONOUS and touch only IDBObjectStore methods: an
// IndexedDB transaction auto-commits as soon as it goes a tick without
// issuing a request, so awaiting anything inside fn (a fetch, a Promise
// from outside this module) would close the transaction out from under it.
// Read with request.onsuccess callbacks inside fn, not by awaiting get().
export async function transaction(storeNames, fn) {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeNames, "readwrite")
    const stores = Object.fromEntries(storeNames.map((name) => [name, tx.objectStore(name)]))
    let result
    try {
      result = fn(stores)
    } catch (error) {
      reject(error)
      return
    }

    tx.oncomplete = () => resolve(result)
    tx.onerror = () => reject(tx.error)
    tx.onabort = () => reject(tx.error)
  })
}

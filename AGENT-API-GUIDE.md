# Agent API Guide — `/api/v1`

Condensed reference for a coding agent writing a client against this API. `API-SPEC.md` is the authoritative contract (full payloads, error codes, design rationale) — read it before implementing anything non-trivial. This doc exists so an agent doesn't have to re-parse all of it just to make the first authenticated call.

**Describes what the server actually does today**, not just the spec's target shape — device pairing currently diverges from `API-SPEC.md` §1b, and owner login diverges on its request field name (§1a). Divergences are called out explicitly; don't assume the spec's payload shape works until you've checked the controller.

---

## Auth model — two separate credentials

1. **Device token** — one per physical terminal, long-lived, authenticates every `/api/v1` request except pairing and owner login.
2. **`acting_user_id`** — the staff PIN session, travels *inside* each write operation's payload, not as a header. One device, many staff. There is no server-side session.

```http
Authorization: Bearer <device_token>
```

That's the only auth header this API reads today. `X-Device-Id` / `X-App-Version` appear in `API-SPEC.md`'s example but `Api::V1::BaseController` does not currently require or read them — don't rely on the server rejecting a request that omits them.

### Getting a device token

`POST /api/v1/devices/pair` — **as implemented**, not as spec'd:

```json
// Request
{ "label": "Counter 1", "pairing_pin": "9999" }

// Response — 201
{ "device": { "id": "...", "label": "Counter 1" }, "token": "dvt_..." }
```

`pairing_pin` is the **shop-wide** PIN (`Shop#pairing_pin`, plaintext, same one admin reads off the Settings screen) — not a per-device single-use code. `API-SPEC.md` §1b describes a short-lived `pairing_code` (`HB-7X2Q` format) minted per-device from the web admin instead; that flow does not exist yet. Build against the shape above until it lands.

Rate-limited 5/15min per IP, plus a shop-wide lockout via `PairingAttempt` on repeated failures (`429 { "error": "pairing_locked" }`). The returned `token` is shown once — store it, it's not retrievable again (only `token_digest` is persisted server-side).

```
404 no_shop_configured   — server has no shop row yet (fresh install)
401 invalid_pairing_pin
429 too_many_attempts | pairing_locked
```

### Owner login (mints a long-lived owner_session_token, independent of device pairing)

`POST /api/v1/owner/login` — **as implemented**, not as spec'd:

```json
// Request
{ "username": "...", "password": "..." }

// Response — 200
{
  "owner_session_token": "...",
  "owner": { "id": "...", "username": "..." },
  "shop_id": "..."
}
```

`API-SPEC.md` §1a specs `email` as the login field; the current implementation takes `username` instead — everything else (the long-lived `owner_session_token` + `shop_id` response) now matches. Cache `owner_session_token` and send it as `Authorization: Bearer <owner_session_token>` on `DELETE /api/v1/owner/logout` to revoke it. It is a separate credential from the device token — an owner session identifies the person, not the terminal, and does not itself authenticate any `/api/v1` write endpoint.

```
POST /api/v1/owner/login
401 invalid_credentials
422 no_shop_configured
429 too_many_attempts

DELETE /api/v1/owner/logout
Authorization: Bearer <owner_session_token>
204 — revoked
401 — missing, unknown, or already-revoked token
```

### Every other request

```http
Authorization: Bearer <device_token>
```

```
401 — token missing, unknown, or revoked. Wipe stored token, re-pair.
403 — not currently returned by BaseController (spec reserves it for "device disabled"
      but Device has no active/disabled flag today — a deleted device just 401s).
```

---

## Core request flow

```
1. POST /devices/pair         → get device_token, store it
2. GET  /bootstrap             → full shop/menu/tables/users snapshot + starting cursor
3. GET  /delta?cursor=N        → catch up on reference-data changes since cursor N
4. POST /sync/batch            → drain the local write queue (idempotent per op_id)
5. GET  /updates?cursor=N      → poll (every 5–10s) for changes flowing back
                                  (kitchen status, another terminal closing a session)
6. GET  /health                → poll (every 5s) for the connectivity indicator
```

`GET /bootstrap`, `GET /delta`, `GET /updates`, `POST /sync/batch` all require the device token and are implemented per `API-SPEC.md` §2–§4, §8 — read those sections for exact payload shape. `GET /health` is unauthenticated (a device with a revoked token still needs to know the server is up).

---

## Gotchas an agent will otherwise get wrong

- **`op_id` is generated once, at enqueue, never regenerated on retry.** It's the idempotency key for `/sync/batch`. Regenerating it on a retry produces duplicate sales.
- **`rejected` ≠ retry.** `rejected` is terminal — stop, surface to the user/admin. Only `deferred` should be retried, with backoff. Retrying a `rejected` op is an anti-pattern the spec calls out explicitly.
- **`duplicate` on replay means "already handled correctly," not an error.** Mark it synced and move on.
- **Never send per-line tax.** Tax is computed server-side on the session total. The server recomputes and rejects (`tax_mismatch`) on any mismatch — it never trusts or auto-corrects client arithmetic.
- **Cursors are integers, not timestamps.** `/delta` and `/updates` both use `cursor`, a monotonic server-side `seq`. Don't build anything around `updated_at`.
- **Deletes are tombstones inside the delta stream**, not a separate endpoint — `action: "delete"` on a `menu_item`/`dining_table`/etc. entity in `/delta`'s `changes[]`.
- **Money is always integer paisa.** Never float, never a decimal string.
- **A batch endpoint is always `200`**, even when individual operations inside it fail. Don't treat a non-200 from `/sync/batch` as "some ops failed" — that's a transport-level problem, not a business one.
- **Invoice numbering is still server/shop-wide today**, not per-device, despite what `API-SPEC.md` §6 describes as the target. Per-device series (`devices.invoice_series`) is explicitly deferred — see `ARCHITECTURE.md` §12 Phase E — until a native Android client exists. Don't build client-side invoice-sequence allocation against this API yet.

---

## Where the real shapes live

- `API-SPEC.md` — full contract: every payload, every error code, `§1`–`§12`.
- `app/controllers/api/v1/` — what's actually implemented; check here when in doubt, this doc and the spec both drift from code over time.
- `CLAUDE.md` — the non-negotiable invariants (money, tax order, idempotency, audit trail) that constrain what any client-side or server-side change is allowed to do.

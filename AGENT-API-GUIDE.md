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
{ "label": "Counter 1", "pairing_pin": "9999", "requested_kind": "counter" }

// Response — 201
{ "device": { "id": "...", "label": "Counter 1", "kind": "counter" }, "token": "dvt_..." }
```

`pairing_pin` is the **shop-wide** PIN (`Shop#pairing_pin`, plaintext, same one admin reads off the Settings screen) — not a per-device single-use code. `API-SPEC.md` §1b describes a short-lived `pairing_code` (`HB-7X2Q` format) minted per-device from the web admin instead; that flow does not exist yet. Build against the shape above until it lands.

`requested_kind` is optional, one of `waiter | kitchen | cashier | counter | admin` (`Device::KINDS`); an omitted or unrecognized value defaults to `counter`. It's advisory only — the server does not restrict which endpoints a device kind can call.

Rate-limited 5/15min per IP, plus a shop-wide lockout via `PairingAttempt` on repeated failures (`429 { "error": "pairing_locked" }`). The returned `token` is shown once — store it, it's not retrievable again (only `token_digest` is persisted server-side).

```
422 no_shop_configured   — server has no shop row yet (fresh install)
401 invalid_pairing_pin
429 too_many_attempts | pairing_locked
```

Pairing has no device token yet, so the server can't derive the shop from a request the way every other endpoint below does — it still falls back to `Shop.order(:id).first` (there is only ever one shop row today). Same for owner login just below. Every *token*-authenticated endpoint (bootstrap, delta, updates, sync/batch) instead resolves the shop from the device token itself — see "Every other request."

**This fallback is a known landmine, not a settled design.** `ARCHITECTURE.md` §14 has this deployment moving cloud-first and multi-shop, and its Phase A explicitly drops the `only_one_shop_may_exist` constraint that currently makes "the one shop row" a safe assumption. Once that ships, `Shop.order(:id).first` silently resolves to *some* shop, not necessarily the one the caller meant — pairing and owner login will need a real shop identifier in the request (not designed yet; don't invent a `shop_id`/`shop_uid` param speculatively, wait for `API-SPEC.md` to spec it). If you're building a client today, don't hardcode any assumption that pairing always lands you on "the shop" — that stops being true the moment a second shop exists in the same database.

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

The shop is derived entirely from the device token — `Api::V1::BaseController` looks the token up across every device in the deployment and sets the request's shop from whatever shop that device belongs to. There is no `shop_id` in the request and none is needed; a device token already proves which shop it's for, so nothing about tenancy is client-supplied or spoofable.

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

`GET /bootstrap`, `GET /delta`, `GET /updates`, `POST /sync/batch` all require the device token. Shapes below are **as implemented** (`app/controllers/api/v1/`); `API-SPEC.md` §2–§4, §8 has full field-by-field rationale. `GET /health` is unauthenticated (a device with a revoked token still needs to know the server is up).

### `GET /bootstrap`

```json
// Response — 200
{
  "server_time": "2026-09-16T09:00:00+05:45",
  "cursor": 4821,
  "shop": {
    "id": "...", "name": "...", "address": "...", "pan": "...",
    "vat_rate_bp": 1300, "service_charge_rate_bp": 1000,
    "invoice_fy": "...", "invoice_prefix": "...", "invoice_footer": "..."
  },
  "device": { "id": "...", "label": "Counter 1", "kind": "counter", "last_seen_at": "..." },
  "users": [ { "id": "...", "name": "...", "role": "..." } ],
  "dining_tables": [ { "id": "...", "label": "...", "seats": 4, "position": 1, "takeaway": false } ],
  "menu_items": [
    { "id": "...", "name": "...", "category": "...", "gross_price_rupees": 150.0, "gross_price_paisa": 15000,
      "variants": [], "active": true, "position": 1 }
  ]
}
```

`users[]` is id/role/name only — PIN never leaves the server. `cursor` is the starting point for step 3's `/delta?cursor=`. `vat_rate_bp`/`service_charge_rate_bp` are basis points (1300 = 13%), not hardcoded — `ARCHITECTURE.md` §6 has the extraction formula. **`gross_price_rupees` (float, 2dp) is the field to build a client-side cart/tax/total on** — build your own arithmetic against it. `gross_price_paisa` (integer) still rides along on every menu item, for a client that wants exact integer math instead; either is a legitimate choice for a *client*, pick one and don't mix them within the same calculation. This is a wire-format decision only — the server's own storage and its own tax computation (`Billing.compute`) are still integer paisa throughout, per `CLAUDE.md` invariant #1; that invariant governs the server's internals, not what a client builds against. Same pair, same ordering, on every menu item in `/delta` records for that entity.

### `GET /delta?cursor=N`

```json
// Response — 200
{ "cursor": 4830, "has_more": false, "server_time": "...", "changes": [ { "seq": 4830, "entity": "menu_item", "action": "update", "record": { "...": "..." } } ] }

// Response — 409, cursor too far behind the retained window
{ "error": "cursor_too_old" }
```

A tombstone is `action: "delete"` with the record's id. On `409` re-bootstrap (step 2) rather than retrying `/delta`.

### `POST /sync/batch`

```json
// Request
{
  "device_time": "2026-09-16T09:00:00+05:45",
  "operations": [
    { "op_id": "uuid", "type": "ticket.create", "acting_user_id": "...", "occurred_at": "...", "payload": { "...": "..." } }
  ]
}

// Response — always 200
{
  "server_time": "...",
  "clock_skew_seconds": 2,
  "cursor": 4831,
  "results": [
    { "op_id": "uuid", "status": "accepted" }
  ]
}
```

Per-operation `results[]` entries: `{ "op_id", "status": "accepted" }`, `{ "op_id", "status": "duplicate" }`, `{ "op_id", "status": "rejected", "retryable": false, "code": "validation_failed", "message": "..." }`, or `{ "op_id", "status": "deferred", "retryable": true, "code": "server_busy", "message": "..." }`. `type` → payload mapping (`table_session.open`, `ticket.create`, `ticket.status`, `ticket_item.void`, `table_session.discount`, `invoice.issue`, `payment.record`, `table_session.close`) is in `Api::V1::Sync::BatchController::TYPE_TO_KIND` — an unknown `type` comes back `rejected`/`validation_failed`, not a 4xx.

`payment.record`'s `method` field is one of `Payment::METHODS`: `cash`, `fonepay`, `esewa`, `khalti`, `imepay`, `card`, `credit`, `other` — Nepali payment rails, not UPI (this is a Nepal deployment, not India, despite `ARCHITECTURE.md`'s still-stale India-market header — see `CLAUDE.md` for the current market).

### `GET /updates?cursor=N`

```json
// Response — 200
{ "cursor": 4835, "changes": [ { "seq": 4835, "entity": "ticket", "action": "update", "record": { "...": "..." } } ] }
```

Same ledger as `/delta`, filtered to `entity: "ticket"` — no `has_more`/`cursor_too_old` handling here, just poll again with the returned `cursor`.

---

## Gotchas an agent will otherwise get wrong

- **`op_id` is generated once, at enqueue, never regenerated on retry.** It's the idempotency key for `/sync/batch`. Regenerating it on a retry produces duplicate sales.
- **`rejected` ≠ retry.** `rejected` is terminal — stop, surface to the user/admin. Only `deferred` should be retried, with backoff. Retrying a `rejected` op is an anti-pattern the spec calls out explicitly.
- **`duplicate` on replay means "already handled correctly," not an error.** Mark it synced and move on.
- **Never send per-line tax.** Tax is computed server-side on the session total. The server recomputes and rejects (`tax_mismatch`) on any mismatch — it never trusts or auto-corrects client arithmetic.
- **Cursors are integers, not timestamps.** `/delta` and `/updates` both use `cursor`, a monotonic server-side `seq`. Don't build anything around `updated_at`.
- **Deletes are tombstones inside the delta stream**, not a separate endpoint — `action: "delete"` on a `menu_item`/`dining_table`/etc. entity in `/delta`'s `changes[]`.
- **Menu item price ships as both `gross_price_rupees` (float, build your own cart/tax math on this) and `gross_price_paisa` (integer, for a client that wants exact integer math instead)** — pick one and don't mix them mid-calculation. This is a wire-format choice, not a server-internals one: the server's own storage and its own tax computation (`Billing.compute`) are integer paisa throughout regardless of which field a client used, `CLAUDE.md` invariant #1 governs that and hasn't changed. Elsewhere on the wire — `payment.record`'s `amount_paisa`, an offline invoice's `gross_paisa` — there is no rupee sibling; those stay integer paisa, no exception. When in doubt about a given field, check the controller — this guide documents what exists today, not a blanket rule to extrapolate from.
- **A batch endpoint is always `200`**, even when individual operations inside it fail. Don't treat a non-200 from `/sync/batch` as "some ops failed" — that's a transport-level problem, not a business one.
- **Invoice numbering is still server/shop-wide today**, not per-device, despite what `API-SPEC.md` §6 describes as the target. Per-device series (`devices.invoice_series`) is explicitly deferred — see `ARCHITECTURE.md` §12 Phase E — until a native Android client exists. Don't build client-side invoice-sequence allocation against this API yet.
- **There is no `shop_id` on any token-authenticated request, and you don't need one.** The device token itself resolves the shop server-side. Pairing and owner login are the only two endpoints that can't do this (no token exists yet at that point) and fall back to "the one shop that exists" — everything else derives tenancy from the token you're already sending. See "Getting a device token" above for why that fallback won't stay safe once this deployment goes multi-shop.

---

## Where the real shapes live

- `API-SPEC.md` — full contract: every payload, every error code, `§1`–`§12`.
- `app/controllers/api/v1/` — what's actually implemented; check here when in doubt, this doc and the spec both drift from code over time.
- `CLAUDE.md` — the non-negotiable invariants (money, tax order, idempotency, audit trail) that constrain what any client-side or server-side change is allowed to do.

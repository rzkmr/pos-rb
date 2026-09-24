# API Specification — v1

Contract between the **Android POS app** (Kotlin, Compose, Room) and the **Rails server** on the restaurant LAN.

Base URL: `https://pos.<domain>.com.np/api/v1`
All bodies `application/json; charset=utf-8`. All money is **integer paisa**. All timestamps are **ISO-8601 UTC**.

Companion docs: `ARCHITECTURE.md` (topology, why), `CLAUDE.md` (build rules), `UI-DESIGN.md` (screens).

---

## 0. Design rules this API follows

These differ from the generic offline-POS template and each one exists for a reason.

| Rule | Why |
|---|---|
| **Cursor-based deltas, never `updated_after` timestamps** | Timestamp pagination drops rows written in the same millisecond and breaks entirely under clock skew. |
| **Per-operation results, never all-or-nothing batches** | One malformed row must not block a device's whole outbox. |
| **Permanent vs transient rejection is explicit** | Otherwise a poison message retries until the end of time. |
| **Server re-computes all tax and totals** | A fiscal document may never trust client arithmetic. |
| **Invoice numbers come from the device, in a per-device series** | A cashier offline must print a numbered bill *now*. §6 |
| **Device clock is reported, never trusted** | Android clocks drift and staff change them. Fiscal timestamps need skew detection. |
| **Money is `_paisa`, never `_cents`** | NPR subunit. Naming drift causes unit bugs. |

---

## 1. Authentication

```http
Authorization: Bearer <device_token>
X-Device-Id: 018f2c4a-...
X-App-Version: 1.4.2
```

- Admin pairs a device once through the web UI. The server issues a long-lived opaque token; only `token_digest` is stored.
- Revoking a lost tablet is deleting one `devices` row.
- **User identity is separate.** The PIN session travels in the operation payload as `acting_user_id`, not in the token. One device, many staff.
- **TLS is the transport guarantee. HMAC request signing is not specified here** — it duplicates protection that TLS plus idempotency keys already give, and adds key-rotation burden. Add it only if you conclude token extraction from a rooted device is a real threat; note the cost before you do.

`401` — token unknown or revoked. Device must wipe its token and show the pairing screen.
`403` — token valid, device disabled. Do not wipe; show "यो यन्त्र निष्क्रिय छ".

---

## 1a. `POST /owner/sessions` — owner login

A second, separate identity from everything else in this spec. Device tokens (§1) authenticate a *terminal*; PIN digests (§2) authenticate *staff, per operation*. This authenticates the **shop owner**, on the one device configured as `kind: "admin"`, so they can log into the on-device Admin screen without re-pairing and can generate pairing codes for other terminals (§1b) from the web admin.

Unauthenticated endpoint — no `Authorization` header on the request.

### Request

```json
{ "email": "owner@himalbhojanalaya.com.np", "password": "..." }
```

### Response — `200`

```json
{
  "owner_session_token": "ost_9f2a1c...",
  "owner": { "id": "01930c...", "name": "Ram Shrestha", "email": "owner@himalbhojanalaya.com.np" },
  "shop_id": "01930a..."
}
```

Store only a salted hash (`bcrypt`/Argon2) of the password server-side, same as PIN digests. `owner_session_token` is a long-lived opaque token, same shape as a device token — store `token_digest` only, revoke by deleting the row.

### Errors

| HTTP | `error` | Meaning |
|---|---|---|
| `401` | `invalid_credentials` | Wrong email or password. Generic message — do not reveal which. |
| `429` | `rate_limited` | Too many attempts; `Retry-After` header. Brute-force guard. |

The device should cache `owner_session_token` locally (DataStore, alongside `DevicePreferences`) so re-opening the Admin screen works **offline** after the first successful login — mirroring how a device token behaves post-pairing. Wipe it only on explicit logout or a `401` from an authenticated owner-scoped call.

---

## 1b. `POST /devices/pair` — exchange a pairing code for a device token

The Android-callable counterpart to "admin pairs a device through the web UI" (§1). The owner, logged into the web admin (§1a's session, browser-side), clicks "Add device" and the server shows a short-lived pairing code on screen. The new terminal calls this endpoint with that code to receive its own long-lived device token — this is what actually creates the `devices` row §1 already assumes exists.

Unauthenticated endpoint (the pairing code itself is the credential, not a device token — this device doesn't have one yet).

### Request

```json
{ "pairing_code": "HB-7X2Q", "device_label_ne": "काउन्टर १", "requested_kind": "counter" }
```

`requested_kind` is one of `waiter | kitchen | cashier | counter | admin` — offered as a hint from the pairing UI; the server may override it (e.g. the code itself was generated for a specific role) but always returns the authoritative `kind` in the response for the device to store.

### Response — `200`

```json
{
  "device_token": "dvt_3b7d9e...",
  "device_id": "018f2c4a-...",
  "kind": "counter",
  "invoice_series": "D2",
  "shop_id": "01930a..."
}
```

Immediately follow with `GET /bootstrap` (§2) using the new token — this endpoint only mints the credential, it does not return menu/shop/table data.

### Errors

| HTTP | `error` | Meaning |
|---|---|---|
| `404` | `invalid_pairing_code` | Code doesn't exist or was already consumed — codes are single-use. |
| `410` | `pairing_code_expired` | Codes expire a few minutes after generation (owner must generate a fresh one). |

Pairing codes are generated and displayed **only** on the web admin (owner-authenticated via §1a) — there is no Android-facing endpoint to create one; a terminal only ever consumes a code, never mints it.

---

## 2. `GET /bootstrap`

First run, and after any `409 bootstrap_required`. Returns everything the device needs to work fully offline.

```json
{
  "server_time": "2026-08-19T09:14:02Z",
  "cursor": 184920,
  "shop": {
    "id": "01930a...",
    "name_ne": "हिमाल भोजनालय",
    "name_en": "Himal Bhojanalaya",
    "pan_vat_no": "301234567",
    "vat_rate_bp": 1300,
    "service_charge_bp": 1000,
    "service_charge_enabled": true,
    "prices_include_tax": true,
    "fiscal_year_bs": "2083/84",
    "invoice_prefix": "HB"
  },
  "device": {
    "id": "018f2c4a-...",
    "label_ne": "क्यासियर १",
    "kind": "cashier",
    "invoice_series": "D1",
    "next_invoice_sequence": 1
  },
  "users": [
    { "id": "...", "name_ne": "सीता", "role": "cashier", "pin_digest_version": 3 }
  ],
  "dining_tables": [
    { "id": "...", "label_ne": "टेबल १", "label_en": "T1", "seats": 4, "position": 1 }
  ],
  "menu_items": [
    {
      "id": "...", "name_ne": "मःम", "name_en": "Momo",
      "category": "main", "gross_price_rupees": 180.0, "gross_price_paisa": 18000,
      "variants": [], "active": true, "position": 1
    }
  ]
}
```

**`gross_price_rupees` (float, 2dp) is the all-inclusive price the guest pays, and the field a client builds cart/tax/total math on.** VAT and service charge are extracted backwards from it — see `ARCHITECTURE.md` §6. `gross_price_paisa` (integer) rides along on the same object for a client that wants exact integer arithmetic instead; both represent the same price, pick one and don't mix them within a calculation. This is a wire-format choice for `/api/v1` consumers only — the server's own storage and its own tax computation (`Billing.compute`) remain integer paisa throughout, per `CLAUDE.md` invariant #1, regardless of which field a client reads. Line-item snapshots a client *submits* (§4 below) stay paisa-only — see there.

PIN verification is **online-preferred, offline-capable**: the device caches an Argon2/bcrypt digest per user so staff can log in during an outage. `pin_digest_version` bumps on any PIN change so the device knows its cache is stale.

---

## 3. `GET /delta?cursor=<int>&limit=<int>`

Incremental changes to reference data — menu, tables, users, shop settings.

```json
{
  "cursor": 184935,
  "has_more": false,
  "server_time": "2026-08-19T09:20:11Z",
  "changes": [
    { "seq": 184931, "entity": "menu_item", "action": "upsert",
      "record": { "id": "...", "name_ne": "चाउमिन", "gross_price_rupees": 220.0, "gross_price_paisa": 22000, "active": true } },
    { "seq": 184933, "entity": "menu_item", "action": "delete", "record": { "id": "..." } },
    { "seq": 184935, "entity": "shop", "action": "upsert",
      "record": { "service_charge_enabled": false } }
  ]
}
```

- `seq` is a **monotonic server-side integer**, not a timestamp. The device stores the last `seq` it applied.
- **Deletes are tombstones and must appear in the stream.** A delta feed that only sends upserts leaves removed menu items on the terminal forever — a real and common bug.
- Apply changes in `seq` order, in one Room transaction, then persist the cursor. Cursor advances only after a successful apply.
- If the server has pruned past the device's cursor: `409 { "error": "cursor_too_old" }` → device calls `/bootstrap` and rebuilds.

---

## 4. `POST /sync/batch`

The outbox drain. Mixed entity types, applied in the order given.

### Request

```json
{
  "device_time": "2026-08-19T09:21:44Z",
  "operations": [
    {
      "op_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
      "type": "ticket.create",
      "acting_user_id": "01930b...",
      "occurred_at": "2026-08-19T09:03:12Z",
      "payload": {
        "id": "7c2a...",
        "table_session_id": "5f11...",
        "items": [
          { "id": "aa01...", "menu_item_id": "...", "quantity": 2,
            "gross_price_paisa": 18000, "notes_ne": "पिरो नबनाउनु" }
        ]
      }
    },
    {
      "op_id": "1a2b3c4d-...",
      "type": "invoice.issue",
      "acting_user_id": "01930b...",
      "occurred_at": "2026-08-19T09:18:40Z",
      "payload": {
        "id": "e91f...",
        "table_session_id": "5f11...",
        "number": "HB/2083-84/D1/00042",
        "fiscal_year_bs": "2083/84",
        "series": "D1",
        "sequence": 42,
        "issued_at_bs": "2083-05-03",
        "gross_paisa": 69000,
        "base_paisa": 55511,
        "service_charge_paisa": 5551,
        "vat_paisa": 7938
      }
    }
  ]
}
```

`op_id` is the idempotency key. It is generated once when the row enters `sync_queue` and **never regenerated on retry**.

### Response — always `200`, even with failures inside

```json
{
  "server_time": "2026-08-19T09:21:45Z",
  "clock_skew_seconds": 3,
  "cursor": 184940,
  "results": [
    { "op_id": "9b1deb4d-...", "status": "accepted" },
    { "op_id": "1a2b3c4d-...", "status": "rejected", "retryable": false,
      "code": "tax_mismatch",
      "message_ne": "करको हिसाब मिलेन",
      "server_values": { "base_paisa": 55511, "service_charge_paisa": 5551, "vat_paisa": 7938 } }
  ]
}
```

### Per-operation status

| status | `retryable` | Device action |
|---|---|---|
| `accepted` | — | Mark `synced`. |
| `duplicate` | — | Mark `synced`. Already ingested; this is the normal retry path. |
| `rejected` | `false` | Mark `failed`. **Stop retrying.** Surface to admin. |
| `deferred` | `true` | Leave `pending`. Retry with backoff. |

**A `rejected` operation must never be retried automatically.** This is the single most important line in this spec — without it a malformed row blocks the outbox head forever and the device silently stops syncing.

HTTP-level codes: `200` for any batch the server understood. `401`/`403` auth. `429` with `Retry-After`. `503` when the server is starting or migrating — device backs off. Never return `500` for a business rejection.

### Ordering

Operations apply in array order within a batch. If one is `deferred`, later operations that depend on it are also `deferred` (dependency inferred from `table_session_id` / `ticket_id`). The device must not reorder its outbox — FIFO by `sync_queue.id`.

---

## 5. Operation types

| `type` | Payload core | Notes |
|---|---|---|
| `table_session.open` | `id`, `client_token`, `dining_table_id`, `guest_count` | Conflict rules §7 |
| `ticket.create` | `id`, `table_session_id`, `items[]` | Snapshots prices |
| `ticket.status` | `id`, `status` | Usually from web kitchen, but Android may mark `served` |
| `ticket_item.void` | `id`, `void_reason_ne` | Reason mandatory; server rejects without it |
| `table_session.discount` | `id`, `discount_paisa`, `reason_ne`, `approved_by_id` | |
| `invoice.issue` | §6 | Server re-computes every figure |
| `payment.record` | `id`, `table_session_id`, `method`, `amount_paisa`, `reference` | `cash`\|`fonepay`\|`esewa`\|`khalti`\|`imepay`\|`card`\|`credit`\|`other` |
| `table_session.close` | `id`, `closed_at` | |
| `invoice.print` | `invoice_id` | Records that a device printed locally (e.g. Bluetooth ESC/POS) — bumps `print_count` for audit/history. Never enqueues a server-side print job; that path (`reprint_invoice`, a network-attached printer) is the web admin's own, unrelated to this. |

**`table_session_id` in every dependent op is a lookup key with two valid shapes, not always the same type.** `table_session.open`'s own `id` is never adopted as the row's real id — a device has no way to know the server's next integer in advance, and letting a client hand out primary keys isn't safe regardless. Instead, `table_session.open` carries a device-minted `client_token` (a UUID, generated once when the table is tapped); the server resolves or creates a session against it and returns the *real* integer id in the operation's result. From there, a device may use either that real id or its own `client_token` as `table_session_id` in every dependent op (`ticket.create`, `payment.record`, `invoice.issue`, `table_session.close`, `table_session.discount`) — the server tells the two apart by shape (all-digit → real id; anything else → `client_token` lookup). Using the client_token throughout is simplest for an offline-first client that may never see the server's response to `table_session.open` (a dropped reply after a successful write) — every later op in the same order still resolves correctly without waiting on that response.

**Nothing is ever deleted.** There is no `delete` operation type. Voids set a flag; corrections are credit notes.

---

## 6. Invoice numbering — per-device series

This is the hardest constraint in an offline fiscal POS and the generic design has no answer for it.

**The problem.** Nepal requires gapless sequential invoice numbers per fiscal year. A cashier who is offline must still print a numbered bill immediately. A single server-side counter cannot supply one.

**The solution.** Each device gets its own declared series and keeps its own counter.

```
HB / 2083-84 / D1 / 00042
│     │         │     └── device-local sequence, gapless within the series
│     │         └──────── series code, allocated at pairing (D1, D2, ...)
│     └────────────────── Nepali fiscal year (Shrawan 1 – Ashad end)
└──────────────────────── shop prefix
```

Rules:

1. The device allocates `sequence` **only when the bill is finalised** — never pre-allocated to an abandoned tab, or you create real gaps.
2. Uniqueness constraint on the server: `(shop_id, fiscal_year_bs, series, sequence)`.
3. **The server never renumbers.** If it disagrees with a number, it rejects the operation and the device escalates to admin.
4. A gap in a device's series means an invoice was lost before sync. The server detects gaps on ingest and raises an admin alert. Do not swallow this.
5. At Shrawan 1 every device resets its sequence to 1 under the new `fiscal_year_bs`. The device learns the rollover from `/bootstrap` or `/delta`; it must also roll over **on its own** if it is offline across the boundary, using its local BS calendar.
6. Declare the series list to the IRD if approval is ever sought. Multiple series are permitted; undeclared ones are not.

**Server re-computes and validates every monetary field.** If the device's `vat_paisa` differs from the server's extraction by even one paisa, the operation is `rejected` with `code: tax_mismatch` and the server's figures attached. The device must not auto-correct and re-submit — a printed bill already exists, so this is a human problem: it goes to the admin queue.

---

## 7. Conflicts

| Situation | Rule |
|---|---|
| Two devices open the same table | **Not a conflict.** Find-or-create on `dining_table_id`: the second `table_session.open` silently joins the session the first one created (or one already open on that table from any earlier source) and gets `accepted` with the same real `table_session_id` back — never `rejected`. This is a deliberate choice, not an oversight: two waiters reaching the same table is the normal case (see the row below), and an explicit `session_exists` rejection was considered and rejected as unnecessary friction for that case. |
| Multiple devices add tickets to one session | **Allowed.** Two waiters on one table is normal. Only `open` is exclusive. |
| Session closed on device A, ticket arrives from device B | Ticket is `accepted` and the session reopens with an `audit_event`. Never drop an order that was actually made. |
| Menu price changed while device was offline | Irrelevant. Line items carry `gross_price_paisa` snapshots. |
| Device clock skew > 300s | Every operation still `accepted`, but `clock_skew_seconds` is returned and the app must show a persistent warning. Server stores both `device_occurred_at` and `server_received_at`. |

---

## 8. `GET /updates?cursor=<int>`

Transactional changes flowing **back** to the device — kitchen marking a ticket ready, another terminal closing a session.

```json
{
  "cursor": 184952,
  "changes": [
    { "seq": 184948, "entity": "ticket", "action": "status",
      "record": { "id": "7c2a...", "status": "ready" } }
  ]
}
```

Poll every 5–10s while the app is foregrounded. **Do not use FCM.** It requires internet and Google Play Services; this server is on the LAN and must work with the internet unplugged. Polling a LAN endpoint costs nothing.

---

## 9. `GET /health`

Unauthenticated. Drives the connectivity indicator.

```json
{ "ok": true, "server_time": "2026-08-19T09:25:00Z", "cursor": 184952 }
```

The app polls this every 5s. Over 15s without a response → offline banner, and the outbox depth becomes visible to the user.

---

## 10. Android outbox — corrections to the draft schema

Keep the outbox pattern. Three fixes:

```sql
CREATE TABLE sync_queue (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,  -- FIFO order, never reorder
    op_id         TEXT NOT NULL UNIQUE,               -- idempotency key, generated ONCE
    type          TEXT NOT NULL,
    payload       TEXT NOT NULL,
    status        TEXT NOT NULL DEFAULT 'pending',    -- pending|processing|synced|failed
    retry_count   INTEGER NOT NULL DEFAULT 0,
    next_retry_at TEXT,                               -- exponential backoff
    error_code    TEXT,
    created_at    TEXT NOT NULL,
    synced_at     TEXT
);
CREATE INDEX idx_sync_pending ON sync_queue (status, id);
```

1. **`op_id` is generated once, at enqueue.** Regenerating it on retry defeats idempotency entirely and produces duplicate sales.
2. **`failed` is terminal.** A permanently rejected operation leaves the queue and appears in an admin screen. It must not block the head.
3. **`next_retry_at` drives backoff** — 5s, 15s, 60s, 5min, capped at 15min. Do not hammer a LAN server that is down.

**Drop `products.stock_quantity` from the device.** Client-authoritative inventory diverges across offline terminals and cannot be reconciled honestly. This restaurant has a fixed menu and needs no inventory in v1. If it is added later, it is server-authoritative and the local copy is advisory display only.

**Retention:** prune `synced` rows after 30 days, but **never prune `failed`** — those are unresolved money.

---

## 11. Error codes

| Code | Retryable | Meaning |
|---|---|---|
| `validation_failed` | no | Malformed payload. Bug — log and surface. |
| `tax_mismatch` | no | Client arithmetic disagrees with server. §6 |
| `invoice_duplicate` | no | `(fy, series, sequence)` already used. Serious — admin alert. |
| `void_reason_required` | no | Void without a reason. |
| `unknown_menu_item` | no | Device cache stale; trigger `/delta`. |
| `cursor_too_old` | no | Re-bootstrap. |
| `fiscal_year_mismatch` | no | Device did not roll over at Shrawan 1. |
| `server_busy` | yes | Back off. |
| `db_locked` | yes | SQLite write contention. Back off. |

---

## 12. Versioning

- URL-versioned: `/api/v1`. A breaking change is `/api/v2`, served alongside for at least one release.
- The device sends `X-App-Version`. The server may return `426 { "error": "upgrade_required", "min_version": "1.5.0" }` to force an update — necessary if the tax logic changes.
- **Additive changes never break clients.** The Android app must ignore unknown JSON fields; configure Moshi/kotlinx accordingly from day 1.

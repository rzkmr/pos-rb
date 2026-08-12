# pos-rb

Restaurant POS for a single shop, running on a mini PC on the restaurant LAN.
Rails 8 + Hotwire + PostgreSQL. Money is integer paise everywhere. Market:
India — INR, GST, UPI.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full design and reasoning,
and [`CLAUDE.md`](CLAUDE.md) for the non-negotiable invariants (money, void
audit trail, invoice numbering, etc.) — read that before changing anything
that touches billing.

---

## Requirements

- Ruby 3.4.5
- PostgreSQL
- Node not required — JS is import-map based, CSS is Tailwind

## Setup

```bash
bin/setup       # bundle install, db:prepare
bin/dev         # starts the server + asset watcher on http://localhost:3000
```

## Running the tests

```bash
bin/rails test          # unit + integration
bin/rubocop -A          # rails-omakase style
bin/brakeman            # security scan, run before any deploy
```

> `test/system` doesn't exist yet — the six critical flows in `CLAUDE.md`
> ("Testing expectations") are covered today as integration tests under
> `test/controllers/`, not true browser-driven system tests.

---

## Using the app

There are two separate ways to sign in, and they are not interchangeable:

| Who | Signs in with | Where |
|---|---|---|
| **Admin** (owner/manager) | Username + password | `/admin/session/new` — any browser, no device pairing needed |
| **Staff** (waiter, cashier, kitchen) | Name + 4-digit PIN | Shared tablets/phones that have been paired to this shop first |

Admin access is deliberately never reachable through a PIN, on any device —
see the security note at the bottom.

### 1. First-time setup (once, ever)

On a brand new install there is no shop yet, so every URL redirects to the
setup wizard automatically.

1. Open the app in a browser — you'll land on **`/setup/new`**.
2. Fill in the shop name, GST state code, address, and GSTIN (leave GSTIN
   blank if you're on the composition scheme).
3. Choose a **device pairing PIN** — any 4 digits. This is what tablets and
   phones will enter once to join the shop. It is not a login.
4. Choose your **admin username and password** (password: 8+ characters).
   This is you, signing in from now on.
5. Submit. You're redirected to `/admin/session/new` — sign in with what you
   just set.

This screen is permanently closed once a shop exists; visiting `/setup/new`
again just redirects you back into the app.

### 2. Pair your devices

Each tablet or phone that staff will use needs to be paired once:

1. On that device, open **`/devices/pair`**.
2. Give it a label ("Kitchen display", "Counter tablet") and pick a kind.
3. Enter the device pairing PIN from setup.

The device stays paired indefinitely (a signed, long-lived cookie) — staff
never re-pair, they just sign in and out with their PIN.

### 3. Set up the shop as admin

Sign in at `/admin/session/new`, then from the admin dashboard (`/admin`):

- **Menu** — add items, prices (entered in paise), HSN/SAC codes, categories.
- **Tables** — add your dining tables or counters. A fresh shop has none;
  staff can't open an order until at least one exists.
- **Staff** — create a user per waiter/cashier/kitchen person and set their
  4-digit PIN. This is the only place PINs are created or reset.
- **Settings** — shop details, GSTIN, composition scheme, and the thermal
  printer's IP address / port (needed before invoices will print).
- **Devices** — see and revoke paired tablets/phones.
- **Sales** — daily totals, GST breakdown, payment-method reconciliation.

### 4. Day-to-day (staff)

On a paired device, staff sign in with their name and PIN:

1. **Counter / table** — pick a table (or the counter), add items to the
   cart, send to kitchen. Submission is idempotent — safe to retry on a
   flaky connection, it will never create a duplicate ticket.
2. **Kitchen display** — tickets appear live, mark preparing → ready →
   served. A full-screen alarm fires if the connection goes stale.
3. **Bill / cashier** — open a table's bill, void a line (reason required),
   apply a discount (reason required), take one or more payments (split
   cash/UPI/card is fine), print or reprint the invoice.

Every void, discount, and reprint is logged with who did it. Every admin
change (menu, staff, tables, settings) is logged too.

---

## Security note

Admin (menu, staff, tables, settings, sales, devices) and shop-floor PINs are
two entirely separate authentication systems on purpose:

- A staff PIN typed into any shared tablet **cannot** reach `/admin/*`,
  regardless of which PIN it is.
- Admin login needs no paired device and works from any browser on the LAN.

If you are exposing this box beyond the restaurant's own network, complete
setup and admin login **before** doing so — the setup wizard has no
credential gate beyond "no shop exists yet," so the first request to reach
it on a reachable network claims the shop.

# Handoff: Nepali Restaurant POS (waiter / kitchen / cashier / admin)

## Overview
Touch POS for a small Nepali restaurant. Six screens: PIN + session open, waiter order-taking
(phone), kitchen ticket wall (tablet), cashier bill + payment (tablet), 80mm thermal bill preview,
and end-of-day reconciliation (laptop/admin). Nepali (नेपाली) is the default language with an
English toggle. Devanagari numerals for dates / table numbers / guest counts; Arabic numerals for
money, quantities and phone numbers. All money is computed from **integer paisa** — never floats.

## About the design files
Two prototypes ship in this bundle:

| File | What it is |
|---|---|
| `Restaurant POS.dc.html` | The six-screen Nepali POS (§2) — waiter, kitchen, cashier, print, admin, PIN |
| `QuickPOS.dc.html` | Single-screen counter service (§8), same token set, English/USD |
| `QuickPOS-standalone.html` | The same screen bundled offline — open it directly, no server, no assets |

They are **design references built in HTML** — a working
prototype of the intended look and behavior, not production code to copy. The task is to recreate
it in the target codebase's own environment (Rails + Hotwire + Tailwind, React, etc.) using that
project's established patterns. Open the file in a browser: the dashed **SIM** row drives the
offline, stale-connection, aging-ticket, void, split-payment, cash-change and undo states.

## Fidelity
**High fidelity.** Colors, type sizes, touch-target sizes and copy are final-intent. Recreate
pixel-close. The one deliberate placeholder is the menu itself (10 items from the spec) — swap in
the real menu.

---

# 1. Tailwind setup

## 1.1 Tokens — Tailwind v4 (`app/assets/stylesheets/application.css`)

```css
@import "tailwindcss";

@theme {
  /* neutrals — warm, low chroma */
  --color-shell:   #edece7;  /* page background */
  --color-surface: #f7f6f2;  /* panels, sheets */
  --color-card:    #ffffff;  /* tiles, rows, tickets */
  --color-line:    #dddbd3;  /* hairline border */
  --color-line-2:  #d2d0c8;  /* input / control border */
  --color-key:     #e4e2da;  /* keypad, inactive chips */
  --color-key-2:   #cfccc2;  /* pressed / disabled */
  --color-ink:     #16181c;  /* primary text, dark buttons */
  --color-ink-2:   #4a4d54;  /* secondary text */
  --color-ink-3:   #6a6d74;  /* tertiary */
  --color-ink-4:   #7a7d84;  /* mono captions, disabled label */

  /* semantic — state must never be colour alone */
  --color-go:      #1d5c48;  /* primary action, "connected", match */
  --color-go-700:  #12402f;  /* pressed */
  --color-go-50:   #e8f2ee;  /* tint */
  --color-warn:    #f0b429;  /* pending, aging ticket, stale overlay */
  --color-warn-700:#a97400;  /* aging border */
  --color-warn-900:#22190a;  /* text on warn */
  --color-warn-50: #fdf3dc;  /* aging card fill */
  --color-stop:    #b4231d;  /* void, late ticket, cash short */
  --color-stop-50: #fdeceb;  /* late card fill */
  --color-slate:   #3d4249;  /* fresh ticket border */

  /* kitchen wall chrome (dark) */
  --color-wall:    #14161a;
  --color-wall-2:  #0e1013;
  --color-wall-3:  #2a2e34;
  --color-live:    #3ec07a;

  --font-ne:   "Noto Sans Devanagari", system-ui, sans-serif;
  --font-mono: "Noto Sans Mono", ui-monospace, monospace;

  --radius-tile:  1rem;    /* 16px  item tiles, sheets */
  --radius-ctl:   0.875rem;/* 14px  primary buttons, modals rows */
  --radius-key:   0.75rem; /* 12px  keypad, chips-square */
  --radius-phone: 2.25rem; /* 36px  phone screen inner radius */
}

/* Self-host the font — the server runs on a LAN and must work with the internet unplugged.
   Do NOT use the Google Fonts CDN in production (the prototype does, for convenience). */
@font-face {
  font-family: "Noto Sans Devanagari";
  src: url("/fonts/NotoSansDevanagari-Regular.woff2") format("woff2");
  font-weight: 400; font-display: swap;
}
/* repeat for 500, 600, 700 */

@layer base {
  html { font-family: var(--font-ne); line-height: 1.6; } /* 1.6 min — 1.4 clips शिरोरेखा on Android */
  body { @apply bg-shell text-ink; text-wrap: pretty; -webkit-tap-highlight-color: transparent; }
  a { @apply text-go; } a:hover { @apply text-go-700; }
}
```

Tailwind v3 equivalent: move the same values into `theme.extend.colors / fontFamily / borderRadius`
in `tailwind.config.js`, and set `theme.extend.lineHeight.DEFAULT`.

## 1.2 Rules that must not be Tailwind-defaulted

| Rule | Why | Tailwind |
|---|---|---|
| Body ≥ 18px, waiter phone ≥ 20px | Devanagari conjuncts break below 16px on cheap screens | `text-[19px]` / `text-[21px]`; do **not** use `text-sm`/`text-base` |
| Line-height ≥ 1.6 | ascenders + descenders clip | `leading-[1.6]` — never `leading-tight` on Nepali |
| Touch targets ≥ 64px | hurried user, one hand | `min-h-[64px]`, primary `min-h-[70px]`, cashier pay `min-h-[84px]` |
| Buttons flex to label | Nepali runs 20–40% longer than English | `px-4 py-3` + `min-h-*`; **never** `w-32`/fixed widths |
| Kitchen item names ≥ 28px | readable from 2m | `text-[28px]` |
| Contrast ≥ 4.5:1 | fluorescent light, greasy glass | all pairs in §1.1 already pass |
| Money in mono, tabular | scanned against a cash drawer | `font-mono tabular-nums` |

## 1.3 Component recipes (copy-paste class strings)

```erb
<%# item tile — waiter phone, 2-col grid %>
<div class="grid grid-cols-2 gap-2.5 p-3.5">
  <button class="min-h-[104px] p-3 rounded-tile bg-card border-2 border-line
                 flex flex-col justify-between items-start text-left gap-1.5
                 active:border-go active:bg-go-50">
    <span class="text-[20px] font-semibold leading-[1.35]">मःम</span>
    <span class="w-full flex items-center justify-between">
      <span class="text-[18px] font-mono text-ink-2">Rs 180</span>
      <span class="text-[16px] font-bold font-mono text-go">× 2</span>
    </span>
  </button>
</div>

<%# primary action — bottom of screen, thumb reach %>
<button class="min-h-[70px] px-4 py-2.5 rounded-tile text-[21px] font-bold leading-[1.35]
               bg-go text-surface active:bg-go-700
               disabled:bg-key-2 disabled:text-ink-4">भान्सामा पठाउनुहोस्</button>

<%# pending banner — amber, persistent, counts items, colour + dot + text %>
<div class="flex items-center gap-2.5 px-4 py-3 bg-warn text-warn-900 border-b-[3px] border-warn-700">
  <span class="w-3.5 h-3.5 rounded-full bg-[#7a5300] animate-pulse"></span>
  <span class="text-[17px] font-bold">२ अर्डर पठाइँदै... इन्टरनेट जोडिएन</span>
</div>

<%# kitchen ticket — three ages. Shape/glyph carries the state as well as colour. %>
<%# fresh  %> bg-card    border-slate    glyph ■
<%# ≥10min %> bg-warn-50 border-warn-700 glyph ●
<%# ≥15min %> bg-stop-50 border-stop     glyph ▲  + diagonal stripe overlay:
<div class="pointer-events-none absolute inset-0
            bg-[repeating-linear-gradient(135deg,rgba(180,35,29,.22)_0_14px,rgba(180,35,29,0)_14px_30px)]"></div>

<%# destructive %>
<button class="min-h-[68px] rounded-ctl text-[19px] font-bold bg-card border-[2.5px] border-stop text-stop">रद्द गर्नुहोस्</button>

<%# stepper — replaces every keyboard in the waiter flow %>
<div class="flex items-center gap-3.5">
  <button class="w-[84px] h-[84px] rounded-[18px] bg-key text-[38px] font-bold active:bg-key-2">−</button>
  <div class="flex-1 text-center text-[44px] font-bold font-mono">3</div>
  <button class="w-[84px] h-[84px] rounded-[18px] bg-go text-surface text-[38px] font-bold active:bg-go-700">+</button>
</div>

<%# undo toast — beats a modal wherever the action is reversible %>
<div class="absolute left-3.5 right-3.5 bottom-5 flex items-center gap-3 px-4 py-3.5
            rounded-tile bg-ink text-surface">
  <span class="flex-1 text-[17px] font-semibold">अर्डर भान्सामा गयो</span>
  <button class="px-4 py-3 rounded-key bg-warn text-warn-900 text-[17px] font-bold">फिर्ता लिनुहोस्</button>
</div>
```

Notes for Tailwind specifically:
- No `hover:`-only affordances. Every touch surface gets `active:` (and `focus-visible:` for admin).
- Arbitrary pixel values (`text-[20px]`) are intentional — the Tailwind type scale has no 18/19/21/28
  steps and rounding down breaks Devanagari legibility. Alternatively extend `theme.fontSize`.
- Kitchen wall is a dark surface, not `dark:` mode — it is always dark. Use the `wall-*` colors directly.
- `animate-pulse` is close enough to the prototype's 1.1s blink; for an exact match add a
  `blink` keyframe to `@theme`.

---

# 2. Screens

## 2.1 PIN + session open — phone, 392px shell
Purpose: identify the waiter (`placed_by_id` comes from this session, never a dropdown) and capture
`guest_count` in one tap at session open.
Layout: header (21px title / 17px sub) → four 58px PIN cells (`rounded-key border-2 border-line-2`,
active cell tinted `bg-go-50`) → 3×4 keypad, keys `h-[72px] rounded-[14px] bg-key text-[26px] font-mono`,
Devanagari digit faces (०–९), `←` and `✓` → hairline → "कति जना?" → six 66px guest chips, selected
`bg-go text-surface` → `mt-auto` hint + 70px primary `टेबल खोल्नुहोस्`, disabled until PIN length 4.

## 2.2 Waiter — phone
Green session header `bg-go text-[#f2f7f4]`: `टेबल ५` 24px bold / `३ जना` 19px, second line
`खुला — २ राउन्ड` 16px at 85% opacity. Optional pending banner. Three category tabs
(`खाना / स्नाक्स / पेय`, selected `bg-ink text-surface`). 2-col tile grid, min-height 104px — two taps
to add: category → item, no search, no nesting. Cart rows are full-width buttons
(19px name / mono qty / 96px right-aligned mono total) opening a **bottom-sheet stepper**; note text
renders below the row in `text-[#8a5a00]`. Footer: `जम्मा` 20px + total 28px mono, then the 70px
primary. Tapping a tile adds one, no confirm, ever.

Bottom sheet: `rounded-t-[24px] bg-surface p-5`, riseIn 180ms ease-out, stepper (§1.3), preset note
chips (`पिरो नबनाउनु / कम पिरो / प्याज नहाल्नु / धेरै पिरो`, selected `bg-warn`), one free-text
`h-[60px]` input (the only keyboard in the flow), then `हटाउनुहोस्` (outlined stop) + `भयो` (ink).

## 2.3 Kitchen — tablet, wall-mounted, 1064px
Dark chrome bar `bg-wall-2`: `भान्सा` 30px, connection dot 18px + label 20px, clock 26px mono
Devanagari. Ticket grid `repeat(auto-fill, minmax(232px, 1fr))`, gap 16px, cards min-height 300px,
3px border, header band uses the border color at full bleed with white text (table 26px, glyph + age
20px). Items 28px / qty 26px mono. Notes are amber blocks, 21px bold, `border-l-[6px] border-[#7a5300]`.
`✓ तयार` button min-height 68px, `bg-go`, margin 14px.
- Audible beep (880Hz square, 300ms) on every new ticket — kitchens are loud, nobody is watching.
- Aging drives colour **and** glyph **and** stripe (§1.3).
- Over 15s stale → full-screen `bg-warn` overlay, `जोडिँदै... २३ सेकेन्ड` at 46px with a live counter.
  A frozen screen must *look* frozen. This overlay is the most important thing on the screen.

## 2.4 Cashier — tablet, 900px
Ink header (table + bill, mono BS date right). Line rows 21px / mono qty / 130px mono total.
**Total first**: white card, `जम्मा (कर सहित)` 24px + total **38px mono**; breakdown beneath at 17px
`text-ink-3` (मूल्य, सेवा शुल्क १०%, मू.अ.कर १३%). Tax is derived from the tax-inclusive total:
`base = round(total / 1.243)`, `service = round(base * 0.10)`, `vat = total - base - service`.
Payments accumulate in a `bg-go-50 border-2 border-go` card with `बाँकी` (or `पूरा भुक्तानी भयो`) at
22px bold. Four pay buttons `min-h-[84px] border-[2.5px] border-ink`, 20px bold. Footer:
outlined-stop `रद्द गर्नुहोस्` (flex 1) + `बिल छाप्नुहोस्` (flex 2, `bg-go` once the balance is clear).
- Cash modal: due line, received (36px mono), then **change due at 54px mono** on `bg-go` — this is
  where mistakes cost money. 3×4 keypad with a `00` key. `नगद लिनुहोस्` disabled while short.
- Void modal: `border-t-8 border-stop`, mandatory reason chips (गलत अर्डर / ग्राहकले फिर्ता गर्नुभयो /
  बिग्रियो) + optional free text; confirm stays `bg-key-2` disabled until a reason exists; hint line
  flips from stop-red "कारण छान्नुहोस्" to go-green "रद्द गर्न तयार". Voiding shows a 5s undo toast
  carrying the reason.

## 2.5 Thermal bill preview — 80mm (340px)
White, 15px/1.65, dashed `#9a9aa0` rules. Header: business name 21px, address 14px, `PAN 601234567`
mono, `कर बीजक` 15px bold. Meta rows: मिति (Devanagari `२०८३/०४/२९`), बीजक नं. `२०८३-००४१२`, टेबल,
पस्किने. Item rows: name / 34px qty / 76px amount, all Arabic mono. Tax breakdown 14px, solid rule,
`जम्मा` 19px bold. Then tender lines, `धन्यवाद!`, and the IRD reprint label
`सक्कलको प्रतिलिपि` 13px mono.
**Devanagari must reach the printer as a raster image** — the font/text path cannot form conjuncts.
Render the receipt to a 1-bit bitmap server-side and send ESC/POS raster.

## 2.6 Admin — end-of-day reconciliation, laptop
The one admin screen that matters. Table `1.4fr 1fr 1fr 1.2fr`: माध्यम / सिस्टममा / गनेको / फरक,
header `bg-[#f2f1ec]` 16px bold, rows 20px with a `w-[120px] h-[52px]` right-aligned mono numeric
input for counted cash. Difference is `—` when matched (go), `+`/`−` in stop red otherwise, `·`
grey when uncounted. Below: verdict banner, 40px bold — `सबै मिल्यो` on `bg-go`, `नगद कम छ` /
`नगद बढी छ` on `bg-stop`, `गन्ती बाँकी` on `bg-key` — plus the signed amount in 20px mono. Then four
KPI cards (दिनको बिक्री, प्रति ग्राहक, रद्द, प्रति बिल). Owner checks this nightly; if it is hard to
read they stop checking. English is acceptable on this screen only.

---

# 3. Interactions & behavior

| Trigger | Behavior |
|---|---|
| Tap item tile | +1 to cart. **No confirm, no toast, no dialog.** Tile shows `× n`. |
| Tap cart row | Bottom sheet stepper, 180ms riseIn. Never a keyboard. |
| Stepper − at qty 1 | Removes the line and closes the sheet. |
| `हटाउनुहोस्` | Removes line + 5s undo toast. |
| Send to kitchen | Clears cart, increments round count, creates ticket, beeps, 5s undo toast (undo restores cart and deletes the ticket). |
| Send while offline | Ticket goes to a client queue; amber pending banner appears with a count and stays until confirmed success. |
| Reconnect | Queue flushes to the kitchen wall, beep fires, banner disappears. |
| Ticket ages | 10 min → amber + `●`; 15 min → red + `▲` + diagonal stripe. Re-evaluated on a 1s tick. |
| `✓ तयार` | Ticket leaves the wall. |
| Kitchen link dies | Full-screen amber overlay with a seconds counter incrementing every 1s. |
| Non-cash pay method | Adds a partial payment; remaining balance recalculates and stays visible. |
| Cash | Keypad modal; change = received − remaining, shown at 54px; confirm disabled while negative. |
| Void | Reason mandatory; confirm disabled without one; undo toast after. |
| Language toggle | Swaps every user-facing string and every numeral context at once. |

Confirm dialogs exist **only** for void, close bill, and discount. Everything reversible uses a 5s
undo toast instead. No time-limited dialogs — a waiter gets interrupted mid-tap. Nothing is icon-only;
every icon carries a Nepali label.

Error copy says what to do next: `इन्टरनेट जोडिएन — अर्डर पठाइँदैछ`, never `Error 422`.

# 4. State

```
session:  table, guest_count, waiter (from PIN), rounds_sent
cart:     [{ menu_item_id, qty, note }]           # client-side until sent
tickets:  [{ id, table, placed_at, placed_by_id, items[], status }]
queue:    [ticket]  # offline outbox, each with a client_token generated BEFORE submit
payments: [{ method, paisa, received_by_id }]
ui:       screen, lang, editing_line, undo{text,fn}, cash_given, void_reason, counted{}
```
Capture at the moment of truth: `guest_count` at session open, `placed_by_id` on every ticket, a
**price snapshot on every line** (a menu edit must never alter a past bill), `void_reason_ne` on
every void, `received_by_id` on every payment, `client_token` generated client-side before submit so
retries are idempotent. Do **not** capture customer name or phone.

Numerals: Devanagari is a rendering concern only — never stored, never in a calculation, never
returned from a form. Inputs use `inputmode="numeric"`, accept both scripts, normalise to Arabic
immediately.

# 5. Assets
None. No images, no icon library — state glyphs are the text characters `■ ● ▲ ✓ − +`. You must
self-host Noto Sans Devanagari (400/500/600/700 woff2) at `/fonts/`.

# 6. Files
- `Restaurant POS.dc.html` — the six-screen prototype. Use the tab row to switch screens and the
  dashed SIM row to drive offline / stale / aging / void / split-payment / undo states.
- `QuickPOS.dc.html` + `QuickPOS-standalone.html` — the counter-service screen (§8).
- `support.js` — runtime for the `.dc.html` files; keep it beside them. The standalone file needs nothing.

# 7. Before you call it done
- [ ] Tested on the cheapest Android phone a waiter actually owns
- [ ] Every string reviewed by a native speaker who works in hospitality (informal register: अर्डर not आदेश; loanwords टेबल/बिल/किचन kept; buttons imperative: पठाउनुहोस्, छाप्नुहोस्)
- [ ] Kitchen screen legible from 2m under kitchen lighting
- [ ] Devanagari verified on the actual thermal printer via the raster path
- [ ] Every money figure traced from integer paisa to display — no float in between
- [ ] A waiter who has never seen the app can place an order after under two minutes of instruction

---

# 8. QuickPOS — counter service, one screen

A second, simpler layout on the identical token set: English, USD, no table sessions. Use it as the
reference for any single-operator counter (café, takeaway, bar). Every color, radius and target size
below is already defined in §1.1 — nothing new is introduced.

## 8.1 Layout
`1240px` shell, `rounded-[18px] border border-line-2 bg-surface`, min-height 780px, two columns.

**Left — catalogue.** Header: shop name 22px bold + date/time 15px mono `text-ink-3`; right side holds
`Hold` and `Held orders` (both `min-h-[64px] border-2 border-line-2 bg-card`, the latter with a count
pill that turns `bg-warn` once anything is parked). Search row: full-width `h-[64px]` field,
`⌕` glyph in mono, clear button appears only when non-empty. Category chips: `min-h-[52px] rounded-full`,
selected `bg-ink text-surface`. Grid: `repeat(auto-fill, minmax(178px, 1fr))`, gap 12px, tiles
`min-h-[132px] rounded-tile bg-card border-2 border-line` with a 4px accent bar along the top edge,
a 40px mono-initials square tinted per category, name 18px, price 19px mono, and `× n` in `go` once
the item is in the cart. Empty search state is a plain sentence, never an illustration.

**Right — cart, 396px.** Header `Current order` + `Clear` (red label only when the cart has contents).
Rows: name 18px / `$x.xx each` 15px mono / 48px −/+ steppers / 84px right-aligned mono line total.
Footer on `bg-surface`: subtotal + tax rows 16px `text-ink-3`, rule, `Total` 20px with the figure at
30px mono, then the `min-h-[72px]` pay button — `bg-go` with the amount inline, `bg-key-2` and
"Add items to pay" when empty.

## 8.2 Payment, receipt, hold
- **Payment modal** (520px): due amount 40px mono on a white card, then Cash / Card as two 84px
  buttons. Cash reveals four quick-tender chips (exact amount first, then the next round notes) plus
  an "Other amount" field; the change block is 44px mono — `bg-go` when covered, `bg-stop` with the
  label flipped to **Short by** when not. Confirm stays disabled until the tender covers the total.
  Card runs a 1.5s spinner → green check → auto-completes.
- **Receipt modal** (460px): green check, order number `#0043`, then an 80mm-style receipt block on
  white with dashed rules — shop block, order/timestamp line, item lines, subtotal + tax, solid rule,
  `TOTAL` 19px bold, tender + change. Actions: `Print` (outlined) and `New order` (`bg-go`).
- **Hold** parks the cart with a 5s undo toast; `Held orders` lists each parked ticket on a card with
  a 6px `warn` left edge, item summary, time, total, `Restore` (`bg-go`) and an outlined-`stop` delete.
- **Toast** is centred bottom, `bg-ink`, with an amber `Undo` when the action is reversible. Clearing
  the cart and holding an order both use it — neither gets a confirm dialog.

## 8.3 State
```
cart:    [{ id, name, price_cents, qty }]
held:    [{ items[], at }]
ui:      category, query, pay_open, method, cash_input, card_stage, receipt, held_open, toast
props:   shop_name, tax_rate (default 8%)
```
Money is integer cents end to end; `tax = round(subtotal * rate / 100)`; the displayed total is
`subtotal + tax`. Quick-tender chips are derived, not hardcoded: `ceil(total)` first, then the round
notes above it.

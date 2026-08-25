# UI & Data Capture Design

**Users:** Nepali restaurant staff. Assume no technical background, possibly limited literacy, working fast under pressure, on their own phones in poor light.
**Language:** Nepali (नेपाली) default, English toggle.
**Numerals:** Devanagari for dates, Arabic for money and quantities.

**Platform split.** §4.1 waiter and §4.3 cashier are the **Android app** (Jetpack Compose). §4.2 kitchen display and §4.4 admin are **web** (Hotwire) on the LAN server. The layouts and rules below apply to both — Compose `Modifier.sizeIn(minHeight = 64.dp)` and a CSS `min-height` express the same requirement.

Two extra rules for the Android screens, because they work offline:

- **Outbox depth is always visible** when non-zero. `२ अर्डर पठाइँदै...` — persistent, amber, dismissible only by success.
- **A failed operation is never hidden.** Terminally rejected items get a red row and an admin escalation, not a silent drop. See `API-SPEC.md` §4.

---

## 1. Design principles

These are ranked. When two conflict, the higher one wins.

**1. Never lose an order.** Every other consideration is secondary. A pending order must be visible, countable, and impossible to mistake for a sent one.

**2. Two taps to add an item.** Category → item. No nesting, no search, no scrolling for the common case. With ~10 menu items everything fits on one screen.

**3. Show state with colour *and* shape *and* text.** Colour alone fails for the ~8% of men with colour-vision deficiency, and it fails completely on a cheap tablet in a bright kitchen.

**4. Confirm only what cannot be undone.** Void, close bill, apply discount. Never confirm adding an item — staff will learn to tap through dialogs blindly, and then they will tap through the important one.

**5. Nothing is icon-only.** An icon with a Nepali label. Icons alone are guesses, and a wrong guess during service costs money.

**6. Errors say what to do next.** Not "Error 422". "इन्टरनेट जोडिएन — अर्डर पठाइँदैछ" *(Not connected — order is being sent)*.

**7. Assume one hand.** A waiter is carrying plates. Primary actions live in the bottom half of the screen, within thumb reach.

---

## 2. Numeral policy

**Devanagari for dates. Arabic for money, quantities and phone numbers.**

This matches how most Nepali businesses actually print bills. Money stays fast to scan and cross-check against a cash drawer or a calculator, which is what the cashier is doing at 11pm.

| Context | Style | Example |
|---|---|---|
| Dates, fiscal year, invoice number | Devanagari | मिति २०८३/०४/२८ |
| Money | Arabic | रु. १,२५० → **Rs 1,250** |
| Quantity | Arabic | × 2 |
| Table number | Devanagari (display only) | टेबल ५ |
| Phone, PAN | Arabic | 9801234567 |

### The hard rule

**Devanagari numerals are a rendering concern only.** They never enter storage, never enter a calculation, never come back from a form.

```ruby
# app/helpers/numeral_helper.rb
DEVA = %w[० १ २ ३ ४ ५ ६ ७ ८ ९].freeze

def deva(n)               # display only — dates, table numbers
  n.to_s.gsub(/\d/) { DEVA[_1.to_i] }
end

def money(paisa)          # ALWAYS Arabic, always from integer paisa
  "Rs #{number_with_delimiter(paisa / 100.0, delimiter: ',', precision: 2)}"
end
```

Input fields use `inputmode="numeric"` and produce Arabic digits. Parse defensively: accept both scripts on input, normalise to Arabic immediately, and never round-trip a Devanagari string into a model.

---

## 3. Typography

- **Font: Noto Sans Devanagari.** Self-host it. Do not link a CDN — the server runs on a LAN and must work with the internet unplugged.
- **Line height 1.6 minimum.** Devanagari has ascenders above the शिरोरेखा and descenders below; 1.4 clips them on Android.
- **Body 18px minimum, 20px on the waiter phone.** Devanagari conjuncts become unreadable below 16px on a cheap screen.
- **Nepali strings run 20–40% longer than English.** Buttons must flex. Never fix a button width to fit the English label.
- Test on an actual budget Android device, not a desktop browser. Devanagari rendering differs meaningfully.

---

## 4. Screens

### 4.1 Waiter — phone

```
┌─────────────────────────┐
│ टेबल ५        ३ जना    │  session header: table, guests
│ खुला — २ राउन्ड        │  open, 2 rounds already sent
├─────────────────────────┤
│  ┌───────┐  ┌───────┐  │
│  │ मःम   │  │ चाउमिन │  │  item tiles ≥ 96px tall
│  │ Rs 180│  │ Rs 220 │  │  Nepali name, Arabic price
│  └───────┘  └───────┘  │
│  ┌───────┐  ┌───────┐  │
│  │ थुक्पा │  │ कोक   │  │
│  │ Rs 250│  │ Rs 80  │  │
│  └───────┘  └───────┘  │
├─────────────────────────┤
│ मःम        × 2   Rs 360│  cart, tap qty to change
│ कोक        × 1   Rs  80│
├─────────────────────────┤
│ जम्मा           Rs 440 │
│ ┏━━━━━━━━━━━━━━━━━━━━━┓ │
│ ┃  भान्सामा पठाउनुहोस्  ┃ │  ≥ 64px, bottom, thumb reach
│ ┗━━━━━━━━━━━━━━━━━━━━━┛ │
└─────────────────────────┘
```

- Tapping a tile adds one. Tapping the cart line opens a **stepper** (− ३ +), never a keyboard.
- Notes ("पिरो नबनाउनु") are a preset chip list plus a free-text fallback. Typing Nepali on a phone mid-service is too slow — presets cover 90%.
- **Pending banner** when the queue is non-empty: amber, persistent, counts items. `२ अर्डर पठाइँदै...` It disappears only on confirmed success.

### 4.2 Kitchen — tablet, wall-mounted

```
┌──────────────────────────────────────────────┐
│ भान्सा                    ● जोडिएको  ११:४२  │  connection dot + BS time
├────────────────┬────────────────┬────────────┤
│ ▌टेबल ५       │ ▌टेबल २       │ ▌टेबल ८   │
│ ▌   ४ मिनेट   │ ▌   १ मिनेट   │ ▌ ११ मिनेट│  ← age drives colour
│                │                │            │
│  मःम      × 2  │  थुक्पा   × 1  │  चाउमिन × 3│
│  कोक      × 1  │                │            │
│  पिरो नबनाउनु  │                │            │  notes highlighted
│                │                │            │
│ ┌────────────┐ │ ┌────────────┐ │ ┌─────────┐│
│ │  ✓ तयार    │ │ │  ✓ तयार    │ │ │ ✓ तयार  ││
│ └────────────┘ │ └────────────┘ │ └─────────┘│
└────────────────┴────────────────┴────────────┘
```

- **Readable from 2 metres.** Item names 28px+.
- Cards age: white → amber at 10 min → red **with a diagonal stripe** at 15 min. Stripe, not just colour.
- **Audible beep on a new ticket.** Kitchens are loud and nobody is watching.
- **Connection dot is the most important pixel on this screen.** Green = live. Over 15s stale → full-screen amber overlay: `जोडिँदै... २३ सेकेन्ड`. A frozen screen must *look* frozen.

### 4.3 Cashier — tablet

```
┌──────────────────────────────────────┐
│ टेबल ५ — बिल                        │
├──────────────────────────────────────┤
│ मःम              × 2        Rs   360 │
│ कोक              × 1        Rs    80 │
│ थुक्पा            × 1        Rs   250 │
├──────────────────────────────────────┤
│ जम्मा (कर सहित)             Rs   690 │  ← what the guest pays
│   मूल्य                     Rs 555.11 │  ← breakdown, smaller type
│   सेवा शुल्क १०%            Rs  55.51 │
│   मू.अ.कर १३%               Rs  79.38 │
├──────────────────────────────────────┤
│ ┌─────┐┌────────┐┌───────┐┌────────┐ │
│ │नगद  ││फोनपे QR││ इसेवा ││ कार्ड  │ │  ≥ 72px tall
│ └─────┘└────────┘└───────┘└────────┘ │
├──────────────────────────────────────┤
│ [ रद्द गर्नुहोस् ]  [ बिल छाप्नुहोस् ] │
└──────────────────────────────────────┘
```

- **Total first, breakdown second.** With all-inclusive pricing the guest already knows the number; the tax split is for the invoice, not the conversation.
- Split payments: tap a method, enter an amount, repeat. Remaining balance always visible.
- **Void needs a reason** — preset chips (गलत अर्डर, ग्राहकले फिर्ता गर्नुभयो, बिग्रियो) plus free text. No reason, no void.
- Cash: show change due in **very large type**. This is where mistakes cost money.

### 4.4 Admin — laptop, English acceptable

Menu CRUD, users, daily sales, payment-method reconciliation, BS-month reports. Plain Rails scaffolds are fine here — the audience is you and the owner, not staff mid-service.

The one screen that matters: **end-of-day reconciliation.** System total by payment method versus counted cash. Any difference stated in plain Nepali, large. The owner checks this nightly, and if it is hard to read they will stop checking.

---

## 5. Data capture rules

**Capture at the moment of truth, never reconstruct later.**

| Field | When | Why |
|---|---|---|
| `guest_count` | Session open | One tap. Powers per-cover revenue, the most useful metric the owner will get. |
| `placed_by_id` | Every ticket | From the PIN session, never a dropdown. |
| Price snapshot | Every line | A menu edit must never alter a past bill. |
| `void_reason_ne` | Every void | Mandatory. Without it the audit trail is decoration. |
| `client_token` | Client, before submit | Makes retries safe. §5 of ARCHITECTURE.md. |
| `received_by_id` | Every payment | Cash differences need a name attached. |

**Do not capture** customer name or phone by default. It slows every bill for data almost nobody will use. Add it later behind a toggle if a loyalty scheme actually happens.

**Every number the staff type is a chance to lose money.** Steppers over keyboards, presets over free text, tap-to-select over search. The only keyboard in the waiter flow should be the optional note field.

---

## 6. Accessibility, concretely

- **Touch targets ≥ 64px** on the waiter phone. The 48dp guideline assumes an unhurried user sitting down.
- **Contrast ≥ 4.5:1.** Kitchen screens sit under fluorescent light with grease on the glass.
- **No hover-only affordances.** Everything is touch.
- **No time-limited dialogs.** A waiter gets interrupted mid-tap constantly.
- **Undo over confirm** wherever the action is reversible — a 5-second "फिर्ता लिनुहोस्" toast beats a modal.

---

## 7. Localisation process

`config/locales/ne.yml` and `en.yml`. `ne` is the default; `en` is fallback and for admin.

**A native Nepali speaker must review every user-facing string before launch.** The Nepali in this document and in the first draft of the locale file is a starting point, not a shippable translation — machine-adjacent Nepali reads as stilted or subtly wrong, and staff who do not trust the wording will not trust the numbers. Budget an afternoon with someone who works in a restaurant, not just someone who speaks Nepali.

Watch specifically for:

- **Register.** Restaurant staff use informal Nepali; over-formal Sanskritised terms (आदेश for "order") read as bureaucratic and unnatural. अर्डर is the word people actually say.
- **Loanwords.** टेबल, अर्डर, बिल, किचन are normal Nepali speech. Do not "correct" them into pure Nepali nobody uses.
- **Verb forms.** Buttons take the imperative (पठाउनुहोस्, छाप्नुहोस्), not the infinitive.

### Starter glossary

| English | Nepali | Note |
|---|---|---|
| Table | टेबल | |
| Order (round) | अर्डर | Not आदेश |
| Menu | मेनु | |
| Quantity | संख्या | |
| Subtotal | उप-जम्मा | |
| Total | जम्मा | |
| Service charge | सेवा शुल्क | |
| VAT | मू.अ.कर | Standard abbreviation |
| Bill / invoice | बिल | |
| Payment | भुक्तानी | |
| Cash | नगद | |
| Change (due) | फिर्ता | |
| Discount | छुट | |
| Void / cancel | रद्द | |
| Kitchen | भान्सा | किचन also fine |
| Pending | बाँकी | |
| Preparing | पकाउँदै | |
| Ready | तयार | |
| Served | पस्किएको | |
| Print | छाप्नुहोस् | |
| Send to kitchen | भान्सामा पठाउनुहोस् | |
| Customer | ग्राहक | |
| Date | मिति | |
| Report | प्रतिवेदन | |
| Copy of original | सक्कलको प्रतिलिपि | IRD reprint label |

Payment methods keep their brand names: नगद, फोनपे, इसेवा, खल्ती, आइएमई पे, कार्ड.

---

## 8. Before you call it done

- [ ] Tested on the cheapest Android phone any waiter actually owns
- [ ] Every string reviewed by a native speaker who works in hospitality
- [ ] Kitchen screen legible from 2m under kitchen lighting
- [ ] Devanagari renders correctly on the **actual thermal printer** (raster path)
- [ ] Every money figure traced from integer paisa to display — no float in between
- [ ] A waiter who has never seen the app can place an order with under two minutes of instruction

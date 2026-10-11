# Robux Store design (P07)

Status: **design v2 approved by the user on 2026-10-11; UI implemented with buying switched off.**
Reconciled with the P01 specification in [docs/MONETIZATION.md](../MONETIZATION.md), where the
user approved D1 and the per-return **Double & Claim** flow. Product rules, values and platform
requirements live in MONETIZATION.md; this file covers presentation, entry points and the UI
contract. It authorizes no platform products, live sales or publishing.

**What is built (§16):** the three ways in, the Store screen, the Coin Shop STORE chip, the
restyled welcome-back card and the plot Upgrade Station. Every product says **Coming soon** and
the Store sends nothing, because the purchase foundation (P02) does not exist yet. Prices,
purchase states, My Perks contents, Auto Open setup, boost timers and Double & Claim come with
P02–P08.

- Clickable prototype: [monetization-store/prototype.html](monetization-store/prototype.html).
  Open it locally in a browser. The controls let you switch viewport, screen, product state,
  prices, the D3 launch subset, long labels, reduced motion and slow delivery.
- **Amounts and benefits follow approved D1.** At runtime every Robux price comes from Roblox
  for the viewing player; the prototype's prices are D1 list prices for illustration. MN-22's
  price is still TBD.

v2 changes the look from the earlier quiet panel to a cute, candy-coloured Roblox shop. It adds
three dedicated ways in and replaces both offline-bonus alternatives with the confirmed
Double & Claim flow.

## 1. Ways in

| # | Entry | Placement | Opens |
| --- | --- | --- | --- |
| 1 | **Green +** button | Inside the right end of the Coins pill, top-left HUD. 44px circle: green gradient, plum outline, white stroked plus. | Store → **Coins** |
| 2 | **STORE** button | Top-right, left of the Daily/Home/Plaza/gear row. Same size as the row tiles (64px desktop, 50×56 phone; the user asked for matching sizes). Candy pink→violet gradient, slow sunburst, blind-box buddy art, twinkle, stroked "STORE" label overlapping the bottom edge. | Store → **Starter & VIP** |
| 3 | **Upgrade Station** | A prop in the front corner of each plot (§9), with an owner-only `E · Upgrades` prompt. | Store → **Upgrades** |
| (4) | **STORE** chip in the Coin Shop header | The Coin Shop's only Robux element. | Store → Starter & VIP |

Restraint: the + never pulses or badges, and it doesn't change when Coins run low (P01 rule G).
No entry point shows a "!" badge, and the Store never opens on its own. The phone HUD fits at
667px: Coins pill with + about 70–300px, then STORE plus the four-tile row from about 357px.

## 2. Visual direction: cute candy shop

The game's plum-outline, hard-shadow system, turned up for a shop players enjoy browsing:

- **Palette:** pastel candy gradients on BRIEF tokens: pink `#FF8DC0`/`#FFC2DD`, violet
  `#9B82FF`, peach `#FFC9A3`, orange `#FFA64D`, gold `#FFC83D`, mint `#4FCB8E`. Ink `#2B1F4A`
  outlines (3–4px) and hard shadows (4–8px). The store body has a soft lilac ground with faint
  dots and sparkles.
- **Money colours:** **Green = Robux** (green-gradient button, white stroked Robux glyph and
  price); **gold = Coins**; **violet = automation and activation**; **red = Close / Stop**.
- **Type:** Fredoka with a plum text stroke (`UIStroke`, `ApplyStrokeMode.Contextual`) for
  titles, tabs, prices and buttons; Nunito 800 for body copy.
- **Cuteness:** product art has little faces (eyes and blush). A blind-box **buddy** peeks over
  the Store header and appears on the STORE button, the Upgrade Station and empty states.
  The buddy is a placeholder for real Peeka art. Card tops carry twinkling sparkles.
- **Motion:** slowly rotating sunbursts behind art, a soft shine across green buttons, a
  twinkle on sparkles and an occasional buddy peek. All of it stops with Reduced Motion. Run
  one shared tween per visible element type, and only while the Store is open.
- **Roblox build notes:** `UIGradient` for fills; `UIStroke` for outlines and text strokes; the
  sunburst is one tinted ImageLabel; hard shadows reuse `UIKit.card`. The art (product
  illustrations, buddy, STORE icon) is a new glossy "Store.*" set, made like the nav icons with
  the `AssetManifest` fallback.

## 3. Categories and products (P01 proposals)

| Tab (colour) | Contents |
| --- | --- |
| **Starter & VIP** (pink) | Hero banner: **Starter Pack**, 7,500 Coins + one 15-min 2x Coins token, 49 R$, ribbon "ONCE PER ACCOUNT". Cards: **VIP** (+10% Display income and +500 Coins with each daily free Grove box, 199, ribbon "FOREVER"), Auto Collect, 2x Coins Boost. |
| **Upgrades** (violet) | **Coin Multiplier** panel with bronze/silver/gold 2x / 4x / 8x medals at 149 / 399 / 999 ("Highest one wins. They never stack."). Cards: **Auto Open** 199, **Auto Collect** 149, **Speedy Shoes** (36 → 48) 49, **Lucky Charm** (Luck ×2 weights) 399, and a **Double & Claim** info card linking to the welcome-back preview. That card has no price because the product is sold only on the welcome-back screen. |
| **Boosts** (orange) | **2x Coins Boost** 15 / 30 / 60 min at 29 / 49 / 79 (length chips on the card); **Luck ×2 Boost** 30 min 49; **Super Luck ×4** 30 min 99; **Coins + Luck** 30 min 79. A "N boosts running → My Perks" strip shows while any timer runs. |
| **Coins** (gold) | Coin Pouch 15,000 / 49; Coin Stack 60,000 / 149; Coin Sack 240,000 / 499; Treasure Chest 1,200,000 / 1,999. The ribbon "+N% COINS PER R$" is **computed from the prices Roblox returns** and hidden until they load. Footnote: packs don't change odds, and multipliers don't apply to them. |
| **My Perks** (mint) | Active now (timer bars, absolute end time), Ready to activate (tokens + Activate), Arriving (saving/recovering purchases), Owned (toggles for Auto Collect and Speedy Shoes; "Set up" for Auto Open). The badge counts unused tokens. |

- **D3 launch subset:** products P01 holds back (Coin 4x/8x, Sack/Chest, all Luck and Coins +
  Luck) are hidden by server configuration. The layouts reflow without gaps; the prototype's
  "D3 launch subset only" switch shows this.
- **Names are placeholders** for approval: Lucky Charm, Speedy Shoes, Super Luck, the pack names.

## 4. Cards and product sheets

- **Card:** pastel gradient top with sunburst, sparkles and 74–88px art; at most one factual
  ribbon; name (Fredoka 19); one-line benefit; footer. The footer holds the green price button,
  or a state stamp (OWNED, CLAIMED, "Included in 8x", "Saving…"). Badges show the token count
  "×2" and the active timer.
- **Coin packs prompt straight from the card's green button**, since the card shows the exact
  amount and price. **Every other card opens its product sheet first**, because P01 rule G
  requires rules, stacking, upgrade cost or odds to be visible before the prompt.
- **Product sheet** (popup over the Store; fills the sheet on phone): coloured art column and
  title with tags (type, "P01 proposal", "Held for launch"). Blocks: "You get"; the length
  picker for boosts; "How tiers work" for the multiplier; **"Odds with Luck ×N"** for Luck
  products, using P01's exact table; "Good to know" with heart bullets; "You pay / You get" for
  packs. A fixed footer holds the big green **Buy [R$] price** and its state message.
- **Upgrade disclosure:** before buying a higher Coin tier, the footer says: "Full price. You
  already own 2x Coins; tiers don't give credit toward each other."
- **Ribbons are factual only:** ONCE PER ACCOUNT, OWNED, FOREVER, LUCK ×2, STRONGEST and
  +N% COINS PER R$. Never POPULAR, LIMITED or countdowns.

## 5. Boosts: buying vs activating

Buying a boost adds a **token**; it never starts a timer (P01 rule T). Activate it from My Perks
or right after delivery. A confirmation uses P01's copy: "Activate 2x Coins Boost? 30 minutes.
The timer continues while you're offline. Same boosts add time, not strength."

The HUD shows a boost chip under the Coins pill ("Luck ×2 · 24m", or "2 boosts · 9m"), updated
on minute boundaries, which opens My Perks. Luck ×2 is hidden for Lucky Charm owners, and the
redundant state reads "This boost won't improve your current Luck." Different Luck strengths
can't overlap: the token waits.

## 6. Welcome back: Claim / Double & Claim (user-confirmed)

The existing welcome-back card is restyled to match: a pastel header with the moon buddy and
"Welcome back!". The line reads "Your Display earned **N Coins** while you were away (3h 12m)."
Two equal-size buttons sit side by side:

- **Claim N:** gold, labelled "Free". It is selected first for gamepad. Tapping outside also
  makes the free claim, except while a purchase is in progress.
- **Double & Claim 2N:** green, with the Roblox price (TBD) and the ribbon "2× THIS RETURN".
  No prompt opens automatically.

States, following P01:

- **Prompt open:** both buttons disabled; "Finish or cancel in the Roblox window."
- **Saving:** both buttons disabled; "Your purchase is being saved. It will be recovered if
  you reconnect. Don't purchase again to retry."
- **Cancelled:** both buttons return; "Purchase cancelled. You weren't charged. Claim is still
  free."
- **Granted:** "Yay! +2N Coins claimed!" with a coin burst, then the card closes.
- **Double hidden:** when N is 0, the return is already claimed or doubled, the paid path is
  restricted or unknown, or 2N won't fit the wallet. Show any clipping of the free claim before
  Claim.
- **Late receipt after the free claim:** the toast "Your Double & Claim bonus arrived: +N Coins"
  credits only the extra N.

## 7. Auto Open setup and Stop

When the player owns Auto Open, the Coin Shop shows a violet **Auto Open…** button under
Open 10. It opens a setup dialog:

- "How many boxes", a − / + stepper from 1 to 100 (default 10).
- "Keep a reserve", a switch with an amount.
- A gold note: "Spends up to N Coins (count × price). Stops when you press Stop, when it's
  done, when you can't afford the next box, or if you leave."
- A violet **Start Auto Open** button.

During openings, a pill at the top right reads "Auto Open · 3 / 10" with a red **Stop** button.
It is always visible; Skip keeps B, and X is the proposed Stop binding, checked in P08. Boxes
start at least 3 seconds apart. Stopping uses P01's copy: "Auto Open stopped: [reason]. No
further Coins will be spent. Select Start to resume."

## 8. Layout

Geometry follows `UILayout.frame`; the prototype mirrors it.

- **Desktop (1280×720 → panel 1152×496):**
  - Header 78 (66 when the panel is shorter than 420): buddy, stroked "STORE", subtitle
    "Treats for Robux · Boxes are in the Shop for Coins", Coins chip, "Coin Shop" chip and a
    red round Close.
  - Body: 208px tab column with 58px candy tabs (the selected one shifts right with a white
    halo), then a content area with a 4-column card grid (cards at least 190–200 wide).
- **Short or narrow desktop (panel under 1000 wide):** the tab column becomes 92px icon tabs
  with short labels.
- **Phone landscape (667×375; 844×390 with insets):**
  - The sheet uses a 58px header, and the dock is hidden.
  - 78px icon tabs, 50px tall with 6px gaps, so all five fit without scrolling.
  - 3-column cards; the product sheet fills the panel.
  - The welcome-back card is 236px tall, and its two buttons fit without scrolling.
- **Scrolling:** the content area scrolls; canvases are measured (`Scroll.bind`) and padded so
  the last card's shadow clears the bottom. There is no portrait flow.

## 9. Upgrade Station (plot prop)

A cute arcade-style cabinet, about 7 studs wide and 11 tall:

- **Body:** candy-pink rounded cabinet with soft stripes and a violet marquee with eight bulbs
  reading "UPGRADES".
- **Front:** a cream window showing the buddy, a gold "POWER-UPS!" plate, a big green + button
  and a coin, all on an oak base.
- **No capsule dome, crank or spinning reels**, so it can't be read as a paid random machine.

| Topic | Proposal |
| --- | --- |
| Location | Front corner on the Shelves side: local X ≈ +40, Z ≈ −40, angled toward the arch path. This spot is clear of the arch (Z −48, X ±11.2), the spawn pad (X −18, Z −28), the Box Shop (X −38, Z 6), the Shelves (X +40, Z about −22..14) and the Display. |
| Prompt | Native `E · Upgrades` (object text "Upgrade Station", 12 studs, no hold). Owner only, like the Box Shop: other plots' prompts are hidden. Living character, distance and ancestry are rechecked. Opening focus and pending requests are respected. |
| Build | About 14 native parts plus SurfaceGuis (marquee, window, plate). At night it glows through unlit SurfaceGuis, with no Light instances, like the Box Shop. |
| Budget | Raises the plot's 184-part runtime fixture budget by about 14. Needs its own world task and visual acceptance. The earlier P08 prompt excluded physical kiosks, so this is a user-requested scope change. |
| Behaviour | The prompt opens the client Store only. There is no remote, purchase path or world-side pricing. |

## 10. States and copy

The server's verified snapshot is the only source of Owned, Claimed, Active and Delivered.
P01's player messages are used verbatim where they exist.

| State | Card | Sheet footer |
| --- | --- | --- |
| loading | shimmer button | "Getting your price from Roblox…" (no number) |
| available | green price button | **Buy [R$] price** (boosts: "Buy 30 min") |
| owned | OWNED stamp (· ON/OFF for toggles) | "You own this. It's active on your account." (Auto Open: Set up in Shop) |
| superseded | "Included in 8x Coins" | "Included in your 8x Coins. Nothing to buy." |
| claimed (Starter) | CLAIMED | "Claimed. Its Coins and boost were delivered." |
| redundant | "Lucky Charm covers this" | "This boost won't improve your current Luck." |
| restricted | Not available | "This purchase isn't available for your account. You can still earn Coins and open boxes through gameplay." |
| unavailable / policy unknown | Try again later | "We couldn't verify this purchase's availability. Please try again. Your earned Coins and free rewards are still available." + Try again |
| won't fit wallet (packs) | Wallet too full | "These Coins won't fit in your wallet right now. Spend some Coins first." |
| prompting | "In Roblox window" | "Finish or cancel in the Roblox window." |
| saving | "Saving…" | "Your purchase is being saved. Don't purchase again to retry." |
| delayed / recovering | "Arriving soon" (also listed in My Perks → Arriving) | "…It will be recovered if you reconnect. Don't purchase again to retry. You can keep playing." + Check again |
| cancelled | price button | "Purchase cancelled. You weren't charged." |
| failed (platform error) | "Didn't go through" | "Roblox couldn't complete the purchase. You weren't charged." + Try again |
| granted | toast with sparkle | "Delivered!" / "Coins added." / boosts: "Delivered to My Perks" + Activate now |

"You weren't charged" appears only when the platform reports no purchase. A charged but
unfulfilled purchase is always shown as saving or recovering, never as failed. Only one prompt
is open at a time. Products stay browsable while one purchase is pending, but their Buy buttons
are disabled.

## 11. Input, accessibility and lifecycle

- **Touch:** every target is at least 44px, including the + button, tabs, chips, steppers,
  switches, Close and Stop. The prototype sweep in §13 checks this.
- **Gamepad:**
  - Y opens or closes the Store like other screens; B closes the sheet first, then the Store.
  - L1/R1 switch tabs inside the Store; the selection ring auto-scrolls.
  - Default selection is the first card; Claim is the default on the welcome-back card.
- **Native prompt:** remember the selected object. When the prompt closes, restore selection
  to the same product's footer action, or to its card.
- **Reduced Motion:** turns off the sunbursts, shine, twinkles, buddy peek, press offsets and
  spinners. State must remain readable without motion.
- **Long text and prices:**
  - Names wrap to 2 lines and benefits clamp at 2.
  - Prices use the platform number in the player's locale, never abbreviated.
  - Tested with 7-digit localized prices and about 40% longer pseudo-localized strings.
- **Lifecycle:**
  - Closing the Store never cancels a pending purchase. Reopening refreshes prices, ownership
    and eligibility.
  - Resizing keeps the tab, open sheet and scroll position.
  - During opening focus, the Store can't open and no prompt can start; results queue as
    toasts until focus is released.
  - Auto Open's Stop is never covered. No forced popups, fake timers or "need Coins" upsells.

## 12. Handoff for P08 (pending approval)

**Client model.** Built by one projection module (a "Store fields" section in `UIState`) and
never read directly by screens.

```luau
export type StoreState = "loading" | "available" | "owned" | "superseded" | "claimed"
	| "redundant" | "restricted" | "unavailable" | "nofit"
export type PurchaseState = "idle" | "prompting" | "cancelled" | "saving" | "recovering"
	| "granted" | "failed"
export type StoreProduct = {
	key: string, -- stable catalog key from P02's public descriptor, never a platform ID
	category: "featured" | "upgrades" | "boosts" | "coins",
	kind: "pass" | "token" | "pack",
	group: string?, -- "coinTier"; boost family
	rank: number?, -- tier rank / boost length
	state: StoreState,
	purchase: PurchaseState,
	price: number?, -- platform Robux price for this player; nil until fetched
	coins: number?, -- fixed pack/Starter amount from the descriptor
	tokens: number?, -- unused boost tokens
	activeUntil: number?, -- UTC expiry (wall clock, P01 rule T)
	toggle: boolean?, -- Auto Collect / Speedy Shoes setting
	held: boolean?, -- hidden by launch configuration when true
}
export type OfflineOffer = { award: string, base: number, double: number, price: number?,
	purchase: PurchaseState, available: boolean }
```

**Intents** (sent through `ctx.send`, so the existing pending lock and `canAct` apply):

- `StorePrompt(key)`
- `BoostActivate(key)`
- `PerkToggle(key, on)`
- `AutoOpenStart(collection, count, reserve)` / `AutoOpenStop()`
- `OfflineClaim()` / `OfflineDouble(award)`
- `StoreRefresh()` (rate-limited)

The client never sends a price, amount, odds, duration or purchase result.

**Wiring:**

- **HUD:**
  - `Hud` gains the green + inside the Coins pill and a `store` rect left of the row in
    `Layout.frame`.
  - `NavigationConfig` gains the HUD key `Store`.
- **Store screen:**
  - `Interface` adds a `StorePresentation` host like `Login`, with a route argument for the
    starting tab.
  - L1/R1 route to Store tabs while it is open.
- **Other screens:**
  - `ShopScreen` gains the STORE chip and the Auto Open… dialog.
  - `OfflineEarnings.show` takes the `OfflineOffer` model.
  - `OpeningView` gets the optional Auto Open pill with Stop.
- **World:** the Upgrade Station prompt routes through the same client prompt routing as the
  Box Shop. It needs a separate world task.

**Tests (P08):**

- Each state in §10 maps to the right card and footer.
- The pending lock across a prompt and focus restore afterwards.
- Hidden screens run no timers or tweens; no instance growth over 25 open/close cycles.
- The D3 subset reflows without gaps.
- Double & Claim disables both buttons while a purchase is active, and Claim works after a
  cancel.
- DEVICE_TEST_MATRIX rows D1/D2/M1/M2.

## 13. Validation done for this design

| Check | Status | Evidence |
| --- | --- | --- |
| Rendered at 1280×720, 1000×600, 667×375 and 844×390 with insets: HUD, Upgrade Station, Store tabs, sheets, Coin Shop, Auto Open, opening, welcome back | PASS | In-app browser screenshots during authoring |
| Automated sweep: 4 viewports × prices (P01 / 7-digit) × label length × every tab, every product sheet, 14 simulated states on long labels, Auto Open setup, boost confirmation, all screens | PASS | 0 elements escaping their container, 0 buttons under 44px, 0 panels off-screen, phone tabs fit without scrolling, no script errors. Fixed on the way: 40px + button, clipped selected tab, short-desktop tab overflow, map label overlap |
| Welcome-back card fits while saving, on all four viewports | PASS | Content height equals visible height |
| Roblox Studio, real fonts and strokes, `UIScale`, safe insets, gamepad, native prompt, the 3D Upgrade Station | NOT RUN | Design task; belongs to P08 and the world task |
| Physical phone | NOT RUN | |

## 14. Open decisions

**Product (P01 decision table; none approved except the Double & Claim flow):**

1. D1: amounts, prices and entitlement models as listed, including full-price tier upgrades
   with no credit.
2. D2: shared effects and the paid-random boundary.
3. D3: the launch subset. Its products are hidden in the design, not removed.
4. The MN-22 Double & Claim price and receipt protocol.
5. Final product names.

**Design (yours to approve):**

1. The three entry points plus the Coin Shop chip, with no badges or pulsing.
2. The cute candy-shop styling, the buddy placeholder (to be replaced by Peeka art) and the
   faces on product art.
3. Green = Robux, gold = Coins, violet = automation.
4. Coin packs buy straight from the card; everything else opens a sheet first.
5. Equal side-by-side Claim / Double & Claim, with Claim selected first.
6. The Upgrade Station look and placement (front corner on the Shelves side, owner-only
   prompt). It needs a separate world/budget task.
7. My Perks as the home for timers, tokens and toggles, plus the HUD boost chip.

## 16. Implementation (2026-10-11, buying switched off)

| Piece | Where | Notes |
| --- | --- | --- |
| Green **+** | `Hud` (Coins pill) | Smaller than the prototype at the user's request: a 30px (desktop) / 26px (phone) green disc in a narrow slot, with a 44px transparent hit area. Opens Store → Coins |
| **STORE** tile | `Hud`, `UILayout.frame().store` | Same size as the row's tiles (64×64 desktop, 50×56 phone, at the user's request); candy gradient, gift icon, stroked "STORE". Phone row gaps are 8px so it fits beside the widest Coins pill at 666px |
| Store screen | `StoreScreen`, `StoreCatalog` | Routed like Login with a `tab` route. Candy header, five tabs (icon rail on phone and narrow desktop), Starter banner, Coin Multiplier tiers, cards and a product sheet. L1/R1 switch tabs; B closes the sheet first |
| Coin Shop chip | `ShopScreen` via `Store.chip` | The Coin Shop's only Robux element |
| Welcome back | `OfflineEarnings` | Candy header, "Your Display earned N Coins while you were away", gold Claim with the amount and "Free". Claim behaviour unchanged |
| Upgrade Station | `UpgradeStation`, `PlayerPlot`, `DisplayInteraction` | 5 parts at plot-local (38, -38), owner-only `E · Upgrades` → Store → Upgrades. Plot budget 189 |

Art is frame-drawn (UIIcons and stroked glyphs) until the Store illustration set exists. The
sunbursts, sparkles and buddy faces from the prototype need that art set and are not built.
Purchase states (§10), prices, My Perks lists, the HUD boost chip, Auto Open setup/Stop and
Double & Claim need the P02 purchase foundation and the product tasks; the handoff in §12 still
applies to them.

**Checks run:** see the completion report. Stylua, Selene, Luau type analysis, the Rojo build and
the full `tests/run.py` suite pass. Studio (desktop 1529×730 and the 667×375 SafeArea preview)
showed the HUD, Store tabs, cards, sheet and Upgrade Station; E at the station and the green +
opened the right tabs. A real phone, a gamepad and two-client checks are not done yet.


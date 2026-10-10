# UI redesign brief

Status: **implemented and merged into `master`.** This brief plus the mockup records the approved
design direction for the client UI rebuild. It does not authorize unrelated server, economy,
persistence or opening-animation changes.

- Live mockup (canvas, clickable): https://claude.ai/artifact/4xaQzngCkP1ooNz6E7oyWT
- Mockup source: [mockup/](mockup/) — one `.dc.html` per screen. Inline styles carry the exact
  sizes, colors and copy. `/_blob/...` image URLs only resolve inside the canvas; locally they map
  to the files in `assets/figures/**/renders/*_beauty.webp`, `assets/ui/navigation/*.png` and
  `assets/ui/collection/tender-echoes/tender_echoes_emblem.png`.
- Player numbers in the mockup (12,480 Coins, owned counts, 20/43 found) are **sample data**. Real
  values always come from the server snapshot.

## Why

Today Shop (cream boutique), Collection (physical book) and Display/Goals/Shelves (ivory/oak/lilac)
look like three different games. Income only appears if you tap the coin pill. Daily rewards are
buried, the nav disappears while screens are open, and Display leaves the "which figure earns most"
math to the player. The redesign is one consistent system with the important numbers always
visible and one obvious next action on every screen.

## Decisions (from the user)

| Topic | Decision |
| --- | --- |
| Collection | Replace the physical book with collection list + filterable grid + detail panel |
| Box opening | Keep the existing opening animation, camera and Skip. Replace only the end result panel with the Reveal card UI |
| Reveal "Put on Display" | Empty slot: place directly. Display full: show "Swap for <lowest earner> (+X/s)" only if the new figure earns more than the lowest displayed earner; otherwise hide it |
| Reveal "Open another" | Instantly buys the same collection's box (one tap). Shows the price; disabled and shows the shortfall when unaffordable; one pending request at a time |
| Reveal "Keep it in my Collection" | Closes back to whatever screen/state the player came from |
| Navigation | Bottom dock on desktop **and** phone; stays visible while a screen is open; active item highlighted |
| Collection theming | Accent color + emblem/icon only. Drop book skins, corner art and shop pattern art from the UI |
| Goals reset | Live countdown ("New goals in 5h 12m") from the server's `nextDay`, updated at most once per minute and only while visible |
| Scrap | Removed entirely: no Scrap pill, Recycle, Redeem or related client intents |
| Duplicates | Show owned count (×3); income boosting values come from the merged authoritative economy |
| Phone | Landscape only |
| Rollout | Everything in one pass, then one round of Studio testing |

## Visual system

One look everywhere: white panels with chunky plum outlines and hard drop shadows, matching the
glossy navigation icon art.

| Token | Value | Use |
| --- | --- | --- |
| ink | `#2B1F4A` | text, outlines (3px panels/buttons, 2px small), hard shadow (0,4–8px offset) |
| muted | `#5C5276` | secondary text (passes 4.5:1 on the surfaces below) |
| surface | `#FFFDF9` | panels |
| surface-2 | `#F6F2FC` | side columns, stat wells; divider `#ECE5F6`, track `#E2DAEF` |
| violet | `#6B4EE6` / dark `#4B32C3` / wash `#EFE8FF` | selection, active dock item, "Put on Display" |
| gold | `#FFC83D` (coin ring `#C98A00`) | buy / claim buttons (ink text), coin glyph, FREE badge |
| mint | `#DDF3E6` bg, `#174F36`/`#1E6B47` text, `#3BA272` fill | income, completion, free box |
| alert | `#D92D46` | count badges (white text) |
| dim | `rgba(35,24,61,0.55)` over the world while a screen is open | replaces the old blur/warm overlays |

Rarity: reuse `src/shared/Rarity.luau` (tint/onTint). Collection accents (color / wash):
Pocket Grove `#4F8A3F`/`#E4F1DA`, Tidepool Tales `#2F7FA6`/`#DCEEF7`, Concepts `#A84C70`/`#F7E1EA`,
Tender Echoes `#C46A2C`/`#FCEADB`, We Are All Stars `#4A5BB8`/`#E1E5F8`. Put these in one
collection-style table with a neutral fallback so a new collection is a config entry.

Type: Fredoka (display: titles, numbers, buttons) and Nunito (body, 700–900 weight). Use the Roblox
font families (`rbxasset://fonts/families/FredokaOne.json`, `.../Nunito.json`): verify both
resolve in Studio. Fall back to GothamBold/GothamMedium if not.

Minimum touch target 44px. Use numbers abbreviated (`State.compact`) in tight spots; exact values
where there is room or on tap. Disabled states must look disabled (`#EDE8F5` fill, `#B9AFCB`
border) and still explain why ("Need 1,240 more").

## Shared components (build once, reuse)

- **Screen shell:** centered panel, desktop reference 1152×508 at 1280×720, 28px radius, header
  76px (nav icon 56px, title 30px, one-line subtitle, optional right-side chip, round 48px ink
  Close). Body below. Short heights scroll the body, never clip it.
- **HUD:** Coins pill (coin glyph, balance, mint "+N/s" chip) top-left, placed right of the Roblox
  top-bar buttons (respect `GuiService` top-bar inset). Top-right row **[Daily] [Home] [gear]**:
  matching rounded white tiles (ink stroke, hard drop shadow, 10px gaps). Daily and Home are
  glossy navigation icons over a "Daily" / "Home" label (64x64 desktop, 50x56 phone), because
  icon-only buttons were hard to tell apart; the gear is the same tile, icon-only;
  Daily carries the "!" Ready badge and an idle nudge (still with Motion Reduced). The row hides
  while any screen is open, like the gear. The gear opens a small popover holding the Motion
  preference (beside the row on short phones). Desktop also shows a Daily goal tracker card
  under the row (title, 3-segment progress, Claim when ready); phone collapses it to a
  "Goal · Claim" chip left of the row.
- **Dock:** 5 tiles (Collection, Display, Shop, Goals, Shelves), 100×94 desktop / 68×70 phone, icon
  + label, active = violet wash + raised. Badges: Display "N empty" (unlocked empty slots),
  Shop "FREE" (daily box ready), Goals count (claimable rewards). Phone dock sits between the
  thumbstick and jump button areas.
- **Collection list item:** icon (emblem/render on accent wash, or 2-letter monogram), name, thin
  progress bar, "found/total". Used in Shop and Collection (phone: icon-only rail with accessible
  names).
- **Figure tile/card:** accent-wash well, rarity-colored bottom bar, owned-count badge "×N",
  "ON DISPLAY" tag; undiscovered = `?` on `#EDE8F5`, name `???`.
- **Buttons:** primary gold (buy/claim), violet (display), mint (free), white secondary; all with ink
  outline and hard shadow; pressed state drops the shadow; respect Motion preference.

## Screens

- **HUD (world):** coins + rate, settings, goal tracker, dock. Nothing else covers the world.
- **Shop:** left = collection list; middle = box preview (existing `BlindBoxPreview` 3D viewport,
  skinned per collection) + "<Collection> box" + "X of Y found · Z left" + "Open 1 box [price]" +
  "Claim today's free box" (only when ready); right = "What's inside" (7-column tiles) and "Drop odds"
  (stacked bar + per-rarity rows: count, % each, total %). Odds come from the snapshot, never
  hardcoded.
- **Reveal card (end of opening):** NEW badge only for first discovery; big figure; name + rarity
  pill; chips: "Earns N coins/s on Display", "X% chance", "<Collection> · a of b found"; owned
  count for duplicates; buttons per the Decisions table. Keep Skip and the existing input/gamepad
  ownership of the opening.
- **Display:** header chip with total "+N coins/s"; set-bonus banner (plain language, shows the
  bonus amount); 6 slot cards (filled: figure, name, rate; empty: "+ Choose"; locked slots 4–6 unlock with
  Coins in order: only the next one shows an unlock price button with affordability, later ones
  say "Unlock slot N first"). *(The original brief had 5–6 "Coming later"; sequential coin
  unlock superseded it.)* Tapping a slot opens the picker
  drawer: owned figures not already displayed, sorted by earnings, top one tagged BEST, Cancel.
  Filled slots offer Change/Remove.
- **Collection:** left list; middle filter chips (All / Found / Missing with counts) + 4-column
  grid; right detail: big image, name + rarity, stats (Earns, You own, Box chance), action:
  "Put on Display" / "On your Display · View" / for undiscovered "Find it in <Collection> boxes"
  (opens Shop on that collection). Arriving from a Display slot picker keeps today's flow.
- **Goals:** three columns: Daily goal (progress segments, reward, Claim), Free box of the day
  (render from the list of collections the server allows: on master that's a chooser of every
  collection; if only one is allowed, show no chooser), Collection progress list (rows link to
  Collection). Countdown chip in the header.
- **Shelves:** shelf tabs (Shelf 1/2/3 + prev/next, disabled when exactly three owned), 3×3 wooden
  cabinet with selectable spots, right picker of discovered figures with collection filter chips;
  "Clear spot". Subtitle states shelves are cosmetic (no coins, no copies used).
- **Phone landscape:** Shop/Collection/etc. become near-full-screen sheets (header 56px with coins
  and Close) with an icon-only collection rail; dock hidden while a sheet is open on short
  landscape, Close restores it.

## Economy integration

The merged economy supplies per-collection `prices`, `baseRates`, `nextRates`, `baseOdds` and
`dailyCollection`; Scrap, redemption and their old snapshot fields are removed. Rates scale into
thousands/millions, the set bonus is percentage-based, and Display permits one placement per
unique figure. Therefore:

- Read price, odds, per-figure rate, set bonus and free-box options through **one** projection
  module (e.g. `UIState`), never directly from screens. The merge should then touch that module only.
- Size every number field for large abbreviated values (`2.4M`).
- Show current versus base odds from the authoritative snapshot without exposing private pity counters.

## Engineering constraints

Follow `AGENTS.md`: strict Luau, small focused modules, `UIScope` owns connections, tasks and
tweens, the server stays authoritative, clients never optimistically change Coins or inventory,
pending requests disable mutations, no new dependencies, no per-frame work, measured scroll
canvases (`Scroll.bind`), gamepad Y/B/shoulders/A preserved. Delete modules that only served the
book or the old per-screen styles once nothing references them, and update the tests that cover them.

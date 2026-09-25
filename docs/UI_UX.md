# Collectible UI visual redesign

Implemented client candidate. **Studio visual, input, mobile and multiplayer acceptance is still
pending.** The server, catalog, economy, networking, persistence and blind-box opening system
remain unchanged. The reference image guides composition, not its example names, prices or rates.
Current figure and packaging models remain procedural placeholders, not the illustrated reference art.

## Two visual layers

The global identity is ivory, dark neutral text and restrained lilac accents, with small floating
controls, fine borders and translucent surfaces. HUD, navigation, Goals, Social, notifications,
settings and generic room controls have no collection motifs. Currency uses gold accents.

`CollectionStyle` supplies page, wash, cover, ink, accent, trim and motif per collection.
`CollectionArt` renders original native gradient and corner ornaments without uploaded assets.
Grove uses warm paper, botanical leaves and an earthy binding. Tide uses pale blue pages,
watery gradients, coral shell fans and bubble outlines. Unknown collections get a neutral
fallback; adding a collection's art direction is a config entry using an existing motif, or an
additional motif renderer. Economy/catalog definitions do not contain UI styling logic.

## Different presentations

- **HUD and navigation:** floating Coin/Scrap capsules leave the world visible. Coins shows the
  exact balance and rate; Scrap links to the book. There is no permanent save button. Preview
  is announced once; changed failure/paused states get an error toast. Tapping Coins can recall
  preview/unsafe status. Ordinary saving/saved transitions are silent. Desktop uses individual
  left-side icon controls that expand on hover, focus or selection. Narrow/touch layouts use
  compact bottom navigation. Labels are Collection, Room, Shop, Goals and Social.
- **Book:** collection tabs sit above a bound, layered spread with a shaded spine. Its paper,
  ink, ornaments, portraits and binding change with collection. Wide layouts keep the grid on
  the left and a large figure detail on the right. Narrow layouts open details in place of the
  grid. Cards emphasize a render, short name and rarity; unknowns show silhouettes and question
  marks. Details contain owned/available quantities, Coins/sec, Display, eligible recycling,
  redemption and odds. All/Owned filtering retains every catalog entry in the measured grid.
  Completion is acknowledged in the discovered count, with the existing plaque in Goals.
- **Shop:** a neutral boutique surface contains large themed package presentations. The box
  preview occupies roughly 60% of each collection card. Name, catalog-derived figure count,
  exact price and OPEN follow it. A visible `i Odds` control opens all per-figure probabilities
  before purchase. The daily free action remains secondary; its one claim is shared across boxes.
- **Room:** a smaller bottom overlay leaves the upper room visible and undimmed. It shows
  income, matching-set progress, four figure slots and a separate Room style palette drawer.
  Choose/Change opens the owned picker; Display places into a chosen slot or asks for a slot.
  Remove, the existing fourth-slot unlock, palette prices and Return home remain available.
- **Goals:** a compact neutral sheet pairs daily display progress/reward with a daily-box choice
  on wider layouts; narrow layouts stack them. Collection plaque progress follows below.
- **Social:** a separate showroom directory presents names, staged display previews, public
  figure count/rate, Visit and Return home. It uses only the existing public snapshots.
- **Feedback:** a bounded measured toast wraps messages, deduplicates repeats and expires.
  Errors last longer. Buttons retain disabled, pressed, focus and selected states, with subtle
  press animation respecting the session motion preference.

There is no shared enclosing menu panel, global page title or permanent balance/status header.
`Interface` coordinates independent presentation hosts and floating close/motion controls.
Only book and shop dim the background. Generic sheets and room controls leave the world clear.

## Layout, authority and lifecycle

`UILayout` defines each presentation's bounds within the Core UI safe area. Desktop reserves
space for the rail; mobile uses bottom navigation. Short landscape hides navigation while a
screen is open, keeps close/motion accessible, and places book collection tabs beside its pages.
Closing returns navigation. Wide books use two pages; small screens focus on one page at a time.

`Scroll.bind` still measures content plus padding rather than relying on automatic canvas height.
Lists, grids and nested tile-container heights respond to filtering and resizing. No catalog
figure is dropped to fit a fixed viewport. `tests/StudioScroll.client.luau` targets the new book
hierarchy and checks the last card at maximum scroll.

The existing module boundaries are preserved: screen modules own presentation, `UIState` owns
read-only projections, `UIScope` owns connections/timers/tweens, and `UIPreview` owns static model
slots. Screen instances are reused. No idle animation loop or external dependency was added.
The server still validates every action, price, reservation, proximity, reward and balance.
Pending requests disable mutations; the client never optimistically changes inventory or Coins.

Gamepad Y opens/closes, B backs out, shoulders switch screens, and A activates selected controls.
Selection inside scrolling containers is brought into view. The existing opening owns its higher
priority bindings, hides this UI and restores focus afterward. Opening files are unchanged.
Motion preference remains session-only and still controls the existing reveal/visitor behavior.

## Verification and Studio checklist

Automated: the existing domain, persistence, opening and four scrolling checks remain; 1,292
checks cover read-only inventory/discovery projections, reservations, collection selection,
bonus preview vs the real domain, responsive grid/presentation bounds, collection theme fallbacks, numeric presentation and scope teardown.
These checks do **not** prove Roblox layout, rendering or input behavior.

Use current Rojo sync or the rebuilt `RobloxWorkspace.rbxlx`, then Play in unsaved preview.
Watch client/server Output. Paste `tests/StudioUI.client.luau` into the **client Command Bar**
on each screen to check target sizes, canvas bounds and safe-area containment. It is read-only.
Run `tests/StudioScroll.client.luau` with Book grid visible and All figures selected;
it scrolls to and verifies the last card. Neither script is mapped into the game build.

1. **Desktop 16:9:** test 1280×720 and 1920×1080. Start with the menu closed, open each nav item,
   close it with X/backdrop, and verify the world stays readable. Check exact balance
   popups and every price. Confirm the selected tab and focus/pressed/disabled treatments differ.
2. **Mobile/tablet:** test 320×568 portrait, 568×320 landscape and a tablet aspect ratio. Resize
   with each screen open, especially Book, figure details and Odds. On short landscape, open a screen and confirm the bottom navigation gives way to content; X/B restores it.
   Check safe-area edges, readable text, visible prices, unclipped portraits and touch targets.
3. **Book:** run the scroll script for both collections. Reach the final card with wheel, touch
   and gamepad; switch collections and All/Owned repeatedly. Progress must update immediately.
   Inspect silhouettes, discovered figures, zero-copy discoveries and duplicates. Confirm the
   larger preview, free count, rarity, rate and odds agree with the collection and server.
4. **Display/recycle:** place from both the book and a chosen slot; replace and remove; verify
   reservations/counts and income update only on replies. Last copies and fully displayed copies
   cannot recycle. Edit away from your shelf to check the server's failure toast. Return home.
5. **Expansion/palettes:** inspect locked slot four while unaffordable, then unlock when funded;
   confirm price is charged once and its lock disappears. Buy a palette, switch to another owned
   palette free, and compare its miniature and Equipped state with the real room.
6. **Shop:** inspect Odds for each box **before** buying; compare all six percentages. Test enough
   and insufficient Coins, claim the daily box from Shop, then confirm Goals and both Shop cards
   show it claimed. Spam Open with delayed networking: one pending request/one granted figure.
7. **Goals:** check 0/3, partial and 3/3 progress, available/claimed reward, free-box choice and
   completion plaque progress. Duplicate displayed IDs must not falsely fill distinct-set progress.
8. **Visits:** use two clients with different displays. Verify names, public portraits/rate,
   Visit, You're here and Return home. Have a host leave. No private Coins/Scrap/ownership appears.
9. **Notifications/saves:** trigger success, insufficient-resource/proximity errors, delayed
   replies and preview/saving/paused states. Toasts should wrap without clipping or stacking;
   paused storage disables actions and retains its status. They must expire cleanly.
10. **Opening integration:** buy, daily-claim and redeem from the redesigned screens. Check that
    the existing opening owns input, hides normal UI, retains NEW/duplicate behavior and restores
    the prior screen after Continue, Skip or reset. Use its existing fixture/checklist separately.
11. **Reduced motion/gamepad:** toggle Motion: low in the floating screen controls, then navigate and open a
    box. Check no new press-scale animation, simplified existing reveal and hidden visitors.
    With gamepad, test Y/B/shoulders/A, book detail/back, Odds/back and reaching offscreen controls.
12. **Respawn/lifecycle:** reset while browsing, in a detail screen and during opening. Switch
    screens 20 times without gameplay changes, then rerun the read-only UI check; descendant
    counts should not grow from navigation. Repeat collection scrolling after reset and watch
    for stuck selection, duplicated GUIs, timers or Output errors.

All Studio/device/multiplayer checks above remain **unrun by the coding agent**.

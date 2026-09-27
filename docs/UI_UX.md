# Collectible UI visual redesign

Implemented client candidate. **Studio visual, input, mobile and multiplayer acceptance is still
pending.** The server, catalog, economy, networking, persistence and blind-box opening system
remain unchanged. The reference image guides composition, not its example names, prices or rates.
Current figure and packaging models remain procedural placeholders, not the illustrated reference art.

The current world uses open Player Plots, an earning Display and cosmetic Shelves.
See [Player Plots and Shelves](PLAYER_PLOTS_AND_SHELVES.md). Shelf editing is functional
placeholder UI; Shop and Collection retain their existing presentations.

## Two visual layers

The global identity is ivory, dark neutral text and restrained lilac accents, with small floating
controls, fine borders and translucent surfaces. HUD, navigation, Goals, Shelves, notifications,
settings and generic Display controls have no collection motifs. Currency uses gold accents.

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
  compact bottom navigation. Labels are Collection, Display, Shop, Goals and Shelves.
- **Book:** the approved physical-book implementation now owns its cover/page stacks, deep fold,
  side index tabs, six mounted portraits, right-page product showcase and optional artwork slots.
  Grove/Tide themes transform the book; global controls remain neutral. See the dedicated
  [Collection implementation, asset map and Studio review](COLLECTION_UI.md).
- **Shop:** a transparent neutral boutique presentation uses compact collection cards above one
  reusable themed 3D product, an editorial detail panel, six possible figures, catalog-derived
  rarity odds, fixed one-box price/action, and a secondary daily claim. Collection themes change
  only card/product/emblem/accent presentation. See [Shop implementation](SHOP_UI.md).
- **Display:** a smaller bottom overlay leaves the plot visible. It shows current capacity,
  locked slots, individual/total rates, matching-set progress, and place/replace/remove controls.
  Three starting slots expand horizontally to a current maximum of six. The existing 4,000 Coin
  fourth-slot unlock remains; slots five and six have no acquisition flow.
- **Shelves:** the former Social navigation position opens a minimal owner editor with
  visible indexes/count (including wrapped sequences such as 4,5,1 of 5), Previous/Next, three
  visible-unit selectors, nine local slot buttons and a discovered-figure picker. Select a
  persistent Shelf Unit, then a local row/slot to place/replace/remove. Discovery is enough, even with zero copies. Edit near your own
  shelves. Physical arrows are also usable by nearby visitors and shift the shared viewport one unit for everyone.
  Navigation is disabled when exactly three units are owned.
  The physical installation is named Collection: its permanent header says COLLECTION, with
  integrated icon-only chevrons. Visible indexes remain in the owner editor, not world signage.
  A stale editor request is rejected if the shared carousel changed; the owner receives a fresh
  snapshot. No shelf customization or acquisition UI exists.
- **Goals:** a neutral sheet retains daily display progress/rewards and daily-box choice.
  Collection completion is tracked and shown; its future reward is TBD.
- **Feedback:** a bounded measured toast wraps messages, deduplicates repeats and expires.
  Errors last longer. Buttons retain disabled, pressed, focus and selected states, with subtle
  press animation respecting the session motion preference.

There is no shared enclosing menu panel, global page title or permanent balance/status header.
`Interface` coordinates independent presentation hosts and floating close/motion controls.
Book and Shop use presentation treatments; Shop applies the reusable mild world blur and warm dim
overlay. Generic sheets and Display controls leave the world clear. The Shop UI remains crisp.

## Layout, authority and lifecycle

`UILayout` defines each presentation's bounds within the Core UI safe area. Desktop reserves
space for the rail; mobile uses bottom navigation. Short landscape hides navigation while a
screen is open and keeps Close accessible. Collection uses left index tabs at every size; its
Motion preference remains accessible from other screens.
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
Motion preference remains session-only and still controls the existing reveal behavior.

## Verification and Studio checklist

Automated: the existing domain, persistence, opening and four scrolling checks remain; 1,839
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
   cannot recycle. Edit away from your Display to check the server's failure toast.
5. **Display expansion/Shelves:** unlock slot four and confirm exactly one charge, one new
   active position and a wider, recentered stand at the back; locked world pads are absent. Use an isolated six-slot test profile to
   inspect the full horizontal row. Place, replace and remove discovered figures in the shelf
   editor, including repeated figures and discoveries with zero copies. Confirm no income,
   inventory or recycle changes. Test a migrated profile with four/five owned units and both wraps.
6. **Shop:** inspect Odds for each box **before** buying; compare all six percentages. Test enough
   and insufficient Coins, claim the daily box from Shop, then confirm Goals and both Shop cards
   show it claimed. Spam Open with delayed networking: one pending request/one granted figure.
7. **Goals:** check 0/3, partial and 3/3 progress, available/claimed reward, free-box choice and
   collection completion progress. Duplicate displayed IDs must not falsely fill distinct-set progress.
8. **Walk-in viewing:** use two clients with different plots. Walk between them without a
   prompt or teleport. Verify owner DisplayName signs, shared one-unit turns, stale edit rejection,
   visitor edit denial, and no private inventory/balance data. Have the host leave and a new
   player join; the old content disappears and the slot is reusable without moving visitors.
9. **Notifications/saves:** trigger success, insufficient-resource/proximity errors, delayed
   replies and preview/saving/paused states. Toasts should wrap without clipping or stacking;
   paused storage disables actions and retains its status. They must expire cleanly.
10. **Opening integration:** buy, daily-claim and redeem from the redesigned screens. Check that
    the existing opening owns input, hides normal UI, retains NEW/duplicate behavior and restores
    the prior screen after Continue, Skip or reset. Use its existing fixture/checklist separately.
11. **Reduced motion/gamepad:** toggle Motion: low in the floating screen controls, then navigate and open a
    box. Check no new press-scale animation, simplified existing reveal.
    With gamepad, test Y/B/shoulders/A, book detail/back, Odds/back and reaching offscreen controls.
12. **Respawn/lifecycle:** reset while browsing, in a detail screen and during opening. Switch
    screens 20 times without gameplay changes, then rerun the read-only UI check; descendant
    counts should not grow from navigation. Repeat collection scrolling after reset and watch
    for stuck selection, duplicated GUIs, timers or Output errors.

All Studio/device/multiplayer checks above remain **unrun by the coding agent**.

# Collectible UI

Implemented client candidate. **Studio visual, input, mobile and multiplayer acceptance is still
pending.** The opening modules, shared catalog/types, server gameplay, persistence, economy and
Rojo mappings are unchanged. There are no new remotes, packages, art downloads or progression systems.

## Player experience

- **HUD/navigation:** small Coin and Scrap capsules leave the world visible. Tap Coins for the
  full balance and Coins/sec, or Scrap for its full balance and the book. Large balances use
  K/M/B abbreviations in the HUD only; prices remain exact. A compact saving-state control
  exposes the server's full status when tapped, including unsaved Studio preview. New save
  pauses also show an error toast. Book, Room, Shop, Goals and Visits use original icons and
  short labels. The menu begins closed, with one first-box/first-display suggestion when relevant.
- **Collection book:** collection name, discovered count and progress precede a portrait grid.
  Arrows switch collections; All figures/Owned only changes the filter. Unknown figures retain
  their silhouette, rarity and question mark; discoveries show name and quantity. Selecting
  a card opens its larger portrait, collection/rarity, owned/free counts, income, display status,
  odds, display action, Scrap redemption and eligible recycling. Completion and recycled
  discoveries continue to derive from server snapshots.
- **Shop:** themed 3D cartons, collection names, exact prices and Open actions replace purchase
  paragraphs. Every box has a clearly labeled Odds button showing all per-figure percentages
  from the snapshot. Daily free/claimed is visible on each card; the one daily claim is shared
  across collections, as before. Insufficient funds disable purchase without hiding its price.
- **Showroom:** four visual slots show their figure, empty state or lock. Choose/Change opens an
  owned-figure picker; selecting the figure and Display places it in the chosen slot. From the
  regular book, Display first asks which slot to use. Remove frees a copy. The fourth-slot card
  shows the server's price and Unlock action, then becomes an ordinary empty slot on confirmation.
  Income, matching-set progress and shelf proximity guidance are concise. Miniature palette
  previews show wall/floor/accent combinations with price, Use palette or Equipped states.
- **Goals:** the existing daily display task has three progress markers, reward and a claim
  state. A separate daily-box card offers one collection choice and shows the UTC reset after
  claiming. Collection completion cards show progress toward the existing showroom plaques.
- **Visits:** same-server player cards show public names, display portraits, public income and
  Visit/You're here states. Return home stays available. No private balances or inventories
  are consulted or displayed for another player.
- **Feedback:** one bounded toast replaces the old permanent instructional bar. Repeated
  identical messages do not stack. Errors last longer and use distinct text color; action
  success messages are concise. Buttons distinguish selection, focus, press and disabled state.

## Design and responsibility boundaries

`UITheme` centralizes cream/sage colors, spacing, rounded corners, Fredoka headings, Gotham
body text, touch targets and animation timing. Rarity colors reuse `OpeningConfig` so the book
and opening match. `Widgets` supplies cards, labels, actions, progress bars and measured list/grid
containers. `UIIcons` is an original native-shape icon adapter. `UIPreview` owns the reusable
static viewport slot, auto-fits figures/boxes and replaces its model only when identity changes.

`Hud`, `Navigation`, `CollectionScreen`, `FigureCard`, `FigureDetails`, `ShopScreen`,
`ShowroomScreen`, `GoalsScreen`, `VisitsScreen` and `Notifications` own their visual concerns.
`Interface` composes them and coordinates navigation, chosen slots, preference and focus.
`UIContext` holds typed callbacks; `UIState` contains read-only projections and sizing rules;
`UIScope` owns screen connections and tween/timer cleanup. Screens are created once and reused.
All models descend from the owning GUI. No permanent UI animation loop was added.

The client coordinator reports whether a mutation is pending. Affordances disable during that
request, paused storage and opening focus. The server continues to validate price, ownership,
reservation, capacity, proximity and every mutation; UI affordances are not authorization.
No ownership, currency or daily marker is optimistically updated.

## Responsive layout, input and motion

The ScreenGui uses Roblox's Core UI safe insets. Normal screens sit in a centered, bounded panel
above a bottom navigation bar; narrower screens use fewer card columns. Short screens move
navigation into a left rail and use the remaining space for the panel, with currency in its
header. On exceptionally short screens the rail scrolls instead of shrinking its 44px targets.
Collection details switch between a side portrait and a stacked scrolling presentation.

List/grid canvases explicitly measure `AbsoluteContentSize` plus padding via `Scroll.bind`,
including nested tile-container height changes. Filtering, viewport resizing and layout updates
recompute sizes. There is no reliance on automatic canvas height for viewport cards. All figures
remain represented in the book; filtering hides cards without deleting catalog entries.

Mouse/touch use Activated controls. Gamepad Y opens the menu, B returns/closes, shoulders switch
screens and A uses normal GUI selection. Focused controls inside a scroll container are brought
into view. The opening's higher-priority bindings retain ownership while it is active. The
normal GUI hides for an opening and restores its current screen afterward.

Motion preference is now in every menu header. Reduced motion disables new press-scale tweens;
color, focus borders, layout and progress stay readable. The same `effects()` preference still
drives the existing opening controller and decorative visitors. It remains a session preference,
matching the previous behavior; no persistent setting was added.

## Asset replacement

Current figure and box models remain original procedural placeholders. `UIPreview` is the slot
for production models/renders, `OpeningBox` remains the existing packaging adapter, `UIIcons`
can later use original image icons, and the simple palette miniatures can receive room art.
Changing those adapters does not require rewriting the screen flows. No production audio/art
was acquired, and the separate opening task was not redone.

## Verification and Studio checklist

Automated: the existing domain, persistence, opening and four scrolling checks remain; 1,118 new
checks cover read-only inventory/discovery projections, reservations, collection selection,
bonus preview vs the real domain, responsive grid bounds, numeric presentation and scope teardown.
These checks do **not** prove Roblox layout, rendering or input behavior.

Use current Rojo sync or the rebuilt `RobloxWorkspace.rbxlx`, then Play in unsaved preview.
Watch client/server Output. Paste `tests/StudioUI.client.luau` into the **client Command Bar**
on each screen to check target sizes, canvas bounds and safe-area containment. It is read-only.
Run `tests/StudioScroll.client.luau` with Book open, details closed and All figures selected;
it scrolls to and verifies the last card. Neither script is mapped into the game build.

1. **Desktop 16:9:** test 1280×720 and 1920×1080. Start with the menu closed, open each nav item,
   close it with X/backdrop, and verify the world stays readable. Check exact balance/status
   popups and every price. Confirm the selected tab and focus/pressed/disabled treatments differ.
2. **Mobile/tablet:** test 320×568 portrait, 568×320 landscape and a tablet aspect ratio. Resize
   with each screen open, especially Book, figure details and Odds. Scroll the rail if needed.
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
11. **Reduced motion/gamepad:** toggle Motion: low in a menu header, then navigate and open a
    box. Check no new press-scale animation, simplified existing reveal and hidden visitors.
    With gamepad, test Y/B/shoulders/A, book detail/back, Odds/back and reaching offscreen controls.
12. **Respawn/lifecycle:** reset while browsing, in a detail screen and during opening. Switch
    screens 20 times without gameplay changes, then rerun the read-only UI check; descendant
    counts should not grow from navigation. Repeat collection scrolling after reset and watch
    for stuck selection, duplicated GUIs, timers or Output errors.

All Studio/device/multiplayer checks above remain **unrun by the coding agent**.

# Pocket Grove game design

The user playtested the MVP, accepted its core loop, and authorized autonomous full-game
implementation. The full-game candidate now follows [this scope](FULL_GAME.md); its new runtime
and persistence acceptance tests remain open. Numbers remain tuning values, not proven balance.

## Vision and loop

Build a collectible showroom worth visiting. Open boxes, discover original cute figures, choose
your best display, earn Coins automatically, expand your shelf and finish themed collections.
Rarity is the main income driver, with small fixed differences between figures within each tier.
A higher-tier figure always earns more than a lower-tier figure. Every displayed copy contributes
its rate; copies in inventory do not earn. There is no income counter or visitor-controlled payout.

Two original collections ship: Pocket Grove and Tidepool Tales, six figures each. Each has three
Commons, two Uncommons and one Rare. Stable catalog IDs define identity, presentation and membership.
Figures are original procedural geometry with distinct silhouettes; no external/licensed assets.
Buying a box resolves charge, random result and grant together on the server. Reveals are short
and skippable; closing one cannot affect ownership. Odds and duplicate value are visible before
purchase. A combined collection index shows silhouettes, discoveries, quantities and free copies.

## Display and expression

A personal decorated showroom starts with three fixed slots. One fourth slot costs a visible
fixed Coin price. Selecting and replacing figures reserves copies without consuming them.
The interface shows individual and total Coins/sec. Three distinct figures from the same
collection add a modest +1/sec once. Set bonuses never compound as multipliers.

Three room palettes provide a small cosmetic purchase choice. Completing each fixed collection
adds a permanent index acknowledgement and cosmetic room plaque, derived from saved discovery.
Expansion and cosmetics are bounded; neither starts an endless upgrade tree. Server-authorized
same-server visits show public displays but never expose private balances or allow guest edits.

## Income, duplicates and returning

Income accrues automatically while online, including idle time. Server elapsed-time accounting
is independent of frame rate and visitors. No offline income. At most two local visitors decorate
the currently visited room. Reduced-motion mode hides them. Inventory, display, progression,
palettes and balances persist after a successful persistent load; Studio preview is clearly
labeled unsaved. Failed loads block play instead of replacing existing data with new defaults.

Voluntarily recycle an extra undisplayed copy for one Scrap, retaining at least one owned copy.
Six Scrap redeems any chosen figure from either collection. Discovery survives recycling. This
provides a deterministic route to completion without duplicate upgrades or trading.

One free daily box and one simple daily display goal use server UTC day boundaries. No streak
penalty, rotating availability or mandatory daily checklist. The core loop works without these
rewards. Starter funds are a one-time new-profile grant in persistent mode.

## Interface and boundaries

The client uses a minimal currency HUD, icon navigation, a collection book with portrait grids
and figure details, a visual box shop, display-slot/palette cards, daily progress and public
showroom cards. Prices, rates, odds and ownership remain accessible without permanent system
paragraphs. Safe-area layouts, measured scrolling and reduced motion support readability;
[UI device and gamepad acceptance](UI_UX.md) still requires Studio testing.

The implementation excludes trading, unique-copy variants, offline income, paid items, battle
passes and public deployment. Original content and code are ready for closed testing, not a claim
of commercial launch readiness. Next decisions should follow real returning-player, performance
and storage tests, not another unbounded feature list. See [operations](OPERATIONS.md).

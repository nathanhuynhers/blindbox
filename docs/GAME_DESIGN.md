# Pocket Grove game design

The user playtested the MVP, accepted its core loop, and authorized autonomous full-game
implementation. The full-game candidate now follows [this scope](FULL_GAME.md); its new runtime
and persistence acceptance tests remain open. Numbers remain tuning values, not proven balance.

## Vision and loop

Build a collectible world worth visiting. Open boxes, discover original cute figures, choose
your best active Display earners, generate Coins automatically, finish themed collections, and
build expressive Showrooms that other players can visit.
Rarity is the main income driver, with small fixed differences between figures within each tier.
A higher-tier figure always earns more than a lower-tier figure. Every displayed copy contributes
its rate; copies in inventory do not earn. There is no income counter or visitor-controlled payout.

Two original collections ship: Pocket Grove and Tidepool Tales, six figures each. Each has three
Commons, two Uncommons and one Rare. Stable catalog IDs define identity, presentation and membership.
Figures are original procedural geometry with distinct silhouettes; no external/licensed assets.
Buying a box resolves charge, random result and grant together on the server. Reveals are short
and skippable; closing one cannot affect ownership. Odds and duplicate value are visible before
purchase. A combined collection index shows silhouettes, discoveries, quantities and free copies.

## Display economy and Showroom expression

A **Display** is the small utility system on the player's main plot. Only copies assigned to its
active slots generate Coins. The approved long-term structure starts with three slots and supports
up to six; unlock methods for slots 4-6 remain TBD. The current candidate implements only one
fixed-price fourth-slot unlock. Selecting and replacing figures reserves copies without consuming
them. The interface shows individual and total Coins/sec. Three distinct figures from the same
collection currently add a modest +1/sec once. Set bonuses never compound as multipliers.

**Showrooms** are separate non-economic spaces for collection completion, customization, social
visiting, and flexing. They generate zero Coins. Completing a collection should unlock its themed
Showroom; separately acquired blank/custom rooms remain possible. One scalable Showroom Gallery
entrance represents all rooms on the main plot. See [the canonical direction](DISPLAY_AND_SHOWROOMS.md).

The current candidate's three room palettes and completion plaques belong to the older combined
room/Display prototype. Their saved ownership must survive migration and should eventually feed
Showroom cosmetics. Current same-server visits show public main-plot Displays; future gallery and
Showroom visiting is not implemented. Guests never receive private balances or editing authority.

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

The client uses a neutral minimal currency HUD and floating icon navigation. Collections have
independently themed book pages, portrait grids and figure details. Package-led shopping,
small Display controls, compact daily sheets and public Display cards have distinct layouts. Prices, rates, odds and ownership remain accessible without permanent system
paragraphs. Safe-area layouts, measured scrolling and reduced motion support readability;
[UI device and gamepad acceptance](UI_UX.md) still requires Studio testing.

The implementation excludes trading, unique-copy variants, offline income, paid items, battle
passes and public deployment. Original content and code are ready for closed testing, not a claim
of commercial launch readiness. Next decisions should follow real returning-player, performance
and storage tests, not another unbounded feature list. See [operations](OPERATIONS.md).

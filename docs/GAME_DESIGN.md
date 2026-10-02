# Blind Box game design

Current direction is [Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md).
The accepted [historical MVP](MVP.md) established the core loop; the current candidate still needs
native Studio, storage and multiplayer acceptance. Collection rewards and final art remain TBD.

Open boxes, discover original collectibles, choose active Display earners, earn Coins, collect
more figures and arrange cosmetic shelves on a large open personal plot. Visitors simply walk
over from the shared world. Pocket Grove and Tidepool Tales are collections, not plot identities.

The supported hierarchy is Common < Uncommon < Rare < Legendary < Mythical. Five collections
contain 43 figures. Prices and income scale by collection tier: Grove 1,500; Tide 2,000; Concepts
20,000; Tender Echoes and We Are All Stars both 200,000 Coins. Standard high-tier base odds are
1% Legendary and 0.1% Mythical, with collection-specific increasing-chance pity and no hard guarantee.

Duplicate copies are permanently retained and automatically enhance their figure's income with
rarity-scaled diminishing returns. Each figure ID can earn in only one Display slot. Display starts
with three slots and expands sequentially to six for 40,000 / 400,000 / 4,000,000 Coins.
Three distinct displayed figures from one collection grant +10% total income once. No offline
income or visitor payouts. Figures bank income until their owner clicks them or presses E nearby;
uncollected balances survive removal and rejoining. Future paid auto-collect is not implemented.
See [economy](ECONOMY.md) for exact formulas and tuning.

Shelves use discovered figures cosmetically and reserve zero copies. Players start with three persistent
Shelf Units, each with three rows of three positions (nine per unit, 27 starting positions).
Exactly three physical structures show the viewport; each turn shifts one owned unit and wraps.
Navigation is disabled with three owned units. Visitors may browse but cannot edit. Future
acquisition adds individual units without growing the plot. No product-design maximum exists;
acquisition/pricing and shelf customization are future work. Completion grants no new
reward: rewards are unresolved.

Scrap, recycling and redemption are removed. New profiles start with 4,500 Coins and fully random
starter purchases. One free Starter box and the 1,000-Coin daily Display goal retain UTC rules.
The authorized economy reset starts schema-6 profiles in new save namespaces; no old progress
is imported. Manual collection advances the current schema to 7, safely upgrading valid Economy2
schema-6 profiles without another reset. Existing lease/retry/storage-failure protection remains.

The current map uses fixed open plots with a pale-wood layered showroom platform, integrated
`<DisplayName>'s Showroom` entrance plaque, Display fixture, Collection shelves and arrow controls.
The center/right stay intentionally open; no plot props or perimeter walls obstruct future fixture
expansion. Collections and Shop retain their existing UI/art. There is no
active Showroom, Gallery, interior visit flow, teleport browser, paid product, trading system,
free placement or new completion reward. See [scope](FULL_GAME.md) and [operations](OPERATIONS.md).

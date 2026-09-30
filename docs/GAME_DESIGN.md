# Blind Box game design

Current direction is [Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md).
The accepted [historical MVP](MVP.md) established the core loop; the current candidate still needs
native Studio, storage and multiplayer acceptance. Collection rewards and final art remain TBD.

Open boxes, discover original collectibles, choose active Display earners, earn Coins, collect
more figures and arrange cosmetic shelves on a large open personal plot. Visitors simply walk
over from the shared world. Pocket Grove and Tidepool Tales are collections, not plot identities.

The supported standard hierarchy is Common < Uncommon < Rare < Legendary < Mythical, with
Mythical highest. Legendary/Mythical presentation and validation are available before any live
figures use them; see [rarity architecture](RARITY.md). No high-tier content or odds are implied.
Two collections contain six figures each: three Common, two Uncommon and one Rare. Catalog IDs,
server rarity rates/odds and the 150-Coin box price are unchanged. Buying resolves spend and grant
atomically; the existing skippable opening cannot grant items. The Collection Book records owned
counts and permanent discoveries, including collection completion.

Display starts with three slots and extends horizontally up to six. Only reserved Display copies
earn, with the existing +1/sec bonus for three distinct figures from one collection. Slot 4 keeps
its legacy Coin unlock; slots 5/6 acquisition remains TBD. No offline income or visitor payouts.

Shelves use discovered figures cosmetically and reserve zero copies. Players start with three persistent
Shelf Units, each with three rows of three positions (nine per unit, 27 starting positions).
Exactly three physical structures show the viewport; each turn shifts one owned unit and wraps.
Navigation is disabled with three owned units. Visitors may browse but cannot edit. Future
acquisition adds individual units without growing the plot. No product-design maximum exists;
acquisition/pricing and shelf customization are future work. Completion grants no new
reward: rewards are unresolved.

Duplicate recycling still consumes one free extra copy for one Scrap while retaining the last
copy; six Scrap redeems a chosen figure. Shelf use never blocks this. Daily free boxes and the
100-Coin daily Display goal retain existing UTC rules. Starter Coins are granted only to a new
profile. Schema-v5 migration preserves prior progress, splits each retired v4 page into three units
and retains v3 cosmetic references.

The current map uses fixed open plots with a pale-wood layered showroom platform, integrated
`<DisplayName>'s Showroom` entrance plaque, Display fixture, Collection shelves and arrow controls.
The center/right stay intentionally open; no plot props or perimeter walls obstruct future fixture
expansion. Collections and Shop retain their existing UI/art. There is no
active Showroom, Gallery, interior visit flow, teleport browser, paid product, trading system,
free placement or new completion reward. See [scope](FULL_GAME.md) and [operations](OPERATIONS.md).

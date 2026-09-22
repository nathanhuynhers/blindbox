# Game design

Status: planning proposal; no gameplay development is authorized by these documents.
The user's concept is the confirmed direction. Prototype defaults below are recommendations,
not approved final balance or content. See [MVP](MVP.md) for scope,
[economy](ECONOMY.md) for tuning, and [roadmap](ROADMAP.md) for implementation gates.

## Vision and confirmed direction

**Build the coolest collectible showroom.** Collect cute original figures, arrange a collection
worth visiting, and turn visitor earnings into more collecting and showroom possibilities.
The target experience mixes the surprise of a reveal with deliberate collection goals and pride
in a physical space. Original characters, names, art, sounds, and brands are required; example
fruit characters in the brief are inspiration for structure, not licensed or final content.

The intended loop is:

Open a box -> discover a figure -> keep it in inventory -> display it -> attract visitors ->
collect Coins -> buy another box -> broaden the collection -> eventually expand the showroom.

RNG creates excitement, but predictable earnings and a route to a chosen missing figure must
support progress after unlucky rolls. Rarity alone must not determine a good display.

## Collecting and opening

Collections are themed groups with stable IDs and data-defined membership. Figure identity,
display name, rarity, presentation asset, and income characteristics come from definitions.
Rarity names, ordering, presentation, and roll weights are configurable; no fixed five-tier
hierarchy is assumed. Exact characters and initial theme remain undecided.

Prototype default: one six-figure collection, three provisional rarity tiers, and one Coin box.
The buy action purchases and resolves one box atomically; unopened-box inventory is deferred.
A short skippable reveal shows the result already granted by the server. Skipping, lag, or
closing the reveal never changes the result. Show odds and duplicate value before purchase.
Each figure should have a recognizable silhouette even when represented by simple original
placeholder models. Collection additions should require definitions and assets, not new systems.

## Showroom and composition

The long-term showroom is a personal, expandable expression of taste. Start the prototype with
three fixed slots on one shelf. Select an owned figure and a slot; replacing a display returns
the previous figure to available inventory. Displaying reserves a copy; it does not consume it.

Prototype economics combine modest rarity differences with an additive bonus for distinct
figures. Three copies of the rarest figure must earn less than a deliberately diverse display
that includes common figures. This is the smallest test of meaningful composition.

Later, test themed shelves with explicit subset membership, completed-set bonuses, and visitor
preferences. Keep bonuses bounded and understandable. A six-piece display set is impossible
in three slots, so it is not an MVP income requirement. Historical collection-book completion
and currently displayed sets are separate concepts. Avoid penalizing decorative choices so
strongly that every showroom converges on the same layout.

## Visitors and income

Visitors explain income visually: enter, browse, react, leave. Prototype visitors follow fixed
waypoints with a low simultaneous count; they need no pathfinding, needs simulation, or queues.
The server accrues income from the validated display. Clients animate representative visits;
animation completion never grants money. This permits stable income on slow devices.

Provisional interaction: collect a capped Coin bank at the showroom counter. An unattended bank
fills and stops earning; offline earnings are excluded. Collection and rearrangement give active
players more opportunity than leaving the application idle. This limits unattended accumulation,
but is not proof of human activity or a complete defense against automation. If collecting feels
like a chore, change the interaction before adding more retention mechanics.

## Progression and completion

Progress has three tracks: discover figures, improve display composition, and later purchase
bounded showroom capacity/customization. The first loop requires no rare roll. Display space
unlocks should have fixed, visible costs, not random requirements.

The MVP index shows six entries, discovered names/rarities, unknown silhouettes, owned counts,
and discovered/total completion. Discovery is permanent within the session even after recycling.
Completing all six unlocks a visible collection-complete stamp in the index. Later rewards can
include a plaque, title, or cosmetic shelf; avoid a large permanent income multiplier.

## Duplicates

Prototype default: voluntarily recycle one extra, undisplayed copy into one Scrap. Six Scrap
redeem one chosen figure from the prototype collection, including its rare tier. Keep at least
one owned copy of each discovered figure when recycling. No automatic recycling.
This creates a deterministic fallback without another random reward or upgrade tree.

Long-term recommendation: retain targeted redemption and explore cosmetic variant crafting.
Consider trading only after persistent item identity, transfer recovery, audit history, and
duplication defenses are designed and tested. Do not assume trading is necessary for launch.
Avoid upgrades that consume dozens of copies solely to multiply income.

## Social and retention direction

Future visits and inspecting displays best express the showroom fantasy. Likes, wishlists,
titles, featured rooms, effects, and leaderboards are candidates, not a committed backlog.
Visitors must not modify a host's inventory, displays, or bank. Visits need not award currency.

Daily rewards and short collection/display goals should encourage returning to an enjoyable
loop. Prototype onboarding grants enough Coins for multiple free-to-the-player openings.
Daily boxes, missions, forgiving streaks, rotating collections, and seasonal content are later
experiments. Avoid punishing missed days or removing the only route to collection completion.
No MVP battle pass, monetization, live calendar, or paid random items.

## Principles and exclusions

- Give ordinary figures aesthetic and compositional value; make luck a bonus to progress.
- Keep economic explanations visible and simple, with bounded additive rewards.
- Respect player time: short reveals, understandable goals, no required endless AFK sessions.
- Keep authority on the server and presentational freedom on the client.
- Start with a playable loop and gather evidence before adding content or infrastructure.
- Do not become a pure slot machine, an escalating multiplier simulator, a clone of a licensed
  brand, a mandatory daily chore list, or an economy dependent on pay-to-win purchases.

## Open Design Questions

All defaults below are provisional. Resolve scope choices before their milestone; tune numbers
through playtests. None blocks documentation creation.

| Question | Recommended prototype default | Evidence or decision needed |
| --- | --- | --- |
| Exact opening interaction? | One buy/open button and skippable reveal | Does the reveal feel exciting after ten openings? |
| Manual income collection? | Counter interaction; capped bank | Is it satisfying or repetitive? Compare automatic collection later. |
| What do visitors actually simulate? | Cosmetic waypoint visitors representing server income | Can players explain where Coins come from? |
| Recycle or upgrade duplicates? | Voluntary recycling and chosen-figure redemption | Is six duplicates per choice fair across rarity tiers? |
| Placement freedom? | Three fixed slots, no rotation controls | Does selecting a composition already feel creative? |
| Individually unique collectibles? | Quantity stacks, identity migration before trading | Are launch variants or provenance actually needed? |
| Initial collection size and theme? | Six original placeholders; theme undecided | Approve final art direction and content budget later. |
| Variants at launch? | Excluded from prototype; decide before persistent schema expands | Do variants add expression worth the complexity? |
| Saving in the first prototype? | Session-only closed Studio test, clearly labeled reset | Confirm this limit before implementation; persistence before external progression tests. |
| Collection-completion reward? | Index stamp now, cosmetic plaque later | Is cosmetic recognition meaningful enough? |
| Social scope at launch? | No MVP visits UI; evaluate same-server visits later | Does showing rooms increase return interest? |
| Future monetization? | Undecided; preserve server grant boundaries | Separate design and current Roblox policy review before any paid mechanic. |

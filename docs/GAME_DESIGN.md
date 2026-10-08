# Blind Box game design

Current direction is [Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md).
The accepted [historical MVP](archive/MVP.md) established the core loop; the current candidate still needs
native storage, multiplayer and physical-device acceptance. Final art remains a proposal;
first-completion Shelf rewards are implemented as described in the [plot reference](PLAYER_PLOTS_AND_SHELVES.md).

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
Three distinct displayed figures from one collection grant +10% total income once. Displayed figures
keep earning offline at half rate for up to 6 hours, claimed from a welcome-back popup. No visitor payouts. Figures bank income until their owner steps on its corresponding plate or clicks/taps that figure;
removal preserves the bank, while replacement automatically attempts to collect the outgoing
figure's whole bank. Fractions and wallet overflow survive replacement and rejoining.
E nearby opens Display management only.
Once either editor is open, a living owner can edit their Display and Shelves from anywhere
inside their own plot; the server rejects edits from outside it. Future paid auto-collect is not implemented.
See [economy](ECONOMY.md) for exact formulas and tuning.

For canonical Shelf capacity, viewport, owned-copy placement, Shelf progression and completion rewards,
see [Player Plots, Display and Shelves](PLAYER_PLOTS_AND_SHELVES.md).

Scrap, recycling and redemption are removed. New profiles start with 4,500 Coins and fully random
starter purchases. One free Starter box and the 1,000-Coin daily Display goal retain UTC rules.
The authorized economy reset uses the Economy2 namespaces; no old-namespace progress is imported.
Consecutive Daily Login rewards (UTC days, 7-day looping cycle, a missed day restarts at Day 1)
grant placeholder Coins and free boxes; see [data model](DATA_MODEL.md).
Current schema 14 (which adds the plaza stall stock to schema 13's Welcome Quest stage and skip choice) safely upgrades valid Economy2 schemas 6–13, while schemas 1–5 are rejected.

New players get a short Welcome Quest taught through real actions: open a free Welcome Box
(Pocket Grove, Uncommon or Rare), put the figure on Display, collect its Coins, open a box with
Coins, then receive a one-time free Pocket Grove x10 with at least one Rare. The x10 summary shows
Pocket Grove discovery progress with silhouettes for missing figures, and an optional tip
introduces Shelves afterwards. See [data model](DATA_MODEL.md#welcome-quest-v13).
Existing lease/retry/storage-failure protection remains.

The world is **Blindbox Town**, a cozy blind-box shopping town (no shared stores or shop buildings):
eight open plots ring a paved plaza with a giant opening blind box, joined by direct paths and
crossed by the cobbled Market Street ring with lanterns. Gift-box stacks and marble statues of Peeka, the town mascot, fill the
gaps between plots, sculpted sakura and green trees line the town, and a hedge wraps the island. Players spawn on their own plot;
each active plot has a walk-through `<DisplayName>'s Showroom` arch, potted plants, striped
Display/Shelves awnings, a spawn pad and Peeka's Box Shop, a box-shaped kiosk where Peeka minds
the counter and E opens the existing Shop screen (owner only), all in one shared pastel-pink accent. A 20-minute
day/night cycle switches lanterns and plot lights on at dusk and strengthens the existing Display
and Shelf fixture washes until dawn. A global plaza leaderboard rotates
Most Figures, Top Coins/sec and Most Boxes Opened; it is presentation only and grants nothing.
The center/right of each plot stays open. Collections and Shop retain their existing UI/art. There
is no active Showroom, Gallery, interior visit flow, teleport browser, paid product, trading
system or free placement. The implemented completion reward is one Shelf Unit per collection;
other completion rewards remain proposals. See [operations](OPERATIONS.md).

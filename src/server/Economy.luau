--!strict
-- Server-only tuning; collections reference reusable tiers and explicit figure income units.
export type Tier = { price: number, paybackSeconds: number }
export type Collection = { tier: string, buckets: string, pity: string?, group: string }
export type Curve = { base: number, start: number, increment: number, maximum: number }
export type Duplicate = { maximum: number, curve: number }
local tiers: { [string]: Tier } = {
	starter = { price = 1500, paybackSeconds = 180 },
	nearStarter = { price = 2000, paybackSeconds = 180 },
	niche = { price = 20000, paybackSeconds = 550 },
	prestige = { price = 200000, paybackSeconds = 850 },
}
local collections: { [string]: Collection } = {
	grove = { tier = "starter", buckets = "starter", group = "grove" },
	tide = { tier = "nearStarter", buckets = "starter", group = "tide" },
	concept = { tier = "niche", buckets = "standard", pity = "standard", group = "concept" },
	echo = { tier = "prestige", buckets = "standard", pity = "standard", group = "echo" },
	star = { tier = "prestige", buckets = "standard", pity = "standard", group = "star" },
}
local buckets: { [string]: { [string]: number } } = {
	starter = { Common = 60, Uncommon = 30, Rare = 10 },
	standard = { Common = 60, Uncommon = 25, Rare = 13.9, Legendary = 1, Mythical = 0.1 },
}
local pity: { [string]: { [string]: Curve } } = {
	standard = {
		Legendary = { base = 1, start = 40, increment = 0.05, maximum = 8 },
		Mythical = { base = 0.1, start = 300, increment = 0.0015, maximum = 2 },
	},
}
local duplicates: { [string]: Duplicate } = {
	Common = { maximum = 0.6, curve = 5 },
	Uncommon = { maximum = 0.9, curve = 5 },
	Rare = { maximum = 1.25, curve = 4 },
	Legendary = { maximum = 1.5, curve = 2 },
	Mythical = { maximum = 3, curve = 2 },
}
return table.freeze({
	tiers = tiers,
	collections = collections,
	buckets = buckets,
	pity = pity,
	duplicates = duplicates,
	expansionCosts = { [4] = 40000, [5] = 400000, [6] = 4000000 },
	goalReward = 1000,
	-- Purchased Shelf Unit n (0-based) costs shelfPrice * shelfGrowth^n; free unlocks don't count.
	shelfPrice = 50000,
	shelfGrowth = 2.5,
	setBonus = 0.1,
	-- Offline earnings: fraction of the online Display rate, accrual cap and minimum absence.
	offlineRate = 0.5,
	offlineMaxSeconds = 6 * 60 * 60,
	offlineMinSeconds = 60,
	startingCoins = 4500,
	dailyCollection = "grove",
	coinLimit = 1000000000000,
	copyLimit = 1000000000,
	counterLimit = 1000000,
	entries = {
		{ id = "grove.pebble", units = 0.55, weight = 1 },
		{ id = "grove.sprout", units = 0.625, weight = 1 },
		{ id = "grove.acorn", units = 0.7, weight = 1 },
		{ id = "grove.mushroom", units = 1.2, weight = 1 },
		{ id = "grove.moth", units = 1.4, weight = 1 },
		{ id = "grove.star", units = 3, weight = 1 },
		{ id = "tide.bubble", units = 0.55, weight = 1 },
		{ id = "tide.coral", units = 0.625, weight = 1 },
		{ id = "tide.shell", units = 0.7, weight = 1 },
		{ id = "tide.jelly", units = 1.2, weight = 1 },
		{ id = "tide.ray", units = 1.4, weight = 1 },
		{ id = "tide.pearl", units = 3, weight = 1 },
		{ id = "concept.verity", units = 0.625, weight = 1 },
		{ id = "concept.falsity", units = 1.3, weight = 1 },
		{ id = "concept.cruelty", units = 3, weight = 1 },
		{ id = "concept.lovity", units = 8, weight = 1 },
		{ id = "concept.verity-true-form", units = 22, weight = 1 },
		{ id = "echo.thread-parade", units = 0.55, weight = 1 },
		{ id = "echo.wander-knit", units = 0.6, weight = 1 },
		{ id = "echo.dino-drift", units = 0.65, weight = 1 },
		{ id = "echo.still-pebble", units = 0.7, weight = 1 },
		{ id = "echo.hearth-helm", units = 1.2, weight = 1 },
		{ id = "echo.echo-line", units = 1.3, weight = 1 },
		{ id = "echo.paper-crown", units = 1.4, weight = 1 },
		{ id = "echo.mask-nuzzle", units = 2.8, weight = 1 },
		{ id = "echo.hush-veil", units = 3, weight = 1 },
		{ id = "echo.crate-spark", units = 3.2, weight = 1 },
		{ id = "echo.feather-hush", units = 7.5, weight = 1 },
		{ id = "echo.mumble-beast", units = 8.5, weight = 1 },
		{ id = "echo.moon-doze", units = 22, weight = 1 },
		{ id = "star.reminiscence", units = 0.55, weight = 1 },
		{ id = "star.mirrorlight", units = 0.6, weight = 1 },
		{ id = "star.wishing", units = 0.65, weight = 1 },
		{ id = "star.page-turner", units = 0.7, weight = 1 },
		{ id = "star.nightlight", units = 1.2, weight = 1 },
		{ id = "star.lamplight", units = 1.3, weight = 1 },
		{ id = "star.garden", units = 1.4, weight = 1 },
		{ id = "star.sanctuary", units = 2.8, weight = 1 },
		{ id = "star.echo", units = 3, weight = 1 },
		{ id = "star.radiant", units = 3.2, weight = 1 },
		{ id = "star.cloud-rest", units = 7.5, weight = 1 },
		{ id = "star.meteor-shower", units = 8.5, weight = 1 },
		{ id = "star.dreamcatcher", units = 22, weight = 1 },
	},
})

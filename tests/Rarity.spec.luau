--!strict
local Rarity = require("./Rarity")
local Config = require("./OpeningConfig")
local Flight = require("./OpeningFlight")
local State = require("./OpeningState")
local Catalog = require("./Catalog")
local Economy = require("./Economy")
local Rules = require("./Rules")
local Style = require("./CollectionStyle")
local Theme = require("./UITheme")
local Assets = require("./CollectionAssets")
local Shop = require("./ShopState")
local Layout = require("./ShopLayout")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local order = { "Common", "Uncommon", "Rare", "Legendary", "Mythical" }
local scrambled = { "Mythical", "Rare", "Legendary", "Common", "Uncommon" }
table.sort(scrambled, Rarity.less)
check(
	table.concat(scrambled, ",") == table.concat(order, ","),
	"sorting uses hierarchy, not alphabet"
)
check(table.concat(Rarity.order, ",") == table.concat(order, ","), "canonical standard hierarchy")
local transitions, holds, silhouettes =
	{ 0.19, 0.22, 0.25, 0.30, 0.38 },
	{ 0.25, 0.35, 0.55, 0.70, 0.90 },
	{ 0.35, 0.48, 0.65, 0.8, 0.95 }
for index, id in order do
	check(
		Rarity.isValid(id) and Rarity.parse(id) == id and Rarity.rank(id) == index,
		"strict known tier: " .. id
	)
	local identity, profile = Rarity.get(id), Config.profile(id)
	check(
		profile.rarity == id and profile.tint == identity.tint and profile.accent == identity.accent,
		"canonical cinematic palette"
	)
	check(
		Style.rarity(id) == identity.tint
			and Theme.rarity(id) == identity.ink
			and Assets.badges[id] ~= nil,
		"complete consistent UI palette and badge slot"
	)
	check(
		profile.flight.transition == transitions[index] and profile.flight.hold == holds[index],
		"exact requested transition and hold"
	)
	check(profile.timing.silhouette == silhouettes[index], "configured silhouette hierarchy")
	check(Config.sounds["rarity" .. id] ~= nil, "rarity audio hook")
	for _, cue in profile.cues do
		check(Config.sounds[cue] ~= nil, "signature audio hook")
	end
	check(
		profile.particles <= Config.rarities.Rare.particles
			and profile.bloom <= Config.rarities.Rare.bloom,
		"higher tiers do not inflate particle or Bloom budget"
	)
	for _, reduced in { false, true } do
		local state = State.create(profile.timing, reduced, false)
		state.phase, state.elapsed = "RarityTease", 0
		check(
			not Flight.sample(state, profile).hushed or profile.signature.quietUntil > 0,
			"quiet rhythm comes from profile"
		)
		state.elapsed = profile.flight.transition + profile.flight.hold - 0.001
		check(Flight.sample(state, profile).dive == 0, "full recognition hold in both motion modes")
		for _, phase in { "Flight", "RarityTease", "Impact", "Silhouette", "Result" } do
			for step = 0, 10 do
				local p = step / 10
				local lights = Config.lightState(
					phase,
					p,
					if phase == "Impact" then p * profile.timing.impact else nil,
					profile
				)
				check(
					lights.studio + lights.seam + lights.comet <= Config.lighting.peak + 0.00001,
					"all-tier lighting budget"
				)
			end
		end
	end
end
for _, invalid in { "", "rare", "MYTHICAL", "Secret", "future", 5, false, {} } do
	check(
		not Rarity.isValid(invalid) and Rarity.parse(invalid) == nil,
		"unknown rarities stay invalid"
	)
end
check(not Rarity.isValid(nil), "nil is invalid")
check(not pcall(Rarity.rank, "Unknown"), "rank does not legitimize unknown labels")
-- Legendary keeps its original bold double pulse. Mythical now has a separate cadence.
for _, rarity in { "Legendary" } do
	local profile = Config.profile(rarity)
	for _, reduced in { false, true } do
		local state = State.create(profile.timing, reduced, false)
		state.phase = "RarityTease"
		local waves = profile.signature.pulses
		state.elapsed = profile.flight.transition * (waves[1].at + waves[1].span / 2)
		local first = Flight.sample(state, profile)
		state.elapsed = profile.flight.transition * (waves[1].at + waves[1].span + waves[2].at) / 2
		local pause = Flight.sample(state, profile)
		state.elapsed = profile.flight.transition * (waves[2].at + waves[2].span / 2)
		local second = Flight.sample(state, profile)
		check(
			first.pulse > 0.9
				and pause.pulse < 0.001
				and second.pulse > 0.5
				and second.pulse < first.pulse,
			"two separated pulses with smaller second wave"
		)
		state.elapsed = profile.flight.transition * 0.1
		check(
			Flight.sample(state, profile).hushed == profile.signature.spectral,
			"Mythical's quiet compression is distinctive"
		)
		state.elapsed = profile.flight.transition
		local final = Flight.sample(state, profile)
		check(
			not final.hushed and final.highlight[1] == profile.highlight[1],
			"highlight resolves to controlled palette"
		)
	end
end
check(
	Config.rarities.Legendary.signature.trailLayers == 2
		and Config.rarities.Mythical.signature.trailLayers == 3,
	"distinct trail structures"
)
check(
	not Config.rarities.Legendary.signature.spectral and Config.rarities.Mythical.signature.spectral,
	"spectral aura is qualitative distinction"
)

-- Figure identities remain stable; new server probabilities are bucket-based.
check(#Catalog.figures == #Economy.entries, "every figure has economy tuning")
for _, figure in Catalog.figures do
 check(Rules.rates[figure.id] > 0 and Rules.odds[figure.id] > 0, "positive published base economy")
end
local tiers = { grove = 3, tide = 3, concept = 5, echo = 5, star = 5 }
local sizes = { grove = 6, tide = 6, concept = 5, echo = 13, star = 13 }
for _, collection in Catalog.collections do
	local rows = Shop.rarityOdds({ odds = Rules.odds, baseOdds = Rules.odds }, collection.id)
	local tierCount = tiers[collection.id]
	check(
		#rows == tierCount and Shop.rarityCount(collection.id) == tierCount,
		"Shop omits unavailable tiers"
	)
	for index, row in rows do
		check(row.rarity == order[index], "Shop canonical order")
	end
	local discovered, total = Shop.progress({ discovered = {} }, collection.id)
	check(
		discovered == 0 and total == sizes[collection.id],
		"completion still follows actual figures"
	)
end
for _, width in { 320, 568, 800 } do
	for _, count in { 3, 5, 6 } do
		local layout = Layout.details(width, count)
		check(layout.oddsHeight >= 36 + count * 29, "all odds rows fit")
		if layout.narrow or layout.wide then
			check(
				layout.purchaseY >= layout.oddsY + layout.oddsHeight,
				"odds cannot overlap purchase controls"
			)
		end
		check(
			layout.height
				>= math.max(
					layout.oddsY + layout.oddsHeight,
					layout.purchaseY + layout.purchaseHeight
				),
			"scroll height includes extended rarity rows"
		)
	end
end
print(
	"PASS: "
		.. checks
		.. " canonical rarity, five-tier profile/UI, identity and live economy preservation checks"
)

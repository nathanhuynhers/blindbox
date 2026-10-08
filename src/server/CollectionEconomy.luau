--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Config = require(script.Parent.Economy)
local Economy = {}
local rates: { [string]: number } = {}
local prices: { [string]: number } = {}
local weights: { [string]: number } = {}
local totals: { [string]: { [string]: number } } = {}
local groups: { [string]: string } = {}
local function positive(value: number): boolean
	return value > 0 and value < math.huge
end
for _, value in
	{
		Config.startingCoins,
		Config.coinLimit,
		Config.copyLimit,
		Config.counterLimit,
		Config.goalReward,
	}
do
	assert(positive(value) and value % 1 == 0, "Invalid economy bound")
end
assert(
	Config.coinLimit < 9007199254740991 and Config.startingCoins <= Config.coinLimit,
	"Unsafe Coin bound"
)
assert(Config.setBonus >= 0 and Config.setBonus <= 1, "Invalid themed bonus")
assert(
	positive(Config.shelfPrice) and Config.shelfPrice % 1 == 0 and Config.shelfGrowth >= 1,
	"Invalid shelf pricing"
)
for _, cost in Config.expansionCosts do
	assert(positive(cost) and cost % 1 == 0 and cost <= Config.coinLimit, "Invalid expansion cost")
end
for _, rarity in Rarity.order do
	local duplicate = Config.duplicates[rarity]
	assert(
		duplicate and positive(duplicate.maximum) and positive(duplicate.curve),
		"Invalid duplicate curve"
	)
end
for _, tier in Config.tiers do
	assert(
		positive(tier.price) and tier.price % 1 == 0 and tier.price <= Config.coinLimit,
		"Invalid tier price"
	)
	assert(positive(tier.paybackSeconds), "Invalid tier pacing")
end
for id, profile in Config.buckets do
	local total = 0
	for rarity, chance in profile do
		assert(Rarity.isValid(rarity) and positive(chance), "Invalid rarity bucket")
		total += chance
	end
	assert(math.abs(total - 100) < 1e-9, "Bucket probabilities must total 100: " .. id)
end
for id, config in Config.collections do
	assert(Catalog.collectionIds[id], "Unknown economic collection")
	local tier, buckets = Config.tiers[config.tier], Config.buckets[config.buckets]
	assert(tier and buckets, "Invalid collection profile")
	assert(#config.group > 0 and #config.group <= 64, "Invalid pity group")
	totals[id], prices[id] = {}, tier.price
	if config.pity then
		local profile = Config.pity[config.pity]
		assert(profile, "Unknown pity profile")
		local maxTotal = 0
		for rarity, curve in profile do
			assert(rarity == "Legendary" or rarity == "Mythical", "Unsupported pity rarity")
			assert(curve.base == buckets[rarity], "Pity base differs from bucket")
			assert(
				curve.start >= 0 and curve.start % 1 == 0 and curve.start <= Config.counterLimit,
				"Invalid pity start"
			)
			assert(
				positive(curve.increment) and curve.maximum >= curve.base and curve.maximum < 100,
				"Invalid pity curve"
			)
			assert(
				curve.start + math.ceil((curve.maximum - curve.base) / curve.increment)
					<= Config.counterLimit,
				"Pity cap unreachable"
			)
			maxTotal += curve.maximum
		end
		assert(profile.Legendary and profile.Mythical and maxTotal < 100, "Invalid high-tier total")
		local previous = groups[config.group]
		if previous then
			local other = Config.collections[previous]
			assert(
				other.tier == config.tier
					and other.pity == config.pity
					and other.buckets == config.buckets,
				"Shared pity must use identical profiles"
			)
		else
			groups[config.group] = id
		end
	end
end
for _, collection in Catalog.collections do
	assert(Config.collections[collection.id], "Missing economic collection")
end
assert(prices[Config.dailyCollection], "Invalid daily collection")
for _, entry in Config.entries do
	local figure = Catalog.byId[entry.id]
	assert(figure and not weights[entry.id], "Invalid economy reference")
	assert(positive(entry.units) and positive(entry.weight), "Invalid income units/weight")
	weights[entry.id] = entry.weight
	local total = totals[figure.collection]
	total[figure.rarity] = (total[figure.rarity] or 0) + entry.weight
end
for _, figure in Catalog.figures do
	assert(weights[figure.id], "Missing figure economy")
end
for id, config in Config.collections do
	local buckets, tier = Config.buckets[config.buckets], Config.tiers[config.tier]
	local average = 0
	for rarity, chance in buckets do
		assert(totals[id][rarity] and positive(totals[id][rarity]), "Bucket has no figures")
		for _, entry in Config.entries do
			local figure = Catalog.byId[entry.id]
			if figure.collection == id and figure.rarity == rarity then
				average += chance / 100 * entry.weight / totals[id][rarity] * entry.units
			end
		end
	end
	assert(positive(average), "Invalid expected income")
	local lowerMaximum = 0
	for _, rarity in Rarity.order do
		local minimum, maximum = math.huge, 0
		for _, entry in Config.entries do
			local figure = Catalog.byId[entry.id]
			if figure.collection == id and figure.rarity == rarity then
				assert(buckets[rarity], "Figure has no rarity bucket")
				local rate = entry.units * tier.price / (tier.paybackSeconds * average)
				assert(positive(rate) and rate <= Config.coinLimit, "Invalid figure rate")
				rates[entry.id] = rate
				minimum, maximum = math.min(minimum, rate), math.max(maximum, rate)
			end
		end
		assert(minimum > lowerMaximum, "Duplicate ceiling violates rarity order")
		if maximum > 0 then
			lowerMaximum = maximum * (1 + Config.duplicates[rarity].maximum)
		end
	end
end
local welcome = Config.welcome
for _, minimum in { welcome.box, welcome.ten } do
	local floor = table.find(Rarity.order, minimum :: Rarity.Id)
	local reachable = false
	for rarity in Config.buckets[Config.collections[welcome.collection].buckets] do
		reachable = reachable or (table.find(Rarity.order, rarity) or 0) >= (floor or math.huge)
	end
	assert(reachable, "Invalid welcome reward")
end
Economy.rates, Economy.prices, Economy.groups = rates, prices, groups
-- Derive fresh per-collection presentation values from this owner's state only. No counters,
-- curve parameters or group identities cross the replication boundary.
function Economy.pityProgress(pity: { [string]: Types.Pity }): { [string]: Types.PityProgress }
	local result: { [string]: Types.PityProgress } = {}
	for id, config in Config.collections do
		if config.pity then
			local progress = pity[config.group]
			local profile = Config.pity[config.pity]
			local function fraction(rarity: string, dry: number): number
				local curve = profile[rarity]
				local full = curve.start + math.ceil((curve.maximum - curve.base) / curve.increment)
				return if full > 0 then math.clamp(dry / full, 0, 1) else 0
			end
			result[id] = {
				Legendary = fraction(
					"Legendary",
					if progress then progress.legendaryDryRolls else 0
				),
				Mythical = fraction("Mythical", if progress then progress.mythicalDryRolls else 0),
			}
		end
	end
	return result
end
function Economy.buckets(collection: string, pity: { [string]: Types.Pity }): { [string]: number }
	local config = Config.collections[collection]
	assert(config, "Unknown collection")
	local result = table.clone(Config.buckets[config.buckets])
	if config.pity then
		local progress = pity[config.group]
		local profile = Config.pity[config.pity]
		local baseHigh, currentHigh = 0, 0
		for rarity, curve in profile do
			local dry = if not progress
				then 0
				elseif rarity == "Legendary" then progress.legendaryDryRolls
				else progress.mythicalDryRolls
			result[rarity] = math.min(
				curve.maximum,
				curve.base + math.max(0, dry - curve.start) * curve.increment
			)
			baseHigh += curve.base
			currentHigh += result[rarity]
		end
		for rarity, chance in result do
			if not profile[rarity] then
				result[rarity] = chance * (100 - currentHigh) / (100 - baseHigh)
			end
		end
	end
	return result
end
function Economy.odds(pity: { [string]: Types.Pity }): { [string]: number }
	local result: { [string]: number } = {}
	for id in Config.collections do
		local buckets = Economy.buckets(id, pity)
		for _, figure in Catalog.figures do
			if figure.collection == id then
				result[figure.id] = buckets[figure.rarity]
					* weights[figure.id]
					/ totals[id][figure.rarity]
			end
		end
	end
	return result
end
-- `minimum` drops the rarities below it and rescales the rest; their relative odds are unchanged.
function Economy.roll(
	value: number,
	collection: string,
	pity: { [string]: Types.Pity },
	minimum: Rarity.Id?
): string
	assert(value >= 0 and value < 1, "Roll must be in [0, 1)")
	local buckets = Economy.buckets(collection, pity)
	local floor = if minimum then table.find(Rarity.order, minimum) or 1 else 1
	local total = 0
	for index, rarity in Rarity.order do
		if index >= floor then
			total += buckets[rarity] or 0
		end
	end
	assert(total > 0, "No figures at the minimum rarity")
	local cursor = value * total
	local last = ""
	for index, rarity in Rarity.order do
		local chance = buckets[rarity]
		if chance and index >= floor then
			for _, figure in Catalog.figures do
				if figure.collection == collection and figure.rarity == rarity then
					last = figure.id
					cursor -= chance * weights[figure.id] / totals[collection][rarity]
					if cursor < 0 then
						return figure.id
					end
				end
			end
		end
	end
	assert(last ~= "", "Empty roll")
	return last -- Floating-point residue at the upper boundary only.
end
function Economy.advance(pity: { [string]: Types.Pity }, collection: string, figureId: string)
	local config = Config.collections[collection]
	if not config.pity then
		return
	end
	local previous = pity[config.group] or { legendaryDryRolls = 0, mythicalDryRolls = 0 }
	local rarity = Catalog.byId[figureId].rarity
	pity[config.group] = {
		legendaryDryRolls = if rarity == "Legendary"
			then 0
			else math.min(Config.counterLimit, previous.legendaryDryRolls + 1),
		mythicalDryRolls = if rarity == "Mythical"
			then 0
			else math.min(Config.counterLimit, previous.mythicalDryRolls + 1),
	}
end
function Economy.multiplier(id: string, owned: number): number
	local duplicate = Config.duplicates[Catalog.byId[id].rarity]
	local extra = math.max(0, owned - 1)
	return 1 + duplicate.maximum * extra / (extra + duplicate.curve)
end
function Economy.effectiveRates(
	owned: { [string]: number },
	nextCopy: boolean?
): { [string]: number }
	local result: { [string]: number } = {}
	for id, rate in rates do
		result[id] = rate * Economy.multiplier(id, (owned[id] or 0) + (if nextCopy then 1 else 0))
	end
	return result
end
return Economy

--!strict
-- Purchase access derives only from permanent, server-owned discovery history.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Access = {}
type Requirement = { collection: string, tier: number, target: number }
local tiers = {
	{ "moon" },
	{ "dessert", "halloween" },
	{ "chess" },
	{ "emotion" },
	{ "astral" },
	{ "biome", "weather" },
	{ "sense" },
	{ "olympian" },
	{ "birthstone" },
	{ "sin" },
	{ "orbit" },
}
local requirements: { Requirement } = {
	{ collection = "echo", tier = 0, target = 9 },
	{ collection = "star", tier = 0, target = 9 },
	{ collection = "moon", tier = 1, target = 9 },
	{ collection = "dessert", tier = 2, target = 7 },
	{ collection = "halloween", tier = 2, target = 7 },
	{ collection = "chess", tier = 3, target = 4 },
	{ collection = "emotion", tier = 4, target = 7 },
	{ collection = "astral", tier = 5, target = 9 },
	{ collection = "biome", tier = 6, target = 3 },
	{ collection = "weather", tier = 6, target = 3 },
	{ collection = "sense", tier = 7, target = 3 },
	{ collection = "olympian", tier = 8, target = 6 },
	{ collection = "birthstone", tier = 9, target = 3 },
}
local tierById: { [string]: number } = { grove = 0, tide = 0, concept = 0, echo = 0, star = 0 }
for tier, ids in tiers do
	for _, id in ids do
		assert(Catalog.collectionIds[id] and tierById[id] == nil, "Invalid progression tier")
		tierById[id] = tier
	end
end
for _, collection in Catalog.collections do
	assert(tierById[collection.id] ~= nil, "Collection needs an explicit access tier")
end
for _, requirement in requirements do
	local count, legendary = 0, false
	for _, figure in Catalog.figures do
		if figure.collection == requirement.collection and figure.rarity ~= "Mythical" then
			count += 1
			legendary = legendary or figure.rarity == "Legendary"
		end
	end
	assert(
		tierById[requirement.collection] == requirement.tier
			and count >= requirement.target
			and legendary,
		"Impossible progression qualification"
	)
end
local function evaluate(
	discovered: { [string]: boolean }
): (number, number, { Types.CollectionQualification })
	local counts: { [string]: number } = {}
	local legendary: { [string]: boolean } = {}
	for _, figure in Catalog.figures do
		if discovered[figure.id] == true and figure.rarity ~= "Mythical" then
			counts[figure.collection] = (counts[figure.collection] or 0) + 1
			if figure.rarity == "Legendary" then
				legendary[figure.collection] = true
			end
		end
	end
	local highest = -1
	local progress: { Types.CollectionQualification } = {}
	for _, requirement in requirements do
		local found = counts[requirement.collection] or 0
		local hasLegendary = legendary[requirement.collection] == true
		local qualified = found >= requirement.target and hasLegendary
		if qualified then
			highest = math.max(highest, requirement.tier)
		end
		table.insert(progress, {
			collection = requirement.collection,
			tier = requirement.tier,
			target = requirement.target,
			found = found,
			legendary = hasLegendary,
			qualified = qualified,
		})
	end
	return if highest < 0 then 0 else math.min(#tiers, highest + 2), highest, progress
end
function Access.canBuy(discovered: { [string]: boolean }, collection: string): boolean
	local tier = tierById[collection]
	return tier ~= nil and (tier == 0 or tier <= evaluate(discovered))
end
function Access.refusal(discovered: { [string]: boolean }, collection: string): string?
	return if Access.canBuy(discovered, collection)
		then nil
		else "Collection purchases locked. Qualify through discoveries, including a Legendary."
end
function Access.view(discovered: { [string]: boolean }): Types.CollectionAccessView
	local frontier, highest, progress = evaluate(discovered)
	local collections: { [string]: Types.CollectionPurchaseAccess } = {}
	for _, collection in Catalog.collections do
		local tier = tierById[collection.id]
		local routes: { Types.CollectionQualification } = {}
		if tier > 0 then
			for _, route in progress do
				if route.tier == math.max(0, tier - 2) then
					table.insert(routes, table.clone(route))
				end
			end
		end
		collections[collection.id] =
			{ tier = tier, unlocked = tier == 0 or tier <= frontier, routes = routes }
	end
	return { frontier = frontier, highestQualifiedTier = highest, collections = collections }
end
return table.freeze(Access)

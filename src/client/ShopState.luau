--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local ShopState = {}
export type OddsRow = { rarity: string, minimum: number, maximum: number, count: number }

function ShopState.figures(collectionId: string): { Types.Figure }
	local result: { Types.Figure } = {}
	for _, figure in Catalog.figures do
		if figure.collection == collectionId then
			table.insert(result, figure)
		end
	end
	return result
end

function ShopState.progress(snapshot: Types.Snapshot, collectionId: string): (number, number)
	local discovered, total = 0, 0
	for _, figure in Catalog.figures do
		if figure.collection == collectionId then
			total += 1
			if snapshot.discovered[figure.id] == true then
				discovered += 1
			end
		end
	end
	return discovered, total
end

function ShopState.rarityOdds(snapshot: Types.Snapshot, collectionId: string): { OddsRow }
	local order: { string } = {}
	local byRarity: { [string]: OddsRow } = {}
	for _, figure in Catalog.figures do
		if figure.collection == collectionId then
			local chance = math.clamp(snapshot.odds[figure.id] or 0, 0, 100)
			local row = byRarity[figure.rarity]
			if row then
				row.minimum = math.min(row.minimum, chance)
				row.maximum = math.max(row.maximum, chance)
				row.count += 1
			else
				row = { rarity = figure.rarity, minimum = chance, maximum = chance, count = 1 }
				byRarity[figure.rarity] = row
				table.insert(order, figure.rarity)
			end
		end
	end
	local result: { OddsRow } = {}
	for _, rarity in order do
		table.insert(result, byRarity[rarity])
	end
	return result
end

return ShopState

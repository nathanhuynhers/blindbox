--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)

local ShopState = {}
export type OddsRow = {
	rarity: Rarity.Id,
	minimum: number,
	maximum: number,
	count: number,
	total: number,
	baseTotal: number,
}

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

function ShopState.rarityCount(collectionId: string): number
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, figure in Catalog.figures do
		if figure.collection == collectionId and not seen[figure.rarity] then
			seen[figure.rarity], count = true, count + 1
		end
	end
	return count
end

function ShopState.rarityOdds(snapshot: Types.Snapshot, collectionId: string): { OddsRow }
	local byRarity: { [string]: OddsRow } = {}
	for _, figure in Catalog.figures do
		if figure.collection == collectionId then
			local chance = math.clamp(snapshot.odds[figure.id] or 0, 0, 100)
			local row = byRarity[figure.rarity]
			if row then
				row.minimum = math.min(row.minimum, chance)
				row.maximum = math.max(row.maximum, chance)
				row.count += 1
				row.total += chance
				row.baseTotal += snapshot.baseOdds[figure.id] or 0
			else
				row = {
					rarity = figure.rarity,
					minimum = chance,
					maximum = chance,
					count = 1,
					total = chance,
					baseTotal = snapshot.baseOdds[figure.id] or 0,
				}
				byRarity[figure.rarity] = row
			end
		end
	end
	local result: { OddsRow } = {}
	for _, rarity in Rarity.order do
		local row = byRarity[rarity]
		if row then
			table.insert(result, row)
		end
	end
	return result
end

return ShopState

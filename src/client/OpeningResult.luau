--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local OpeningResult = {}
export type Ownership = { owned: { [string]: number }, discovered: { [string]: boolean } }
export type Result = {
	requestId: string,
	figureId: string,
	isNew: boolean,
	quantity: number,
	direct: boolean,
}

-- Called at the acknowledgement boundary, before presentation. Snapshots remain authoritative.
function OpeningResult.fromReply(
	request: Types.Intent,
	before: Ownership,
	after: Ownership,
	reply: Types.Reply
): Result?
	local id = reply.figure
	if not reply.ok or reply.id ~= request.id or not id or not Catalog.byId[id] then
		return nil
	end
	if request.action ~= "Buy" and request.action ~= "Daily" then
		return nil
	end
	local quantity = after.owned[id] or 0
	if quantity < 1 or not after.discovered[id] then
		return nil
	end
	return table.freeze({
		requestId = reply.id,
		figureId = id,
		isNew = before.discovered[id] ~= true,
		quantity = quantity,
		direct = false,
	})
end

-- A BuyTen reply as ten reveals, rarest first; only a figure's first copy is marked new.
function OpeningResult.fromBatch(
	request: Types.Intent,
	before: Ownership,
	after: Ownership,
	reply: Types.Reply
): { Result }
	local ids = reply.figures
	if not reply.ok or reply.id ~= request.id or request.action ~= "BuyTen" or not ids then
		return {}
	end
	local order: { number } = {}
	for index, id in ids do
		if not Catalog.byId[id] or (after.owned[id] or 0) < 1 or not after.discovered[id] then
			return {}
		end
		order[index] = index
	end
	local rank = function(index: number): number
		return table.find(Rarity.order, Catalog.byId[ids[index]].rarity) or 0
	end
	table.sort(order, function(a, b)
		local rankA, rankB = rank(a), rank(b)
		return if rankA ~= rankB then rankA > rankB else a < b
	end)
	local results: { Result } = {}
	local shown: { [string]: boolean } = {}
	for position, index in order do
		local id = ids[index]
		table.insert(
			results,
			table.freeze({
				requestId = reply.id .. ":" .. position,
				figureId = id,
				isNew = before.discovered[id] ~= true and not shown[id],
				quantity = after.owned[id] or 0,
				direct = false,
			})
		)
		shown[id] = true
	end
	return results
end

return OpeningResult

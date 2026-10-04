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
	-- Box-only opening that ends after teasing this rarity (the first step of an Open 10).
	tease: Rarity.Id?,
	-- Place in an Open 10 sequence; steps hand off to each other under the curtain.
	sequence: Sequence?,
}
export type Sequence = "first" | "middle" | "last"

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
	-- Login replies carry a figure only on single-box reward days.
	if request.action ~= "Buy" and request.action ~= "Daily" and request.action ~= "Login" then
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

-- A BuyTen (or multi-box Login reward) reply as one box opening that teases the best rarity, then ten box-less reveals
-- in roll order. Only a figure's first copy in the batch is marked new.
function OpeningResult.fromBatch(
	request: Types.Intent,
	before: Ownership,
	after: Ownership,
	reply: Types.Reply
): { Result }
	local ids = reply.figures
	if
		not reply.ok
		or reply.id ~= request.id
		or (request.action ~= "BuyTen" and request.action ~= "Login")
		or not ids
	then
		return {}
	end
	local best = 0
	for _, id in ids do
		local figure = Catalog.byId[id]
		if not figure or (after.owned[id] or 0) < 1 or not after.discovered[id] then
			return {}
		end
		best = math.max(best, table.find(Rarity.order, figure.rarity) or 0)
	end
	if #ids == 0 or best == 0 then
		return {}
	end
	local box: Result = {
		requestId = reply.id .. ":box",
		figureId = ids[1],
		isNew = false,
		quantity = after.owned[ids[1]] or 0,
		direct = false,
		tease = Rarity.order[best],
		sequence = "first",
	}
	local results: { Result } = { table.freeze(box) }
	local shown: { [string]: boolean } = {}
	for index, id in ids do
		local step: Result = {
			requestId = reply.id .. ":" .. index,
			figureId = id,
			isNew = before.discovered[id] ~= true and not shown[id],
			quantity = after.owned[id] or 0,
			direct = true,
			sequence = if index == #ids then "last" else "middle",
		}
		table.insert(results, table.freeze(step))
		shown[id] = true
	end
	return results
end

return OpeningResult

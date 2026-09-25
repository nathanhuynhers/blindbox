--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
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
	if request.action ~= "Buy" and request.action ~= "Daily" and request.action ~= "Redeem" then
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
		direct = request.action == "Redeem",
	})
end

return OpeningResult

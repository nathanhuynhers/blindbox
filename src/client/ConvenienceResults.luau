--!strict
-- Single result queue uses the existing confirmed-result adapter, never local rolling.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Wire = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local Result = require(script.Parent.OpeningResult)
local Results = {}
export type Dependencies = {
	applySnapshot: (Types.Snapshot) -> (),
	present: (Result.Result, Types.Snapshot, Types.Snapshot) -> boolean,
	error: (string, string) -> (), -- request identity, message; Stop/ack on presentation failure.
}
export type Controller = {
	receive: (Wire.OpeningDelivery) -> (),
	step: () -> (),
	busy: () -> boolean,
	destroy: () -> (),
}
function Results.create(deps: Dependencies): Controller
	local active = true
	local pending: Wire.OpeningDelivery? = nil
	local seen: { [string]: boolean } = {}
	local order: { string } = {}
	local function remember(id: string)
		seen[id] = true
		table.insert(order, id)
		if #order > 64 then
			local old = table.remove(order, 1)
			if old then
				seen[old] = nil
			end
		end
	end
	return {
		receive = function(delivery)
			if
				not active
				or seen[delivery.reply.id]
				or delivery.request.action ~= "Buy"
				or delivery.reply.id ~= delivery.request.id
			then
				return
			end
			if pending and pending.reply.id ~= delivery.reply.id then
				return
			end
			deps.applySnapshot(delivery.after)
			if not delivery.reply.ok then
				remember(delivery.reply.id)
				deps.error(delivery.reply.id, delivery.reply.message)
				return
			end
			pending = delivery
		end,
		step = function()
			local delivery = pending
			if not active or not delivery then
				return
			end
			local result =
				Result.fromReply(delivery.request, delivery.before, delivery.after, delivery.reply)
			if not result then
				remember(delivery.reply.id)
				pending = nil
				deps.error(
					delivery.reply.id,
					"Your figure is saved. The opening result could not be displayed."
				)
			elseif deps.present(result, delivery.before, delivery.after) then
				remember(delivery.reply.id)
				pending = nil
			end
		end,
		busy = function()
			return pending ~= nil
		end,
		destroy = function()
			active = false
			pending = nil
			table.clear(seen)
			table.clear(order)
		end,
	}
end
return Results

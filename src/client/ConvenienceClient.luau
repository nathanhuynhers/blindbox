--!strict
local Wire = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local Client = {}
export type Dependencies = { id: () -> string, send: (Wire.Request) -> () }
export type Controller = {
	receive: (Wire.Snapshot) -> boolean,
	view: () -> Wire.Snapshot?,
	start: (string, number, number) -> (),
	stop: () -> (),
	collection: (string) -> (),
	presented: (string) -> (),
	collect: (boolean) -> (),
	movement: (boolean) -> (),
	beforeHandoff: () -> (),
	ready: () -> (),
	destroy: () -> (),
}
function Client.create(deps: Dependencies): Controller
	local active, handoff = true, false
	local serial = 0
	local snapshot: Wire.Snapshot? = nil
	local function send(
		action: Wire.Action,
		collection: string?,
		limit: number?,
		reserve: number?,
		requestId: string?,
		enabled: boolean?
	)
		if not active then
			return
		end
		serial += 1
		deps.send({
			id = deps.id(),
			serial = serial,
			action = action,
			collection = collection,
			limit = limit,
			reserve = reserve,
			requestId = requestId,
			enabled = enabled,
		})
	end
	local function stop()
		send("Stop", nil, nil, nil, nil, nil)
	end
	return {
		receive = function(value)
			if not active or (snapshot and value.sequence <= snapshot.sequence) then
				return false
			end
			snapshot = value
			return true
		end,
		view = function()
			return snapshot
		end,
		start = function(collection, limit, reserve)
			if
				handoff
				or not snapshot
				or not snapshot.openAllowed
				or snapshot.open.running
				or snapshot.open.phase == "Pending"
				or snapshot.open.phase == "Presenting"
			then
				return
			end
			send("Start", collection, limit, reserve, nil, nil)
		end,
		stop = stop,
		collection = function(value)
			send("Collection", value, nil, nil, nil, nil)
		end,
		presented = function(id)
			send("Presented", nil, nil, nil, id, nil)
		end,
		collect = function(enabled)
			if not handoff then
				send("AutoCollect", nil, nil, nil, nil, enabled)
			end
		end,
		movement = function(enabled)
			if not handoff then
				send("Movement", nil, nil, nil, nil, enabled)
			end
		end,
		beforeHandoff = function()
			stop()
			handoff = true
		end,
		ready = function()
			handoff = false
			send("State", nil, nil, nil, nil, nil)
		end,
		destroy = function()
			if active then
				stop()
			end
			active = false
			snapshot = nil
		end,
	}
end
return Client

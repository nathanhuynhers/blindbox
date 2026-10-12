--!strict
local E = require("./OpeningEngine")
local Movement = require("./PlayerMovement")
local Service = require("./ConvenienceService")
local Protocol = require("./ConvenienceProtocol")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local now, starts, stops, steps, pauses, resumes, removals = 0, 0, 0, 0, 0, 0, 0
local prefs = { autoCollect = false, movement = false }
local owned, fresh, ready, busy = true, true, true, false
E.player.Character.ChildAdded = E.signal()
local binding = Movement.bind(E.player)
local owner = {
	open = {
		start = function()
			starts += 1
			return true
		end,
		stop = function()
			stops += 1
		end,
		step = function()
			steps += 1
		end,
		collection = function()
			stops += 1
		end,
		presented = function(id)
			return id == "own-result"
		end,
		view = function()
			return {
				running = false,
				phase = "Idle",
				collection = "grove",
				limit = 10,
				reserve = 0,
				completed = 0,
				spent = 0,
				reason = "Idle",
			}
		end,
		busy = function()
			return busy
		end,
		destroy = function()
			removals += 1
		end,
	},
	collect = {
		step = function()
			steps += 1
			return 0
		end,
		reason = function()
			return "Off"
		end,
		pause = function()
			pauses += 1
		end,
		resume = function()
			resumes += 1
		end,
		destroy = function()
			removals += 1
		end,
	},
	binding = binding,
	preferences = function()
		return prefs
	end,
	setPreference = function(key, value)
		if key == "movement" then
			prefs.movement = value
		else
			prefs.autoCollect = value
		end
		return true
	end,
	ready = function()
		return ready
	end,
	ownership = function()
		return owned, fresh
	end,
	openAllowed = function()
		return owned and fresh and ready
	end,
}
local notices = {}
local activeCollection = "grove"
owner.collection = function(value)
	activeCollection = value
end
local service = Service.create({
	now = function()
		return now
	end,
	notify = function(userId, snapshot)
		table.insert(notices, { userId, snapshot })
	end,
})
check(service.add(123, owner) and not service.add(123, owner), "one owner controller")
local request =
	{ id = "start", serial = 1, action = "Start", collection = "grove", limit = 10, reserve = 0 }
check(service.receive(123, request) and starts == 1, "owner starts")
check(not service.receive(456, request) and starts == 1, "unregistered cross-owner rejected")
check(not service.receive(123, {
	id = "spoof",
	serial = 2,
	action = "Start",
	collection = "grove",
	limit = 1,
	reserve = 0,
	userId = 456,
}), "payload owner field rejected")
check(service.receive(123, request) and starts == 1, "Start replay cannot spawn another workflow")
check(
	service.receive(123, { id = "stop", serial = 5, action = "Stop" }) and stops == 1,
	"Stop bypasses exhausted bucket"
)
check(not service.receive(123, {
	id = "late-start",
	serial = 4,
	action = "Start",
	collection = "grove",
	limit = 1,
	reserve = 0,
}) and starts == 1, "delayed earlier Start cannot restart after Stop")
now += 10
check(
	service.receive(123, { id = "collect-on", serial = 6, action = "AutoCollect", enabled = true })
		and prefs.autoCollect,
	"saved toggle callback"
)
fresh = false
check(
	not service.receive(
			123,
			{ id = "movement-on", serial = 7, action = "Movement", enabled = true }
		) and not prefs.movement,
	"stale entitlement rejects new benefit"
)
check(
	service.receive(
		123,
		{ id = "collect-off", serial = 8, action = "AutoCollect", enabled = false }
	) and not prefs.autoCollect,
	"opt-out available on uncertainty"
)
fresh = true
now += 10
check(
	service.receive(123, { id = "movement-new", serial = 9, action = "Movement", enabled = true })
		and binding.speed == 48,
	"speed through existing boundary"
)
ready = false
service.step()
check(binding.speed == 36, "readiness loss selects baseline")
ready = true
service.step()
check(binding.speed == 48 and steps == 4, "single shared scheduler refresh")
busy = true
check(not service.beforeHandoff(123) and pauses == 0, "pending workflow defers storage freeze")
busy = false
check(service.beforeHandoff(123), "stopped clean workflow permits handoff")
ready = false
service.recover(123)
check(resumes == 0, "uncertain recovery stays paused")
ready = true
service.recover(123)
check(resumes == 1 and starts == 1, "recovery never starts spending")
check(
	not service.receive(
		123,
		{ id = "wrong-result", serial = 10, action = "Presented", requestId = "visitor-result" }
	),
	"foreign presentation identity rejected"
)
check(
	service.receive(123, { id = "close", serial = 11, action = "Collection", collection = "" })
		and activeCollection == "",
	"flow close bypasses exhausted bucket and updates server selection"
)
for _, raw in
	{
		false,
		{},
		{ id = "x", serial = 0, action = "Stop" },
		{
			id = "x",
			serial = 1,
			action = "Start",
			collection = "grove",
			limit = 0 / 0,
			reserve = 0,
		},
		{ id = "x", serial = 1, action = "Movement", enabled = 1 },
		{ id = "x", serial = 1, action = "Start", collection = "grove", limit = 101, reserve = 0 },
		{
			id = "x",
			serial = 1,
			action = "Start",
			collection = "grove",
			limit = 1,
			reserve = math.huge,
		},
	}
do
	check(Protocol.parse(raw) == nil, "malformed control rejected")
end
service.remove(123)
service.remove(123)
check(removals == 2 and not service.receive(123, request), "both owner controllers cleaned once")
check(service.add(123, owner), "reconnect owns one new entry")
service.destroy()
service.destroy()
check(removals == 4 and not service.add(123, owner), "shutdown closes every entry")
Movement.unbind(binding)
print(`PASS: {checks} convenience service protocol/lifecycle checks (injected owners)`)

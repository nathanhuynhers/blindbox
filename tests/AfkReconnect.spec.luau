--!strict
local Reconnect = require("./AfkReconnect")
local Idle = require("./AfkIdle")
local Config = require("./AfkConfig")
local checks = 0
local function check(value, text)
	checks += 1
	assert(value, text)
end
local function fixture()
	local f = {
		now = 0,
		queue = {},
		notices = {},
		logs = {},
		prepares = 0,
		recovers = 0,
		teleports = 0,
		serial = 0,
		saved = true,
		available = true,
	}
	local player = {}
	local controller
	controller = Reconnect.create({
		now = function()
			return f.now
		end,
		token = function()
			f.serial += 1
			return tostring(f.serial)
		end,
		spawn = function(work)
			table.insert(f.queue, work)
		end,
		available = function()
			return f.available
		end,
		prepare = function()
			f.prepares += 1
			if f.onPrepare then
				f.onPrepare()
			end
			return f.saved
		end,
		recover = function()
			f.recovers += 1
			return true
		end,
		teleport = function(_, token, call)
			f.teleports += 1
			f.token, f.call = token, call
			if f.onTeleport then
				f.onTeleport()
			end
			if f.error then
				error("unavailable")
			end
		end,
		notify = function(_, phase, token)
			table.insert(f.notices, { phase = phase, token = token })
		end,
		log = function(_, text)
			table.insert(f.logs, text)
		end,
	})
	f.c, f.player = controller, player
	controller.add(player)
	function f.run()
		while #f.queue > 0 do
			table.remove(f.queue, 1)()
		end
	end
	function f.idle(now, duration)
		f.now = now
		controller.receive(player, { action = "Idle", idle = duration or math.min(now, 1200) })
	end
	function f.confirm()
		local notice = f.notices[#f.notices]
		assert(notice.phase == "Check")
		controller.receive(player, { action = "Confirm", token = notice.token, idle = 1110 })
	end
	function f.eligible()
		f.idle(120, 120)
		f.idle(1110, 1110)
	end
	function f.depart()
		f.eligible()
		f.confirm()
		f.run()
		f.confirm()
		f.run()
	end
	return f
end
check(Idle.threshold() == 1110 and table.isfrozen(Config), "safe configurable production threshold")
local clock = Idle.new(0)
Idle.report(clock, 120, 120)
check(Idle.duration(clock, 130) == 130, "reported duration includes the first two minutes")
check(Idle.duration(clock, 166) == nil, "stale engine events fail closed")
Idle.active(clock, 140)
check(Idle.duration(clock, 141) == nil, "activity cancels the local clock")
Idle.report(clock, 150, 150)
check(Idle.duration(clock, 150) == 10, "late idle event cannot backdate before renewed input")
Idle.report(clock, 0 / 0, 160)
check(clock.eventAt == 150, "invalid idle event rejected")

local f = fixture()
for at = 120, 1110, 15 do
	f.c.activity(f.player)
	f.idle(at, 1200)
end
check(#f.notices == 0 and f.teleports == 0, "active clients cannot use forged durations to hop")
f = fixture()
f.idle(0, 1200)
check(#f.notices == 0, "forged first duration cannot teleport on join")
for _, raw in
	{
		false,
		"teleport",
		{ action = "Idle", idle = 0 / 0 },
		{ action = "Idle", idle = math.huge },
		{ action = "Idle", idle = -1 },
		{ action = "Idle", idle = 1201 },
		{ action = "Idle", idle = 1110, placeId = 1 },
		{ action = "Confirm", idle = 1110, token = string.rep("x", 65) },
	}
do
	f.c.receive(f.player, raw)
end
f.idle(1109)
check(#f.notices == 0, "malformed and arbitrary destination requests ignored; threshold enforced")
f.idle(1125)
check(#f.notices == 1, "eligible only after server time and client signal")
f.c.receive(f.player, { action = "Confirm", token = "forged", idle = 1110 })
check(#f.queue == 0, "server confirmation token required")
local token = f.notices[#f.notices].token
f.confirm()
for _ = 1, 100 do
	f.c.receive(f.player, { action = "Confirm", token = token, idle = 1110 })
end
f.run()
check(f.prepares == 1 and f.teleports == 0, "duplicate acknowledgements prepare once")
f.confirm()
f.run()
check(f.teleports == 1, "fresh post-save confirmation initiates one teleport")
for _ = 1, 100 do
	f.idle(f.now)
	f.c.receive(f.player, { action = "Confirm", token = token, idle = 1110 })
end
check(f.prepares == 1 and f.teleports == 1, "duplicate requests during teleport do nothing")

f = fixture()
f.eligible()
f.c.activity(f.player)
f.run()
check(f.prepares == 0 and f.teleports == 0, "activity cancels the offer")
f = fixture()
f.eligible()
f.confirm()
f.onPrepare = function()
	f.c.activity(f.player)
end
f.run()
check(f.recovers == 1 and f.teleports == 0, "activity while saving reclaims safely")
f = fixture()
f.eligible()
f.confirm()
f.run()
f.confirm()
f.c.activity(f.player)
f.run()
check(f.recovers == 1 and f.teleports == 0, "activity before queued TeleportAsync cancels it")
f = fixture()
f.saved = false
f.eligible()
f.confirm()
f.run()
check(f.teleports == 0 and f.recovers == 1 and #f.logs == 1, "save failure never teleports")
f.idle(1140)
check(f.prepares == 1, "failed cycle does not repeat saving while still AFK")
f = fixture()
f.eligible()
f.c.receive(f.player, { action = "Busy", token = f.notices[#f.notices].token })
check(f.prepares == 0, "pending transactions and opening animation decline the handoff")
f = fixture()
f.available = false
f.eligible()
check(#f.notices == 0, "preview, private and unready sessions are ineligible")
f = fixture()
f.eligible()
f.now += 6
f.c.step()
f.run()
check(
	f.prepares == 0 and f.notices[#f.notices].phase == "Failed",
	"lost confirmation has a bounded timeout"
)

f = fixture()
f.error = true
f.depart()
check(f.teleports == 1 and f.recovers == 0, "TeleportAsync error schedules retry")
for attempt = 1, 2 do
	f.now += Config.retryDelays[attempt]
	f.c.step()
	f.confirm()
	f.run()
end
check(
	f.teleports == 3 and f.prepares == 1 and f.recovers == 1,
	"two retries, one checkpoint, bounded recovery"
)
f.now += 15
f.idle(f.now)
f.c.step()
f.run()
check(
	f.teleports == 3 and f.prepares == 1,
	"no infinite retry or new attempt in the same idle cycle"
)
f = fixture()
f.depart()
f.c.failed(f.player, "other-feature", 1)
check(f.recovers == 0, "other teleport failures ignored")
f.c.failed(f.player, f.token, f.call)
f.c.failed(f.player, f.token, f.call)
check(#f.logs == 1, "duplicate TeleportInitFailed logs and retries once")
f.now += 3
f.c.step()
f.confirm()
f.run()
f.c.failed(f.player, "2", 1)
check(f.teleports == 2 and #f.logs == 1, "old failure event cannot invalidate the next retry")
f = fixture()
f.depart()
f.now += 20
f.c.step()
f.run()
check(
	f.teleports == 1 and f.recovers == 1,
	"delayed initialization times out without launching a duplicate"
)
f = fixture()
f.onTeleport = function()
	f.now += 30
	f.c.step()
	check(#f.queue == 0, "in-flight API timeout cannot overlap reclaim or retry")
end
f.depart()
check(f.teleports == 1 and f.recovers == 1, "unresolved API recovers after its return")
f = fixture()
f.onTeleport = function()
	f.c.failed(f.player, f.token, f.call)
	f.now += 25
	f.c.step()
	check(#f.queue == 0, "failure event while API is unresolved cannot launch overlapping retry")
end
f.depart()
check(f.teleports == 1 and f.recovers == 1, "in-flight failure event still has a bounded timeout")
f = fixture()
f.eligible()
f.confirm()
f.onPrepare = function()
	f.c.remove(f.player)
end
f.run()
check(
	f.teleports == 0 and f.recovers == 0,
	"leave during preparation cannot start teleport or reclaim"
)
f = fixture()
f.eligible()
f.confirm()
f.run()
f.c.remove(f.player)
f.now += 100
f.c.step()
f.run()
check(f.teleports == 0 and f.recovers == 0, "removed player leaves no retry work")
f = fixture()
f.eligible()
f.now += 46
f.c.step()
check(f.prepares == 0, "stale idle signal cannot teleport")
f = fixture()
for cycle = 1, 25 do
	f.c.activity(f.player)
	local start = f.now
	f.idle(start + 120, 120)
	f.idle(start + 1110, 1110)
	f.confirm()
	f.run()
	f.confirm()
	f.run()
	f.c.activity(f.player)
	f.run()
	check(
		#f.queue == 0 and f.recovers == cycle and f.teleports == cycle,
		"bounded state across repeated AFK cycles"
	)
end
f.c.destroy()
f.now += 2000
f.idle(f.now)
f.c.step()
f.run()
check(f.teleports == 25 and #f.queue == 0, "service teardown clears every tracked player")
print(
	string.format("PASS: %d AFK clock, authority, cancellation, retry and lifecycle checks", checks)
)

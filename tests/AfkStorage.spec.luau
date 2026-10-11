--!strict
local E = require("./AfkEngine")
local Storage = require("./Storage")
local Persistence = require("./Persistence")
local Profile = require("./Profile")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Economy = require("./Economy")
local checks = 0
local function check(value, text)
	checks += 1
	assert(value, text)
end
local function open(id)
	local session = Storage.open(id)
	assert(session and session.handle)
	return session
end
local function populated(session)
	local s = session.state
	s.owned["grove.pebble"], s.discovered["grove.pebble"] = 2, true
	s.display.slots[1] = "grove.pebble"
	s.earnings["grove.pebble"] = 12.75
	s.shelves.units[1].placements["row:1/slot:1"] = "grove.pebble"
	s.pityByGroup.echo = { legendaryDryRolls = 9, mythicalDryRolls = 12 }
	s.lastDailyDay = 9
	s.lastLoginDay, s.loginStreak = 9, 2
	s.goalDay, s.goalProgress, s.goalClaimed = 9, 1, false
	s.sfxVolume, s.musicVolume = 40, 60
	s.offlinePending = 77
	s.boxesOpened = 12
	return s
end
local function equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not equal(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end
local function advance(session, seconds)
	local target = E.now + seconds
	while E.now < target do
		E.now = math.min(target, E.now + 30)
		Storage.step(session, E.now)
		if session.ready and not session.transferring then
			Rules.settle(session.state, E.now)
		end
	end
end

local s = open(101)
local state = populated(s)
local transaction = Transactions.new(E.now)
transaction.state = state
local request = { action = "Buy", id = "purchase", revision = state.revision, choice = "grove" }
local reply = Transactions.process(transaction, request, E.now, true, 0, 10)
check(reply and reply.ok, "pending purchase commits atomically before freeze")
local boughtCoins = state.coins
local rate = Rules.rate(state)
local before = state.earnings["grove.pebble"]
advance(s, 1110)
local writes = E.writes
check(Storage.prepareTeleport(s), "preparation settles, saves and releases")
check(
	not s.ready and s.transferring and s.released and not s.busy,
	"all gameplay paused during handoff"
)
check(
	math.abs(state.earnings["grove.pebble"] - before - rate * 1110) < 0.000001,
	"legitimate active banks and fractions preserved"
)
check(E.writes == writes + 1, "one final checkpoint per reconnect")
local checkpoint = Profile.encode(state)
for _ = 1, 10 do
	E.now += 1
	Storage.step(s, E.now)
end
check(
	E.writes == writes + 1 and equal(Profile.encode(state), checkpoint),
	"no autosave or earnings changes after release"
)
local destination = open(101)
check(
	destination.state.coins == boughtCoins + 77,
	"previous unclaimed offline reward auto-claims once"
)
check(
	destination.state.owned["grove.pebble"] == state.owned["grove.pebble"],
	"purchased inventory preserved"
)
local expected = Profile.decode(checkpoint, E.now)
assert(expected)
Rules.offline(expected, E.os.time())
check(
	equal(Profile.encode(destination.state), Profile.encode(expected)),
	"every persistent field survives through the normal destination loader"
)
check(destination.state.offlinePending == 0, "short AFK hop does not duplicate active earnings")
local savedGeneration = destination.handle.generation
check(Storage.close(s), "departed released source does not write again")
check(
	destination.handle.generation == savedGeneration
		and E.database["Player_101"].token == destination.handle.token,
	"source cannot overwrite destination lease"
)
local repeated = Transactions.process(transaction, request, E.now, true, 0, 10)
check(
	repeated and not repeated.ok and state.coins == boughtCoins,
	"expired transaction replay cannot charge/grant twice"
)

E.now = 2000
s = open(102)
state = populated(s)
advance(s, 100)
check(Storage.prepareTeleport(s), "second player handoff")
local boundary = state.lastSeen
local frozenBank = state.earnings["grove.pebble"]
E.now += Economy.offlineMinSeconds + 30
destination = open(102)
check(
	destination.state.offlinePending
		== math.floor((E.os.time() - boundary) * Rules.rate(state) * Economy.offlineRate),
	"only post-checkpoint transfer downtime earns capped offline income"
)
check(
	destination.state.earnings["grove.pebble"] == frozenBank,
	"offline award never re-awards settled active banks"
)
check(
	not Storage.recoverTeleport(s) and not s.ready and s.transferring,
	"source reclaim cannot steal the destination session"
)
check(Storage.close(s), "failed reclaim still cannot write stale source data")

s = open(103)
state = populated(s)
advance(s, 100)
check(Storage.prepareTeleport(s), "failed teleport has a saved checkpoint")
local frozen = state.earnings["grove.pebble"]
E.now += 20
check(Storage.recoverTeleport(s), "teleport failure reclaims same generation")
check(
	s.ready and not s.transferring and not s.released and not s.pendingRelease,
	"gameplay can safely resume after confirmed ownership"
)
check(
	state.earnings["grove.pebble"] == frozen + Rules.rate(state) * 20,
	"failed teleport keeps legitimate source earnings"
)
check(state.offlinePending == 77, "source recovery never grants offline rewards")
Storage.step(s, E.now)
check(s.ready and not s.busy, "normal autosaves resume")

s = open(104)
state = populated(s)
E.before = 3
check(not Storage.prepareTeleport(s) and not s.ready, "all save retries failing blocks teleport")
check(
	Storage.recoverTeleport(s) and s.ready,
	"failed uncommitted handoff can reclaim retained lease"
)
check(
	state.owned["grove.pebble"] == 2 and state.coins == Economy.startingCoins,
	"in-memory progress remains intact on save failure"
)

s = open(105)
state = populated(s)
E.after = 3
check(not Storage.prepareTeleport(s), "uncertain release response is treated as failure")
check(E.database["Player_105"].token == "", "fault committed the immutable checkpoint")
local generation = E.database["Player_105"].generation
local durable = Profile.encode(Profile.decode(E.database["Player_105"].data, E.now))
check(
	Storage.recoverTeleport(s) and s.handle.generation == generation,
	"recovery reconciles lost release without duplicate generations"
)
check(equal(durable, E.database["Player_105"].data), "recovery never rewrites stored progress")

s = open(106)
E.now += 100
check(not Storage.prepareTeleport(s), "expired local safety lease blocks preparation")
check(not s.transferring, "invalid session never starts a handoff")
s = open(107)
state = populated(s)
s.busy = true
E.onWait = function()
	s.busy = false
end
check(Storage.prepareTeleport(s), "in-flight autosave drains before checkpoint")
E.onWait = nil
s = open(108)
E.onUpdate = function()
	s.closed = true
end
check(Storage.prepareTeleport(s), "release may finish after removal")
E.onUpdate = nil
check(not Storage.recoverTeleport(s) and not s.ready, "removed session cannot resume gameplay")
s = open(109)
check(Storage.prepareTeleport(s), "recovery failure fixture saves first")
E.before = 3
check(
	not Storage.recoverTeleport(s) and not s.ready and s.transferring,
	"failed reacquire retains freeze instead of risking data"
)
check(Storage.close(s), "already released failure can leave safely")

-- Direct lost-reclaim response and ownership transition test uses the real transforms.
local handle = Persistence.load(function(key, transform)
	return E.store:UpdateAsync(key, transform)
end, "resume", "owner", E.os.time(), E.now)
assert(handle)
local fresh = Rules.new(E.now)
check(
	Persistence.save(function(key, transform)
		return E.store:UpdateAsync(key, transform)
	end, handle, Profile.encode(fresh), E.os.time(), true),
	"release transform fixture"
)
E.after = 1
local update = function(key, transform)
	return E.store:UpdateAsync(key, transform)
end
check(not Persistence.resume(update, handle, E.os.time()), "lost reclaim response fails closed")
check(Persistence.resume(update, handle, E.os.time()), "same reclaim can be retried idempotently")
print(string.format("PASS: %d AFK persistence, transaction and earnings checks", checks))

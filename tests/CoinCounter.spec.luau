--!strict
local Counter = require("./CoinCounter")
local State = require("./UIState")
local E = require("./CoinEngine")
local Burst = require("./CoinBurst")
local Earnings = require("./DisplayEarnings")
local checks = 0
local function check(ok: boolean, message: string)
	checks += 1
	assert(ok, message)
end
local value = 0
local counter = Counter.create(function(n)
	value = n
end)
counter.snapshot(100)
local first = counter.snapshot(201, 101, 0, 5) :: number
check(value == 100, "collection does not jump before impacts")
for i = 1, 5 do
	local before = value
	counter.impact(first, i)
	check(value >= before and value == 100 + math.floor(101 * i / 5), "monotonic impact shares")
end
counter.finish(first)
check(value == 201, "exact final wallet including indivisible remainder")
first = counter.snapshot(301, 100, 0, 4) :: number
counter.impact(first, 1)
local second = counter.snapshot(361, 60, 0, 3) :: number
check(value == 226, "second collection preserves first progress")
counter.impact(second, 1)
counter.finish(first)
check(value == 321, "older completion leaves newest flight pending")
counter.finish(second)
check(value == 361, "rapid collections reach newest wallet")
first = counter.snapshot(461, 100, 0, 4) :: number
counter.snapshot(400) -- Spending/correction during collection.
counter.impact(first, 4)
counter.finish(first)
check(value == 400, "old callbacks cannot undo spending")
first = counter.snapshot(500, 100, 0, 4) :: number
counter.snapshot(1000) -- Non-collection reward.
counter.finish(first)
check(value == 1000, "new reward cannot be overwritten by old completion")
counter.snapshot(900)
check(value == 900, "spending after animation remains exact")
counter.snapshot(9999999)
first = counter.snapshot(10001000, 1001, 0, 3) :: number
check(State.number(value) == "9,999,999", "exact formatting below HUD threshold")
counter.impact(first, 1)
check(State.compact(value) == "10M", "abbreviation crossing threshold")
counter.finish(first)
check(State.number(value) == "10,001,000", "exact tap value remains available")
counter.snapshot(999999999000)
first = counter.snapshot(1000000000000, 1000, 0, 4) :: number
counter.impact(first, 1)
check(State.compact(value) == "999.9B", "large progress rounds down")
counter.finish(first)
check(State.compact(value) == "1T", "trillion final formatting")

local sequence = 0
local function snapshot(coins: number)
	sequence += 1
	return {
		coins = coins,
		sequence = sequence,
		ready = true,
		unlocked = 3,
		slots = { "grove.pebble", "grove.moss", "" },
		earnings = { ["grove.pebble"] = 101, ["grove.moss"] = 60 },
	}
end
local enabled = true
local hits = 0
local earnings = Earnings.create(function()
	return enabled
end, function()
	hits += 1
end, function(n)
	value = n
end)
local state = snapshot(100)
earnings.receive(nil, state, nil)
local idle = E.connections
E.flush()

check(next(require("./UIEngine").timers) == nil, "no idle scheduled work")
E.clicks[1]:Fire()
E.step(1.2)
E.land(2)
check(value == 100 and hits == 2, "predicted impacts never mint balance")
local after = snapshot(201)
earnings.receive(state, after, { id = "collect:1", ok = true, figure = "grove.pebble" })
check(
	value == 100 + math.floor(101 * 2 / Burst.count(101)),
	"prediction progress attaches on confirmation"
)
local beforeHit = value
E.land(2)
check(value > beforeHit and value < 201, "actual impact radius advances visible counter")
E.land(100)
check(value == 201 and E.connections == idle, "last impact reconciles and disconnects heartbeat")
E.flush()

state = after
after = snapshot(state.coins + 101)
earnings.receive(state, after, { id = "collect:rapid1", ok = true, figure = "grove.pebble" })
local newest = snapshot(after.coins + 60)
earnings.receive(after, newest, { id = "collect:rapid2", ok = true, figure = "grove.moss" })
check(value == state.coins, "rapid actual bursts preserve prior visible balance")
E.step(1.2)
E.land(2)
local progress = value
earnings.receive(newest, newest, nil)
check(value == progress, "unchanged wallet snapshot preserves impacts in flight")
E.land(100)
check(
	value == newest.coins and E.connections == idle,
	"rapid actual bursts reconcile newest snapshot"
)
after = newest
E.flush()

-- Repeat with unpredicted confirmations and actual interruption paths.
local function collect()
	state = after
	after = snapshot(state.coins + 101)
	earnings.receive(state, after, { id = "collect:new", ok = true, figure = "grove.pebble" })
	check(value == state.coins, "unpredicted collection waits for landing")
end
collect()
E.player.CharacterRemoving:Fire()
check(
	value == after.coins and E.connections == idle - 1,
	"reset reconciles immediately and releases character signal"
)
E.player.CharacterAdded:Fire()
collect()
E.humanoid.Died:Fire()
check(value == after.coins and E.connections == idle, "death reconciles immediately")
collect()
enabled = false
earnings.interrupt()
check(value == after.coins and E.connections == idle, "skip reconciles immediately")
enabled = true
state = after
after = snapshot(state.coins + 101)
sequence += 1
after.sequence = sequence
earnings.receive(state, after, { id = "collect:gap", ok = true, figure = "grove.pebble" })
check(
	value == after.coins and E.connections == idle,
	"snapshot gap never attributes unknown wallet changes to impacts"
)
enabled = false
state = after
after = snapshot(state.coins + 101)
earnings.receive(state, after, { id = "collect:reduced", ok = true, figure = "grove.pebble" })
check(
	value == after.coins and E.connections == idle,
	"disabled effects reconcile without a frame listener"
)
enabled = true
collect()
local failed = snapshot(after.coins)
earnings.receive(after, failed, { id = "collect:error", ok = false })
check(value == after.coins and E.connections == idle, "rejection reconciles immediately")
after = failed
collect()
local spent = snapshot(after.coins - 70)
earnings.receive(after, spent, nil)
check(value == spent.coins and E.connections == idle, "non-collection spending cancels flight")
after = spent
collect()
E.step(3)
check(
	value == after.coins and E.connections == idle,
	"expired coins reconcile even without impacts"
)
E.flush()
collect()
local oldEmit = E.methods.Emit
E.methods.Emit = function()
	error("Injected impact failure")
end
E.step(1.2)
E.land(1)
E.methods.Emit = oldEmit
check(value == after.coins and E.connections == idle, "effect error reconciles and disconnects")
collect()
earnings.destroy()
check(value == after.coins, "UI teardown reconciles immediately")
check(E.connections == 0, "teardown disconnects all collection-owned signals")
E.flush()
check(next(require("./UIEngine").timers) == nil, "teardown cancels owned tasks")
local baseline = E.connections
E.step(10)
check(E.connections == baseline, "no idle frame listener after teardown")
print(string.format("PASS: %d Coin presentation assertions", checks))

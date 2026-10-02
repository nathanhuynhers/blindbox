--!strict
-- Global leaderboard bookkeeping (fake DataStore I/O), stat derivation and the day/night clock.
local Store = require("./LeaderboardStore")
local Stats = require("./LeaderboardStats")
local Rules = require("./Rules")
local DayNight = require("./DayNight")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local function close(a: number, b: number): boolean
	return math.abs(a - b) < 0.0001
end

-- Stats come only from authoritative state.
local state = Rules.new(0)
state.discovered["grove.star"] = true
state.discovered["tide.pearl"] = true
state.owned["grove.star"] = 1
state.owned["tide.pearl"] = 1
state.display.slots = { "grove.star", "tide.pearl", "" }
state.boxesOpened = 1234567
local values = Stats.of(state)
check(values.figures == 2, "Most Figures counts permanent discoveries")
check(values.rate == 1450, "Coins/sec is the current Display rate in hundredths")
check(values.boxes == 1234567, "Boxes Opened reads the persistent counter")
check(Stats.format("rate", 1450) == "14.5/s" and Stats.format("rate", 125) == "1.25/s", "rate formatting")
check(
	Stats.format("boxes", 1234567) == "1,234,567"
		and Stats.format("boxes", 1000) == "1,000"
		and Stats.format("figures", 999) == "999"
		and Stats.format("figures", 0) == "0",
	"grouped integer formatting"
)
check(#Stats.list == 3 and Stats.keys()[2] == "rate", "three stats in display order")
check(
	Store.sanitize(-5) == 0 and Store.sanitize(0 / 0) == 0 and Store.sanitize(7.9) == 7,
	"ordered values are clamped to non-negative integers"
)

-- Fake ordered data stores.
local data: { [string]: { [number]: number } } = { figures = {}, rate = {}, boxes = {} }
local writes, reads = 0, 0
local writeBudget, readBudget = 100, 100
local failWrites, failReads = false, false
local duringWrite: (() -> ())? = nil
local io: Store.Io = {
	write = function(stat: string, userId: number, value: number)
		writes += 1
		if duringWrite then
			local hook = duringWrite
			duringWrite = nil
			hook()
		end
		if failWrites then
			error("throttled")
		end
		data[stat][userId] = value
	end,
	read = function(stat: string, count: number): { Store.TopEntry }
		reads += 1
		if failReads then
			error("unavailable")
		end
		local entries: { Store.TopEntry } = {}
		for userId, value in data[stat] do
			table.insert(entries, { userId = userId, value = value })
		end
		table.sort(entries, function(a, b)
			return a.value > b.value
		end)
		local top = {}
		for index = 1, math.min(count, #entries) do
			top[index] = entries[index]
		end
		return top
	end,
	budget = function(kind: "write" | "read"): number
		return if kind == "write" then writeBudget else readBudget
	end,
}
local options: Store.Options = {
	stats = Stats.keys(),
	topCount = 5,
	readSeconds = 90,
	backoffBase = 5,
	backoffMax = 120,
	writeReserve = 2,
	readReserve = 1,
	maxPending = 6,
	writesPerPump = 6,
}
local store = Store.new(io, options)
check(Store.offer(store, 1, values) == 3, "first offer queues all three stats")
check(Store.offer(store, 1, values) == 0 and Store.pendingCount(store) == 3, "repeat offers coalesce")
check(Store.pump(store, 0) == 3 and data.rate[1] == 1450 and writes == 3, "pump writes queued scores")
check(Store.offer(store, 1, values) == 0, "unchanged scores are never rewritten")
values.boxes += 1
check(Store.offer(store, 1, values) == 1, "only the changed stat is queued")
writeBudget = 2
check(Store.pump(store, 1) == 0 and Store.pendingCount(store) == 1, "writes wait for request budget")
writeBudget = 100
failWrites = true
check(Store.pump(store, 2) == 0 and Store.pendingCount(store) == 1, "a failed write is kept for retry")
local before = writes
failWrites = false
check(Store.pump(store, 3) == 0 and writes == before, "writes back off after a failure")
check(Store.pump(store, 7.1) == 1 and data.boxes[1] == 1234568, "write succeeds after backoff")
failWrites = true
values.figures = 3
Store.offer(store, 1, values)
duringWrite = function()
	values.figures = 4
	Store.offer(store, 1, values)
end
Store.pump(store, 100)
check(
	Store.pendingCount(store) == 1 and store.pending["figures:1"].value == 4,
	"a newer score queued during a failed write wins without duplicates"
)
failWrites = false
Store.pump(store, 1000)
check(data.figures[1] == 4, "newest score is written")
for userId = 10, 17 do
	Store.offer(store, userId, { figures = userId })
end
check(Store.pendingCount(store) == options.maxPending, "pending writes stay bounded")
check(store.pending["figures:10"] == nil and store.pending["figures:17"] ~= nil, "oldest pending write is dropped")
Store.pump(store, 2000)

-- Reads keep the last good page.
check(not store.loaded.figures, "nothing is shown as loaded before the first read")
check(Store.refresh(store, 0) and store.loaded.figures, "a successful read loads every stat")
check(#store.top.figures == 5 and store.top.figures[1].value == 17, "top five sorted entries")
local reads0 = reads
check(not Store.refresh(store, 30) and reads == reads0, "reads wait for their cadence")
failReads = true
local good = store.top.figures
check(not Store.refresh(store, 91), "failed read reports failure")
check(store.top.figures == good and store.loaded.figures, "failure keeps the last good page")
check(store.nextRead == 96, "reads back off after a failure")
failReads = false
readBudget = 1
check(not Store.refresh(store, 97) and store.top.figures == good, "reads wait for request budget")
readBudget = 100
local hostile = Store.new({
	write = io.write,
	budget = io.budget,
	read = function(_stat: string, _count: number): { Store.TopEntry }
		return { { userId = 1.5, value = 3 }, { userId = 2, value = -1 }, { userId = 3, value = 9 } } :: any
	end,
}, options)
check(Store.refresh(hostile, 0) and #hostile.top.figures == 1 and hostile.top.figures[1].userId == 3, "malformed rows are ignored")

-- Day/night clock: ~20 minutes, mostly daylight, lights only between dusk and dawn.
local config = DayNight.config
check(config.cycleSeconds == 1200, "a full day/night cycle lasts twenty minutes")
check(close(DayNight.clockAt(0), 6.5) and close(DayNight.clockAt(540), 16.5), "day runs from 6:30 to 16:30")
check(close(DayNight.clockAt(720), 18.2) and close(DayNight.clockAt(1020), 5.6), "golden hour then night")
check(close(DayNight.clockAt(1200), 6.5) and close(DayNight.clockAt(1500), DayNight.clockAt(300)), "the cycle repeats")
for t = 0, 1199, 7 do
	check(close(DayNight.elapsedFor(DayNight.clockAt(t)), t), "clock and elapsed time invert")
end
local nightSeconds = 0
for t = 0, 1199 do
	if DayNight.isNight(DayNight.clockAt(t)) then
		nightSeconds += 1
	end
end
check(nightSeconds > 300 and nightSeconds < 480, string.format("lights are on for %d of 1200 seconds", nightSeconds))
check(
	DayNight.isNight(19) and DayNight.isNight(2) and not DayNight.isNight(12) and not DayNight.isNight(6.5),
	"lights switch on at dusk and off at dawn"
)
for _, keyframe in DayNight.looks do
	check(close(DayNight.sample(keyframe.clock).brightness, keyframe.brightness), "keyframes are exact")
end
local noon, golden, midnight = DayNight.sample(12), DayNight.sample(17.1), DayNight.sample(0)
check(noon.brightness > midnight.brightness and golden.shift.R > golden.shift.B, "bright day, warm golden hour")
check(
	DayNight.sample(23.99).brightness == midnight.brightness and close(DayNight.sample(18.3).brightness, 1.25),
	"looks interpolate smoothly and wrap past midnight"
)
print(string.format("PASS: %d leaderboard store/stat and day-night checks", checks))

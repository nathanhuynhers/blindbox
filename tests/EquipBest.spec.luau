--!strict
-- Equip Best: the optimizer against a brute-force oracle, ties, no-op, bank conservation,
-- retries and rejections. Real Rules/Transactions; incomes come from Rules.rate only.
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Catalog = require("./Catalog")
local Economy = require("./Economy")
local Tutorial = require("./Tutorial")
local Types = require("./Types")
local checks = 0
local function check(ok: boolean, message: string)
	assert(ok, message)
	checks += 1
end
local function same(a: unknown, b: unknown): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	local left, right = a :: { [string]: unknown }, b :: { [string]: unknown }
	for key, value in left do
		if not same(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end
local function rateOf(state: Types.State, slots: { string }): number
	local saved = state.display.slots
	state.display.slots = slots
	local rate = Rules.rate(state)
	state.display.slots = saved
	return rate
end
-- Oracle: every subset of owned figures up to the slot count.
local function brute(state: Types.State): number
	local owned: { string } = {}
	for _, figure in Catalog.figures do
		if (state.owned[figure.id] or 0) > 0 then
			table.insert(owned, figure.id)
		end
	end
	local best = 0
	local picked: { string } = {}
	local function walk(start: number)
		best = math.max(best, rateOf(state, picked))
		if #picked == state.display.unlocked then
			return
		end
		for index = start, #owned do
			table.insert(picked, owned[index])
			walk(index + 1)
			table.remove(picked)
		end
	end
	walk(1)
	return best
end
local function close(a: number, b: number): boolean
	return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(a), math.abs(b))
end
local function session(owned: { [string]: number }, unlocked: number?): Transactions.Session
	local result = Transactions.new(0)
	local state = result.state
	state.step = Tutorial.done
	state.display.unlocked = unlocked or 3
	for slot = 1, state.display.unlocked do
		state.display.slots[slot] = ""
	end
	for id, count in owned do
		state.owned[id], state.discovered[id] = count, true
	end
	return result
end
local function equip(target: Transactions.Session, id: string, now: number, inside: boolean?)
	return Transactions.process(target, {
		action = "EquipBest",
		id = id,
		revision = target.state.revision,
	}, now, if inside == nil then true else inside, 0, 50)
end
local function bankTotal(state: Types.State): number
	local total = 0
	for _, value in state.earnings do
		total += value
	end
	return total
end

-- Randomized inventories (duplicates, mixed collections, 3-6 slots) match brute force exactly.
math.randomseed(20261007)
local ids: { string } = {}
for _, figure in Catalog.figures do
	table.insert(ids, figure.id)
end
local trioWins = 0
for _ = 1, 400 do
	local owned: { [string]: number } = {}
	-- Bias toward one or two collections so themed trios compete with raw rate.
	local focus = Catalog.collections[math.random(#Catalog.collections)].id
	for _ = 1, math.random(1, 11) do
		local id = ids[math.random(#ids)]
		if math.random() < 0.5 then
			local members = {}
			for _, figure in Catalog.figures do
				if figure.collection == focus then
					table.insert(members, figure.id)
				end
			end
			id = members[math.random(#members)]
		end
		owned[id] = (owned[id] or 0) + math.random(1, 4)
	end
	local state = session(owned, math.random(3, 6)).state
	local best, total = Rules.best(state)
	local oracle = brute(state)
	check(
		close(total, oracle) and close(rateOf(state, best), oracle),
		"optimizer matches brute force"
	)
	local unique: { [string]: boolean } = {}
	for _, id in best do
		check(not unique[id] and (state.owned[id] or 0) > 0, "one owned slot per figure ID")
		unique[id] = true
	end
	check(#best <= state.display.unlocked, "never more figures than unlocked slots")
	state.display.slots = best
	if Rules.bonus(state) > 0 then
		trioWins += 1
	end
end
check(trioWins > 20, "random cases exercise the set bonus")

-- The +10% trio beats a higher raw rate: three Grove commons outearn a Tidepool common swap.
do
	local state = session({
		["grove.pebble"] = 1,
		["grove.sprout"] = 1,
		["grove.acorn"] = 1,
		["tide.bubble"] = 1,
	}).state
	local raw = { "tide.bubble", "grove.acorn", "grove.sprout" }
	check(
		Rules.figureRate(state, "tide.bubble") > Rules.figureRate(state, "grove.pebble"),
		"raw top-3 includes the Tidepool figure"
	)
	local best, total = Rules.best(state)
	check(
		not table.find(best, "tide.bubble") and total > rateOf(state, raw),
		"bonus trio beats higher raw rate"
	)
	check(close(total, brute(state)), "bonus edge case matches brute force")
end
-- Bonus is once only: two complete trios in six slots get one +10%.
do
	local state = session({
		["grove.pebble"] = 1,
		["grove.sprout"] = 1,
		["grove.acorn"] = 1,
		["tide.bubble"] = 1,
		["tide.coral"] = 1,
		["tide.shell"] = 1,
	}, 6).state
	local best, total = Rules.best(state)
	local subtotal = 0
	for _, id in best do
		subtotal += Rules.figureRate(state, id)
	end
	check(
		#best == 6 and close(total, subtotal * (1 + Economy.setBonus)),
		"one-time bonus with two trios"
	)
end

-- Determinism: equal-rate figures (matching Tender Echoes / We Are All Stars rosters) resolve by
-- catalog order, and repeated presses do not shuffle them.
do
	local target = session({
		["echo.thread-parade"] = 1,
		["star.reminiscence"] = 1,
		["grove.pebble"] = 1,
		["echo.wander-knit"] = 1,
	})
	local state = target.state
	check(
		Rules.figureRate(state, "echo.thread-parade")
			== Rules.figureRate(state, "star.reminiscence"),
		"tie fixture has equal rates"
	)
	local first = Rules.best(state)
	local again = Rules.best(state)
	check(same(first, again), "optimizer is deterministic")
	local reply = equip(target, "tie-1", 1)
	check(reply ~= nil and reply.ok, "equip ties")
	local placed = table.clone(state.display.slots)
	local second = equip(target, "tie-2", 2)
	check(
		second ~= nil
			and second.ok
			and second.message == "Already your best Display."
			and same(placed, state.display.slots),
		"second press is a no-op"
	)
end

-- Already optimal: nothing settles, swaps, collects or bumps the revision.
do
	local target = session({ ["grove.star"] = 2, ["grove.moth"] = 1, ["grove.mushroom"] = 1 })
	local state = target.state
	state.display.slots = { "grove.mushroom", "grove.star", "grove.moth" }
	state.earnings["grove.star"] = 41.5
	local before = Profile.encode(state)
	local reply, changed = equip(target, "noop", 30)
	check(
		reply ~= nil and reply.ok and changed and reply.message == "Already your best Display.",
		"already best reply"
	)
	check(
		same(before, Profile.encode(state)) and state.revision == 0 and state.time == 0,
		"no-op leaves state untouched"
	)
end

-- Replacement: settle at the old rate, collect only outgoing whole banks, keep kept slots,
-- conserve Coins + banks exactly.
for _, capacity in { math.huge, 7, 0 } do
	local target = session({
		["grove.pebble"] = 1,
		["grove.sprout"] = 1,
		["concept.lovity"] = 1,
		["echo.moon-doze"] = 3,
		["star.dreamcatcher"] = 1,
		["concept.verity-true-form"] = 1,
	}, 4)
	local state = target.state
	state.display.slots = { "grove.pebble", "echo.moon-doze", "", "grove.sprout" }
	state.earnings["grove.pebble"], state.earnings["grove.sprout"] = 20.25, 3.5
	state.earnings["echo.moon-doze"], state.earnings["star.dreamcatcher"] = 9.75, 120.5
	if capacity ~= math.huge then
		state.coins = Economy.coinLimit - capacity
	end
	local coins, banks = state.coins, bankTotal(state)
	local oldRate = Rules.rate(state)
	local settledPebble = 20.25 + 10 * Rules.figureRate(state, "grove.pebble")
	local settledSprout = 3.5 + 10 * Rules.figureRate(state, "grove.sprout")
	local request: Types.Intent = { action = "EquipBest", id = "swap", revision = state.revision }
	local reply, changed = Transactions.process(target, request, 10, true, 0, 50)
	check(reply ~= nil and reply.ok and changed and state.revision == 1, "one atomic revision")
	check(state.display.slots[2] == "echo.moon-doze", "kept figure stays in its slot")
	check(
		state.display.slots[1] ~= "grove.pebble"
			and state.display.slots[4] ~= "grove.sprout"
			and state.display.slots[3] ~= "",
		"worse figures replaced and empty slot filled"
	)
	check(
		close(Rules.rate(state), brute(state)) and Rules.rate(state) > oldRate,
		"result is optimal"
	)
	local collected = math.min(
		math.floor(settledPebble) + math.floor(settledSprout),
		if capacity == math.huge then math.huge else capacity
	)
	check(state.coins == coins + collected, "only outgoing whole banks collected")
	check(
		close(state.coins + bankTotal(state), coins + banks + 10 * oldRate),
		"Coins + banks conserved apart from settled income"
	)
	check(state.earnings["star.dreamcatcher"] == 120.5, "incoming bank untouched")
	if capacity == math.huge then
		check(
			close(state.earnings["grove.pebble"], settledPebble % 1)
				and close(state.earnings["grove.sprout"], settledSprout % 1),
			"fractions stay banked"
		)
	else
		check(state.coins == Economy.coinLimit, "wallet fills to the limit")
		check(
			close(
				state.earnings["grove.pebble"] + state.earnings["grove.sprout"],
				settledPebble + settledSprout - capacity
			),
			"wallet overflow stays banked"
		)
	end
	local committed = Profile.encode(state)
	local retry, retried = Transactions.process(target, request, 11, true, 0, 51)
	check(
		retry == reply
			and not retried
			and same(committed, Profile.encode(state))
			and state.time == 10,
		"retry cannot recollect or settle"
	)
	local loaded = Profile.decode(committed, 10)
	assert(loaded)
	check(
		same(loaded.earnings, state.earnings) and loaded.coins == state.coins,
		"banks survive save round trip"
	)
end

-- Welcome Quest: equipping the first figure counts as the placement step.
do
	local target = session({ ["grove.moth"] = 1 })
	target.state.step = Tutorial.display
	local reply = equip(target, "quest", 1)
	check(
		reply ~= nil and reply.ok and target.state.step == Tutorial.collect,
		"equip advances placement step"
	)
end

-- Rejections leave every persisted field, clock and revision unchanged.
do
	local target = session({ ["grove.moth"] = 1, ["grove.star"] = 1 })
	local state = target.state
	local before = Profile.encode(state)
	local outside = equip(target, "outside", 1, false)
	check(
		outside ~= nil
			and not outside.ok
			and outside.message == "Return to your own plot to edit your Display.",
		"not on own plot rejected"
	)
	local stale = Transactions.process(
		target,
		{ action = "EquipBest", id = "stale", revision = 5 },
		2,
		true,
		0,
		50
	)
	check(stale ~= nil and not stale.ok, "stale revision rejected")
	check(
		same(before, Profile.encode(state)) and state.revision == 0 and state.time == 0,
		"rejections mutate nothing"
	)
	-- Token bucket: four immediate requests are processed, the fifth is dropped without a reply.
	local limited = session({ ["grove.moth"] = 1 })
	limited.state.revision = 9
	for index = 1, 4 do
		Transactions.process(
			limited,
			{ action = "EquipBest", id = "burst" .. index, revision = 0 },
			0,
			true,
			0,
			50
		)
	end
	local dropped, droppedChanged = equip(limited, "burst5", 0)
	check(
		dropped == nil and not droppedChanged and limited.state.display.slots[1] == "",
		"rate limit drops the request"
	)
	check(
		Protocol.parse({ action = "EquipBest", id = "x", revision = 0, figure = "grove.moth" })
				== nil
			and Protocol.parse({ action = "EquipBest", id = "x", revision = 0, slot = 1 }) == nil
			and Protocol.parse({
					action = "EquipBest",
					id = "x",
					revision = 0,
					choice = "grove",
				})
				== nil,
		"no client-chosen figures, slots or choices"
	)
	local empty = session({})
	local nothing = equip(empty, "empty", 1)
	check(
		nothing ~= nil and nothing.ok and nothing.message == "Already your best Display.",
		"no figures is a no-op"
	)
end

print(`PASS: {checks} Equip Best checks`)

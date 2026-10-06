--!strict
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Profile = require("./Profile")
local Persistence = require("./Persistence")
local Economy = require("./Economy")
local Tutorial = require("./Tutorial")
local Types = require("./Types")
local outgoing, incoming = "grove.pebble", "tide.ray"
local checks = 0
local function check(ok: boolean, message: string)
	assert(ok, message)
	checks += 1
end
local function close(a: number, b: number): boolean
	return math.abs(a - b) < 1e-7
end
local function seeded(): Transactions.Session
	local session = Transactions.new(0)
	local state = session.state
	for _, id in { outgoing, incoming, "grove.sprout", "grove.acorn" } do
		state.owned[id], state.discovered[id] = 1, true
	end
	state.display.slots[1] = outgoing
	state.earnings[outgoing], state.earnings[incoming] = 12.75, 99.5
	state.step = Tutorial.collect
	return session
end
local function place(state: Types.State): Types.Intent
	return { action = "Place", id = "swap", revision = state.revision, figure = incoming, slot = 1 }
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

-- Settle at the old rate, collect only the outgoing bank, and commit one Place revision.
local session = seeded()
local state = session.state
local bank = 12.75 + Rules.figureRate(state, outgoing) * 10
local request = place(state)
local reply, changed = Transactions.process(session, request, 10, true, 0, 50)
check(reply ~= nil and reply.ok and changed, "occupied replacement succeeds")
check(
	state.coins == 4500 + math.floor(bank),
	"exact outgoing whole bank collected after settlement"
)
check(close(state.earnings[outgoing], bank % 1), "fraction remains banked")
check(state.earnings[incoming] == 99.5, "incoming bank untouched")
check(
	state.display.slots[1] == incoming and state.time == 10 and state.revision == 1,
	"one atomic Place revision"
)
check(state.step == Tutorial.collect, "replacement is not Welcome Quest collection")
local committed = Profile.encode(state)
local retry, retried = Transactions.process(session, request, 11, true, 0, 51)
check(
	retry == reply and not retried and same(committed, Profile.encode(state)) and state.time == 10,
	"lost-reply retry cannot recollect or settle"
)
local altered = table.clone(request)
altered.figure = outgoing
local reused = Transactions.process(session, altered, 12, true, 0, 51)
check(
	reused ~= nil and not reused.ok and same(committed, Profile.encode(state)),
	"ID reuse cannot collect"
)
local expired = Transactions.process(session, request, 131, true, 0, 51)
check(
	expired ~= nil and not expired.ok and same(committed, Profile.encode(state)),
	"expired receipt still rejects stale retry"
)

for _, capacity in { 3, 0 } do
	local limited = seeded()
	limited.state.coins = Economy.coinLimit - capacity
	local result = Transactions.process(limited, place(limited.state), 10, true, 0, 50)
	check(
		result ~= nil and result.ok and limited.state.display.slots[1] == incoming,
		"wallet cap permits replacement"
	)
	check(
		limited.state.coins == Economy.coinLimit
			and close(limited.state.earnings[outgoing], bank - capacity),
		"wallet overflow and fraction retained"
	)
	check(limited.state.earnings[incoming] == 99.5, "capped replacement leaves incoming bank")
	local loaded = Profile.decode(Profile.encode(limited.state), 10)
	assert(loaded)
	check(
		loaded.coins == limited.state.coins
			and loaded.earnings[outgoing] == limited.state.earnings[outgoing],
		"capped bank/wallet round trip"
	)
	loaded.coins -= 1000
	check(
		Rules.mutate(loaded, {
			action = "Place",
			id = "restore",
			revision = loaded.revision,
			figure = outgoing,
			slot = 2,
		}, 0, 50, 10),
		"outgoing can be redisplayed"
	)
	local remainder = loaded.earnings[outgoing]
	local coins = loaded.coins
	check(
		Rules.collect(loaded, 2, outgoing) and loaded.coins == coins + math.floor(remainder),
		"remaining outgoing bank recoverable manually"
	)
	check(close(loaded.earnings[outgoing], remainder % 1), "recovered bank keeps fraction")
end

-- Every rejection must preserve all persisted fields plus runtime clock/revision.
type Invalid = { name: string, edit: (Types.Intent, Types.State) -> (), inside: boolean }
local invalid: { Invalid } = {
	{
		name = "stale",
		edit = function(r)
			r.revision = 1
		end,
		inside = true,
	},
	{ name = "out of plot", edit = function() end, inside = false },
	{
		name = "duplicate ID",
		edit = function(_, s)
			s.display.slots[2] = incoming
		end,
		inside = true,
	},
	{
		name = "same ID",
		edit = function(r)
			r.figure = outgoing
		end,
		inside = true,
	},
	{
		name = "locked slot",
		edit = function(r)
			r.slot = 4
		end,
		inside = true,
	},
	{
		name = "unowned",
		edit = function(_, s)
			s.owned[incoming] = nil
		end,
		inside = true,
	},
	{
		name = "malformed slot",
		edit = function(r)
			r.slot = 0 / 0
		end,
		inside = true,
	},
}
for _, case in invalid do
	local rejected = seeded()
	local raw = place(rejected.state)
	case.edit(raw, rejected.state)
	local before = Profile.encode(rejected.state)
	local result, mutated = Transactions.process(rejected, raw, 10, case.inside, 0, 51)
	check((result == nil or not result.ok) and not mutated, case.name .. " rejected")
	check(
		same(before, Profile.encode(rejected.state))
			and rejected.state.time == 0
			and rejected.state.revision == 0,
		case.name .. " leaves gameplay unchanged"
	)
end
for _, field in { "amount", "price", "ownerId", "collectAuthorized" } do
	local rejected = seeded()
	local raw = place(rejected.state) :: unknown
	(raw :: { [string]: unknown })[field] = 1
	local before = Profile.encode(rejected.state)
	check(
		Transactions.process(rejected, raw, 10, true, 0) == nil
			and same(before, Profile.encode(rejected.state)),
		"client authority field rejected: " .. field
	)
end
local throttled = seeded()
throttled.tokens = 0
local beforeThrottle = Profile.encode(throttled.state)
check(
	Transactions.process(throttled, place(throttled.state), 0, true, 0) == nil
		and same(beforeThrottle, Profile.encode(throttled.state)),
	"rate limit preserves bank"
)

local empty = seeded()
empty.state.display.slots[1] = ""
local emptyReply = Transactions.process(empty, place(empty.state), 10, true, 0)
check(
	emptyReply ~= nil
		and emptyReply.ok
		and empty.state.coins == 4500
		and empty.state.earnings[outgoing] == 12.75
		and empty.state.earnings[incoming] == 99.5,
	"empty placement never collects"
)
local removed = seeded()
local removeReply = Transactions.process(
	removed,
	{ action = "Remove", id = "remove", revision = 0, slot = 1 },
	10,
	true,
	0
)
check(
	removeReply ~= nil
		and removeReply.ok
		and removed.state.coins == 4500
		and close(removed.state.earnings[outgoing], bank),
	"ordinary Remove keeps settled bank"
)

local themed = seeded()
themed.state.display.slots[2], themed.state.display.slots[3] = "grove.sprout", "grove.acorn"
check(Rules.bonus(themed.state) > 0, "old themed trio active")
local expected = 12.75 + Rules.figureRate(themed.state, outgoing) * 10 * (1 + Economy.setBonus)
local themedReply = Transactions.process(themed, place(themed.state), 10, true, 0)
check(
	themedReply ~= nil and themedReply.ok and Rules.bonus(themed.state) == 0,
	"replacement breaks trio"
)
check(
	themed.state.coins == 4500 + math.floor(expected)
		and close(themed.state.earnings[outgoing], expected % 1),
	"outgoing settled with old trio bonus"
)
for _, id in { "grove.sprout", "grove.acorn" } do
	check(
		close(
			themed.state.earnings[id],
			Rules.figureRate(themed.state, id) * 10 * (1 + Economy.setBonus)
		),
		"other banks retain old bonus"
	)
end
Rules.settle(themed.state, 11)
check(
	close(themed.state.earnings[incoming], 99.5 + Rules.figureRate(themed.state, incoming)),
	"incoming earns at new loadout rate"
)

-- Genuine native collection retains authorization, quest progression and receipt behavior.
local manual = seeded()
local collect: Types.Intent =
	{ action = "Collect", id = "remote", revision = 0, figure = outgoing, slot = 1 }
local denied = Transactions.process(manual, collect, 0, true, 0)
check(
	denied ~= nil
		and not denied.ok
		and manual.state.coins == 4500
		and manual.state.step == Tutorial.collect,
	"remote collection remains unauthorized"
)
collect.id = "native"
local collected = Transactions.process(manual, collect, 0, true, 0, nil, nil, true)
check(
	collected ~= nil
		and collected.ok
		and manual.state.coins == 4512
		and manual.state.earnings[outgoing] == 0.75
		and manual.state.step == Tutorial.buy,
	"native collection preserves arithmetic and quest"
)
check(
	Transactions.process(manual, collect, 0, true, 0, nil, nil, true) == collected
		and manual.state.coins == 4512,
	"native retry does not duplicate"
)

-- Save the wallet, placement and residual bank together and recover through a new lease.
local database: { [string]: unknown } = {}
local update: Persistence.Update = function(key, transform)
	transform(database[key])
	local value = transform(database[key])
	if value ~= nil then
		database[key] = value
	end
	return value
end
local handle = Persistence.load(update, "swap", "first", 100, 0)
assert(handle)
check(
	Persistence.save(update, handle, Profile.encode(state), 101, true),
	"replacement aggregate saves"
)
local nextHandle, rejoined = Persistence.load(update, "swap", "second", 102, 10)
assert(nextHandle and rejoined)
check(
	same(Profile.encode(state), Profile.encode(rejoined)),
	"replacement wallet/banks/quest/placement persist together"
)
print(string.format("PASS: %d Display replacement checks", checks))

--!strict
-- Real production modules, using only the existing deterministic engine/DataStore double.
local E = require("./AfkEngine")
local Storage = require("./Storage")
local Persistence = require("./Persistence")
local Profile = require("./Profile")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Shelves = require("./Shelves")
local Economy = require("./Economy")
local checks = 0
local function check(value: boolean, message: string)
	checks += 1
	assert(value, message)
end
local function equal(a: unknown, b: unknown): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	local left, right = a :: { [unknown]: unknown }, b :: { [unknown]: unknown }
	for key, value in left do
		if not equal(value, right[key]) then
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
local function populated()
	local state = Rules.new(E.now)
	state.coins = 1234567
	state.owned = { ["grove.pebble"] = 7, ["tide.ray"] = 2 }
	state.discovered = { ["grove.pebble"] = true, ["tide.ray"] = true, ["grove.sprout"] = true }
	state.earnings = { ["grove.pebble"] = 123.75, ["tide.ray"] = 0.125 }
	state.display = { unlocked = 6, slots = { "grove.pebble", "tide.ray", "", "", "", "" } }
	for _ = 1, 4 do
		assert(Shelves.add(state.shelves))
	end
	state.shelves.units[1].placements["row:1/slot:1"] = "grove.pebble"
	state.shelves.units[7].placements["row:999/slot:999"] = "grove.pebble"
	state.shelves.legacyOverflow = {
		{
			sourceId = "page:old",
			logicalUnit = 4,
			placements = { ["row:100/slot:100"] = "tide.ray" },
		},
	}
	state.pityByGroup.echo = { legendaryDryRolls = 93, mythicalDryRolls = 601 }
	state.step, state.tutorialHidden = 7, true
	state.lastDailyDay = 10
	state.lastLoginDay, state.loginStreak = 10, 3
	state.goalDay, state.goalProgress, state.goalClaimed = 10, 3, true
	state.boxesOpened = 1234
	state.shelfRewards.grove = true
	state.lastSeen, state.offlinePending = E.os.time(), 333
	state.sfxVolume, state.musicVolume = 17, 81
	state.deals = { window = 277, bought = { 3, 1, 2 } }
	return state
end
local function update(key: string, transform: (unknown) -> unknown): unknown
	return E.store:UpdateAsync(key, transform)
end
local current = Profile.encode(populated())
-- Sparse arrays have undefined length borders; cover every layout of eight saved stalls.
for mask = 0, 255 do
	local candidate = Profile.encode(populated())
	local bought: { number } = {}
	local count = 0
	for stall = 1, 8 do
		if bit32.band(mask, 2 ^ (stall - 1)) ~= 0 then
			bought[stall] = 1
			count += 1
		end
	end
	candidate.deals.bought = bought
	check(
		(Profile.decode(candidate, 0) ~= nil) == (mask == 2 ^ count - 1),
		`deal layout {mask} requires a dense array`
	)
end
check(
	equal(Profile.encode(assert(Profile.decode(current, 50))), current),
	"every current persisted field round-trips"
)
local handle = assert(Persistence.load(update, "aggregate", "first", E.os.time(), E.now))
check(Persistence.save(update, handle, current, E.os.time(), true), "aggregate saved and released")
local second, restored = Persistence.load(update, "aggregate", "second", E.os.time(), E.now)
assert(second and restored)
check(
	equal(Profile.encode(restored), current),
	"stored aggregate reloads without loss or starter grant"
)
check(
	not Persistence.save(update, handle, current, E.os.time(), false),
	"departed writer cannot overwrite rejoin"
)

-- All documented Economy2 versions, with populated progression rather than fresh-only fixtures.
for version = 6, 14 do
	local legacy = (Profile.encode(populated()) :: unknown) :: { [string]: unknown }
	legacy.schemaVersion = version
	if version < 14 then
		legacy.deals = nil
	end
	if version < 13 then
		legacy.tutorialHidden, legacy.step = nil, 5
	end
	if version < 12 then
		legacy.sfxVolume, legacy.musicVolume = nil, nil
	end
	if version < 11 then
		legacy.lastLoginDay, legacy.loginStreak = nil, nil
	end
	if version < 10 then
		legacy.lastSeen, legacy.offlinePending = nil, nil
	end
	if version < 9 then
		legacy.shelfRewards = nil
	end
	if version < 8 then
		legacy.boxesOpened = nil
	end
	if version < 7 then
		legacy.earnings = nil
	end
	local before = Profile.encode(assert(Profile.decode(legacy, 0)))
	E.database["migration"] =
		{ data = legacy, token = "", writer = "previous", generation = 11, expires = 0 }
	local migratedHandle, state =
		Persistence.load(update, "migration", "migrate", E.os.time(), E.now)
	assert(migratedHandle and state)
	check(
		equal(Profile.encode(state), before),
		`v{version} acquisition uses deterministic migration`
	)
	check(
		state.coins == current.coins
			and equal(state.owned, current.owned)
			and equal(state.discovered, current.discovered),
		`v{version} preserves wallet, copies and discoveries`
	)
	check(
		equal(state.display, current.display)
			and equal(state.shelves, current.shelves)
			and equal(state.pityByGroup, current.pityByGroup),
		`v{version} preserves unlocks, hidden placements and pity`
	)
	check(
		state.lastDailyDay == 10 and state.goalClaimed and state.step == 7,
		`v{version} preserves claim protection and grants no Welcome reward`
	)
	check(
		version == 6 or equal(state.earnings, current.earnings),
		`v{version} preserves existing fractional banks`
	)
	check(
		version < 8 or state.boxesOpened == current.boxesOpened,
		`v{version} preserves existing lifetime counter`
	)
	check(
		version < 9 or state.shelfRewards.grove == true,
		`v{version} preserves completion reward marker`
	)
	check(
		version < 10 or (state.lastSeen == current.lastSeen and state.offlinePending == 333),
		`v{version} preserves offline claim aggregate`
	)
	check(
		version < 11 or (state.loginStreak == 3 and state.lastLoginDay == 10),
		`v{version} preserves login claims`
	)
	check(
		version < 12 or (state.sfxVolume == 17 and state.musicVolume == 81),
		`v{version} preserves settings`
	)
	check(version < 13 or state.tutorialHidden, `v{version} preserves tutorial choice`)
	check(
		version < 14 or equal(state.deals, current.deals),
		`v{version} preserves hourly purchases`
	)
	check(
		Persistence.save(update, migratedHandle, Profile.encode(state), E.os.time(), true),
		`v{version} upgraded save succeeds`
	)
	check(
		equal(E.database.migration.data, before) and legacy.schemaVersion == version,
		`v{version} save preserves migration result and original input`
	)
end

for _, field in
	{
		"schemaVersion",
		"coins",
		"earnings",
		"owned",
		"discovered",
		"display",
		"shelves",
		"pityByGroup",
		"step",
		"tutorialHidden",
		"lastDailyDay",
		"lastLoginDay",
		"loginStreak",
		"goalDay",
		"goalProgress",
		"goalClaimed",
		"boxesOpened",
		"shelfRewards",
		"lastSeen",
		"offlinePending",
		"sfxVolume",
		"musicVolume",
		"deals",
	}
do
	local damaged = (Profile.encode(populated()) :: unknown) :: { [string]: unknown }
	damaged[field] = nil
	E.database.damaged = { data = damaged, token = "", writer = "old", generation = 1, expires = 0 }
	local raw = E.database.damaged
	check(
		Persistence.load(update, "damaged", "new", E.os.time(), E.now) == nil,
		`missing {field} fails closed`
	)
	check(E.database.damaged == raw, `missing {field} never overwrites stored data`)
end
local future = Profile.encode(populated())
future.schemaVersion = 15
E.database.future = {
	data = future,
	token = "owner",
	writer = "owner",
	generation = 5,
	expires = E.os.time() + 120,
}
local futureHandle = { key = "future", token = "owner", generation = 5 }
check(
	Persistence.load(update, "future", "older", E.os.time(), E.now) == nil,
	"older reader blocks newer schema"
)
check(
	not Persistence.save(update, futureHandle, current, E.os.time(), false),
	"older writer cannot downgrade newer data even with matching token"
)
check(
	not Persistence.resume(update, futureHandle, E.os.time()),
	"handoff recovery cannot downgrade newer data"
)
check(
	E.database.future.data == future and future.schemaVersion == 15,
	"future record is preserved exactly"
)
local unknown = Profile.encode(populated())
unknown.owned["deleted.figure"] = 1
check(
	Profile.decode(unknown, 0) == nil,
	"removed catalog IDs block loading rather than dropping inventory"
)
unknown = Profile.encode(populated())
unknown.shelves.units[1].customization.future = "value"
check(Profile.decode(unknown, 0) == nil, "unknown shelf customization is never erased")

E.before = 4
local raw = E.database.aggregate
check(
	Storage.open(9999) == nil and E.database.Player_9999 == nil,
	"four failed loads cannot create a starter record"
)
E.before = 4
check(
	Persistence.load(update, "aggregate", "failed", E.os.time(), E.now) == nil
		and E.database.aggregate == raw,
	"failed load cannot replace existing progress"
)
E.before = 0

-- An action can finish while the first autosave yields, before its failure pauses gameplay.
local session = assert(Storage.open(9001))
session.state = populated()
local tx = Transactions.new(E.now)
tx.state = session.state
E.onUpdate = function()
	E.onUpdate = nil
	local reply = Transactions.process(
		tx,
		{ action = "Buy", id = "during-save", revision = tx.state.revision, choice = "grove" },
		E.now,
		true,
		0,
		10
	)
	assert(reply and reply.ok)
end
E.after = 3
check(
	not Storage.flush(session, false) and not session.ready,
	"three lost autosave replies pause gameplay"
)
local committed = E.database.Player_9001.data
check(
	committed.coins ~= session.state.coins,
	"newer in-memory purchase was outside uncertain checkpoint"
)
check(
	Storage.close(session),
	"final save reconciles uncertain autosave before releasing latest state"
)
check(
	E.database.Player_9001.token == ""
		and equal(E.database.Player_9001.data, Profile.encode(session.state)),
	"final checkpoint contains later purchase exactly once"
)
local rejoined = assert(Storage.open(9001))
check(
	rejoined.state.coins == session.state.coins + 333
		and equal(rejoined.state.owned, session.state.owned),
	"rapid rejoin preserves purchase and auto-claims pending offline once"
)
check(Storage.close(rejoined), "rejoin final save")
local third = assert(Storage.open(9001))
check(
	third.state.coins == rejoined.state.coins and third.state.offlinePending == 0,
	"second rejoin cannot duplicate pending reward"
)

session = assert(Storage.open(9002))
session.state = populated()
E.before = 3
check(not Storage.flush(session, false), "uncommitted autosave failure fixture")
check(
	Storage.close(session) and equal(E.database.Player_9002.data, Profile.encode(session.state)),
	"uncommitted retry followed by final release preserves state"
)
session = assert(Storage.open(9003))
session.state = populated()
E.after = 3
check(not Storage.flush(session, false), "expired uncertain autosave fixture")
local saved = E.database.Player_9003
E.now += 121
local replacement = assert(Storage.open(9003))
check(
	not Storage.close(session) and E.database.Player_9003.token == replacement.handle.token,
	"expired source final save cannot steal replacement owner"
)
check(equal(saved.data, E.database.Player_9003.data), "takeover cannot revive unsaved source state")

session = assert(Storage.open(9004))
session.state = populated()
E.after = 3
check(not Storage.flush(session, false), "uncertain autosave before cancelled handoff")
session.transferring = true -- Same barrier set while an in-flight autosave drains.
check(
	Storage.recoverTeleport(session) and session.pendingSave == nil,
	"handoff reclaim clears reconciled autosave snapshot"
)
session.state.coins += 20
check(
	Storage.close(session) and E.database.Player_9004.data.coins == session.state.coins,
	"reclaim cannot revive an older autosave over current memory"
)

session = assert(Storage.open(9005))
session.state = populated()
session.busy = true
local locked = E.database.Player_9005
check(
	not Storage.close(session) and E.database.Player_9005 == locked,
	"shutdown timeout never races an unresolved write"
)
session.busy = false

-- UpdateAsync can re-run a callback with a different record after a conflicting acquisition.
local owner = assert(Persistence.load(update, "conflict", "old", E.os.time(), E.now))
local competing: Persistence.Update = function(key, transform)
	transform(E.database[key])
	local takeover = Persistence.load(update, key, "replacement", E.os.time() + 121, E.now)
	assert(takeover)
	local result = transform(E.database[key])
	if result ~= nil then
		E.database[key] = result
	end
	return result
end
check(
	not Persistence.save(competing, owner, current, E.os.time(), false),
	"callback retry rechecks latest ownership"
)
check(
	E.database.conflict.token == "replacement",
	"conflicting UpdateAsync cannot overwrite new session"
)
print(`PASS: {checks} production save safety and migration checks`)

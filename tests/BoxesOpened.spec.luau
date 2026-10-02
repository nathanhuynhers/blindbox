--!strict
-- Schema-v6 lifetime box counter: authoritative increments, v1-v5 migration and fail-closed decoding.
local Rules = require("./Rules")
local Profile = require("./Profile")
local Persistence = require("./Persistence")
local Transactions = require("./Transactions")
local Economy = require("./Economy")
local Types = require("./Types")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local function intent(action: string, revision: number, figure: string?, choice: string?): Types.Intent
	return {
		action = action,
		id = tostring(revision) .. action,
		revision = revision,
		figure = figure,
		choice = choice,
	}
end

local state = Rules.new(0)
check(state.schemaVersion == 6 and state.boxesOpened == 0, "fresh profiles start at schema 6 with zero boxes")
check(Rules.mutate(state, intent("Buy", 0), 0, 10), "funded purchase succeeds")
check(state.boxesOpened == 1, "a successful purchase counts one box")
check(Rules.mutate(state, intent("Daily", 1, nil, "tide"), 0.5, 10), "daily free box succeeds")
check(state.boxesOpened == 2, "a daily free box that grants a figure counts one box")
check(not Rules.mutate(state, intent("Daily", 2), 0.5, 10), "second daily box on the same day fails")
check(state.boxesOpened == 2, "a rejected daily claim never counts")
state.coins = Economy.price - 1
check(not Rules.mutate(state, intent("Buy", 2), 0, 10), "unfunded purchase fails")
check(state.boxesOpened == 2, "a rejected purchase never counts")
state.scrap = Economy.redeemCost
check(Rules.mutate(state, intent("Redeem", 2, "grove.star"), 0, 10), "targeted redemption succeeds")
check(state.boxesOpened == 2, "Scrap redemption is not a box")
local full = Rules.new(0)
full.owned["grove.pebble"] = Economy.capacity
full.discovered["grove.pebble"] = true
check(not Rules.mutate(full, intent("Buy", 0), 0, 10), "full inventory blocks purchase")
check(full.boxesOpened == 0, "a purchase blocked by capacity never counts")
local capped = Rules.new(0)
capped.boxesOpened = Rules.boxesOpenedLimit
check(Rules.mutate(capped, intent("Buy", 0), 0, 10), "purchase at the counter guard still succeeds")
check(capped.boxesOpened == Rules.boxesOpenedLimit, "counter clamps at its numeric guard")

-- Retried request IDs replay the stored receipt and never increment twice.
local session = Transactions.new(0)
local raw = { action = "Buy", id = "buy-once", revision = 0 }
local reply = Transactions.process(session, raw, 0, false, 0.1, 10)
check(reply ~= nil and reply.ok and session.state.boxesOpened == 1, "remote purchase counts once")
local replay = Transactions.process(session, raw, 0.1, false, 0.1, 10)
check(replay ~= nil and replay.ok and session.state.boxesOpened == 1, "replayed purchase is not recounted")

-- Encoding and decoding preserve the counter.
local restored = Profile.decode(Profile.encode(state), 0)
check(restored ~= nil and restored.boxesOpened == 2, "v6 round trip keeps the counter")

-- v1-v5 profiles migrate with an explicit zero and keep their other progress.
local v5 = Profile.encode(state) :: { [string]: any }
v5.schemaVersion = 5
v5.boxesOpened = nil
local migrated = Profile.decode(v5, 0)
check(
	migrated ~= nil
		and migrated.boxesOpened == 0
		and migrated.coins == state.coins
		and migrated.owned["grove.star"] == state.owned["grove.star"],
	"v5 profiles start at zero boxes and keep their progress"
)
check(v5.boxesOpened == nil and v5.schemaVersion == 5, "migration does not mutate its input")
check(
	migrated ~= nil and Profile.encode(migrated).schemaVersion == 6,
	"migrated profiles always re-encode as schema 6"
)
local v1: { [string]: unknown } = {
	schemaVersion = 1,
	coins = 12,
	scrap = 0,
	step = 2,
	owned = { ["grove.pebble"] = 1 },
	discovered = { ["grove.pebble"] = true },
	slots = { "", "", "" },
}
local fromV1 = Profile.decode(v1, 0)
check(fromV1 ~= nil and fromV1.boxesOpened == 0, "v1 profiles start at zero boxes")

-- Malformed counters fail closed instead of being reset.
local invalid: { { [string]: any } } = {}
for _, value in { -1, 1.5, Rules.boxesOpenedLimit + 1, "3", true } do
	local corrupt = Profile.encode(state) :: { [string]: any }
	corrupt.boxesOpened = value
	table.insert(invalid, corrupt)
end
local missing = Profile.encode(state) :: { [string]: any }
missing.boxesOpened = nil
table.insert(invalid, missing)
local early = Profile.encode(state) :: { [string]: any }
early.schemaVersion = 5
table.insert(invalid, early)
for _, corrupt in invalid do
	check(Profile.decode(corrupt, 0) == nil, "invalid, missing or premature counters block loading")
end

-- Lease acquisition migrates a stored v5 record in place without losing data.
local database: unknown = { data = v5, token = "", writer = "old", expires = 0, generation = 4 }
local update: Persistence.Update = function(_, transform)
	local result = transform(database)
	if result then
		database = result
	end
	return result
end
local handle, loaded = Persistence.load(update, "Player_1", "join", 1000, 0)
local stored = (database :: { [string]: any }).data
check(
	handle ~= nil and loaded ~= nil and loaded.boxesOpened == 0 and handle.generation == 4,
	"stored v5 record loads through the lease"
)
check(stored.schemaVersion == 6 and stored.boxesOpened == 0, "acquired record is rewritten as v6")
local corruptRecord: unknown = {
	data = invalid[1],
	token = "",
	writer = "old",
	expires = 0,
	generation = 1,
}
local before = corruptRecord
database = corruptRecord
local blocked = Persistence.load(update, "Player_2", "join", 1000, 0)
check(blocked == nil and database == before, "a corrupt counter never becomes a fresh profile")
print(string.format("PASS: %d box counter schema/migration/authority checks", checks))

--!strict
-- Schema-v8 lifetime box counter: authoritative increments, v6/v7 migration and fail-closed decoding.
local Rules = require("./Rules")
local Profile = require("./Profile")
local Persistence = require("./Persistence")
local Transactions = require("./Transactions")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local Types = require("./Types")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local function intent(action: string, revision: number, choice: string?): Types.Intent
	return { action = action, id = tostring(revision) .. action, revision = revision, choice = choice }
end
local starter = Economy.dailyCollection
local price = Rules.prices[starter]

local state = Rules.new(0)
check(state.schemaVersion == 14 and state.boxesOpened == 0, "fresh profiles start at schema 14 with zero boxes")
check(Rules.mutate(state, intent("Buy", 0, starter), 0, 10), "funded purchase succeeds")
check(state.boxesOpened == 1, "a successful purchase counts one box")
check(Rules.mutate(state, intent("Daily", 1, starter), 0.5, 10), "daily free box succeeds")
check(state.boxesOpened == 2, "a daily free box that grants a figure counts one box")
check(not Rules.mutate(state, intent("Daily", 2, starter), 0.5, 10), "second daily box on the same day fails")
check(state.boxesOpened == 2, "a rejected daily claim never counts")
state.coins = price - 1
check(not Rules.mutate(state, intent("Buy", 2, starter), 0, 10), "unfunded purchase fails")
check(state.boxesOpened == 2, "a rejected purchase never counts")
check(not Rules.mutate(state, intent("Buy", 2, "unknown"), 0, 10), "unknown collection fails")
check(state.boxesOpened == 2, "an unknown collection never counts")
local full = Rules.new(0)
for _, figure in Catalog.figures do
	if figure.collection == starter then
		full.owned[figure.id] = Economy.copyLimit
		full.discovered[figure.id] = true
		break
	end
end
check(not Rules.mutate(full, intent("Buy", 0, starter), 0, 10), "copy safety limit blocks purchase")
check(full.boxesOpened == 0, "a purchase blocked by the safety limit never counts")
local capped = Rules.new(0)
capped.boxesOpened = Rules.boxesOpenedLimit
check(Rules.mutate(capped, intent("Buy", 0, starter), 0, 10), "purchase at the counter guard still succeeds")
check(capped.boxesOpened == Rules.boxesOpenedLimit, "counter clamps at its numeric guard")

-- Retried request IDs replay the stored receipt and never increment twice.
local session = Transactions.new(0)
local raw = { action = "Buy", id = "buy-once", revision = 0, choice = starter }
local reply = Transactions.process(session, raw, 0, false, 0.1, 10)
check(reply ~= nil and reply.ok and session.state.boxesOpened == 1, "remote purchase counts once")
local replay = Transactions.process(session, raw, 0.1, false, 0.1, 10)
check(replay ~= nil and replay.ok and session.state.boxesOpened == 1, "replayed purchase is not recounted")

-- Encoding and decoding preserve the counter.
local restored = Profile.decode(Profile.encode(state), 0)
check(restored ~= nil and restored.boxesOpened == 2, "v8 round trip keeps the counter")

-- v6/v7 profiles in the current store migrate with an explicit zero and keep their progress.
for _, version in { 6, 7 } do
	local old = Profile.encode(state) :: { [string]: any }
	old.schemaVersion = version
	old.boxesOpened = nil
	old.shelfRewards = nil
	old.lastSeen, old.offlinePending = nil, nil
	old.lastLoginDay, old.loginStreak = nil, nil
	old.sfxVolume, old.musicVolume = nil, nil
	old.tutorialHidden = nil
	old.deals = nil
	if version == 6 then
		old.earnings = nil
	end
	local migrated = Profile.decode(old, 0)
	check(
		migrated ~= nil and migrated.boxesOpened == 0 and migrated.coins == state.coins,
		"v" .. version .. " profiles start at zero boxes and keep their progress"
	)
	check(old.boxesOpened == nil and old.schemaVersion == version, "migration does not mutate its input")
	check(migrated ~= nil and Profile.encode(migrated).schemaVersion == 14, "migrated profiles re-encode as schema 14")
end

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
early.schemaVersion = 7
early.lastLoginDay, early.loginStreak = nil, nil
early.sfxVolume, early.musicVolume = nil, nil
early.tutorialHidden = nil
early.deals = nil
table.insert(invalid, early)
for _, corrupt in invalid do
	check(Profile.decode(corrupt, 0) == nil, "invalid, missing or premature counters block loading")
end

-- Lease acquisition migrates a stored v7 record in place without losing data.
local v7 = Profile.encode(state) :: { [string]: any }
v7.schemaVersion = 7
v7.boxesOpened = nil
v7.shelfRewards = nil
v7.lastSeen, v7.offlinePending = nil, nil
v7.lastLoginDay, v7.loginStreak = nil, nil
v7.sfxVolume, v7.musicVolume = nil, nil
v7.tutorialHidden = nil
v7.deals = nil
local database: unknown = { data = v7, token = "", writer = "old", expires = 0, generation = 4 }
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
	"stored v7 record loads through the lease"
)
check(stored.schemaVersion == 14 and stored.boxesOpened == 0, "acquired record is rewritten as v14")
local corruptRecord: unknown = {
	data = invalid[1],
	token = "",
	writer = "old",
	expires = 0,
	generation = 1,
}
database = corruptRecord
local blocked = Persistence.load(update, "Player_2", "join", 1000, 0)
check(blocked == nil and database == corruptRecord, "a corrupt counter never becomes a fresh profile")
-- Open 10: one all-or-nothing grant of ten server rolls.
local tenRolls = { 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.99 }
local ten = Rules.new(0)
ten.coins = price * 10 - 1
check(not Rules.mutate(ten, intent("BuyTen", 0, starter), tenRolls, 10), "nine-and-a-bit boxes of Coins cannot open ten")
check(ten.coins == price * 10 - 1 and ten.boxesOpened == 0 and next(ten.owned) == nil, "rejected Open 10 changes nothing")
ten.coins = price * 10
check(not Rules.mutate(ten, intent("BuyTen", 0, starter), 0.5, 10), "Open 10 without ten rolls fails closed")
local ok, _, single, figures = Rules.mutate(ten, intent("BuyTen", 0, starter), tenRolls, 10)
check(ok and single == nil and figures ~= nil and #figures == 10, "Open 10 returns ten figures")
local granted = 0
for _, count in ten.owned do
	granted += count
end
check(granted == 10 and ten.coins == 0 and ten.boxesOpened == 10 and ten.revision == 1, "ten copies, one charge, one revision")
local nearFull = Rules.new(0)
nearFull.coins = price * 10
for _, figure in Catalog.figures do
	if figure.collection == starter then
		nearFull.owned[figure.id] = Economy.copyLimit - 9
		break
	end
end
check(not Rules.mutate(nearFull, intent("BuyTen", 0, starter), tenRolls, 10), "copy limit is checked for all ten copies")
check(nearFull.coins == price * 10 and nearFull.boxesOpened == 0, "capacity rejection is all-or-nothing")
check(not Rules.mutate(Rules.new(0), intent("BuyTen", 0, starter), tenRolls, 10), "starting Coins cannot open ten")
local tenSession = Transactions.new(0)
tenSession.state.coins = price * 10
local tenRaw = { action = "BuyTen", id = "ten-once", revision = 0, choice = starter }
local tenReply = Transactions.process(tenSession, tenRaw, 0, false, tenRolls, 10)
check(tenReply ~= nil and tenReply.ok and tenReply.figures ~= nil and #tenReply.figures == 10, "remote Open 10 replies with ten figures")
local tenReplay = Transactions.process(tenSession, tenRaw, 0.1, false, tenRolls, 10)
check(tenReplay == tenReply and tenSession.state.boxesOpened == 10, "replayed Open 10 is not recharged")

print(string.format("PASS: %d box counter schema/migration/authority checks", checks))

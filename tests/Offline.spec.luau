--!strict
-- Schema-v10 offline earnings: server-computed award, caps, auto-claim, one-time claim and decoding.
local Rules = require("./Rules")
local Profile = require("./Profile")
local Persistence = require("./Persistence")
local Transactions = require("./Transactions")
local Protocol = require("./Protocol")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local hour = 3600
local function displayed()
	local state = Rules.new(0)
	for index = 1, 3 do
		local id = Catalog.figures[index].id
		state.owned[id], state.discovered[id] = 2, true
		state.display.slots[index] = id
	end
	return state
end

-- Award = floor(rate * min(away, cap) * offlineRate), at the saved Display's full rate.
local state = displayed()
local rate = Rules.rate(state)
check(rate > 0, "fixture Display earns")
state.lastSeen = 1000000
Rules.offline(state, 1000000 + hour)
check(state.offlinePending == math.floor(rate * hour * Economy.offlineRate), "one hour at the offline rate")
check(state.offlineSeconds == hour and state.lastSeen == 1000000 + hour, "absence recorded and clock advanced")
check(state.coins == Economy.startingCoins, "nothing is credited before the claim")

local capped = displayed()
capped.lastSeen = 1000000
Rules.offline(capped, 1000000 + 30 * hour)
check(
	capped.offlinePending == math.floor(rate * Economy.offlineMaxSeconds * Economy.offlineRate)
		and capped.offlineSeconds == Economy.offlineMaxSeconds,
	"accrual stops at the offline cap"
)

for _, case in { { 0, 1000000 + hour, "unknown last save" }, { 1000000, 1000000 + Economy.offlineMinSeconds - 1, "short hop" }, { 1000000 + hour, 1000000, "clock behind last save" } } do
	local skipped = displayed()
	skipped.lastSeen = case[1] :: number
	Rules.offline(skipped, case[2] :: number)
	check(skipped.offlinePending == 0 and skipped.offlineSeconds == 0, (case[3] :: string) .. " awards nothing")
end
local empty = Rules.new(0)
empty.lastSeen = 1000000
Rules.offline(empty, 1000000 + hour)
check(empty.offlinePending == 0 and empty.offlineSeconds == 0, "an empty Display awards nothing")

-- An unclaimed amount from the previous visit auto-claims on the next join, then resets.
local returning = displayed()
returning.lastSeen, returning.offlinePending = 1000000, 500
Rules.offline(returning, 1000000 + 10)
check(returning.coins == Economy.startingCoins + 500 and returning.offlinePending == 0, "leftover auto-claims on join")

-- Claim goes through the normal transaction path exactly once.
local session = Transactions.new(0)
session.state = state
local pendingCoins = state.offlinePending
local raw = { action = "ClaimOffline", id = "offline-1", revision = state.revision }
local reply = Transactions.process(session, raw, 1, false, 0)
check(reply ~= nil and reply.ok and state.coins == Economy.startingCoins + pendingCoins, "claim credits the wallet")
check(state.offlinePending == 0 and state.offlineSeconds == 0, "claim clears the pending amount")
local replay = Transactions.process(session, raw, 2, false, 0)
check(replay ~= nil and replay.ok and state.coins == Economy.startingCoins + pendingCoins, "replayed claim is not paid twice")
local again = Transactions.process(session, { action = "ClaimOffline", id = "offline-2", revision = state.revision }, 3, false, 0)
check(again ~= nil and not again.ok and state.coins == Economy.startingCoins + pendingCoins, "second claim is rejected")
check(Protocol.parse({ action = "ClaimOffline", id = "x", revision = 0, choice = "grove" }) == nil, "claim carries no amount or extra fields")
check(Protocol.parse({ action = "ClaimOffline", id = "x", revision = 0, slot = 1 }) == nil, "claim rejects slots")
local full = displayed()
full.coins, full.offlinePending = Economy.coinLimit - 5, 50
check(Rules.claimOffline(full) == 5 and full.coins == Economy.coinLimit and full.offlinePending == 0, "claim stops at the Coin limit")

-- Persistence: v10 round trip and fail-closed fields; pre-v10 profiles upgrade with nothing awarded.
local saved = displayed()
saved.lastSeen, saved.offlinePending = 1000000, 42
local restored = Profile.decode(Profile.encode(saved), 0)
check(restored ~= nil and restored.lastSeen == 1000000 and restored.offlinePending == 42, "v10 round trip")
check(restored ~= nil and restored.offlineSeconds == 0, "absence length is runtime-only")
for _, field in { "lastSeen", "offlinePending" } do
	for _, value in { -1, 1.5, "5", true, 0 / 0 } do
		local corrupt = Profile.encode(saved) :: { [string]: any }
		corrupt[field] = value
		check(Profile.decode(corrupt, 0) == nil, field .. " corruption fails closed")
	end
	local missing = Profile.encode(saved) :: { [string]: any }
	missing[field] = nil
	check(Profile.decode(missing, 0) == nil, field .. " is required in v10")
end
local tooRich = Profile.encode(saved) :: { [string]: any }
tooRich.offlinePending = Economy.coinLimit + 1
check(Profile.decode(tooRich, 0) == nil, "pending above the Coin limit fails closed")
local v9 = Profile.encode(saved) :: { [string]: any }
v9.schemaVersion = 9
v9.lastLoginDay, v9.loginStreak = nil, nil
v9.sfxVolume, v9.musicVolume = nil, nil
v9.tutorialHidden = nil
check(Profile.decode(v9, 0) == nil, "v9 records cannot carry offline fields")
v9.lastSeen, v9.offlinePending = nil, nil
local upgraded = Profile.decode(v9, 0)
check(upgraded ~= nil and upgraded.lastSeen == 0 and upgraded.offlinePending == 0, "v9 upgrades with unknown last save")
if upgraded then
	Rules.offline(upgraded, 2000000)
	check(upgraded.offlinePending == 0 and upgraded.lastSeen == 2000000, "first v10 join awards nothing and starts the clock")
end

-- Rejoin through the lease: the stored pending amount survives, then auto-claims once.
local database: unknown = { data = Profile.encode(saved), token = "", writer = "old", expires = 0, generation = 1 }
local update: Persistence.Update = function(_, transform)
	local result = transform(database)
	if result then
		database = result
	end
	return result
end
local handle, loaded = Persistence.load(update, "Player_1", "join", 1000000 + hour, 0)
check(handle ~= nil and loaded ~= nil and loaded.offlinePending == 42, "pending survives the lease load")
if handle and loaded then
	Rules.offline(loaded, 1000000 + hour)
	check(loaded.coins == Economy.startingCoins + 42 and loaded.offlinePending > 0, "leftover claimed, new hour pending")
	check(Persistence.save(update, handle, Profile.encode(loaded), 1000000 + hour, true), "release save")
	local _, rejoined = Persistence.load(update, "Player_1", "hop", 1000000 + hour + 1, 0)
	check(rejoined ~= nil and rejoined.lastSeen == 1000000 + hour, "server hop sees the saved clock")
	if rejoined then
		local before = rejoined.coins + rejoined.offlinePending
		Rules.offline(rejoined, 1000000 + hour + 1)
		check(rejoined.coins == before and rejoined.offlinePending == 0, "a quick hop auto-claims and awards nothing new")
	end
end
print(string.format("PASS: %d offline earnings checks", checks))

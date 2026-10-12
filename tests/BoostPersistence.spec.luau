--!strict
local Engine = require("./AfkEngine")
local Storage = require("./Storage")
local Runtime = require("./BoostRuntime")
local Boosts = require("./Boosts")
local Ledger = require("./PurchaseLedger")
local Profile = require("./Profile")
local Rules = require("./Rules")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function entry(token, product)
	return { product = product or "fixture", platformId = 101, kind = "DeveloperProduct", grant = { coins = 0, tokens = { [token] = 1 } } }
end
local function open(userId)
	local session = Storage.open(userId)
	assert(session and session.handle)
	return session
end
-- Actual P02 transforms may run twice; token/marker commit is an independently retried,
-- leased profile operation. Crash between the two values retains recoverable paid value.
local database = {}
local function update(key, transform)
	transform(database[key])
	local saved = transform(database[key])
	if saved then database[key] = saved end
	return saved
end
local s = open(7001)
local record = Ledger.commit(update, 7001, "receipt:abc", entry("Combo2_30"))
check(record ~= nil and s.state.boosts.tokens.Combo2_30 == nil, "P02 reservation grants no timer")
Engine.before = 3
check(not Runtime.fulfill(s, "receipt:abc", record.entries["receipt:abc"], Engine.now), "Failed profile save not acknowledged")
check(not s.ready and s.pendingSave ~= nil and s.state.boostCommitPending, "Pending save freezes gameplay")
check(Rules.luck(s.state) == 1 and Rules.earningFactors(s.state).timedCoinFactor == 1, "Unconfirmed effect suppressed")
check(not Runtime.fulfill(s, "receipt:abc", record.entries["receipt:abc"], Engine.now), "Retry while pending cannot acknowledge")
check(Ledger.load(update, 7001).entries["receipt:abc"] ~= nil, "Paid value remains reserved")
check(Storage.flush(s, false), "Recover exact pending save")
check(s.ready and not s.state.boostCommitPending and s.state.boosts.tokens.Combo2_30 == 1, "Confirmed once")
check(Runtime.fulfill(s, "receipt:abc", record.entries["receipt:abc"], Engine.now), "Receipt replay confirms prior delivery")
check(s.state.boosts.tokens.Combo2_30 == 1 and s.state.boosts.coin == nil, "Replay neither duplicates nor activates")
check(Storage.close(s), "Release lease")
local joined = open(7001)
check(joined.state.boosts.tokens.Combo2_30 == 1, "Unused token survives logout/rejoin")
check(Runtime.fulfill(joined, "receipt:abc", record.entries["receipt:abc"], Engine.now), "Durable marker survives rejoin")
local changed = entry("Luck4_30")
check(not Runtime.fulfill(joined, "receipt:abc", changed, Engine.now), "Changed immutable promise rejected")
check(joined.state.boosts.tokens.Luck4_30 == nil, "Changed promise grants nothing")
local nextRecord = Ledger.commit(update, 7001, "receipt:def", entry("Coins2_15"))
Engine.after = 3
check(not Runtime.fulfill(joined, "receipt:def", nextRecord.entries["receipt:def"], Engine.now), "Lost replies pause acknowledgement")
check(Engine.database.Player_7001.data.boosts.tokens.Coins2_15 == 1, "Save did commit despite lost responses")
check(Storage.flush(joined, false), "Generation reconciliation confirms original aggregate")
check(Runtime.fulfill(joined, "receipt:def", nextRecord.entries["receipt:def"], Engine.now) and joined.state.boosts.tokens.Coins2_15 == 1, "Lost reply recovery exactly once")
local mixed = entry("Coins2_15", "starter")
mixed.grant.coins = 7500
check(not Runtime.fulfill(joined, "pass:starter", mixed, Engine.now), "Mixed bundle refused, no half Starter")
check(joined.state.boosts.tokens.Coins2_15 == 1, "Refused bundle retains current value")
for _, flag in { "closed", "transferring", "busy" } do
	joined[flag] = true
	check(not Runtime.fulfill(joined, "blocked-" .. flag, entry("Luck2_30"), Engine.now), "Lifecycle guard " .. flag)
	joined[flag] = false
end
local oldUntil = joined.safeUntil
joined.safeUntil = Engine.now
check(not Runtime.fulfill(joined, "expired-lease", entry("Luck2_30"), Engine.now), "Expired lease")
joined.safeUntil = oldUntil
check(Profile.decode(Profile.encode(joined.state), 0) ~= nil, "Profile aggregate valid after recovery")
local full = Boosts.empty()
for index = 1, Boosts.maxMarkers do full.deliveries["receipt:" .. index] = { product = "fixture", platformId = 101, token = "Luck2_30", count = 1 } end
check(not Boosts.deliver(full, "receipt:overflow", entry("Luck2_30")), "Paid markers never evicted")
check(full.deliveries["receipt:1"] ~= nil and full.tokens.Luck2_30 == nil, "Capacity keeps reservation recoverable")
check(Storage.close(joined), "Clean final release")
print("Boost persistence:", checks, "checks passed")

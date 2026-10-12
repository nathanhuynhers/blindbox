--!strict
local Rules = require("./Rules")
local Grants = require("./PackageGrants")
local Runtime = require("./PackageRuntime")
local Config = require("./PurchaseConfig")
local Economy = require("./Economy")
local Profile = require("./Profile")
local OfflineAwards = require("./OfflineAwards")
local Boosts = require("./Boosts")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function entry(key, id)
	local product = Config.find(key)
	return { product = key, platformId = id or 101, kind = if key == "starter" then "Pass" else "DeveloperProduct", grant = product.grant }
end
for key, amount in { pack_small = 15000, pack_medium = 60000, pack_large = 240000, pack_huge = 1200000 } do
	local s = Rules.new(0)
	s.earningFactors = { permanentTier = 8, vipFactor = 1.1, timedCoinFactor = 2 }
	local grant = entry(key)
	check(Grants.capacity(s, Config.find(key)), "Capacity " .. key)
	s.coins = Economy.coinLimit - amount
	check(Grants.capacity(s, Config.find(key)), "Exact capacity " .. key)
	s.coins += 1
	check(not Grants.capacity(s, Config.find(key)), "Prompt refuses insufficient space " .. key)
	s.coins = Economy.coinLimit
	check(Grants.deliver(s, "receipt:fixed", grant), "Charged overflow delivered " .. key)
	check(s.packages.assistedCredit == amount and s.coins == Economy.coinLimit, "Exact unmultipled credit, no random-box wallet " .. key)
	check(Grants.deliver(s, "receipt:fixed", grant), "Replay " .. key)
	check(s.packages.assistedCredit == amount, "No duplicate " .. key)
	local changed = entry(key, 102)
	check(not Grants.deliver(s, "receipt:fixed", changed), "Identity collision " .. key)
	local invalid = table.clone(grant)
	invalid.grant = { coins = amount + 1, tokens = {} }
	check(not Grants.deliver(s, "receipt:tampered", invalid), "Exact approved promise " .. key)
	Grants.promote(s)
	check(Profile.decode(Profile.encode(s), 0) ~= nil, "v18 round trip " .. key)
end
for _, stage in { 1, 4, 7 } do
	local s = Rules.new(0)
	s.step, s.boxesOpened = stage, 999
	check(Grants.capacity(s, Config.find("starter")), "Starter has no age/progress restriction")
	check(Grants.deliver(s, "pass:101", entry("starter")), "Starter granted")
	check(s.packages.assistedCredit == 7500 and s.boosts.tokens.Coins2_15 == 1 and s.boosts.coin == nil, "All contents, manual activation")
	check(s.step == stage and s.boxesOpened == 999, "Welcome Quest unaffected")
	check(not Grants.capacity(s, Config.find("starter")), "Lifetime prompt exclusion")
	check(Grants.deliver(s, "pass:101", entry("starter")), "Idempotent reconciliation")
	check(not Grants.deliver(s, "pass:102", entry("starter", 102)), "Lifetime marker survives new identity")
end
local s = Rules.new(0)
s.boosts.tokens.Coins2_15 = 1000000
check(not Grants.deliver(s, "pass:101", entry("starter")), "Token cap refuses whole package")
check(s.packages == nil and s.coins == 4500, "No partial Coin grant or marker")
s.boosts.tokens.Coins2_15 = nil
s.packages = { assistedCredit = Grants.creditLimit, deliveries = {} }
check(not Grants.deliver(s, "pass:101", entry("starter")), "Credit cap refuses whole package")
check(s.boosts.tokens.Coins2_15 == nil and s.packages.starterClaim == nil, "No partial token grant")
s.packages = Grants.empty()
for i = 1, Grants.maxMarkers do s.packages.deliveries["receipt:" .. i] = entry("pack_small") end
check(not Grants.deliver(s, "receipt:new", entry("pack_small")), "Never evict paid markers")
check(Grants.deliver(s, "receipt:1", entry("pack_small")), "Duplicate works at marker capacity")
-- Rate composition, old-income settlement, repeat refresh and UTC claim boundaries.
s = Rules.new(0)
s.owned["grove.pebble"], s.discovered["grove.pebble"], s.display.slots[1] = 2, true, "grove.pebble"
local base = Rules.baseRate(s)
check(Rules.setVip(s, true, true, 10), "VIP verified")
check(math.abs(s.earnings["grove.pebble"] - base * 10) < 1e-6, "Pre-VIP income settled at old rate")
check(not Rules.setVip(s, true, true, 20), "Repeated refresh no stacking")
Rules.setCoinModifiers(s, { verifiedTier = 4, appliedTier = 4, ownershipFresh = true, reason = "Ready" }, 10)
s.paidBoostsAllowed, s.boostClockValid, s.boostWall, s.boostTime = true, true, 1000, 10
s.boosts.coin = { strength = 2, started = 1000, expires = 1900 }
s.boosts.lastClock, s.lastSeen = 1000, 1000
check(math.abs(Rules.rate(s) - base * 4 * 1.1 * 2) < 1e-6, "Highest tier times VIP times shared Coin timer")
local wallet = s.coins
check(Rules.mutate(s, { action = "Daily" }, { 0.1 }, 20, 11), "VIP daily")
check(s.coins == wallet and s.packages.assistedCredit == 500 and s.lastDailyDay == 20, "Atomic fixed daily credit, not multiplied")
check(not Rules.mutate(s, { action = "Daily" }, { 0.1 }, 20, 11) and s.packages.assistedCredit == 500, "Same UTC day no replay")
check(not Rules.mutate(s, { action = "Daily" }, { 0.1 }, 19, 11), "Rollback no claim")
check(Rules.mutate(s, { action = "Daily" }, { 0.1 }, 21, 11) and s.packages.assistedCredit == 1000, "Next UTC day once")
local joined = Profile.decode(Profile.encode(s), 0)
check(joined and joined.lastDailyDay == 21 and not joined.vipOwned and not joined.vipAllowed, "Saved marker retained, ownership must be reverified")
Rules.setVip(joined, true, true, 0)
check(not Rules.mutate(joined, { action = "Daily" }, { 0.1 }, 21, 0), "Rejoin cannot repeat daily")
local view = Grants.view(joined, "vip", true, false, 21)
check(view.dailyClaimed and not view.dailySupplementAvailable, "P08 current daily state")
s = Rules.new(0)
check(Rules.mutate(s, { action = "Daily" }, { 0.1 }, 30, 0), "Free daily before purchase")
Rules.setVip(s, true, true, 1)
check(not Rules.mutate(s, { action = "Daily" }, { 0.1 }, 30, 1) and s.packages == nil, "Late ownership no retroactive supplement")
check(Rules.mutate(s, { action = "Daily" }, { 0.1 }, 31, 1) and s.packages.assistedCredit == 500, "Late owner gets next day")
local priorCount = s.boxesOpened
s.packages.assistedCredit = Grants.creditLimit
check(not Rules.mutate(s, { action = "Daily" }, { 0.1 }, 32, 1) and s.lastDailyDay == 31 and s.boxesOpened == priorCount, "Daily cap retains entire eligible claim")
Rules.setVip(s, true, false, 2)
check(s.earningFactors.vipFactor == 1 and not s.vipAllowed and s.vipOwned, "Policy suppression preserves ownership")
s.packages.assistedCredit = 500
check(Rules.mutate(s, { action = "Daily" }, { 0.1 }, 32, 2) and s.packages.assistedCredit == 1000, "Verified VIP daily promise retained as restricted credit, never spendable")
-- Older saves remain free; package promotion preserves an older pending offline obligation.
s = Rules.new(0)
s.offlinePending = 23
Grants.deliver(s, "pass:101", entry("starter"))
Grants.promote(s)
local encoded = Profile.encode(s)
check(encoded.schemaVersion == 18 and encoded.offlineData.current.normal == 23, "Legacy pending retained across promotion")
check(Profile.decode(encoded, 0) ~= nil, "Legacy pending v18 valid")
local copied = Profile.decode(encoded, 0)
encoded.packages.deliveries["pass:101"].grant.tokens.Coins2_15 = 9
check(copied.boosts.tokens.Coins2_15 == 1 and copied.packages.deliveries["pass:101"].grant.tokens.Coins2_15 == 1, "Deep copies")
encoded = Profile.encode(s)
encoded.packages.starterClaim = nil
check(Profile.decode(encoded, 0) == nil, "Missing durable lifetime marker fails closed")
encoded = Profile.encode(s)
encoded.packages.assistedCredit = 0/0
check(Profile.decode(encoded, 0) == nil, "Malformed credit fails closed")
encoded = Profile.encode(s)
encoded.packages.assistedCredit = 0
check(Profile.decode(encoded, 0) == nil, "Erased purchased credit fails closed")
encoded = Profile.encode(s)
encoded.boosts.tokens = {}
check(Profile.decode(encoded, 0) == nil, "Incomplete Starter token obligation fails closed")
encoded = Profile.encode(s)
encoded.schemaVersion = 17
check(Profile.decode(encoded, 0) == nil, "No downgrade with package data")
local free = Profile.encode(Rules.new(0))
check(free.schemaVersion == 14 and free.packages == nil, "No new writer for free profile")
free.schemaVersion = 19
check(Profile.decode(free, 0) == nil, "Future versions fail closed")
for version = 14, 17 do
	local old = Rules.new(0)
	old.schemaVersion = version
	old.owned["grove.pebble"], old.discovered["grove.pebble"], old.earnings["grove.pebble"] = 9, true, 3.5
	if version == 17 then old.offlineData = OfflineAwards.empty() end
	local loaded = Profile.decode(Profile.encode(old), 0)
	check(loaded and loaded.schemaVersion == version and loaded.packages == nil, "Older valid schema loads without package writer " .. version)
	Grants.deliver(loaded, "pass:101", entry("starter")); Grants.promote(loaded)
	local upgraded = Profile.decode(Profile.encode(loaded), 0)
	check(upgraded and upgraded.schemaVersion == 18 and upgraded.owned["grove.pebble"] == 9 and upgraded.earnings["grove.pebble"] == 3.5, "Package promotion preserves prior progress " .. version)
end
s = Rules.new(0)
Grants.deliver(s, "pass:101", entry("starter")); Grants.promote(s)
check(Boosts.activate(s.boosts, { id = "manual", token = "Coins2_15" }, 1000, 1), "Explicit Starter token activation")
check(Profile.decode(Profile.encode(s), 0) ~= nil, "Consumed Starter token remains valid with durable activation marker")
print("Packages:", checks, "checks passed")

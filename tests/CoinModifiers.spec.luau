--!strict
local Modifiers = require("./CoinModifiers")
local Runtime = require("./CoinModifierRuntime")
local Config = require("./PurchaseConfig")
local Entitlements = require("./Entitlements")
local Rules = require("./Rules")
local Profile = require("./Profile")
local Economy = require("./Economy")
local Persistence = require("./Persistence")
local Service = require("./PurchaseService")
local assertions = 0
local function check(value, message)
	assertions += 1
	assert(value, message)
end
local function near(a, b, message)
	check(math.abs(a - b) < math.max(1e-8, math.abs(b) * 1e-10), message)
end
local products = {}
for index, key in { "coins_2", "coins_4", "coins_8" } do
	local product = table.clone(Config.find(key))
	product.kind, product.platformId, product.integrationReady = "Pass", 100 + index, true
	products[index] = product -- isolated fixture IDs, never production config
end
local state = {}
local function ownership(key)
	return Entitlements.view(state, key)
end
local function resolve(mask, allowed)
	state = {}
	for index, product in products do
		Entitlements.refresh(state, product.key, 7, product.platformId, function()
			return bit32.band(mask, 2 ^ (index - 1)) ~= 0
		end)
	end
	return Modifiers.resolve(products, ownership, allowed)
end
for mask = 0, 7 do
	local expected = if mask >= 4 then 8 elseif mask >= 2 then 4 elseif mask == 1 then 2 else 1
	local view = resolve(mask, true)
	check(view.appliedTier == expected and view.verifiedTier == expected and view.ownershipFresh, "Highest tier combination " .. mask)
	local gated = Modifiers.resolve(products, ownership, false)
	check(gated.appliedTier == 1 and gated.verifiedTier == expected and gated.reason == "ValidationPending", "Policy gate " .. mask)
	local inputs = Modifiers.free()
	inputs.permanentTier = expected
	for _, source in { "Display", "OfflineDisplay", "BankTransfer", "FixedReward", "CoinPack" } do
		check(Modifiers.factor(inputs, source) == (if source == "Display" or source == "OfflineDisplay" then expected else 1), "Source " .. source)
	end
end
check(Modifiers.effectsValidated, "Display effects validated")
local closedProducts = {}
for _, product in Config.products do
 local copy = table.clone(product)
 copy.integrationReady = false
 table.insert(closedProducts, copy)
end
check(Modifiers.resolve(closedProducts, ownership, true).appliedTier == 1, "Configured IDs cannot bypass integration validation")
resolve(7, true)
products[3].integrationReady = false
check(Modifiers.resolve(products, ownership, true).appliedTier == 4, "Unintegrated 8 cannot activate")
products[3].integrationReady = true
local factors = { permanentTier = 8, vipFactor = 1.1, timedCoinFactor = 2 }
near(Modifiers.factor(factors, "Display"), 17.6, "Explicit future composition; no timer or VIP activation")
for _, bad in { 0, 3, 16, math.huge, 0/0 } do
	check(not pcall(Modifiers.factor, { permanentTier = bad, vipFactor = 1, timedCoinFactor = 1 }, "Display"), "Invalid tier rejected")
end
resolve(1, true)
Entitlements.refresh(state, "coins_2", 7, 101, function() error("unavailable") end)
local stale = Modifiers.resolve(products, ownership, true)
check(stale.appliedTier == 2 and not stale.ownershipFresh, "Refresh failure retains verified ownership")
Entitlements.refresh(state, "coins_8", 7, 103, function() error("unavailable") end)
check(Modifiers.resolve(products, ownership, true).appliedTier == 2, "Failure grants no new tier")
Entitlements.refresh(state, "coins_2", 7, 101, function() return false end)
check(Modifiers.resolve(products, ownership, true).appliedTier == 1, "Verified revocation removes tier")

local ids = { "grove.pebble", "grove.sprout", "grove.bloom" }
-- Catalog-independent selection of three Grove IDs avoids assumptions about rarity/art.
local Catalog = require("./Catalog")
table.clear(ids)
for _, figure in Catalog.figures do
	if figure.collection == "grove" and #ids < 3 then table.insert(ids, figure.id) end
end
local function displayed()
	local profile = Rules.new(0)
	for slot, id in ids do
		Rules.grantFigure(profile, id, slot + 1)
		profile.display.slots[slot] = id
	end
	return profile
end
local function apply(profile, tier, now)
	Rules.setCoinModifiers(profile, { verifiedTier = tier, appliedTier = tier, ownershipFresh = true, reason = "Ready" }, now)
end
local profile = displayed()
local base = Rules.baseRate(profile)
check(Rules.bonus(profile) > 0, "Duplicate/trio fixture")
Rules.settle(profile, 5)
local before = table.clone(profile.earnings)
apply(profile, 8, 10)
for _, id in ids do near(profile.earnings[id], before[id] * 2, "Old interval remains free") end
Rules.settle(profile, 12)
for _, id in ids do near(profile.earnings[id], before[id] * 2 + before[id] / 5 * 2 * 8, "New interval boosted once") end
near(Rules.rate(profile), base * 8, "Rate includes duplicates and trio once")
apply(profile, 2, 13)
local bank = table.clone(profile.earnings)
Rules.settle(profile, 14)
for _, id in ids do near(profile.earnings[id] - bank[id], before[id] / 5 * 2, "Mid-interval downgrade") end
local wallet, accumulated = profile.coins, profile.earnings[ids[1]]
Rules.collect(profile, 1, ids[1])
check(profile.coins - wallet == math.floor(accumulated), "Collection never multiplies again")
near(profile.earnings[ids[1]], accumulated % 1, "Fraction conserved")
profile.coins, profile.earnings[ids[1]] = Economy.coinLimit - 3, 100.25
Rules.collect(profile, 1, ids[1])
check(profile.coins == Economy.coinLimit and profile.earnings[ids[1]] == 97.25, "Wallet overflow/fraction retained")
Rules.settle(profile, 1e15)
check(profile.earnings[ids[1]] == Economy.coinLimit, "Per-figure ceiling retained")

local direct = displayed()
apply(direct, 4, 0)
local oldFigureRate = Rules.figureRate(direct, ids[1]) * 1.1 * 4
Rules.adminFigures(direct, { ids[1] }, 1, false, 10)
near(direct.earnings[ids[1]], oldFigureRate * 10, "Duplicate grant settles preceding rate")
local oldTotal = Rules.rate(direct)
Rules.mutate(direct, { action = "Remove", slot = 3 }, 0, 0, 20)
near(direct.earnings[ids[3]], Rules.figureRate(direct, ids[3]) * 1.1 * 4 * 20, "Direct Remove settles old trio")
check(Rules.rate(direct) < oldTotal, "Removed slot/trio no longer earns")
local fixed = displayed()
apply(fixed, 8, 0)
Rules.adminCoins(fixed, "GrantCoins", 500, 0)
check(fixed.coins == Economy.startingCoins + 500, "Fixed grants unchanged")
Rules.mutate(fixed, { action = "Goal" }, 0, 0, 0)
check(fixed.coins == Economy.startingCoins + 500 + Economy.goalReward, "Goal unchanged")
local login = Rules.new(0)
apply(login, 8, 0)
Rules.mutate(login, { action = "Login" }, 0, 1, 0)
check(login.coins == Economy.startingCoins + 500, "Login Coins unchanged")

for _, tier in { 1, 2, 4, 8 } do
	for _, away in { 59, 60, 3600, 21600, 99999 } do
		local saved = displayed()
		apply(saved, tier, 0)
		saved.lastSeen = 1000000
		local encoded = Profile.encode(saved)
		local loaded = Profile.decode(encoded, 0)
		check(loaded ~= nil and loaded.earningFactors.permanentTier == 1, "Saved checkpoint never restores online ownership")
		Rules.offline(loaded, 1000000 + away, true)
		local expected = if away < 60 then 0 else math.floor(base * tier * math.min(away, 21600) * 0.5)
		check(loaded.offlinePending == expected, "Saved normal offline tier/boundary " .. tier .. "/" .. away)
		local gated = Profile.decode(encoded, 0)
		Rules.offline(gated, 1000000 + away, false) -- explicit unknown/restricted policy stays closed
		check(gated.offlinePending == (if away < 60 then 0 else math.floor(base * math.min(away, 21600) * 0.5)), "Offline validation gate")
	end
end
local saved = displayed()
apply(saved, 4, 0)
check(Rules.setConveniencePreference(saved, "auto_collect", true), "Shared P05 toggle setter")
check(not Rules.setConveniencePreference(saved, "unknown", true), "Unknown preference rejected")
saved.lastSeen, saved.offlinePending, saved.earnings[ids[1]] = 1000000, 123, 42.25
local loaded = Profile.decode(Profile.encode(saved), 0)
check(loaded.convenience.autoCollect and not loaded.convenience.movement, "Preferences round trip independently of entitlement")
local preferenceCopy = Profile.encode(saved)
preferenceCopy.convenience.autoCollect = false
check(saved.convenience.autoCollect, "Preference snapshot owns its copy")
apply(loaded, 8, 0)
Rules.offline(loaded, 1003600, true)
check(loaded.coins == Economy.startingCoins + 123 and loaded.offlinePending == math.floor(base * 4 * 3600 * 0.5), "New ownership cannot revalue absence/pending")
check(loaded.earnings[ids[1]] == 42.25, "Offline never revalues existing bank")
for _, inputs in { { permanentTier = 3 }, { permanentTier = 2, surprise = 1 }, { permanentTier = 0/0 }, {} } do
	local bad = Profile.encode(saved)
	bad.earningInputs = inputs
	check(Profile.decode(bad, 0) == nil, "Invalid checkpoint fails closed")
end
local bad = Profile.encode(saved)
bad.earningInputs = nil
check(Profile.decode(bad, 0) == nil, "v15 requires checkpoint")
for _, preferences in { {}, { autoCollect = true, movement = 1 }, { autoCollect = true, movement = false, extra = true } } do
	local corrupt = Profile.encode(saved)
	corrupt.convenience = preferences
	check(Profile.decode(corrupt, 0) == nil, "Invalid convenience preferences fail closed")
end
bad = Profile.encode(saved)
bad.convenience = nil
check(Profile.decode(bad, 0) == nil, "v15 requires preferences")
bad = Profile.encode(saved)
bad.schemaVersion = 14
check(Profile.decode(bad, 0) == nil, "v14 rejects checkpoint rather than silently downgrading")
apply(saved, 1, 0)
check(Profile.encode(saved).schemaVersion == 15, "No backward schema writer after revocation")
local whole, split = displayed(), displayed()
apply(whole, 8, 0)
apply(split, 8, 0)
Rules.settle(whole, 3.25)
for tick = 1, 325 do Rules.settle(split, tick / 100) end
for _, id in ids do near(split.earnings[id], whole.earnings[id], "Split accrual conserves fractions") end
local revision, lesson = split.revision, split.step
local total = split.coins + split.earnings[ids[1]]
Rules.transferBank(split, ids[1])
near(split.coins + split.earnings[ids[1]], total, "Shared transfer helper conserves value")
check(split.revision == revision and split.step == lesson, "Shared helper owns no revision or lesson advancement")

local session = { state = displayed(), ready = true, closed = false, transferring = false,
	busy = false, pendingSave = nil, pendingRelease = nil, safeUntil = 100 }
resolve(7, true)
for _, flag in { "closed", "transferring", "busy" } do
	session[flag] = true
	check(not Runtime.sync(session, products, ownership, true, 10) and session.state.time == 0, "Lifecycle barrier " .. flag)
	session[flag] = false
end
session.ready = false
check(not Runtime.sync(session, products, ownership, true, 10), "Storage failure pause")
session.ready = true
session.pendingSave = Profile.encode(session.state)
check(not Runtime.sync(session, products, ownership, true, 10), "Uncertain save barrier")
session.pendingSave, session.pendingRelease = nil, Profile.encode(session.state)
check(not Runtime.sync(session, products, ownership, true, 10), "Handoff checkpoint immutable")
session.pendingRelease = nil
check(not Runtime.sync(session, products, ownership, true, 100), "Lease expired")
check(Runtime.sync(session, products, ownership, true, 10), "Ready modifier change")
check(not Runtime.sync(session, products, ownership, true, 11), "Repeat does not settle/revise")

-- Aggregate v15 persists with the existing lease, lost-response retry and rejoin protocol.
local database = nil
local lost = false
local function update(_, transform)
	local nextValue = transform(database)
	if nextValue then database = nextValue end
	if lost then error("lost reply after commit") end
	return database
end
apply(saved, 4, 0)
local handle = Persistence.load(update, "Player_7", "first", 1000000, 0)
lost = true
check(not Persistence.save(update, handle, Profile.encode(saved), 1000000, false), "Lost save reply not acknowledged")
lost = false
check(Persistence.save(update, handle, Profile.encode(saved), 1000000, false), "Lost save reconciliation")
check(Persistence.save(update, handle, Profile.encode(saved), 1000001, true), "Release")
local _, rejoin = Persistence.load(update, "Player_7", "second", 1000002, 0)
check(rejoin.schemaVersion == 15 and rejoin.earnings[ids[1]] == 42.25 and rejoin.offlinePending == 123, "v15 bank/pending/checkpoint rejoin")
check(rejoin.earningInputs.permanentTier == 4 and rejoin.convenience.autoCollect, "Tier and P05 preference survive lease/rejoin")

-- Observer runs only after verification; late removed-session results cannot notify a replacement.
local notices, api = 0, nil
local deps = { now = function() return 0 end, ready = function() return true end,
	update = function(_, transform) return transform(nil) end,
	owns = function() return true end, prompt = function() return false end,
	eligible = function() return false end, send = function() end,
	ownershipChanged = function(userId)
		notices += 1
		check(api.ownership(userId, "coins_2") == "Owned", "Observer sees P02 verified state")
	end }
api = Service.create(deps, { products[1] })
api.add(7)
check(notices == 1, "Join ownership observer")
api.finished(7, 101, "Pass", true)
check(notices == 2, "Event re-verifies and notifies")
deps.owns = function() api.remove(7); return true end
api.finished(7, 101, "Pass", true)
check(notices == 2, "Late ownership result suppressed after removal")
check(api.ownership(7, "coins_2") == "Unknown", "Teardown clears verified state")
print("PASS: Coin modifiers " .. assertions .. " checks")

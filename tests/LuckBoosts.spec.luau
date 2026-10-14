--!strict
local Boosts = require("./Boosts")
local Luck = require("./LuckModifiers")
local Rules = require("./Rules")
local Profile = require("./Profile")
local Collection = require("./CollectionEconomy")
local Catalog = require("./Catalog")
local Rarity = require("./Rarity")
local Config = require("./PurchaseConfig")
local Economy = require("./Economy")
local Entitlements = require("./Entitlements")
local Protocol = require("./BoostProtocol")
local Runtime = require("./BoostRuntime")
local Transactions = require("./Transactions")
local Deals = require("./Deals")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function near(a, b, message)
	check(math.abs(a - b) < math.max(1e-9, math.abs(b) * 1e-10), message)
end
local function permit(state, weight, wall, now)
	Rules.syncBoosts(state, { verifiedPermanent = weight, permanent = weight, ownershipFresh = true, reason = "Ready" }, true, wall or 1000000, now or state.time)
end
local function displayed()
	local state = Rules.new(0)
	for index = 1, 3 do
		local id = Catalog.figures[index].id
		Rules.grantFigure(state, id, index + 1)
		state.display.slots[index] = id
	end
	return state
end
local function activate(record, token, id, wall, permanent)
	return Boosts.activate(record, { id = id, token = token, revision = 0 }, wall or 1000000, permanent or 1)
end
-- Production safety stays closed independently of D1/D2 design approval.
check(Boosts.effectsValidated, "Boost effects validated")
for _, policy in { "Allowed", "Restricted", "Unknown" } do
	check(Runtime.allowed({ policy = policy, lineageValidated = true, disclosureReady = true }) == (policy == "Allowed"), "Current policy gate " .. policy)
end
for _, product in Config.products do
	check(product.salesEnabled and product.integrationReady, "Validated catalog enabled")
end
for _, bad in { { id = "x", token = "Luck2_30", revision = 0, luck = 4 }, { id = "x", token = "Luck2_30", revision = 0, expires = 42 },
	{ id = "x", token = "Luck2_30", revision = 0, userId = 1 }, { id = "x", token = "unknown", revision = 0 },
	{ id = "x", token = "Luck2_30", revision = 0/0 }, { id = "", token = "Luck2_30", revision = 0 } } do
	check(Protocol.parse(bad) == nil, "Forged input rejected")
end
-- Real verified entitlement state, including failed refresh and outside-game ownership.
local product = table.clone(Config.find("luck"))
product.kind, product.platformId, product.integrationReady = "Pass", 101, true
local ownership = {}
local function owns(key) return Entitlements.view(ownership, key) end
check(Luck.resolve({ product }, owns, true).permanent == 1, "Unknown grants nothing")
Entitlements.refresh(ownership, "luck", 1, 101, function() return true end)
check(Luck.resolve({ product }, owns, true).permanent == 2, "Verified permanent Luck 2")
check(Luck.resolve({ product }, owns, false).permanent == 1, "Policy suppression")
Entitlements.refresh(ownership, "luck", 1, 101, function() error("unavailable") end)
local stale = Luck.resolve({ product }, owns, true)
check(stale.permanent == 2 and not stale.ownershipFresh, "Prior proof retained on failure")
Entitlements.refresh(ownership, "luck", 1, 101, function() return false end)
check(Luck.resolve({ product }, owns, true).permanent == 1, "Verified revocation")

-- Every current pool, every figure, both no-pity and extreme high demand. Sample each
-- disclosed item's midpoint from its exact interval, proving draw/disclosure agreement.
for _, pity in { {}, { concept = { legendaryDryRolls = 100, mythicalDryRolls = 500 },
	echo = { legendaryDryRolls = 2000, mythicalDryRolls = 66800 }, star = { legendaryDryRolls = 1800, mythicalDryRolls = 65000 } } } do
	for _, weight in { 1, 2, 4 } do
		local odds = Collection.odds(pity, weight)
		for id in Economy.collections do
			local buckets = Collection.buckets(id, pity, weight)
			local total, cursor = 0, 0
			for _, chance in buckets do check(chance >= 0 and chance <= 100, "Valid bucket"); total += chance end
			near(total, 100, "Normalized " .. id)
			for _, rarity in Rarity.order do
				local figureTotal = 0
				for _, figure in Catalog.figures do
					if figure.collection == id and figure.rarity == rarity then
						local chance = odds[figure.id]
						figureTotal += chance
						if chance > 0 then
							local value = (cursor + chance / 2) / 100
							check(Collection.roll(value, id, pity, nil, nil, weight) == figure.id, "Disclosed interval rolls " .. figure.id)
						end
						cursor += chance
					end
				end
				near(figureTotal, buckets[rarity] or 0, "Figure/rarity sum")
			end
			near(cursor, 100, "Individual odds normalized")
			check(Collection.roll(0, id, pity, nil, nil, weight) ~= "", "Lower roll boundary")
			check(Collection.roll(0.9999999999999999, id, pity, nil, nil, weight) ~= "", "Upper roll boundary")
		end
	end
end
near(Collection.buckets("grove", {}, 2).Rare, 100 * 0.2 / 1.1, "Approved starter Luck 2")
near(Collection.buckets("echo", {}, 4).Mythical, 100 * 0.004 / 1.45, "Approved five tier Luck 4")
near(Collection.buckets("grove", {}, 2, "Uncommon").Rare, 40, "Welcome U/R Luck 2")
near(Collection.buckets("grove", {}, 4, "Uncommon").Rare, 400 / 7, "Welcome U/R Luck 4")
for _, weight in { 1, 2, 4 } do
	for _, collection in { "concept", "echo", "star" } do
		local group = Economy.collections[collection].group
		for _, dry in { { 2019, 66899 }, { 2020, 0 }, { 0, 66900 }, { 2020, 66900 } } do
			local pity = { [group] = { legendaryDryRolls = dry[1], mythicalDryRolls = dry[2] } }
			local buckets = Collection.buckets(collection, pity, weight)
			if dry[2] >= 66900 then near(buckets.Mythical, 100, "Mythical guarantee priority")
			elseif dry[1] >= 2020 then near(buckets.Legendary, 100, "Legendary guarantee") end
			if dry[1] == 2020 and dry[2] == 66900 then
				local figure = Collection.roll(0.5, collection, pity, nil, nil, weight)
				Collection.advance(pity, collection, figure)
				check(pity[group].legendaryDryRolls == 2021 and pity[group].mythicalDryRolls == 0, "Independent guarantee resets")
				near(Collection.buckets(collection, pity, weight).Legendary, 100, "Second guarantee follows")
			end
		end
	end
end

-- All paid/free grant paths use the same owner Luck. Restrictions and unknown policy
-- use identical base/free-pity results; free claims are never denied by the paid gate.
for _, action in { "Buy", "BuyTen", "Deal", "Daily", "Login", "Welcome", "WelcomeTen" } do
	for _, allowed in { true, false } do
		local state = Rules.new(0)
		permit(state, 2)
		if not allowed then Rules.syncBoosts(state, Luck.free(), false, 1000000, 0) end
		state.coins = 10000000
		local choice, slot, window = "grove", nil, nil
		if action == "WelcomeTen" then state.step = 5 end
		if action == "Login" then state.lastLoginDay, state.loginStreak = 0, 2 end
		if action == "Deal" then slot, window = 1, 10; choice = Deals.offers(window)[slot] end
		local rolls = table.create(10, 0.85)
		local beforePity = {}
		local minimum = if action == "Welcome" then "Uncommon" else nil
		local expected = Collection.roll(0.85, choice, beforePity, minimum, nil, if allowed then 2 else 1)
		local ok, _, figure, figures = Rules.mutate(state, { action = action, choice = choice, slot = slot, window = window }, rolls, 1, 0, window)
		check(ok, "Supported path " .. action)
		check((figure or figures[1]) == expected, "Same Luck on " .. action .. "/" .. tostring(allowed))
	end
end
local batch = Rules.new(0)
batch.coins = 10000000
permit(batch, 4)
batch.pityByGroup.echo = { legendaryDryRolls = 2020, mythicalDryRolls = 66900 }
local ok, _, _, figures = Rules.mutate(batch, { action = "BuyTen", choice = "echo" }, table.create(10, 0.5), 1, 0)
check(ok and Catalog.byId[figures[1]].rarity == "Mythical" and Catalog.byId[figures[2]].rarity == "Legendary", "Batch advances sequential pity")
local free = Rules.new(0)
for _, figure in Catalog.figures do near(Collection.odds({}, 1)[figure.id], Rules.odds[figure.id], "Exact free baseline") end
check(Rules.luck(free) == 1, "New/free Luck unchanged")

-- All approved SKUs, delivery idempotency and immutable P02 promises.
for token, benefit in Config.tokenBenefits do
	local record = Boosts.empty()
	local entry = { product = "fixture", platformId = 200, kind = "DeveloperProduct", grant = { coins = 0, tokens = { [token] = 1 } } }
	check(Boosts.deliver(record, "receipt-1", entry), "Token delivered " .. token)
	check(Boosts.deliver(record, "receipt-1", entry) and record.tokens[token] == 1, "Duplicate receipt")
	check(Boosts.deliver(record, "receipt-2", entry) and record.tokens[token] == 2, "Genuine repurchase")
	check(activate(record, token, "activation-1"), "Activate " .. token)
	check(record.tokens[token] == 1, "One token consumed")
	if benefit.coins > 1 then check(record.coin.expires == 1000000 + benefit.seconds, "Coin duration") end
	if benefit.luck > 1 then check(record.luck.expires == 1000000 + benefit.seconds, "Luck duration") end
	check(activate(record, token, "activation-1", 1000001) and record.tokens[token] == 1, "Activation replay")
	check(activate(record, token, "activation-2", 1000001), "Compatible extension")
	if benefit.coins > 1 then check(record.coin.expires == 1000000 + 2 * benefit.seconds, "Shared Coin extension") end
	if benefit.luck > 1 then check(record.luck.expires == 1000000 + 2 * benefit.seconds, "Shared Luck extension") end
	check(Boosts.decode(Boosts.copy(record)) ~= nil, "Strict boost round trip")
end
local combo = Boosts.empty()
combo.tokens = { Combo2_30 = 2, Luck4_30 = 1, Coins2_60 = 1 }
check(activate(combo, "Luck4_30", "l4"), "Luck 4 timer")
check(not activate(combo, "Combo2_30", "combo"), "Incompatible combo rejected")
check(combo.coin == nil and combo.tokens.Combo2_30 == 2, "No half combo")
check(not activate(combo, "Combo2_30", "redundant", 1000000, 2), "Permanent Luck redundancy")
check(activate(combo, "Combo2_30", "after-expiry", 1001800), "Strength switch exactly at expiry")
check(combo.coin.expires == combo.luck.expires and combo.tokens.Combo2_30 == 1, "Coherent combo activation")
check(activate(combo, "Coins2_60", "coin-only", 1001801), "Coin-only shares combo timer")
check(combo.coin.expires == 1007200 and combo.luck.expires == 1003600, "Component extension only")
local bounded = Boosts.empty()
bounded.tokens = { Coins2_60 = 25, Combo2_30 = 1 }
for index = 1, 24 do check(activate(bounded, "Coins2_60", "bound-" .. index), "24-hour extension") end
check(not activate(bounded, "Coins2_60", "too-long") and bounded.tokens.Coins2_60 == 1, "Queue over bound, retain token")
check(not activate(bounded, "Combo2_30", "half-bound") and bounded.luck == nil and bounded.tokens.Combo2_30 == 1, "Combo bound atomicity")
check(not activate(bounded, "Coins2_60", "rollback", 999999), "Backward activation refused")
check(not activate(bounded, "Coins2_60", "impossible", math.huge), "Impossible activation refused")

-- Accurate online overlap, duplicate/trio bonuses, fractions and existing banks.
for _, tier in { 1, 2, 4, 8 } do
	for _, vip in { 1, 1.1 } do
		local state = displayed()
		state.earningFactors.permanentTier, state.earningFactors.vipFactor = tier, vip
		state.schemaVersion = 16
		permit(state, 1)
		state.boosts.tokens.Coins2_15 = 1
		Rules.settle(state, 5)
		check(activate(state.boosts, "Coins2_15", "start", 1000005), "Activate after old interval")
		Rules.settle(state, 1000) -- scheduler deliberately late, 900s paid + 100s free
		for _, id in state.display.slots do near(state.earnings[id], Rules.figureRate(state, id) * 1.1 * tier * vip * 1900, "Delayed expiry segmented") end
		near(Rules.rate(state), Rules.baseRate(state) * tier * vip, "Expired current rate")
		local before = state.earnings[state.display.slots[1]]
		local wallet = state.coins
		Rules.collect(state, 1, state.display.slots[1])
		check(state.coins - wallet == math.floor(before), "Collection transfers once")
		near(state.earnings[state.display.slots[1]], before % 1, "Fraction retained")
	end
end
local crossing = displayed()
crossing.schemaVersion = 16
crossing.boosts.tokens.Combo2_30 = 1
permit(crossing, 1)
check(activate(crossing.boosts, "Combo2_30", "cross"), "Crossing combo")
Rules.settle(crossing, 1799.75)
check(Rules.luck(crossing) == 2, "Before Luck expiry")
Rules.settle(crossing, 1800)
check(Rules.luck(crossing) == 1 and Rules.boostView(crossing).coinRemaining == 0, "Exact expiry ends both")
permit(crossing, 2, 1001800, 1800)
check(Rules.luck(crossing) == 2, "Permanent survives timed expiry")
local rollback = displayed()
rollback.schemaVersion = 16
rollback.boosts.tokens.Combo2_30 = 1
permit(rollback, 1)
activate(rollback.boosts, "Combo2_30", "rollback-test")
Rules.syncBoosts(rollback, rollback.luckModifiers, true, 999999, 10)
check(not rollback.boostClockValid and Rules.luck(rollback) == 1, "Clock reversal suppresses paid Luck")
near(rollback.earnings[rollback.display.slots[1]], Rules.figureRate(rollback, rollback.display.slots[1]) * 1.1 * 10, "Uncertain interval baseline only")

-- Eligible saved overlap inside the FIRST six-hour cap; return-active timer ignored.
for _, away in { 59, 60, 900, 1800, 21600, 40000 } do
	for _, eligible in { true, false } do
		local state = displayed()
		state.schemaVersion = 16
		state.earningFactors.permanentTier = 4
		permit(state, 1)
		state.boosts.tokens.Coins2_15 = 1
		activate(state.boosts, "Coins2_15", "saved")
		state.lastSeen = 1000100
		Rules.settle(state, 100)
		local encoded = Profile.encode(state)
		local loaded = Profile.decode(encoded, 0)
		check(loaded ~= nil and loaded.earningFactors.permanentTier == 1 and Rules.luck(loaded) == 1, "Save not ownership proof")
		check(Profile.encode(loaded).earningInputs.timedCoin.expires == 1000900, "Lease reencode retains checkpoint")
		Rules.offline(loaded, state.lastSeen + away, eligible)
		local capped = math.min(away, Economy.offlineMaxSeconds)
		local expected = if away < 60 then 0 else math.floor(Rules.baseRate(state) * 0.5 * (if eligible then 4 * (capped + math.min(800, capped)) else capped))
		check(loaded.offlinePending == expected, "Normal N saved overlap " .. away)
		local n = loaded.offlinePending
		permit(loaded, 2, state.lastSeen + away)
		check(loaded.offlinePending == n, "New entitlement cannot reprice N")
	end
end
local restricted = displayed()
restricted.schemaVersion = 16
restricted.boosts.tokens.Coins2_15 = 1
permit(restricted, 1)
activate(restricted.boosts, "Coins2_15", "r")
Rules.syncBoosts(restricted, Luck.free(), false, 1000100, 100)
restricted.lastSeen = 1000100
check(Profile.encode(restricted).earningInputs.timedCoin == nil, "Suppressed saved timer is ineligible offline")

for _, invalidWall in { -1, 0, 0/0, math.huge, 100000000001, 1000000.5 } do
	local saved = displayed()
	saved.schemaVersion, saved.lastSeen = 16, 1000000
	saved.boosts.lastClock = 1000000
	Rules.offline(saved, invalidWall, true)
	check(saved.offlinePending == 0 and saved.lastSeen == 1000000 and not saved.boostClockValid, "Impossible offline clock fails closed without poisoning save")
	check(Profile.decode(Profile.encode(saved), 0) ~= nil, "Valid profile preserved after clock failure")
end
local returned = displayed()
returned.schemaVersion, returned.lastSeen = 16, 1000000
returned.earningInputs = { permanentTier = 1, vipFactor = 1 }
returned.boosts.coin = { strength = 2, started = 1003590, expires = 1004490 }
returned.boosts.lastClock = 1003590
Rules.offline(returned, 1003600, true)
check(returned.offlinePending == math.floor(Rules.baseRate(returned) * 1800), "Return-active timer never reprices absence")

-- Decoder must refuse corrupt/new shapes rather than reset progress or paid value.
for _, bad in { -1, 0/0, math.huge, 1.5, "100" } do
	local raw = Boosts.empty(); raw.lastClock = bad
	check(Boosts.decode(raw) == nil, "Invalid UTC fails closed")
end
for _, raw in { { lastClock = 100, tokens = {}, deliveries = {}, activations = {}, coin = { strength = 4, started = 1, expires = 100 } },
	{ lastClock = 100, tokens = { Unknown = 1 }, deliveries = {}, activations = {} },
	{ lastClock = 100, tokens = { Luck2_30 = -1 }, deliveries = {}, activations = {} },
	{ lastClock = 100, tokens = {}, deliveries = {}, activations = {}, luck = { strength = 2, started = 1, expires = 90000 } },
	{ lastClock = 0, tokens = {}, deliveries = {}, activations = {}, injected = true } } do
	check(Boosts.decode(raw) == nil, "Invalid boost record")
end
local legacy = Profile.encode(displayed())
check(legacy.schemaVersion == 14 and legacy.boosts == nil, "Free writer unchanged")
legacy.boosts = Boosts.empty()
check(Profile.decode(legacy, 0) == nil, "No boost fields smuggled into old schema")
local promoted = displayed()
promoted.schemaVersion = 16
promoted.boosts.tokens.Luck4_30 = 1
local encoded = Profile.encode(promoted)
check(Profile.decode(encoded, 0) ~= nil, "v16 unused tokens survive rejoin")
encoded.boosts.tokens.Luck4_30 = 2
check(promoted.boosts.tokens.Luck4_30 == 1, "Save deeply copied")
encoded.earningInputs.vipFactor = nil
check(Profile.decode(encoded, 0) == nil, "v16 checkpoint fields required")
print("Luck/boost domain:", checks, "checks passed")

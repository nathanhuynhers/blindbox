--!strict
-- Production economy/protocol modules; no native rendering or DataStore claims.
local Catalog = require("./Catalog")
local Economy = require("./Economy")
local Collection = require("./CollectionEconomy")
local Rules = require("./Rules")
local Profile = require("./Profile")
local Rarity = require("./Rarity")
local UI = require("./UIState")
local Currency = require("./Currency")
local AutoOpen = require("./AutoOpen")
local Ledger = require("./PurchaseLedger")
local Transactions = require("./Transactions")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function near(a, b)
	return math.abs(a - b) <= 1e-10 * math.max(1, math.abs(b))
end
-- Approved prices and category counts, independently pinned to the approved roster.
local fixtures = {
	moon = {2000000, 3, 3, 2, 4, 1}, dessert = {10000000, 2, 2, 2, 3, 1},
	halloween = {10000000, 2, 2, 3, 2, 1}, chess = {50000000, 1, 1, 2, 1, 1},
	emotion = {250000000, 2, 3, 2, 2, 1}, astral = {1250000000, 2, 3, 4, 3, 1},
	biome = {6250000000, 1, 1, 1, 2, 1}, weather = {6250000000, 1, 1, 0, 2, 3},
	sense = {31250000000, 1, 1, 1, 1, 1}, olympian = {156250000000, 2, 1, 3, 2, 2},
	birthstone = {781250000000, 1, 1, 0, 6, 2}, sin = {3906250000000, 1, 0, 3, 3, 1},
	orbit = {19531250000000, 1, 0, 0, 7, 1},
}
local budgets = {0, 25, 13.9, 1, 0.1}
local baseOdds = Collection.odds({})
local newCount = 0
for id, fixture in fixtures do
	check(Rules.prices[id] == fixture[1], "Exact approved price: " .. id)
	check(Rules.prices[id] * 10 == fixture[1] * 10 and fixture[1] * 10 < Currency.limit, "Safe exact Open 10: " .. id)
	local expected, common = {}, 100
	for index, rarity in Rarity.order do
		if index > 1 then
			expected[rarity] = if fixture[index + 1] > 0 then budgets[index] else 0
			common -= expected[rarity]
		end
	end
	expected.Common = common
	local distribution = Collection.buckets(id, {})
	local total, expectedRate = 0, 0
	for index, rarity in Rarity.order do
		check(near(distribution[rarity] or 0, expected[rarity]), "Absent budgets go only to Common: " .. id .. rarity)
		local count = 0
		for _, figure in Catalog.figures do
			if figure.collection == id and figure.rarity == rarity then
				count += 1
				newCount += 1
				check(near(baseOdds[figure.id], expected[rarity] / fixture[index + 1]), "Equal figure share: " .. figure.id)
				total += baseOdds[figure.id]
				expectedRate += baseOdds[figure.id] / 100 * Rules.rates[figure.id]
			end
		end
		check(count == fixture[index + 1], "Approved rarity count: " .. id .. rarity)
	end
	check(near(total, 100), "Base probabilities sum to 100: " .. id)
	check(near(expectedRate, Economy.collections[id].expectedIncome), "Income uses actual collection distribution: " .. id)
	for _, luck in {1, 2, 4} do
		for _, dry in {0, 41, 500, 2020, 66900, Economy.counterLimit} do
			local pity = {[id] = {legendaryDryRolls = dry, mythicalDryRolls = dry}}
			local odds = Collection.odds(pity, luck)
			local snapshot = {odds = odds, baseOdds = baseOdds} :: any
			local buckets = Collection.buckets(id, pity, luck)
			local cursor = 0
			for _, rarity in Rarity.order do
				local category = 0
				for _, figure in Catalog.figures do
					if figure.collection == id and figure.rarity == rarity then
						local chance = odds[figure.id]
						check(chance >= 0 and UI.figureOdds(snapshot, figure.id) == chance, "Displayed odds are exact server odds")
						if chance > 0 then
							check(Collection.roll((cursor + chance / 2) / 100, id, pity, nil, nil, luck) == figure.id, "Actual roll interval matches disclosure: " .. figure.id)
						end
						cursor += chance
						category += chance
					end
				end
				check(near(category, buckets[rarity] or 0), "Rarity disclosure agrees with figures")
			end
			check(near(cursor, 100), "Pity and Luck preserve total probability")
			for _, row in UI.rarityOdds(snapshot, id) do
				check(near(row.total, buckets[row.rarity]), "Shop totals agree with roll distribution")
			end
			for _, value in {0, 0.5, 0.999999999999} do
				check(Catalog.byId[Collection.roll(value, id, pity, nil, nil, luck)].collection == id, "Roll remains in collection")
			end
		end
		for _, minimum in {"Uncommon", "Rare", "Legendary", "Mythical"} do
			local conditioned = Collection.buckets(id, {}, luck, minimum)
			local sum = 0
			for rarity, chance in conditioned do
				sum += chance
				check(chance == 0 or fixture[(table.find(Rarity.order, rarity) :: number) + 1] > 0, "Reward conditioning cannot invent absent rarity")
			end
			check(near(sum, 100), "Conditioned probability totals 100")
			for _, value in {0, 0.2, 0.999999999999} do
				local figure = Catalog.byId[Collection.roll(value, id, {}, minimum, nil, luck)]
				check((table.find(Rarity.order, figure.rarity) :: number) >= (table.find(Rarity.order, minimum) :: number), "Sparse reward floor is honored")
			end
		end
	end
end
check(newCount == 117 and #Catalog.figures == 160 and #Catalog.collections == 18, "Complete authorized catalog")
check(near(baseOdds["orbit.earth"], 98.9) and near(baseOdds["orbit.mercury"], 1 / 7), "Pocket Orbit example")
check(near(baseOdds["weather.fog"], 73.9) and near(baseOdds["weather.rain"], 0.1 / 3), "Weather example")
check(near(baseOdds["birthstone.peridot"], 73.9) and near(baseOdds["birthstone.opal"], 0.05), "Birthstones example")
check(Economy.expansionCosts[4] == 1000000, "Fourth Display price")
check(Economy.offlineRate == 0.5 and Economy.offlineMaxSeconds == 21600, "Offline tuning unchanged")
check(not pcall(Collection.roll, 0.5, "orbit", {}, nil, "Rare"), "Debug cannot force absent rarity")
check(not pcall(Collection.roll, 0/0, "orbit", {}) and not pcall(Collection.roll, math.huge, "orbit", {}), "Invalid roll numbers rejected")

local legacy = {
	["grove.pebble"] = {20.0, 4.3035993740219105},
	["grove.sprout"] = {20.0, 4.890453834115807},
	["grove.acorn"] = {20.0, 5.477308294209703},
	["grove.mushroom"] = {15.0, 9.389671361502348},
	["grove.moth"] = {15.0, 10.954616588419405},
	["grove.star"] = {10.0, 23.47417840375587},
	["tide.bubble"] = {20.0, 5.7381324986958795},
	["tide.coral"] = {20.0, 6.520605112154408},
	["tide.shell"] = {20.0, 7.303077725612937},
	["tide.jelly"] = {15.0, 12.519561815336465},
	["tide.ray"] = {15.0, 14.606155451225874},
	["tide.pearl"] = {10.0, 31.29890453834116},
	["concept.verity"] = {60.0, 18.644194197926765},
	["concept.falsity"] = {25.0, 38.77992393168767},
	["concept.cruelty"] = {13.9, 89.49213215004846},
	["concept.lovity"] = {1.0, 238.64568573346259},
	["concept.verity-true-form"] = {0.1, 656.2756357670221},
	["echo.thread-parade"] = {15.0, 106.16223519760653},
	["echo.wander-knit"] = {15.0, 115.81334748829802},
	["echo.dino-drift"] = {15.0, 125.46445977898952},
	["echo.still-pebble"] = {15.0, 135.115572069681},
	["echo.hearth-helm"] = {8.333333333333334, 231.62669497659604},
	["echo.echo-line"] = {8.333333333333334, 250.92891955797904},
	["echo.paper-crown"] = {8.333333333333334, 270.231144139362},
	["echo.mask-nuzzle"] = {4.633333333333334, 540.462288278724},
	["echo.hush-veil"] = {4.633333333333334, 579.0667374414901},
	["echo.crate-spark"] = {4.633333333333334, 617.671186604256},
	["echo.feather-hush"] = {0.5, 1447.6668436037253},
	["echo.mumble-beast"] = {0.5, 1640.6890894175551},
	["echo.moon-doze"] = {0.1, 4246.489407904261},
	["star.reminiscence"] = {15.0, 106.16223519760653},
	["star.mirrorlight"] = {15.0, 115.81334748829802},
	["star.wishing"] = {15.0, 125.46445977898952},
	["star.page-turner"] = {15.0, 135.115572069681},
	["star.nightlight"] = {8.333333333333334, 231.62669497659604},
	["star.lamplight"] = {8.333333333333334, 250.92891955797904},
	["star.garden"] = {8.333333333333334, 270.231144139362},
	["star.sanctuary"] = {4.633333333333334, 540.462288278724},
	["star.echo"] = {4.633333333333334, 579.0667374414901},
	["star.radiant"] = {4.633333333333334, 617.671186604256},
	["star.cloud-rest"] = {0.5, 1447.6668436037253},
	["star.meteor-shower"] = {0.5, 1640.6890894175551},
	["star.dreamcatcher"] = {0.1, 4246.489407904261},
}
for id, values in legacy do
 check(near(baseOdds[id], values[1]) and near(Rules.rates[id], values[2]), "Original odds/income unchanged: " .. id)
end

-- The same suite also runs with isolated content-ready metadata, exercising every real
-- BuyTen transaction without pretending that unuploaded production assets exist.
for id, fixture in fixtures do
 local session = Transactions.new(0)
 -- Existing permanent Birthstone discoveries qualify the highest required tier, so
 -- these transaction fixtures continue testing economics after access is introduced.
 for _, figure in Catalog.figures do
  if figure.collection == "birthstone" and figure.rarity ~= "Mythical" then
   session.state.discovered[figure.id] = true
  end
 end
 session.state.coins = fixture[1] * 10 + 17
 local rolls = {0,0.05,0.1,0.2,0.4,0.5,0.6,0.7,0.9,0.999999}
 local raw = {action="BuyTen", id="batch:"..id, revision=0, choice=id}
 local reply = Transactions.process(session, raw, 0, false, rolls, 1)
 if Catalog.comingSoon[id] then
  check(reply and not reply.ok and session.state.coins == fixture[1]*10+17 and session.state.boxesOpened == 0, "Pending models cannot be silently sold")
 else
  check(reply and reply.ok and #reply.figures == 10 and session.state.coins == 17 and session.state.boxesOpened == 10, "Actual Open 10 total: "..id)
  check(Transactions.process(session, raw, 0.1, false, rolls, 1) == reply and session.state.coins == 17, "Large batch replay cannot charge twice")
  check(Profile.decode(Profile.encode(session.state),0) ~= nil, "New purchases save and reload")
 end
end
local reserved = Ledger.empty()
for i=1,9 do reserved.entries["receipt:"..i] = {product="large", platformId=1, kind="DeveloperProduct", grant={coins=Currency.limit,tokens={}}} end
check(Ledger.decode(reserved) ~= nil and Ledger.summary(reserved).coins == Currency.limit * 9, "Large receipt promises retain exact cumulative total")
local durable = assert(Ledger.decode(reserved))
local writes = 0
local function update(_, transform)
	local changed = transform(durable)
	if changed then durable = changed; writes += 1 end
	return changed
end
local tenth = {product="large", platformId=1, kind="DeveloperProduct", grant={coins=Currency.limit,tokens={}}}
check(Ledger.commit(update, 1, "receipt:10", tenth) == nil and writes == 0, "Unsafe cumulative promise is refused before a durable write")
check(Ledger.decode(durable) ~= nil and Ledger.summary(durable).coins == Currency.limit * 9, "Refused receipt leaves prior paid recovery promises valid")
reserved.entries["receipt:10"] = {product="large", platformId=1, kind="DeveloperProduct", grant={coins=Currency.limit,tokens={}}}
check(Ledger.decode(reserved) == nil, "Unsafe cumulative receipt promise fails closed")

local price = 19531250000000
local state = Rules.new(0)
state.coins = price * 10 + 17
Rules.grantFigure(state, "orbit.earth", 2)
Rules.grantFigure(state, "moon.rat", 3)
state.display.slots[1] = "orbit.earth"
state.earnings["orbit.earth"] = Currency.limit - 1.375
state.pityByGroup.moon = {legendaryDryRolls=111, mythicalDryRolls=555}
local saved = Profile.encode(state)
local loaded = assert(Profile.decode(saved, 0))
check(loaded.coins == state.coins and loaded.earnings["orbit.earth"] == state.earnings["orbit.earth"], "Large wallet and fractional bank survive serialization")
check(loaded.owned["moon.rat"] == 3 and loaded.discovered["moon.rat"] and loaded.pityByGroup.moon.mythicalDryRolls == 555, "Existing stable IDs and pity retained")
check(Catalog.byId["moon.rat"].rarity == "Uncommon" and Catalog.byId["moon.rabbit"].rarity == "Legendary", "Approved Moonrace metadata reconciled")
for _, value in {-1, 0/0, math.huge, -math.huge, Currency.limit + 1, 1.5} do
	local bad = table.clone(saved)
	bad.coins = value
	check(Profile.decode(bad, 0) == nil, "Invalid wallet fails closed")
	bad = table.clone(saved)
	bad.earnings = {["orbit.earth"] = value}
	if value ~= 1.5 then check(Profile.decode(bad, 0) == nil, "Invalid bank fails closed") end
end
local oldBank = loaded.earnings["orbit.earth"]
loaded.coins = Currency.limit - 23
check(Rules.transferBank(loaded, "orbit.earth") == 23 and loaded.coins == Currency.limit, "Large collection stops at wallet ceiling")
check(loaded.earnings["orbit.earth"] == oldBank - 23 and loaded.earnings["orbit.earth"] % 1 == 0.625, "Bank overflow and fraction retained")
check(Profile.decode(Profile.encode(loaded), 0) ~= nil, "Overflow state saves and reloads")
local offline = Rules.new(0)
Rules.grantFigure(offline, "orbit.pluto", 1)
offline.display.slots[1] = "orbit.pluto"
offline.lastSeen = 1000000
Rules.offline(offline, 1000000 + 21600)
check(offline.offlinePending > 1e12 and offline.offlinePending <= Currency.limit, "Offline awards above one trillion")
check(Profile.decode(Profile.encode(offline), 0) ~= nil, "Large offline aggregate reloads")
local amount = offline.offlinePending
check(Rules.claimOffline(offline) == amount and Rules.claimOffline(offline) == 0, "Large award claims once")
check(UI.number(price * 10) == "195,312,500,000,000" and UI.number(Currency.limit) == "1,000,000,000,000,000", "Exact-value text avoids scientific notation")
check(UI.compact(Currency.limit) == "1Qa" and UI.compact(price) == "19.5T", "Large abbreviations")

local balance, calls = price * 2 + 100, 0
local auto = AutoOpen.create({
	now = function() return 0 end, id = function() return "large-auto" end,
	context = function() return {ready=true,alive=true,owned=true,fresh=true,policyAllowed=true,flowActive=true,busy=false,cooldownReady=true,price=price,spendable=balance} end,
	purchase = function(_, _, reserve)
		check(balance - price >= reserve, "Reserve evaluated with large balance")
		calls += 1; balance -= price
		return {id="large-auto",ok=true,message="Bought",figure="orbit.earth"}
	end,
	reconcile = function() return nil end, deliver = function() end,
})
check(auto.start("orbit", 1, price + 100), "Auto Open accepts large reserve")
auto.step()
check(calls == 1 and balance == price + 100, "Large Auto Open charges exactly once")
auto.destroy()
print("PASS:", checks, "new collection distributions, sparse pity/Luck/rewards, large currency and progress checks")

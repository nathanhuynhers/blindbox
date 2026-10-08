--!strict
-- Real server economy/transactions/profile: linear growth, probability budget and guarantees.
local Config = require("./Economy")
local Economy = require("./CollectionEconomy")
local Catalog = require("./Catalog")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Profile = require("./Profile")
local checks = 0
local function check(value: boolean, message: string)
	checks += 1
	assert(value, message)
end
local function near(a: number, b: number): boolean return math.abs(a - b) < 1e-8 end
local function counters(collection: string, legendary: number, mythical: number)
	return {[Config.collections[collection].group] = {legendaryDryRolls = legendary, mythicalDryRolls = mythical}}
end
local samples = {0, 40, 41, 180, 181, 300, 301, 1567, 2018, 2019, 2020, 2021, 66899, 66900, 66901, 1000000}
for _, collection in {"concept", "echo", "star"} do
	local curve = Config.pity[Config.collections[collection].pity]
	check(curve.Legendary.maximum == nil and curve.Mythical.maximum == nil, "no configured 8/2 caps")
	local before = Economy.buckets(collection, counters(collection, 180, 1567))
	local after = Economy.buckets(collection, counters(collection, 181, 1568))
	check(near(before.Legendary, 8) and after.Legendary > 8, "Legendary keeps growing past old cap")
	check(before.Mythical > 2 and after.Mythical > before.Mythical, "Mythical keeps growing past old cap")
	check(near(after.Legendary - before.Legendary, 0.05)
		and near(after.Mythical - before.Mythical, 0.0015), "original linear increments preserved")
	for _, legendary in samples do
		for _, mythical in samples do
			local odds = Economy.buckets(collection, counters(collection, legendary, mythical))
			local sum = 0
			for _, chance in odds do
				check(chance == chance and chance >= 0 and chance <= 100, "all mixed-drought odds are valid")
				sum += chance
			end
			check(near(sum, 100), "every mixed-drought distribution totals 100")
			if mythical >= 66900 then
				check(odds.Mythical == 100 and odds.Legendary == 0, "Mythical guarantee takes priority")
			elseif legendary >= 2020 then
				check(odds.Legendary == 100 and odds.Mythical == 0, "Legendary guarantee is exact")
			else
				check(odds.Legendary < 100 and odds.Mythical < 100, "no early guarantee")
			end
		end
	end
	for _, rarity in {"Legendary", "Mythical"} do
		local pity = counters(collection, if rarity == "Legendary" then 2020 else 0,
			if rarity == "Mythical" then 66900 else 0)
		for _, roll in {0, 0.000001, 0.25, 0.5, 0.9, 0.9999999999999999} do
			local id = Economy.roll(roll, collection, pity)
			check(Catalog.byId[id].rarity == rarity, "guaranteed tier wins for every random boundary")
		end
		local id = Economy.roll(0, collection, pity)
		Economy.advance(pity, collection, id)
		local progress = Economy.pityProgress(pity)[collection]
		check(progress[rarity] == 0, "guaranteed hit resets its own meter")
	end
	local shared = counters(collection, 2019, 66899)
	local odds = Economy.buckets(collection, shared)
	check(near(odds.Legendary / odds.Mythical, 99.95 / 99.9985), "overlapping demands share budget proportionally")
	check(odds.Common == 0 and odds.Uncommon == 0 and odds.Rare == 0, "overlap cannot make lower odds negative")
	check(Economy.pityProgress(counters(collection, 2019, 66899))[collection].Legendary < 1,
		"last miss before threshold is not full guarantee progress")
end
local session = Transactions.new(0)
session.state.coins = 5000000
session.state.pityByGroup = counters("echo", 2020, 66900)
local saved = Profile.decode(Profile.encode(session.state), 0)
check(saved ~= nil and Economy.buckets("echo", saved.pityByGroup).Mythical == 100,
	"saved due counters restore guarantees without schema reset")
local intent = {action = "BuyTen", id = "both-due", revision = 0, choice = "echo"}
local rolls = table.create(10, 0)
local reply = Transactions.process(session, intent, 1, false, rolls, 10)
check(reply ~= nil and reply.ok and reply.figures ~= nil, "batch accepts due guarantees atomically")
check(Catalog.byId[reply.figures[1]].rarity == "Mythical" and Catalog.byId[reply.figures[2]].rarity == "Legendary",
	"simultaneous guarantees grant Mythical then Legendary on consecutive batch rolls")
check(session.state.pityByGroup.echo.legendaryDryRolls == 8 and session.state.pityByGroup.echo.mythicalDryRolls == 9,
	"batch continues from independently reset counters")
local wallet = session.state.coins
local replay = Transactions.process(session, intent, 2, false, rolls, 10)
check(replay == reply and session.state.coins == wallet and session.state.pityByGroup.echo.legendaryDryRolls == 8,
	"retry cannot re-grant a guaranteed tier or advance progress")
local poor = Rules.new(0)
poor.pityByGroup = counters("echo", 2020, 66900)
check(not Rules.mutate(poor, {action = "Buy", id = "poor", revision = 0, choice = "echo"}, 0),
	"guarantee still needs a valid affordable purchase")
check(poor.pityByGroup.echo.legendaryDryRolls == 2020 and poor.pityByGroup.echo.mythicalDryRolls == 66900,
	"failed purchase preserves both due counters")
local untouched = Economy.buckets("star", poor.pityByGroup)
check(untouched.Legendary == 1 and untouched.Mythical == 0.1, "guarantees stay collection-specific")
for _, collection in {"grove", "tide"} do
	local odds = Economy.buckets(collection, poor.pityByGroup)
	check(odds.Common == 60 and odds.Uncommon == 30 and odds.Rare == 10, "starter odds unchanged")
end
print("PASS: " .. checks .. " linear pity, guarantee, probability-budget, persistence and retry checks")

--!strict
local Rules = require("./Rules")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local Economy = require("./Economy")
local Types = require("./Types")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local function intent(action: string, revision: number, figure: string?, slot: number?): Types.Intent
	return { action = action, id = tostring(revision) .. action, revision = revision, figure = figure, slot = slot }
end
local common, sprout, rare = "grove.pebble", "grove.sprout", "grove.star"
for _, case in { {0, common}, {0.199999, common}, {0.2, sprout}, {0.399999, sprout}, {0.4, "grove.acorn"}, {0.6, "grove.mushroom"}, {0.75, "grove.moth"}, {0.9, rare}, {0.999999, rare} } do
	check(Rules.roll(case[1] :: number) == case[2], "roll boundary")
end
local state = Rules.new(0)
check(Rules.rate(state) == 0, "empty display")
check(Rules.mutate(state, intent("Buy", 0), 0), "purchase")
check(state.coins == 300 and state.owned[common] == 1 and state.discovered[common], "purchase conservation")
check(not Rules.mutate(state, intent("Recycle", 1, common), 0), "last copy protected")
check(Rules.mutate(state, intent("Place", 1, common, 1), 0), "place owned copy")
check(not Rules.mutate(state, intent("Place", 2, common, 2), 0), "cannot double reserve")
check(not Rules.mutate(state, intent("Place", 2, common, 1), 0), "same assignment is a no-op")
Rules.settle(state, 0.5)
check(state.coins == 300 and state.fraction == 0.5, "fraction retained")
Rules.settle(state, 1.25)
check(state.coins == 301 and state.fraction == 0.25, "whole coin accrual")
Rules.settle(state, 1.25)
check(state.coins == 301, "same time cannot double accrue")
state.owned[rare] = 1
check(Rules.mutate(state, intent("Place", 2, rare, 1), 0), "replace")
check(Rules.available(state, common) == 1 and Rules.available(state, rare) == 0, "replacement reservations")
Rules.settle(state, 2.25)
check(state.coins == 308 and state.fraction == 0.25, "new rate applies only after replacement")
state.slots = {rare, rare, rare}
state.owned[rare] = 3
check(Rules.rate(state) == 21, "rare sum")
state.slots = { common, sprout, "grove.acorn" }
check(Rules.rate(state) == 5.5, "common sum including themed bonus")
for _, lower in {common, sprout, "grove.acorn"} do
	for _, higher in {"grove.mushroom", "grove.moth", rare} do check(Rules.rates[higher] > Rules.rates[lower], "rarity order") end
end
check(Rules.rates[rare] > Rules.rates["grove.moth"], "rare beats uncommon")
state = Rules.new(0)
state.owned[common] = 7
state.discovered[common] = true
for _ = 1, 6 do check(Rules.mutate(state, intent("Recycle", state.revision, common), 0), "valid recycle") end
check(state.scrap == 6 and state.owned[common] == 1, "six scrap conservation")
check(Rules.mutate(state, intent("Redeem", state.revision, rare), 0), "chosen rare redemption")
check(state.scrap == 0 and state.owned[rare] == 1 and state.discovered[rare], "redemption discovery")
check(not Rules.mutate(state, intent("Redeem", state.revision, rare), 0), "no negative scrap")
state.owned[common] = 3
state.slots = {common, common, common}
check(not Rules.mutate(state, intent("Recycle", state.revision, common), 0), "all copies reserved")
check(Rules.mutate(state, intent("Remove", state.revision, nil, 2), 0), "remove")
check(Rules.mutate(state, intent("Recycle", state.revision, common), 0), "removed copy recyclable")
check(state.discovered[common], "discovery permanent")
state = Rules.new(0)
state.coins = 149
check(not Rules.mutate(state, intent("Buy", 0), 0) and state.coins == 149 and state.revision == 0, "insufficient funds atomic")
state.coins = 450
state.owned[common] = 200
state.scrap = 6
check(not Rules.mutate(state, intent("Buy", 0), 0) and state.coins == 450, "purchase capacity")
check(not Rules.mutate(state, intent("Redeem", 0, rare), 0) and state.scrap == 6, "redemption capacity")
state.owned[common] = 199
state.slots = {common, "", ""}
state.coins = Economy.coinLimit - 1
Rules.settle(state, 10.5)
check(state.coins == Economy.coinLimit and state.fraction == 0, "currency safety ceiling")
Rules.mutate(state, intent("Buy", 0), 0)
Rules.settle(state, 11.5)
check(state.coins == Economy.coinLimit - 149, "resume without hidden accrual")
local malformed: { unknown } = { false, 1, "Buy", {}, {action = "Buy", id = "x", revision = 0/0}, {action = "Buy", id = "x", revision = math.huge}, {action = "Buy", id = "x", revision = -1}, {action = "Buy", id = "x", revision = 0, price = 0}, {action = "Buy", id = "x", revision = 0, owner = 123}, {action = "Place", id = "x", revision = 0, figure = common, slot = 0/0}, {action = "Place", id = "x", revision = 0, figure = common, slot = 5}, {action = "Redeem", id = "x", revision = 0, figure = "fake"}, {action = "Buy", id = string.rep("x",65), revision = 0} }
for _, raw in malformed do check(Protocol.parse(raw) == nil, "malformed request rejected") end
local session = Transactions.new(0)
local buy = intent("Buy", 0)
local first = Transactions.process(session, buy, 0, true, 0)
local retry = Transactions.process(session, buy, 0, true, 0.99)
check(first ~= nil and retry == first and session.state.coins == 300 and not session.state.owned[rare], "receipt prevents spend and reroll")
local changed = table.clone(buy)
changed.action = "Redeem"
changed.figure = rare
local rejected = Transactions.process(session, changed, 1, true, 0)
check(rejected ~= nil and not rejected.ok, "request ID mismatch rejected")
local stale = intent("Buy", 0); stale.id = "stale"
rejected = Transactions.process(session, stale, 2, true, 0)
check(rejected ~= nil and not rejected.ok and session.state.coins == 300, "stale rejected")
local place = intent("Place", 1, common, 1)
rejected = Transactions.process(session, place, 3, false, 0)
check(rejected ~= nil and not rejected.ok and Rules.rate(session.state) == 0, "distance rejected")
place.id = "near"
local placed = Transactions.process(session, place, 4, true, 0)
check(placed ~= nil and placed.ok, "near shelf accepted")
local other = Transactions.new(0)
check(other.state.coins == 450 and next(other.state.owned) == nil, "sessions isolated")
for i = 1, 100 do
	local request = intent("Remove", session.state.revision, nil, 3); request.id = tostring(i)
	Transactions.process(session, request, 4 + i, true, 0)
end
check(#session.receipts <= 64, "bounded receipts")
local old = Transactions.process(session, buy, 200, true, 0.99)
check(old ~= nil and not old.ok and not session.state.owned[rare], "evicted committed request stays stale")
local spam = Transactions.new(0)
for _ = 1, 4 do Transactions.process(spam, {}, 0, true, 0) end
check(Transactions.process(spam, buy, 0, true, 0) == nil and spam.state.coins == 450, "malformed spam consumes rate limit")
check(Transactions.process(spam, buy, 0.5, true, 0) ~= nil, "rate limit refills")
local reset = Rules.new(10000)
Rules.settle(reset, 10001)
check(reset.coins == 450 and next(reset.owned) == nil, "rejoin has no offline income")
local full = Rules.new(0)
full.scrap = 72
for _, entry in Economy.entries do check(Rules.mutate(full, intent("Redeem", full.revision, entry.id), 0), "redeem every discovery") end
local discoveries = 0
for _ in full.discovered do discoveries += 1 end
check(discoveries == 12 and full.scrap == 0, "completion without lucky rolls")
-- Deterministic mixed actions exercise reservations through many replacements/recycles.
local mixed = Transactions.new(0)
mixed.state.coins = 100000
local actions = {"Buy", "Place", "Recycle", "Redeem", "Remove"}
for i = 1, 1000 do
	local action = actions[(i * 7) % #actions + 1]
	local id = Economy.entries[(i * 11) % #Economy.entries + 1].id
	local request = intent(action, mixed.state.revision, if action == "Place" or action == "Recycle" or action == "Redeem" then id else nil, if action == "Place" or action == "Remove" then i % 3 + 1 else nil)
	request.id = "mixed" .. i
	Transactions.process(mixed, request, i, true, (i * 37 % 100) / 100)
	check(mixed.state.coins >= 0 and mixed.state.scrap >= 0, "nonnegative currencies")
	local quantity = 0
	for figure, owned in mixed.state.owned do
		quantity += owned
		check(owned >= 1 and owned % 1 == 0 and Rules.available(mixed.state, figure) >= 0, "ownership invariants")
	end
	check(quantity <= 200 and #mixed.receipts <= 64, "bounded inventory/receipts")
end
print(string.format("PASS: %d deterministic MVP checks", checks))

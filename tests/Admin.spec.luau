--!strict
local A = require("./AdminTypes")
local Service = require("./AdminService")
local Config = require("./AdminConfig")
local Protocol = require("./AdminProtocol")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local Profile = require("./Profile")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local count = 0
local function same(a: unknown, b: unknown): boolean
	if typeof(a) ~= typeof(b) then return false end
	if typeof(a) ~= "table" then return a == b end
	local firstTable, secondTable = a :: { [string]: unknown }, b :: { [string]: unknown }
	for key, value in firstTable do if not same(value, secondTable[key]) then return false end end
	for key in secondTable do if firstTable[key] == nil then return false end end
	return true
end
local function check(value: boolean, message: string)
	assert(value, message); count += 1
end
local now, sequence, changes, logs = 10, 0, 0, 0
local owner = Config.ownerUserId
local token = "00000000-0000-0000-0000-000000000001"
local first, second = Transactions.new(now), Transactions.new(now)
local targets: { [number]: Service.Target } = {
	[1] = { state = first.state, plot = 1, ready = true, saveStatus = "test", persistent = false, transferring = false },
	[2] = { state = second.state, plot = 2, ready = true, saveStatus = "test", persistent = false, transferring = false },
}
local teleports, kicks = 0, 0
local service = Service.create({
	now = function() return now end, wall = function() return 864000 end, token = function() return token end,
	players = function() return { { userId = 1, username = "One", displayName = "One", plot = 1, ready = true } } end,
	target = function(id) return targets[id] end,
	changed = function() changes += 1 end,
	teleport = function() teleports += 1; return true, "moved" end,
	kick = function() kicks += 1; return true, "kicked" end,
	random = function() return 0 end,
	log = function() logs += 1 end,
})
local function request(action: string, id: number?): A.Request
	sequence += 1
	local target = id or 1
	return { token = token, sequence = sequence, action = action, target = target,
		revision = if targets[target] then targets[target].state.revision else 0 }
end
local function call(value: A.Request): A.Reply
	now += 0.6
	return service.receive(owner, value)
end
check(Protocol.allowed(owner, "Owner"), "explicit owner recognized")
check(not Protocol.allowed(0, "Owner") and not Protocol.allowed(-1, "Owner") and not Protocol.allowed(owner + 1, "Owner"), "no creator/name/Studio fallback")
check(not Protocol.allowed(owner, "Unknown"), "unknown permission fails closed")
local connected = service.receive(owner, "Connect")
check(connected.ok and connected.token == token and connected.sequence == 0, "owner bootstrap")
for _, box in connected.boxes or {} do
	if box.id == "orbit" then
		check(box.base.Common == 98.9 and box.base.Uncommon == 0 and box.base.Rare == 0, "admin base odds use the sparse authoritative distribution")
	elseif box.id == "weather" or box.id == "birthstone" then
		check(box.base.Common == 73.9 and box.base.Rare == 0, "admin absent Rare budget goes only to Common")
	end
end
check(not service.receive(99, "Connect").ok, "unauthorized bootstrap")
local unauthorized = request("GrantCoins"); unauthorized.amount = 100
check(not service.receive(99, unauthorized).ok and first.state.coins == Economy.startingCoins, "forged unauthorized mutation")
local raw: { [string]: unknown } = { token = token, sequence = 1, action = "GrantCoins", target = 1, revision = 0, amount = 100 }
for _, invalid in { -1, 0, 0.5, math.huge, -math.huge, 0/0, Config.transactionLimit + 1 } do
	raw.amount = invalid; check(Protocol.parse(raw) == nil, "invalid numeric payload")
end
raw.amount = 10; raw.admin = owner
check(Protocol.parse(raw) == nil, "client caller identity rejected")
raw.admin = nil; raw.balance = 100
check(Protocol.parse(raw) == nil, "client balance rejected")
raw.balance = nil; raw.action = "ArbitraryMethod"
check(Protocol.parse(raw) == nil, "unknown action rejected")
raw.action = "GrantCoins"; raw.target = math.huge
check(Protocol.parse(raw) == nil, "invalid target rejected")
raw.target = 1; raw.token = string.rep("x", 10000)
check(Protocol.parse(raw) == nil, "oversized token rejected")
raw.token = token; raw.sequence = math.huge
check(Protocol.parse(raw) == nil, "invalid sequence rejected")
local grant = request("GrantCoins"); grant.amount = 100
check(call(grant).ok and first.state.coins == Economy.startingCoins + 100, "authoritative coin grant")
local beforeRevision, beforeChanges = first.state.revision, changes
check(call(grant).ok and first.state.revision == beforeRevision and changes == beforeChanges, "exact retry returns receipt without mutation")
local forged = table.clone(grant); forged.amount = 101
check(not call(forged).ok, "same sequence different payload refused")
local inspect = request("Inspect"); inspect.revision = nil
local view = call(inspect)
check(view.ok and view.inspector ~= nil and view.inspector.coins == first.state.coins, "server-confirmed inspector")
if view.inspector then view.inspector.owned["grove.pebble"] = 99 end
check(first.state.owned["grove.pebble"] == nil, "inspector is a deep copy of authoritative state")
check(not call(grant).ok, "old replay refused after receipt replacement")
check(view.boxes ~= nil and #view.boxes == #Catalog.collections, "box definitions derived from actual configuration")
local stale = request("GrantCoins"); stale.amount = 100; stale.revision = 0
check(not call(stale).ok and first.state.revision == beforeRevision, "stale state refused")
local large = request("GrantCoins"); large.amount = Config.largeChange
check(not call(large).ok, "large mutation requires confirmation")
large = request("GrantCoins"); large.amount = Config.largeChange; large.confirmed = true
check(call(large).ok, "confirmed large grant")
local set = request("SetBalance"); set.amount = 20; set.confirmed = true
check(call(set).ok and first.state.coins == 20, "set balance")
local high = request("SetBalance"); high.amount = Economy.coinLimit
check(not call(high).ok and first.state.coins == 20, "large SetBalance still requires confirmation")
high = request("SetBalance"); high.amount = Economy.coinLimit; high.confirmed = true
check(call(high).ok and first.state.coins == Economy.coinLimit, "SetBalance supports the full large wallet independently of incremental cap")
check(call(high).ok and first.state.coins == Economy.coinLimit, "large SetBalance replay is idempotent")
high = request("SetBalance"); high.amount = Economy.coinLimit + 1; high.confirmed = true
check(not call(high).ok and first.state.coins == Economy.coinLimit, "SetBalance rejects over-limit currency")
set = request("SetBalance"); set.amount = 20; set.confirmed = true
check(call(set).ok and first.state.coins == 20, "restore balance for subsequent admin checks")
local remove = request("RemoveCoins"); remove.amount = 21
check(not call(remove).ok and first.state.coins == 20, "no negative coins")
remove = request("RemoveCoins"); remove.amount = 5
check(call(remove).ok and first.state.coins == 15, "remove coins")
first.state.coins = Economy.coinLimit
grant = request("GrantCoins"); grant.amount = 1
check(not call(grant).ok and first.state.coins == Economy.coinLimit, "no overflow")
first.state.coins = 100
local fg = request("GrantFigure"); fg.figure, fg.quantity = "grove.pebble", 3; fg.confirmed = true
check(call(fg).ok and first.state.owned["grove.pebble"] == 3 and first.state.discovered["grove.pebble"] == true, "duplicate figure grant and discovery")
first.state.display.slots[1] = "grove.pebble"
first.state.shelves.units[1].placements["row:1/slot:1"] = "grove.pebble"
first.state.shelves.units[1].placements["row:1/slot:2"] = "grove.pebble"
first.state.shelves.units[1].placements["row:1/slot:3"] = "grove.pebble"
local fr = request("RemoveFigure"); fr.figure, fr.quantity, fr.confirmed = "grove.pebble", 2, true
check(call(fr).ok and first.state.owned["grove.pebble"] == 1 and first.state.display.slots[1] == "grove.pebble", "partial removal preserves unique Display")
local placements = first.state.shelves.units[1].placements
check(placements["row:1/slot:1"] == "grove.pebble" and placements["row:1/slot:2"] == nil and placements["row:1/slot:3"] == nil, "stable shelf copy reconciliation")
first.state.earnings["grove.pebble"] = 12.5
first.state.time = now + 10 -- no new accrual in the final removal
local coins = first.state.coins
fr = request("RemoveFigure"); fr.figure, fr.quantity, fr.confirmed = "grove.pebble", 1, true
check(call(fr).ok and first.state.owned["grove.pebble"] == nil and first.state.display.slots[1] == "", "final removal cleans Display")
check(placements["row:1/slot:1"] == nil and first.state.earnings["grove.pebble"] == nil and first.state.coins == coins + 12, "final bank transfers and no dangling bank or shelf")
check(first.state.discovered["grove.pebble"] == true and Profile.decode(Profile.encode(first.state), now) ~= nil, "discovery retained and schema valid")
fr = request("RemoveFigure"); fr.figure, fr.quantity, fr.confirmed = "grove.pebble", 1, true
check(not call(fr).ok, "unowned removal refused")
local collectionGrant = request("GrantCollection"); collectionGrant.collection, collectionGrant.confirmed = "grove", true
local shelfCount = #first.state.shelves.units
check(call(collectionGrant).ok and first.state.shelfRewards.grove and #first.state.shelves.units == shelfCount + 1, "completion reward preserved")
collectionGrant = request("GrantCollection"); collectionGrant.collection, collectionGrant.confirmed = "grove", true
check(call(collectionGrant).ok and #first.state.shelves.units == shelfCount + 1, "completion reward once")
local member = "grove.pebble"
first.state.owned[member] = Economy.copyLimit
local other = Catalog.figures[2].id
local previous = first.state.owned[other]
collectionGrant = request("GrantCollection"); collectionGrant.collection, collectionGrant.confirmed = "grove", true
check(not call(collectionGrant).ok and first.state.owned[other] == previous, "bulk preflight prevents partial grants")
first.state.owned[member] = 1
first.state.earnings[member] = 10
first.state.coins = Economy.coinLimit
fr = request("RemoveFigure"); fr.figure, fr.quantity, fr.confirmed = member, 1, true
check(not call(fr).ok and first.state.owned[member] == 1 and first.state.earnings[member] == 10, "wallet-full removal preserves bank and copy")
first.state.coins = 1000000
local pity = request("SetPity"); pity.collection, pity.rarity, pity.amount, pity.confirmed = "concept", "Legendary", Economy.counterLimit, true
check(call(pity).ok and first.state.pityByGroup.concept.legendaryDryRolls == Economy.counterLimit, "pity inclusive bound")
pity = request("SetPity"); pity.collection, pity.rarity, pity.amount, pity.confirmed = "concept", "Common", 1, true
check(not call(pity).ok, "non-pity rarity refused")
pity = request("SetPity"); pity.collection, pity.rarity, pity.amount, pity.confirmed = "grove", "Legendary", 1, true
check(not call(pity).ok, "starter pity refused")
local reset = request("ResetPity"); reset.collection, reset.confirmed = "concept", true
check(call(reset).ok and first.state.pityByGroup.concept.legendaryDryRolls == 0 and first.state.pityByGroup.concept.mythicalDryRolls == 0, "reset both pity counters")
local force = request("ForceRarity"); force.collection, force.rarity, force.confirmed = "grove", "Legendary", true
check(not call(force).ok, "ineligible forced rarity refused")
local absent = request("ForceRarity"); absent.collection, absent.rarity, absent.confirmed = "orbit", "Rare", true
check(not call(absent).ok, "admin cannot arm a rarity absent from a sparse collection")
force = request("ForceFigure"); force.collection, force.figure, force.confirmed = "tide", "grove.pebble", true
check(not call(force).ok, "ineligible forced figure refused")
force = request("ForceRarity"); force.collection, force.rarity, force.confirmed = "grove", "Rare", true
check(call(force).ok, "rarity override armed")
check(service.consume(2, "grove", 0) == nil and service.consume(1, "tide", 0) == nil, "override isolated by target and collection")
first.state.coins = 0
local opening = { id = "admin-test-buy", revision = first.state.revision, action = "Buy", choice = "grove" }
local function consume(collection: string, value: number): string? return service.consume(1, collection, value) end
local result = Transactions.process(first, opening, now, true, 0, 10, nil, nil, nil, consume)
check(result ~= nil and not result.ok, "failed opening")
inspect = request("Inspect"); inspect.revision = nil
view = call(inspect)
check(view.inspector ~= nil and view.inspector.override ~= nil, "failed opening does not consume override")
first.state.coins = 100000
local rolls = table.create(10, 0)
opening = { id = "admin-test-ten", revision = first.state.revision, action = "BuyTen", choice = "grove" }
local success = Transactions.process(first, opening, now, true, rolls, 10, nil, nil, nil, consume)
check(success ~= nil and success.ok and success.figures ~= nil and Catalog.byId[success.figures[1]].rarity == "Rare", "override injected in actual opening pipeline")
local rares = 0
for _, id in if success and success.figures then success.figures else {} do if Catalog.byId[id].rarity == "Rare" then rares += 1 end end
check(rares == 1 and service.consume(1, "grove", 0) == nil, "one and only one roll in ten forced")
local boxCount = first.state.boxesOpened
local retried = Transactions.process(first, opening, now + 1, true, rolls, 10, nil, nil, nil, consume)
check(retried ~= nil and retried.ok and first.state.boxesOpened == boxCount, "opening replay cannot double-grant or consume another override")
force = request("ForceFigure"); force.collection, force.figure, force.confirmed = "grove", "grove.pebble", true
check(call(force).ok and service.consume(1, "grove", 0.99) == "grove.pebble" and service.consume(1, "grove", 0.99) == nil, "forced figure consumed exactly once")
force = request("ForceRarity"); force.collection, force.rarity, force.confirmed = "grove", "Rare", true
check(call(force).ok, "expiring override armed")
now += Config.overrideSeconds + 1; service.step()
check(service.consume(1, "grove", 0) == nil, "unused override expires automatically")
force = request("ForceRarity"); force.collection, force.rarity, force.confirmed = "grove", "Rare", true; call(force)
local clear = request("ClearOverride")
check(call(clear).ok and service.consume(1, "grove", 0) == nil, "override removable")
local before = Profile.encode(first.state)
local sim = request("Simulate"); sim.revision, sim.collection, sim.amount = nil, "concept", Config.simulationLimit
local distribution = call(sim)
local total = 0; for _, n in distribution.simulation or {} do total += n end
check(distribution.ok and total == Config.simulationLimit, "bounded simulation actual roll logic")
check(same(before, Profile.encode(first.state)), "simulation leaves entire encoded profile unchanged")
check(first.state.coins == before.coins and first.state.boxesOpened == before.boxesOpened and first.state.pityByGroup.concept.legendaryDryRolls == before.pityByGroup.concept.legendaryDryRolls, "simulation leaves wallet, inventory progression and pity unchanged")
for id, n in before.owned do check(first.state.owned[id] == n, "simulation ownership unchanged") end
local teleport = request("Teleport"); check(call(teleport).ok and teleports == 1, "teleport callback")
local kick = request("Kick"); check(not call(kick).ok and kicks == 0, "kick needs confirmation")
kick = request("Kick"); kick.confirmed = true; check(call(kick).ok and kicks == 1, "confirmed kick callback")
targets[1].ready = false
grant = request("GrantCoins"); grant.amount = 1; check(not call(grant).ok, "paused or expired-lease session refused")
targets[1].ready = true; targets[1].transferring = true
grant = request("GrantCoins"); grant.amount = 1; check(not call(grant).ok, "profile handoff refused")
targets[1].transferring = false
targets[2] = nil
local departed = request("GrantCoins", 2); departed.amount = 1
check(not call(departed).ok, "departure fails safely")
now += 10
local throttled = false
for _ = 1, 8 do
	local r = request("Inspect"); r.revision = nil
	if string.find(service.receive(owner, r).message, "Rate limited", 1, true) then throttled = true end
end
check(throttled, "token bucket limits spam")
now += 10
local reconnect = service.receive(owner, "Connect")
check(reconnect.sequence ~= nil and reconnect.sequence > grant.sequence, "bootstrap never resets replay watermark")
check(logs > 10 and changes > 5, "mutations and failures audited and synchronized")
service.remove(1)
check(service.consume(1, "grove", 0) == nil, "departure clears scoped override")
-- Logger / projection failures cannot throw out of an opening or duplicate a committed grant.
local fault = Service.create({
	now = function() return now end, wall = function() return 1000 end, token = function() return token end,
	players = function() return {} end, target = function() return targets[1] end,
	changed = function() error("presentation failure") end, log = function() error("logger failure") end,
	teleport = function() return false, "unavailable" end, kick = function() return false, "unavailable" end,
	random = function() return 0 end,
})
check(fault.receive(owner, "Connect").ok, "fault service connects")
local faultRequest = request("GrantCoins"); faultRequest.amount = 1
coins = first.state.coins
local applied = fault.receive(owner, faultRequest)
check(applied.ok and first.state.coins == coins + 1 and applied.audit ~= nil and #applied.audit > 0, "mutation audited despite output/projection failure")
check(fault.receive(owner, faultRequest).ok and first.state.coins == coins + 1, "projection failure retry never duplicates")
now += 1
local faultForce = request("ForceRarity"); faultForce.collection, faultForce.rarity, faultForce.confirmed = "grove", "Rare", true
check(fault.receive(owner, faultForce).ok, "override arms despite output logger failure")
local forced = fault.consume(1, "grove", 0)
check(forced ~= nil and Catalog.byId[forced].rarity == "Rare", "logging failure cannot interrupt override consumption")
print(`PASS: {count} admin security/integration assertions`)

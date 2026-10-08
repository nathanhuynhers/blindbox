--!strict
-- Actual server economy, transactions and production snapshot sender; remote I/O is captured.
local CollectionEconomy = require("./CollectionEconomy")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local SnapshotSender = require("./SnapshotSender")
local checks = 0
local function check(value: boolean, message: string)
	checks += 1
	assert(value, message)
end
local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end
local captured = {}
local send = SnapshotSender({FireClient = function(_, player, snapshot)
	captured[player] = snapshot
end})
local function session()
	return {transaction = Transactions.new(0), sequence = 0,
		plot = {view = {first = 1, revision = 0}, showcase = {editorToken = 0}}, storage = {status = "Ready", ready = true}}
end
local alice, bob = session(), session()
alice.transaction.state.coins = 10000000
alice.transaction.state.pityByGroup.echo = {legendaryDryRolls = 90, mythicalDryRolls = 780}
send("alice", alice)
send("bob", bob)
local a, b = captured.alice, captured.bob
for _, collection in {"concept", "echo", "star"} do
	check(b.pityProgress[collection].Legendary == 0 and b.pityProgress[collection].Mythical == 0,
		"fresh owner has zero build-up for " .. collection)
end
check(a.pityProgress.grove == nil and a.pityProgress.tide == nil, "three-tier collections omit pity")
check(near(a.pityProgress.echo.Legendary, 0.5), "mid Legendary progress toward chance cap")
local curve = Economy.pity.standard.Mythical
local full = curve.start + math.ceil((curve.maximum - curve.base) / curve.increment)
check(near(a.pityProgress.echo.Mythical, 780 / full), "mid Mythical uses its own curve")
check(a.pityProgress.concept.Legendary == 0 and a.pityProgress.star.Mythical == 0, "collection isolation")
check(a.pityByGroup == nil and a.pityProgress.echo.legendaryDryRolls == nil, "no raw counters replicated")
check(captured.bob == b and b.pityProgress.echo.Legendary == 0, "sender directs only this owner's snapshot")
check(alice.sequence == 1 and bob.sequence == 1, "normal snapshot sequencing retained")
a.pityProgress.echo.Legendary = 0
check(alice.transaction.state.pityByGroup.echo.legendaryDryRolls == 90, "view does not alias saved counters")
for _, collection in {"concept", "echo", "star"} do
	local group = Economy.collections[collection].group
	local counters = {[group] = {legendaryDryRolls = Economy.counterLimit, mythicalDryRolls = Economy.counterLimit}}
	local view = CollectionEconomy.pityProgress(counters)[collection]
	check(view.Legendary == 1 and view.Mythical == 1, "both progress meters saturate for " .. collection)
	local odds = CollectionEconomy.buckets(collection, counters)
	check(odds.Legendary == 8 and odds.Mythical == 2, "full meters still mean chance, never guarantee")
end
local function buy(roll: number, id: string)
	local state = alice.transaction.state
	local reply = Transactions.process(alice.transaction,
		{action = "Buy", id = id, revision = state.revision, choice = "echo"}, state.time + 1, false, roll, 10)
	check(reply ~= nil and reply.ok, "confirmed purchase")
	send("alice", alice, reply)
	return reply
end
-- Roll in the real Legendary bucket, then the Mythical bucket: independent resets.
local odds = CollectionEconomy.buckets("echo", alice.transaction.state.pityByGroup)
local reply = buy(1 - (odds.Mythical + odds.Legendary / 2) / 100, "legendary-hit")
check(reply.figure ~= nil and Catalog.byId[reply.figure].rarity == "Legendary", "actual Legendary grant")
check(captured.alice.pityProgress.echo.Legendary == 0, "confirmed snapshot resets Legendary on hit")
check(captured.alice.pityProgress.echo.Mythical > 780 / full, "Legendary hit still advances Mythical")
reply = buy(0.99999, "mythical-hit")
check(reply.figure ~= nil and Catalog.byId[reply.figure].rarity == "Mythical", "actual Mythical grant")
check(captured.alice.pityProgress.echo.Mythical == 0 and captured.alice.pityProgress.echo.Legendary > 0,
	"confirmed snapshot independently resets Mythical")
check(captured.bob == b and b.pityProgress.echo.Mythical == 0 and bob.transaction.state.revision == 0,
	"another player receives no progress, purchase or reset")
local state = alice.transaction.state
local before = CollectionEconomy.pityProgress(state.pityByGroup)
state.coins = 0
reply = Transactions.process(alice.transaction,
	{action = "Buy", id = "failed", revision = state.revision, choice = "echo"}, state.time + 1, false, 0, 10)
check(reply ~= nil and not reply.ok, "failed purchase")
send("alice", alice, reply)
check(captured.alice.pityProgress.echo.Legendary == before.echo.Legendary,
	"failed purchase cannot advance exposed progress")
print("PASS: " .. checks .. " private pity snapshot checks")

--!strict
-- Real presentation on the existing engine double. No remotes, receipt grants or rendering.
local Engine = require("./UIEngine")
local Scope = require("./UIScope")
local Store = require("./StoreScreen")
local Presentation = require("./StorePresentation")
local Fixtures = require("./StoreFixtures")
local Offline = require("./OfflineEarnings")
local checks = 0
local function check(value: boolean, message: string)
	checks += 1
	assert(value, message)
end
local function find(root, name)
	return assert(root:FindFirstChild(name, true), "Missing " .. name)
end
local scope = Scope.create()
local root = Engine.Instance.new("Frame")
local sends = 0
local screen = Store.create(root, {
	scope = scope,
	effects = function()
		return false
	end,
	scale = function()
		return 1
	end,
	snapshot = function()
		return nil
	end,
	canAct = function()
		return true
	end,
	send = function()
		sends += 1
	end,
	navigate = function() end,
	close = function() end,
	message = function() end,
})
screen.shown(true)
for _, state in Fixtures.states do
	local input = Fixtures.make(state)
	screen.present(input)
	for _, viewport in { { 1152, 496, false }, { 640, 359, true }, { 812, 374, true } } do
		screen.layout(viewport[1], viewport[2], viewport[3])
		for _, tab in { "featured", "upgrades", "boosts", "coins", "perks" } do
			screen.route({ tab = tab })
			check(
				find(root, "StoreTab_" .. tab):GetAttribute("Selected"),
				state .. " routes " .. tab
			)
		end
	end
	screen.route({ tab = "boosts" })
	Engine.click(find(root, "Card_boostCoins"))
	check(find(root, "ProductSheet").Visible, state .. " opens details")
	Engine.click(find(root, "Length60"))
	local expected = Presentation.view(input, "boostCoins", 60)
	check(
		find(find(root, "SheetFooter"), "Text").Text == expected.stamp,
		state .. " length-specific state/price"
	)
	check(
		find(root, "PresentationStatus").Text == expected.note,
		state .. " explanatory state visible on phone"
	)
	screen.back()
end
check(sends == 0, "fixtures never send requests")
for _, outcome in { "prompting", "verifying", "saving", "recovering", "granted", "failed" } do
	local result = Presentation.view(Fixtures.make(outcome), "pouch")
	check(
		not string.find(result.stamp, "Preview R$", 1, true),
		outcome .. " state stamp survives loaded price"
	)
end
local fixture = Fixtures.make("available")
fixture.fixture = false
check(Presentation.view(fixture, "pouch").price == nil, "fixture prices cannot become a live offer")
check(
	Presentation.view(fixture, "pouch").stamp == "Buying disabled",
	"production available remains disabled"
)
local uncertain = Fixtures.make("uncertainFailure")
check(Presentation.view(uncertain, "pouch").pending, "unknown charge remains recovery pending")
check(
	not string.find(Presentation.view(uncertain, "pouch").note, "weren't charged", 1, true),
	"no fabricated no-charge assurance"
)
local upgrade = Fixtures.make("available")
upgrade.offers.coins8.ownedCoinTier = 2
check(
	string.find(Presentation.view(upgrade, "coins8").note, "Full price", 1, true) ~= nil,
	"full-price tier upgrade disclosure"
)
screen.present(Fixtures.make("perks"))
screen.route({ tab = "perks" })
check(not find(root, "PerksEmpty").Visible, "verified perks replace empty state")
for _, name in
	{ "Timer_boostCoins", "Token_coin15", "Arriving_pouch", "Owned_autoOpen", "Owned_speed" }
do
	check(find(root, name) ~= nil, name .. " shown")
end
screen.tick(1800000600)
check(
	string.find(find(find(root, "Timer_boostCoins"), "Status").Text, "Expired", 1, true) ~= nil,
	"timer expiry without negative countdown"
)
screen.shown(false)
local frozen = find(find(root, "Timer_boostLuck2"), "Status").Text
screen.tick(1800000900)
check(
	find(find(root, "Timer_boostLuck2"), "Status").Text == frozen,
	"hidden screen does no timer work"
)
screen.shown(true)
screen.route({ tab = "upgrades" })
Engine.click(find(root, "Card_autoOpen"))
check(find(root, "Count").Text == "10 boxes", "Auto Open default setup")
Engine.click(find(root, "CountPlus"))
check(find(root, "Count").Text == "11 boxes", "local setup stepper")
check(
	string.find(find(root, "Spend").Text, "16,500", 1, true) ~= nil,
	"setup cost tracks selected count"
)
for _ = 1, 120 do
	Engine.click(find(root, "CountPlus"))
end
check(find(root, "Count").Text == "100 boxes", "bounded setup maximum")
for _ = 1, 120 do
	Engine.click(find(root, "CountMinus"))
end
check(find(root, "Count").Text == "1 boxes", "bounded setup minimum")
Engine.click(find(root, "AutoAction"))
check(
	string.find(find(root, "SetupStatus").Text, "No Coins", 1, true) ~= nil,
	"simulated running spends nothing"
)
Engine.click(find(root, "AutoAction"))
screen.present(Fixtures.make("prompting"))
check(
	not find(root, "CountPlus"):GetAttribute("Enabled"),
	"source update replaces stale setup availability"
)
screen.back()
screen.present(Fixtures.make("hidden"))
screen.route({ tab = "upgrades" })
check(
	not find(root, "Tier_coins8").Visible and find(root, "Tier_coins2").Visible,
	"configured hidden tiers"
)
check(find(root, "Tier_coins2").Size.X.Offset > 200, "remaining tier reflows")
screen.present(Fixtures.make("perks"))
screen.route({ tab = "boosts" })
local alive, connections = Engine.alive(root), Engine.connections
for _ = 1, 30 do
	Engine.click(find(root, "Card_boostCoins"))
	Engine.click(find(root, "Length15"))
	Engine.click(find(root, "Activate"))
	Engine.click(find(root, "Activate"))
	screen.back()
	screen.present(Fixtures.make("perks"))
end
check(
	Engine.alive(root) == alive and Engine.connections == connections,
	"no sheet/perks instance or listener growth"
)
check(sends == 0, "activation, toggle and automation demonstrations send nothing")
scope.destroy()
root:Destroy()
check(Engine.connections == 0, "Store teardown disconnects owned listeners")

local claims = 0
local popup = Offline.create(function()
	return false
end, function()
	claims += 1
end)
popup.show("10,000", "3h 12m")
local gui = Engine.game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
Engine.click(find(gui, "Claim"))
check(claims == 1 and not popup.isOpen(), "existing free claim still works")
popup.show("10,000", "3h 12m")
Engine.click(find(gui, "Backdrop"))
check(claims == 2, "outside tap retains free claim")
for _, outcome in
	{ "idle", "prompting", "verifying", "saving", "recovering", "granted", "cancelled", "failed" }
do
	popup.present(Fixtures.offline(outcome))
	popup.show("10,000", "3h 12m")
	check(
		not find(gui, "DoubleClaim"):GetAttribute("Enabled"),
		"paid offline action always disabled"
	)
	Engine.click(find(gui, "DoubleClaim"))
	local _, busy = Presentation.offline(Fixtures.offline(outcome))
	check(find(gui, "Claim"):GetAttribute("Enabled") == not busy, outcome .. " claim lock")
	Engine.click(find(gui, "Backdrop"))
	check(popup.isOpen() == busy, outcome .. " outside tap lock")
	check(claims == 2, "fixture never grants free or paid rewards")
	popup.destroy()
end
check(Engine.connections == 0, "offline popup teardown")
print(`PASS: {checks} Store presentation assertions; no real purchases/fulfillment exercised`)

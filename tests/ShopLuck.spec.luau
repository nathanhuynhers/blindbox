--!strict
-- Real ShopScreen/ShopLuck on engine doubles: no Roblox rendering is simulated.
local Engine = require("./UIEngine")
local Shop = require("./ShopScreen")
local Scope = require("./UIScope")
local Rarity = require("./Rarity")
local Rules = require("./Rules")
local State = require("./UIState")
local Layout = require("./UILayout")
local SnapshotSender = require("./SnapshotSender")
local checks = 0
local function check(value: boolean, message: string)
	checks += 1
	assert(value, message)
end
local snapshot
local send = SnapshotSender({FireClient = function(_, _, value) snapshot = value end})
local session = {transaction = {state = Rules.new(0)}, sequence = 0,
	plot = {view = {first = 1, revision = 0}, showcase = {editorToken = 0}}, storage = {status = "Ready", ready = true}}
session.transaction.state.coins = 10000000
session.transaction.state.step = 7
send("owner", session)
local effects, pending, requests = true, false, 0
local scope = Scope.create()
local tweens = {}
local service = Engine.services.TweenService
local original = service.Create
service.Create = function(self, object, info, goals)
	local tween = original(self, object, info, goals)
	local entry = {object = object, info = info, goals = goals, cancelled = false}
	table.insert(tweens, entry)
	tween.Cancel = function() entry.cancelled = true end
	return tween
end
local gui = Engine.Instance.new("ScreenGui")
gui.Enabled = true
gui.Parent = Engine.playerGui
local screen = Shop.create(gui, {
	scope = scope, effects = function() return effects end, scale = function() return 1 end,
	snapshot = function() return snapshot end, canAct = function() return not pending end,
	send = function() requests += 1 end, navigate = function() end,
	close = function() end, message = function() end,
})
local function find(name)
	return assert(Engine.find(screen.root, name), "Missing " .. name)
end
local function meter(rarity) return find("Luck" .. rarity) end
local function child(rarity, name) return Engine.find(meter(rarity), name) end
local function update(legendary, mythical)
	session.transaction.state.pityByGroup.echo = {legendaryDryRolls = legendary, mythicalDryRolls = mythical}
	send("owner", session)
	screen.update(snapshot)
end
for _, viewport in {{1280, 720}, {844, 390}, {667, 375}, {568, 320}} do
	local frame = Layout.frame(viewport[1], viewport[2], {left = 0, right = viewport[1]})
	screen.layout(frame.panel.width, frame.panel.height, frame.phone)
	screen.route({collection = "echo"})
	update(0, 0)
	check(find("LuckProgress").Visible, "eligible collection shows both meters")
	for _, rarity in {"Legendary", "Mythical"} do
		check(meter(rarity):GetAttribute("Fraction") == 0, "zero confirmed progress")
		check(child(rarity, "Status").Text == "Fresh luck", "zero has a calm fresh state")
		check(child(rarity, "LuckFill").BackgroundColor3 == Rarity.get(rarity).tint, "canonical rarity color")
	end
	update(20, 150)
	check(child("Legendary", "Status").Text == "Building" and child("Mythical", "Status").Text == "Building",
		"warm-up progress never claims raised odds")
	check(child("Legendary", "LuckOdds").Text == "1% now · 1% base", "base odds remain honest before boost")
	update(41, 301)
	check(child("Legendary", "Status").Text == "Lucky!" and child("Mythical", "Status").Text == "Lucky!",
		"first real boosts show Lucky")
	check(child("Mythical", "LuckOdds").Text == "0.1015% now · 0.1% base", "first tiny boost is readable")
	local mark = #tweens
	screen.update(snapshot)
	check(#tweens == mark, "unchanged snapshot cannot restart lucky glints")
	update(90, 780)
	check(meter("Legendary"):GetAttribute("Fraction") == 90 / 2020, "meter uses confirmed guarantee progress")
	check(child("Legendary", "LuckOdds").Text == "3.5% now · 1% base", "raised total vs base odds")
	if not frame.phone then
		local label = Engine.find(find("OddsRow4"), "Figures")
		check(string.find(label.Text, "base 1%", 1, true) ~= nil, "existing base odds presentation retained")
	end
	update(2020, 0)
	check(child("Legendary", "Status").Text == "Guaranteed", "due Legendary has honest guarantee copy")
	check(child("Legendary", "LuckOdds").Text == "100% now · 1% base", "confirmed Legendary guarantee odds")
	update(2020, 66900)
	check(child("Legendary", "Status").Text == "Due next", "due Legendary waits behind Mythical")
	check(child("Mythical", "Status").Text == "Guaranteed", "due Mythical has honest guarantee copy")
	check(child("Legendary", "LuckOdds").Text == "0% now · 1% base", "queued guarantee does not lie about next box")
	check(child("Mythical", "LuckOdds").Text == "100% now · 0.1% base", "confirmed Mythical guarantee odds")
	check(find("LuckNote").Text == "Mythical first · Legendary next", "simultaneous guarantees explain priority")
	update(0, 66900)
	check(child("Legendary", "LuckFill").Size.X.Scale == 0, "hit gently resets fill to zero")
	check(child("Mythical", "LuckFill").Size.X.Scale == 1, "Legendary reset preserves Mythical")
	check(tweens[#tweens].goals.Size.X.Scale == 0, "reset owns a fill tween")
	update(1, 0)
	check(child("Mythical", "Status").Text == "Fresh luck", "Mythical hit independently resets")
	pending = true
	screen.update(snapshot)
	local before = meter("Legendary"):GetAttribute("Fraction")
	Engine.click(find("BuyBox"))
	check(requests == 0 and meter("Legendary"):GetAttribute("Fraction") == before,
		"pending request cannot mutate or optimistically advance progress")
	pending = false
	screen.update(snapshot)
	Engine.click(find("BuyBox"))
	check(meter("Legendary"):GetAttribute("Fraction") == before, "purchase click alone never advances pity")
	requests = 0
	local luck, contents = find("LuckProgress"), find("Contents")
	check(luck.Position.Y.Offset >= find("OddsRow5").Position.Y.Offset + find("OddsRow5").Size.Y.Offset,
		"meters do not overlap ordinary odds")
	check(luck.Position.Y.Offset + luck.Size.Y.Offset <= math.max(contents.Size.Y.Offset, contents.CanvasSize.Y.Offset),
		"scroll canvas includes every meter on short landscape")
	for _, rarity in {"Legendary", "Mythical"} do
		check(child(rarity, "LuckTrack").Size.X.Offset > 0, "phone track has positive width")
		check(child(rarity, "Status").Position.X.Offset >= child(rarity, "Rarity").Size.X.Offset,
			"rarity and status use separate text bounds")
	end
	screen.route({collection = "star"})
	check(meter("Legendary"):GetAttribute("Fraction") == 0, "switch collection never carries prior luck")
	for _, collection in {"grove", "tide"} do
		screen.route({collection = collection})
		check(not luck.Visible and luck.Size.Y.Offset == 0, "starter collections omit meters and empty space")
	end
	screen.route({collection = "echo"})
	effects = false
	mark = #tweens
	update(90, 780)
	check(#tweens == mark and child("Legendary", "LuckFill").Size.X.Scale == 90 / 2020,
		"reduced motion updates immediately without tweens")
	effects = true
end
-- Confirmed changes during an opening keep their glint/reset for the returning Shop.
update(0, 0)
gui.Enabled = false
local hiddenMark = #tweens
update(90, 780)
check(#tweens == hiddenMark, "hidden opening does not spend the lucky moment")
check(meter("Legendary"):GetAttribute("Fraction") == 90 / 2020, "hidden metadata still updates from confirmed snapshot")
gui.Enabled = true
check(#tweens > hiddenMark and child("Legendary", "LuckFill").Size.X.Scale == 90 / 2020,
	"returning Shop presents the confirmed boost")
check(tweens[#tweens].goals.Transparency == 1, "returning boost has one soft glint")
gui.Enabled = false
hiddenMark = #tweens
update(0, 781)
check(#tweens == hiddenMark, "hit reset waits for opening dismissal")
gui.Enabled = true
check(child("Legendary", "LuckFill").Size.X.Scale == 0 and child("Legendary", "Status").Text == "Fresh luck",
	"returning Shop gently resets the hit rarity")
-- Missing presentation data fails closed rather than deriving pity from inventory/history.
snapshot.pityProgress = nil
screen.update(snapshot)
check(not find("LuckProgress").Visible, "missing snapshot progress hides the panel")
scope.destroy()
for _, tween in tweens do check(tween.cancelled, "owned tweens cancelled at teardown") end
service.Create = original
print("PASS: " .. checks .. " Shop luck state, snapshot, responsive and lifecycle checks (engine doubles)")

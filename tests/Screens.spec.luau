--!nocheck
-- Real Interface, screens and components on the UIEngine double: routing, sends, pending
-- locks, countdown timer lifetime, instance reuse and teardown. No rendering is simulated.
local Engine = require("./UIEngine")
local Interface = require("./Interface")
local RevealCard = require("./RevealCard")
local Scope = require("./UIScope")
local UI = require("./UIState")
local Rules = require("./Rules")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end
local function snapshot()
	return {
		shelves = {
			ownedCount = 3,
			canNavigate = false,
			carouselRevision = 4,
			visible = {
				{ id = "shelf:1", index = 1, placements = {} },
				{ id = "shelf:2", index = 2, placements = {} },
				{ id = "shelf:3", index = 3, placements = {} },
			},
		},
		shelfAvailable = {},
		coins = 5000000,
		earnings = {},
		owned = {},
		discovered = {},
		slots = { "", "", "" },
		revision = 0,
		sequence = 1,
		rate = 0,
		step = 1,
		rates = Rules.rates,
		baseRates = Rules.rates,
		nextRates = Rules.rates,
		odds = Rules.odds,
		baseOdds = Rules.odds,
		prices = Rules.prices,
		dailyCollection = Economy.dailyCollection,
		unlocked = 3,
		expansionCost = Economy.expansionCosts[4],
		shelfPrice = Economy.shelfPrice,
		dailyReady = true,
		goalProgress = 0,
		goalClaimed = false,
		goalReward = Economy.goalReward,
		nextDay = 86400 * 2,
		saveStatus = "Ready",
		ready = true,
		bonus = 0,
	}
end
local requests = {}
local homeRequests = 0
local ui = Interface.create(function(action, figure, slot, choice)
	table.insert(requests, { action = action, figure = figure, slot = slot, choice = choice })
end, function()
	homeRequests += 1
end)
local gui = Engine.playerGui:FindFirstChild("PocketGrove")
check(gui ~= nil and gui.ResetOnSpawn == false, "one persistent ScreenGui")
local state = snapshot()
ui.update(state)
local function last()
	return requests[#requests]
end
local function find(name)
	return Engine.find(gui, name)
end
local function host(id)
	return find(id .. "Presentation")
end
local function within(root, name)
	return Engine.find(root, name)
end

-- Native management routes into the existing screen, without a mutation intent.
local managementRequests = #requests
ui.openDisplay()
check(host("Display").Visible and #requests == managementRequests, "management opens Display without collecting or sending intents")
Engine.click(within(host("Display"), "Close"))
ui.openShelves()
check(
	host("Shelves").Visible and #requests == managementRequests,
	"management opens Shelves without sending intents"
)
Engine.click(within(host("Shelves"), "Close"))
ui.pending(true)
ui.openDisplay()
check(not host("Display").Visible, "pending work blocks world management")
ui.pending(false)
ui.openingFocus(true)
ui.openDisplay()
check(not host("Display").Visible, "opening focus blocks world management")
ui.openingFocus(false)

-- HUD and dock
check(within(find("Hud"), "Balance").Text == "5,000,000", "HUD shows the snapshot balance")
check(within(find("Hud"), "Rate"):FindFirstChild("Text").Text == "+0/s", "HUD income chip")
check(find("Hud"):FindFirstChild("Scrap", true) == nil, "no Scrap pill")
for _, id in { "Collection", "Display", "Shop", "Goals", "Shelves" } do
	check(find("Dock" .. id) ~= nil, "dock tile " .. id)
end
local displayBadge = within(find("DockDisplay"), "Badge")
check(displayBadge.Visible and within(displayBadge, "Text").Text == "3 empty", "Display badge")
check(within(find("DockShop"), "Badge").Visible, "Shop FREE badge while the daily box is ready")
check(not within(find("DockGoals"), "Badge").Visible, "no Goals badge without a claim")
check(not find("Backdrop").Visible, "world is not dimmed with no screen open")
local homeButton = find("HomeButton")
check(homeButton.Text == "Home", "temporary Home button is labeled")
check(
	homeButton:GetAttribute("AccessibleName") == "Return Home to your plot",
	"Home has an accessible name"
)
Engine.click(homeButton)
check(homeRequests == 1, "Home activation sends one request")

-- Settings popover holds Motion.
Engine.click(find("SettingsButton"))
check(find("Settings").Visible, "gear opens settings")
Engine.click(find("MotionReduced"))
check(find("MotionReduced"):GetAttribute("Selected") == true, "Motion preference toggles")
Engine.click(find("SettingsCatcher"))
check(not find("Settings").Visible, "outside tap closes settings")
Engine.click(find("SettingsButton"))
Engine.click(find("MotionFull"))
Engine.click(find("SettingsCatcher"))

-- Shop
Engine.click(find("DockShop"))
check(host("Shop").Visible and find("Backdrop").Visible, "dock opens Shop over the dim")
check(find("DockShop"):GetAttribute("Active") == true, "active dock tile")
check(find("Dock").Visible, "dock stays visible on desktop while a screen is open")
local shop = host("Shop")
check(within(shop, "BoxTitle").Text == "Pocket Grove box", "first collection selected")
check(within(shop, "Discovery").Text == "0 of 6 found · 6 left to discover", "box progress")
check(
	within(within(shop, "BuyBox"), "Price").Text == UI.compact(Rules.prices.grove),
	"price from UIState"
)
Engine.click(within(shop, "Collection_echo"))
check(within(shop, "BoxTitle").Text == "Tender Echoes box", "list selects a collection")
Engine.click(within(shop, "BuyBox"))
check(last().action == "Buy" and last().choice == "echo", "Open 1 box buys the selected collection")
check(within(shop, "BuyTen").Visible, "Open 10 shown when ten boxes are affordable")
check(within(within(shop, "BuyTen"), "Price").Text == UI.compact(Rules.prices.echo * 10), "Open 10 shows the ten-box price")
Engine.click(within(shop, "BuyTen"))
check(last().action == "BuyTen" and last().choice == "echo", "Open 10 buys ten of the selected collection")
check(within(shop, "DailyBox").Visible, "free box offered when ready")
check(
	within(within(shop, "DailyBox"), "Label").Text == "Claim free Pocket Grove box",
	"free box names the server's daily collection"
)
Engine.click(within(shop, "DailyBox"))
check(last().action == "Daily" and last().choice == "grove", "free box claims the daily collection")
local rows = 0
for _, child in shop:GetDescendants() do
	if string.match(child.Name, "^OddsRow%d$") and child.Visible then
		rows += 1
	end
end
check(rows == #UI.rarityOdds(state, "echo"), "one odds row per rarity present")
state = snapshot()
state.coins = 20
state.dailyReady = false
state.sequence += 1
ui.update(state)
check(not within(shop, "DailyBox").Visible, "free box hidden once claimed")
local before = #requests
Engine.click(within(shop, "BuyBox"))
check(#requests == before, "unaffordable box cannot be bought")
check(not within(shop, "BuyTen").Visible, "Open 10 hidden when ten boxes are unaffordable")
check(
	within(within(shop, "BuyBox"), "Detail").Text == "Need " .. UI.compact(Rules.prices.echo - 20) .. " more",
	"shortfall explains why"
)
state.coins = 5000000
ui.update(state)
ui.pending(true)
Engine.click(within(shop, "BuyBox"))
check(#requests == before, "pending request disables mutations")
ui.pending(false)

-- Collection
Engine.click(find("DockCollection"))
local collection = host("Collection")
local collectionRoot = collection:FindFirstChild("Collection")
check(collection.Visible, "Collection opened")
check(not host("Shop").Visible, "one screen at a time")
check(collection:FindFirstChild("PhysicalBook", true) == nil, "the physical book is gone")
check(collection:FindFirstChild("Recycle", true) == nil, "no Recycle control")
check(within(collection, "FigureName").Text == "???", "undiscovered detail is anonymous")
check(within(collection, "FigureAction"):FindFirstChild("Label", true).Text == "Find it in Pocket Grove boxes", "missing figure routes to Shop")
Engine.click(within(collection, "FigureAction"))
check(host("Shop").Visible and within(shop, "BoxTitle").Text == "Pocket Grove box", "Find it opens that Shop box")
state = snapshot()
state.owned["grove.star"] = 2
state.discovered["grove.star"] = true
state.owned["grove.moth"] = 1
state.discovered["grove.moth"] = true
state.sequence += 1
ui.update(state)
Engine.click(find("DockCollection"))
Engine.click(within(collection, "Filter_found"))
check(collectionRoot:GetAttribute("Filter") == "found", "Found filter")
check(collectionRoot:GetAttribute("FigureId") == "grove.moth", "first found figure selected")
Engine.click(within(collection, "grove.star"))
check(collectionRoot:GetAttribute("FigureId") == "grove.star", "card selects its figure")
check(within(within(collection, "grove.star"), "Owned").Visible, "owned count badge for duplicates")
Engine.click(within(collection, "FigureAction"))
check(last().action == "Place" and last().figure == "grove.star" and last().slot == 1, "Put on Display uses the first empty slot")

-- Display
state.slots = { "grove.star", "", "" }
state.rate = 7
state.sequence += 1
ui.update(state)
Engine.click(find("DockDisplay"))
local display = host("Display")
local displayRoot = display:FindFirstChild("Display")
check(within(display, "Income"):FindFirstChild("Text").Text == "+7 coins/s", "header income chip")
check(within(within(collection, "grove.star"), "OnDisplay") ~= nil, "ON DISPLAY tag exists")
Engine.click(within(display, "DisplaySlot2"))
check(displayRoot:GetAttribute("Target") == 2, "tapping a slot opens the picker")
local picker = within(display, "Picker")
check(within(picker, "Title").Text == "Choose a figure for slot 2", "picker title")
local choices = within(picker, "Choices")
local shown = {}
for _, child in choices:GetChildren() do
	if child:IsA("TextButton") and child.Visible then
		table.insert(shown, child)
	end
end
check(#shown == 1 and shown[1].Name == "grove.moth", "picker lists owned figures not already displayed")
check(within(shown[1], "Best").Visible, "top pick tagged BEST")
Engine.click(shown[1])
check(last().action == "Place" and last().figure == "grove.moth" and last().slot == 2, "pick places into the target slot")
check(displayRoot:GetAttribute("Target") == nil, "picker closes after placing")
Engine.click(within(display, "DisplaySlot1"))
Engine.click(within(picker, "Remove"))
check(last().action == "Remove" and last().slot == 1, "filled slot offers Remove")
Engine.click(within(display, "DisplaySlot3"))
Engine.click(within(picker, "Browse"))
check(collection.Visible, "Browse Collection opens Collection for the slot")
check(within(collection, "FigureAction"):FindFirstChild("Label", true).Text ~= "", "slot route keeps an action")
Engine.click(find("DockDisplay"))
check(displayRoot:GetAttribute("Target") == nil, "dock navigation clears the picker")
state.coins = Economy.expansionCosts[4]
state.sequence += 1
ui.update(state)
check(within(display, "DisplaySlot4"):FindFirstChild("Unlock").Visible, "slot 4 shows its unlock price")
check(not within(display, "DisplaySlot5"):FindFirstChild("Unlock").Visible, "slot 5 waits for slot 4")
check(
	within(within(display, "DisplaySlot5"), "Hint").Text == "Unlock slot 4 first",
	"later coin slots unlock in order"
)
Engine.click(within(within(display, "DisplaySlot4"), "Unlock"))
check(last().action == "Expand", "unlock sends Expand")
Engine.click(within(display, "DisplaySlot2"))
check(displayRoot:GetAttribute("Target") == 2, "target set before back")
Engine.bound.CollectibleMenu("", Engine.Enum.UserInputState.Begin, { KeyCode = Engine.Enum.KeyCode.ButtonB })
check(display.Visible and displayRoot:GetAttribute("Target") == nil, "B closes the picker first")
Engine.bound.CollectibleMenu("", Engine.Enum.UserInputState.Begin, { KeyCode = Engine.Enum.KeyCode.ButtonB })
check(not display.Visible and not find("Backdrop").Visible, "B then closes the screen")
Engine.bound.CollectibleMenu("", Engine.Enum.UserInputState.Begin, { KeyCode = Engine.Enum.KeyCode.ButtonY })
check(display.Visible, "Y reopens the last screen")
Engine.bound.CollectibleMenu("", Engine.Enum.UserInputState.Begin, { KeyCode = Engine.Enum.KeyCode.ButtonR1 })
check(host("Shop").Visible, "R1 cycles to the next screen")
Engine.bound.CollectibleMenu("", Engine.Enum.UserInputState.Begin, { KeyCode = Engine.Enum.KeyCode.ButtonL1 })
check(display.Visible, "L1 cycles back")

-- Goals: countdown from nextDay, at most once a minute, only while visible.
Engine.now = 86400 * 2 - (5 * 3600 + 11 * 60 + 30)
local timersBefore = Engine.pending()
Engine.click(find("DockGoals"))
local goals = host("Goals")
local countdown = within(within(goals, "Countdown"), "Text")
check(countdown.Text == "New goals in 5h 12m", "countdown from the server's nextDay")
check(Engine.pending() == timersBefore + 1, "one countdown timer while visible")
Engine.advance(30.1)
check(countdown.Text == "New goals in 5h 11m", "countdown advances on the minute")
Engine.advance(59)
check(countdown.Text == "New goals in 5h 11m", "no update before the next minute")
Engine.advance(1.1)
check(countdown.Text == "New goals in 5h 10m", "updates once per minute")
check(not within(goals, "ClaimGoal"):GetAttribute("Enabled"), "goal not claimable yet")
state.goalProgress = 3
state.sequence += 1
ui.update(state)
check(within(find("DockGoals"), "Badge").Visible, "Goals badge when the reward is claimable")
Engine.click(within(goals, "ClaimGoal"))
check(last().action == "Goal", "Claim sends Goal")
check(find("GoalTracker").Visible and within(goals, "DailyGoal").Visible, "unconfirmed claim remains visible")
ui.pending(true)
check(find("GoalTracker").Visible, "pending claim keeps active goal")
ui.pending(false)
state.goalClaimed = true
ui.update(state)
check(not find("GoalTracker").Visible and not find("GoalChip").Visible, "confirmed claim clears both HUD variants")
check(not within(goals, "DailyGoal").Visible and within(goals, "NoActiveGoals").Visible, "Goals shows clean empty state")
check(not within(find("DockGoals"), "Badge").Visible, "claimed goal badge cleared")
Engine.click(within(goals, "Close"))
Engine.click(find("DockGoals"))
check(not within(goals, "DailyGoal").Visible and not find("GoalTracker").Visible, "reopening never restores claimed goal")

state.dailyReady = true
ui.update(state)
check(not within(goals, "Daily_tide").Visible, "one allowed collection: no chooser")
check(within(goals, "FreeTitle").Text == "Pocket Grove box", "free box names its collection")
Engine.click(within(goals, "OpenFreeBox"))
check(last().action == "Daily" and last().choice == "grove", "free box of the daily collection")
Engine.click(within(goals, "Progress_star"))
check(collection.Visible and collectionRoot:GetAttribute("CollectionId") == "star", "progress rows open Collection")
check(Engine.pending() == timersBefore, "countdown timer stops when Goals is hidden")

-- Shelves
state.shelfAvailable["grove.star"] = 1
state.shelfAvailable["grove.moth"] = 0
Engine.click(find("DockShelves"))
local shelves = host("Shelves")
local shelvesRoot = shelves:FindFirstChild("Shelves")
check(within(shelves, "Title").Text == "Shelves", "Shelf menu title stays Shelves")
check(shelvesRoot:GetAttribute("SelectedShelfId") == "shelf:1", "first visible shelf selected")
Engine.click(within(shelves, "Spot5"))
check(shelvesRoot:GetAttribute("SelectedSlotId") == "row:2/slot:2", "spot selection")
Engine.click(within(within(shelves, "Figures"), "grove.star"))
check(
	last().action == "ShelfPlace" and last().figure == "grove.star" and last().slot == 5 and last().choice == "shelf:1",
	"placing on a shelf sends the spot and shelf"
)
local shelfRequests = #requests
Engine.click(within(within(shelves, "Figures"), "grove.moth"))
check(#requests == shelfRequests, "exhausted owned figure cannot send ShelfPlace")
check(not within(shelves, "PreviousShelves"):GetAttribute("Enabled"), "prev disabled with exactly three shelves")
state.shelves.visible[1].placements["row:2/slot:2"] = "grove.star"
state.shelfAvailable["grove.star"] = 0
state.sequence += 1
ui.update(state)
Engine.click(within(shelves, "ClearSpot"))
check(last().action == "ShelfRemove" and last().slot == 5, "Clear spot")

-- Never Scrap, never stale actions.
for _, request in requests do
	check(request.action ~= "Recycle" and request.action ~= "Redeem", "client never sends Recycle/Redeem")
end

-- Instance reuse: repeated switching and snapshots create nothing new.
local function cycle()
	for _, id in { "Collection", "Display", "Shop", "Goals", "Shelves" } do
		Engine.click(find("Dock" .. id))
		state.sequence += 1
		ui.update(state)
	end
	Engine.bound.CollectibleMenu("", Engine.Enum.UserInputState.Begin, { KeyCode = Engine.Enum.KeyCode.ButtonB })
end
cycle()
local count, connections = Engine.alive(gui), Engine.connections
for _ = 1, 25 do
	cycle()
end
check(Engine.alive(gui) == count, "no instance growth across repeated screen switching")
check(Engine.connections == connections, "no connection growth across repeated screen switching")

-- Phone landscape: sheet, dock hidden while open, coins in the sheet header.
Engine.screen.X, Engine.screen.Y = 844, 390
find("SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
Engine.click(find("DockShop"))
check(not find("Dock").Visible, "phone hides the dock while a sheet is open")
check(within(shop, "Coins").Visible, "phone sheet header shows coins")
check(not find("Coins").Visible or find("Coins").Parent ~= find("Hud"), "HUD coins hide under the sheet")
Engine.click(within(shop, "Close"))
check(find("Dock").Visible and not shop.Visible, "Close restores the dock")
Engine.screen.X, Engine.screen.Y = 1280, 720
find("SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()

-- Rotate between phone and desktop after claim, with no new snapshot.
Engine.screen.X, Engine.screen.Y = 844, 390
find("SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(not find("GoalTracker").Visible and not find("GoalChip").Visible, "claimed goal stays hidden on phone resize")
state.goalClaimed = false
state.goalProgress = 1
ui.update(state)
Engine.click(find("DockGoals"))
check(within(goals, "DailyGoal").Visible and not within(goals, "NoActiveGoals").Visible, "next day incomplete goal returns")
Engine.click(within(goals, "Close"))
state.goalProgress = 3
ui.update(state)
check(find("GoalChip").Visible and not find("GoalTracker").Visible, "phone unclaimed goal chip remains claimable")
Engine.click(find("GoalChip"))
check(last().action == "Goal", "phone chip preserves claim action")
state.goalClaimed = true
ui.update(state)
check(not find("GoalChip").Visible, "phone claim clears chip")
Engine.screen.X, Engine.screen.Y = 1280, 720
find("SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(not find("GoalTracker").Visible, "desktop resize cannot restore claimed goal")
state.goalProgress = 0
state.goalClaimed = false
ui.update(state)
check(find("GoalTracker").Visible, "incomplete next-day goal appears on desktop")

-- Reveal card
local scope = Scope.create()
local root = Engine.Instance.new("Frame")
local reveal = snapshot()
reveal.owned["echo.feather-hush"] = 1
reveal.discovered["echo.feather-hush"] = true
local card = RevealCard.create(root, scope, "echo.feather-hush", true, 1, function()
	return false
end)
card.set(UI.reveal(reveal, "echo.feather-hush", true, 1))
check(within(root, "NewBadge").Visible, "NEW only for a first discovery")
check(card.choices.display.Visible and card.first() == card.choices.display, "Put on Display leads")
check(
	within(card.choices.display, "Detail").Text
		== "You have 3 empty slots · " .. UI.rate(UI.figureRate(reveal, "echo.feather-hush")),
	"slot detail"
)
reveal.slots = { "grove.star", "grove.moth", "tide.ray" }
reveal.owned["grove.star"], reveal.owned["grove.moth"], reveal.owned["tide.ray"] = 1, 1, 1
reveal.coins = 0
card.set(UI.reveal(reveal, "echo.feather-hush", true, 1))
local lowest, lowestRate = "", math.huge
for _, id in reveal.slots do
	if UI.figureRate(reveal, id) < lowestRate then
		lowest, lowestRate = id, UI.figureRate(reveal, id)
	end
end
check(
	within(card.choices.display, "Label").Text == "Swap for " .. Catalog.byId[lowest].name,
	"swap replaces the lowest earner"
)
check(card.choices.another:GetAttribute("Enabled") == false, "Open another disabled when unaffordable")
check(
	within(card.choices.another, "Detail").Text == "Need " .. UI.compact(Rules.prices.echo) .. " more",
	"shortfall shown"
)
check(card.first() == card.choices.display, "gamepad starts on the swap")
reveal.owned["echo.feather-hush"] = 2
local duplicate = RevealCard.create(root, scope, "echo.feather-hush", false, 2, function()
	return false
end)
duplicate.set(nil)
check(within(duplicate.root, "Owned").Visible == true, "duplicate shows owned count")
check(not duplicate.choices.display.Visible and not duplicate.choices.another.Visible, "no model: Continue only")
scope.destroy()

-- Teardown releases every connection, timer and instance.
ui.destroy()
Engine.click(homeButton)
check(homeRequests == 1, "Home activation connection released on teardown")
check(Engine.playerGui:FindFirstChild("PocketGrove") == nil, "UI destroyed")
check(Engine.bound.CollectibleMenu == nil, "gamepad binding released")
check(Engine.pending() == 0, "no timers survive teardown")
-- A new client tree receives the persisted claim marker, as on rejoin.
local rejoined = Interface.create(function()
	error("A claimed goal must not send a new request")
end)
local savedSnapshot = snapshot()
savedSnapshot.goalClaimed, savedSnapshot.goalProgress = true, 3
rejoined.update(savedSnapshot)
local rejoinedGui = Engine.playerGui:FindFirstChild("PocketGrove")
check(not Engine.find(rejoinedGui, "GoalTracker").Visible and not Engine.find(rejoinedGui, "GoalChip").Visible, "claimed snapshot hides goal on new client tree")
Engine.click(Engine.find(rejoinedGui, "DockGoals"))
check(Engine.find(rejoinedGui, "NoActiveGoals").Visible, "rejoin opens empty goal state")
Engine.click(Engine.find(rejoinedGui, "ClaimGoal"))
rejoined.destroy()
check(Engine.pending() == 0, "recreated UI releases countdown")
print("PASS: " .. checks .. " screen routing, send, pending, countdown and lifetime checks")

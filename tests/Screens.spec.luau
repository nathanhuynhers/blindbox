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
local CollectionEconomy = require("./CollectionEconomy")
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
		-- A returning player whose Welcome Quest is finished.
		step = 7,
		tutorialHidden = false,
		rates = Rules.rates,
		baseRates = Rules.rates,
		nextRates = Rules.rates,
		odds = Rules.odds,
		pityProgress = CollectionEconomy.pityProgress({}),
		baseOdds = Rules.odds,
		prices = Rules.prices,
		dailyCollection = Economy.dailyCollection,
		unlocked = 3,
		expansionCost = Economy.expansionCosts[4],
		shelfPrice = Economy.shelfPrice,
		dailyReady = true,
		loginReady = false,
		loginStreak = 1,
		goalProgress = 0,
		goalClaimed = false,
		goalReward = Economy.goalReward,
		nextDay = 86400 * 2,
		saveStatus = "Ready",
		ready = true,
		bonus = 0,
		offlinePending = 0,
		offlineSeconds = 0,
	}
end
local requests = {}
local homeRequests = 0
local ui = Interface.create(function(action, figure, slot, choice, volume)
	table.insert(requests, { action = action, figure = figure, slot = slot, choice = choice, volume = volume })
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
ui.displayCoins(4000000)
ui.pending(true)
ui.pending(false)
check(within(find("Hud"), "Balance").Text == "4,000,000", "HUD refresh preserves presentation balance")
Engine.click(within(find("Hud"), "Coins"))
check(string.find(within(find("Notification"), "Message").Text, "5,000,000 Coins", 1, true) ~= nil, "exact wallet tap uses authoritative balance")
Engine.advance(8)
ui.displayCoins(9999999)
check(within(find("Hud"), "Balance").Text == "9,999,999", "presentation below abbreviation threshold")
ui.displayCoins(10001000)
check(within(find("Hud"), "Balance").Text == "10M", "presentation crosses abbreviation threshold")
ui.displayCoins(state.coins)
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
local coinInterruptions = 0
ui.onCoinInterrupted(function() coinInterruptions += 1 end, function() end)
Engine.click(find("SettingsButton"))
check(find("Settings").Visible, "gear opens settings")
Engine.click(find("MotionReduced"))
check(coinInterruptions == 1, "reduced motion interrupts active Coin presentation")
check(find("MotionReduced"):GetAttribute("Selected") == true, "Motion preference toggles")
Engine.click(find("SettingsCatcher"))
check(not find("Settings").Visible, "outside tap closes settings")
Engine.click(find("SettingsButton"))
Engine.click(find("MotionFull"))
ui.openingFocus(true)
check(coinInterruptions == 2, "opening interruption reconciles hidden HUD presentation")
ui.openingFocus(false)
Engine.click(find("SettingsCatcher"))

-- Sounds (names only; Sfx.spec covers playback, caps and the one-UI-sound-per-gesture gap).
local function heard(from)
	return table.concat(table.move(Engine.sounds, from + 1, #Engine.sounds, 1, {}), ",")
end
local mark = #Engine.sounds
Engine.click(find("DockShop"))
check(heard(mark) == "open", "opening a screen plays open")
mark = #Engine.sounds
Engine.click(find("DockGoals"))
check(heard(mark) == "tab", "switching screens plays tab")
mark = #Engine.sounds
Engine.click(within(host("Goals"), "Close"))
check(heard(mark) == "close", "closing plays close")
Engine.click(find("DockShop"))
mark, requests = #Engine.sounds, {}
ui.pending(true)
Engine.click(within(host("Shop"), "BuyBox"))
check(heard(mark) == "denied" and #requests == 0, "a disabled button plays denied and sends nothing")
ui.pending(false)
mark = #Engine.sounds
Engine.click(within(host("Shop"), "BuyBox"))
check(heard(mark) == "click" and #requests == 1, "an enabled button clicks once")
Engine.click(find("DockShop"))
mark = #Engine.sounds
Engine.click(find("SettingsButton"))
check(heard(mark) == "select", "gear selects")
-- Volume sliders: saved values show and apply; a step or drag applies at once and saves once.
state.sfxVolume, state.musicVolume = 40, 70
ui.update(state)
check(find("SfxVolume"):GetAttribute("Volume") == 40, "saved Sound effects volume shows")
check(Engine.Sfx.volume("sfx") == 0.4 and Engine.Sfx.volume("music") == 0.7, "saved volumes apply")
requests = {}
Engine.services.GuiService.SelectedObject = find("SfxVolume")
local Enum = Engine.Enum
Engine.bound.SettingsVolumeStep("SettingsVolumeStep", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.DPadRight })
check(Engine.Sfx.volume("sfx") == 0.5, "gamepad step applies at once")
check(#requests == 1 and last().action == "SetVolume" and last().choice == "sfx" and last().volume == 50, "gamepad step saves once")
state.sfxVolume = 50
ui.update(state)
check(#requests == 1, "the saved snapshot ends the edit without resending")
Engine.services.GuiService.SelectedObject = nil
local width = find("MusicVolume"):FindFirstChild("Track").AbsoluteSize.X
find("MusicVolume").InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = { X = width * 0.26, Y = 0 } })
check(Engine.Sfx.volume("music") == 0.25 and #requests == 1, "drag applies (snapped) but waits")
Engine.services.UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
check(last().action == "SetVolume" and last().choice == "music" and last().volume == 25, "release saves")
state.musicVolume = 25
ui.update(state)
Engine.click(find("SettingsCatcher"))
check(Engine.bound.SettingsVolumeStep == nil, "closing settings releases the gamepad step")

-- Shop
Engine.click(find("DockShop"))
check(host("Shop").Visible and find("Backdrop").Visible, "dock opens Shop over the dim")
check(find("DockShop"):GetAttribute("Active") == true, "active dock tile")
check(find("Dock").Visible, "dock stays visible on desktop while a screen is open")
local shop = host("Shop")
check(not within(shop, "LuckProgress").Visible, "no meaningless pity panel on Grove")
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
ui.displayCoins(999999999)
state.dailyReady = false
state.sequence += 1
ui.update(state)
check(not within(shop, "DailyBox").Visible, "free box hidden once claimed")
local before = #requests
Engine.click(within(shop, "BuyBox"))
check(#requests == before, "unaffordable box cannot be bought")
check(within(find("Hud"), "Balance").Text == "999.9M", "affordability ignores presentation value")
check(not within(shop, "BuyTen").Visible, "Open 10 hidden when ten boxes are unaffordable")
check(
	within(within(shop, "BuyBox"), "Detail").Text == "Need " .. UI.compact(Rules.prices.echo - 20) .. " more",
	"shortfall explains why"
)
state.coins = 5000000
ui.displayCoins(state.coins)
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

-- Equip Best: a secondary violet control in the picker header, hidden while a slot is targeted.
local equip = within(picker, "EquipBest")
check(equip.Visible and equip:GetAttribute("Enabled"), "Equip Best offered with owned figures")
check(within(equip, "Label").Text == "Equip Best" and equip.Size.Y.Offset >= 44, "Equip Best label and touch target")
Engine.click(within(display, "DisplaySlot2"))
check(not equip.Visible, "slot controls replace Equip Best while choosing")
Engine.click(within(picker, "Cancel"))
local equipRequests = #requests
Engine.click(equip)
check(#requests == equipRequests + 1 and last().action == "EquipBest" and last().figure == nil and last().slot == nil, "Equip Best sends one bare intent")
ui.pending(true)
check(equip.Visible and not equip:GetAttribute("Enabled"), "Equip Best disabled while pending")
Engine.click(equip)
check(#requests == equipRequests + 1, "no second request while pending")
local before = state
state = table.clone(before)
state.slots = { "grove.star", "grove.moth", "" }
state.rate = 7 + before.rates["grove.moth"]
state.sequence += 1
ui.update(state)
ui.pending(false)
local summary, changed = UI.equipSummary(before, state)
check(#changed == 1 and changed[1] == 2, "summary lists the changed slot")
check(string.find(summary, UI.rate(before.rates["grove.moth"]), 1, true) ~= nil and string.find(summary, "slot 2 changed", 1, true) ~= nil, "summary shows income gain and slot")
check(within(display, "DisplaySlot2"):FindFirstChildOfClass("UIScale").Scale == 1, "changed slot settles at full size")
check(UI.equipSummary(state, state) == "Already your best Display", "already optimal message")
check(equip:GetAttribute("Enabled"), "Equip Best re-enabled after the reply")
local notReady = table.clone(state)
notReady.ready = false
notReady.sequence += 1
ui.update(notReady)
check(not equip:GetAttribute("Enabled"), "Equip Best disabled until the profile is ready")
state.sequence = notReady.sequence + 1
ui.update(state)
local bare = table.clone(state)
bare.owned, bare.slots = {}, { "", "", "" }
bare.sequence += 1
ui.update(bare)
check(not equip.Visible, "no Equip Best without figures")
state.sequence = bare.sequence + 1
ui.update(state)
Engine.advance(8) -- Let the not-ready status toast expire before the timer counts below.

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

-- Daily Login: HUD button, grid states, claim, pending lock, phone layout and reuse.
local dailyButton = find("DailyButton")
check(dailyButton.Visible and not within(dailyButton, "Ready").Visible, "Daily button without badge once claimed")
check(not host("Login").Visible, "no auto-open on a claimed first snapshot")
state.loginReady, state.loginStreak = true, 3
state.sequence += 1
ui.update(state)
check(within(dailyButton, "Ready").Visible, "Daily badge when today's reward is claimable")
check(not host("Login").Visible, "auto-open is decided once, on the first ready snapshot")
Engine.click(dailyButton)
local login = host("Login")
check(login.Visible and not find("DailyButton").Visible, "Daily opens Login and hides the HUD buttons")
check(
	within(login, "Day1"):GetAttribute("Status") == "claimed"
		and within(login, "Day2"):GetAttribute("Status") == "claimed"
		and within(login, "Day3"):GetAttribute("Status") == "ready"
		and within(login, "Day4"):GetAttribute("Status") == "locked"
		and within(login, "Day7"):GetAttribute("Status") == "locked",
	"grid shows claimed, today and locked days"
)
check(within(within(login, "Day3"), "Today").Visible and not within(within(login, "Day2"), "Today").Visible, "TODAY marks only today")
check(within(within(login, "Streak"), "Text").Text == "2-day streak", "streak chip counts completed days")
check(within(within(login, "ClaimLogin"), "Label").Text == "Claim Day 3", "claim names today")
Engine.click(within(login, "ClaimLogin"))
check(last().action == "Login" and last().choice == nil and last().figure == nil, "Claim sends a bare Login intent")
ui.pending(true)
check(not within(login, "ClaimLogin"):GetAttribute("Enabled"), "pending request disables Claim")
local loginRequests = #requests
Engine.click(within(login, "ClaimLogin"))
check(#requests == loginRequests, "no second Login while one is pending")
ui.pending(false)
state.loginReady = false
state.sequence += 1
ui.update(state)
check(
	within(login, "Day3"):GetAttribute("Status") == "claimed" and not within(login, "ClaimLogin"):GetAttribute("Enabled"),
	"confirmed claim marks today claimed and locks Claim"
)
check(not within(dailyButton, "Ready").Visible, "claimed reward clears the Daily badge")
state.loginReady, state.loginStreak = true, 8
state.sequence += 1
ui.update(state)
check(
	within(login, "Day1"):GetAttribute("Status") == "ready" and within(login, "Day2"):GetAttribute("Status") == "locked",
	"day 8 loops back to the Day 1 card"
)
Engine.click(within(login, "Close"))
check(not login.Visible and find("DailyButton").Visible, "Close returns to the world")
local loginCount, loginConnections = Engine.alive(gui), Engine.connections
for _ = 1, 25 do
	Engine.click(find("DailyButton"))
	state.sequence += 1
	ui.update(state)
	Engine.click(within(login, "Close"))
end
check(Engine.alive(gui) == loginCount and Engine.connections == loginConnections, "no growth across Login open/close")
Engine.screen.X, Engine.screen.Y = 844, 390
find("SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
Engine.click(find("DailyButton"))
check(login.Visible and not find("Dock").Visible, "phone shows Login as a sheet")
local lastCard = within(login, "Day7")
check(
	lastCard.Position.X.Offset + lastCard.Size.X.Offset <= login.Size.X.Offset - 12,
	"phone row fits all seven days"
)
Engine.click(within(login, "Close"))
Engine.screen.X, Engine.screen.Y = 1280, 720
find("SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
state.loginReady, state.loginStreak = false, 1

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
-- Open 10 steps keep a stable Skip to results; a guided reveal drops Open another.
local stepCard = RevealCard.create(root, scope, "echo.feather-hush", false, 2, function()
	return false
end)
local stepModel = UI.reveal(reveal, "echo.feather-hush", false, 2)
stepModel.next, stepModel.skip = "Next figure (3 left)", "View all results"
stepCard.set(stepModel)
check(stepCard.choices.skip.Visible and stepCard.choices.keep.Text == "Next figure (3 left)", "Skip to results sits beside Next figure")
check(stepCard.choices.skip.Text == "View all results  ›", "batch action names the complete summary")
check(stepCard.choices.keep.NextSelectionRight == stepCard.choices.skip and stepCard.choices.skip.NextSelectionLeft == stepCard.choices.keep, "desktop gamepad navigation connects Next and summary")
stepCard.layout(true)
check(stepCard.choices.skip.Visible and within(stepCard.root, "Chance").Visible, "phone batch keeps both Skip and odds")
check(stepCard.choices.skip.Size.Y.Offset >= 44 and stepCard.choices.keep.Size.Y.Offset >= 44, "batch choices retain touch targets")
check(stepCard.choices.keep.NextSelectionDown == stepCard.choices.skip and stepCard.choices.skip.NextSelectionUp == stepCard.choices.keep, "phone gamepad navigation connects Next and summary")
check(stepCard.choices.skip.Position.Y.Offset + stepCard.choices.skip.Size.Y.Offset <= 306, "batch choices fit the short Android content height")
stepCard.layout(false)
check(within(stepCard.root, "Chance").Visible, "desktop restores the chance chip")
stepModel.next, stepModel.skip, stepModel.guided = nil, nil, true
stepCard.set(stepModel)
check(not stepCard.choices.another.Visible and not stepCard.choices.skip.Visible, "a guided reveal hides Open another")
check(stepCard.first() ~= stepCard.choices.another, "gamepad never starts on a hidden choice")
scope.destroy()

-- Render the actual summary from confirmed batch metadata, including repeated figures.
local OpeningResult = require("./OpeningResult")
local PullSummary = require("./PullSummary")
local ids = { "grove.pebble", "grove.star", "grove.pebble", "grove.moth", "grove.star", "grove.moth", "grove.pebble", "grove.star", "grove.moth", "grove.pebble" }
local confirmed = snapshot()
confirmed.owned = { ["grove.pebble"] = 6, ["grove.star"] = 3, ["grove.moth"] = 3 }
confirmed.discovered = { ["grove.pebble"] = true, ["grove.star"] = true, ["grove.moth"] = true }
local steps = OpeningResult.fromBatch({ id = "summary-test", action = "BuyTen", revision = 0 }, { owned = { ["grove.pebble"] = 2 }, discovered = { ["grove.pebble"] = true } }, confirmed, { id = "summary-test", ok = true, message = "", figures = ids })
local items = OpeningResult.summary(steps)
table.clear(steps)
local summaryFocus = false
local pullSummary = PullSummary.create(function(value) summaryFocus = value end, function() return false end)
pullSummary.show(items, confirmed)
local summaryGui = Engine.playerGui:FindFirstChild("OpenTenResults")
local tiles = {}
for _, child in within(summaryGui, "Results"):GetChildren() do
        if child:GetAttribute("FigureId") then table.insert(tiles, child) end
end
table.sort(tiles, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
check(#tiles == 10 and summaryFocus, "the real summary renders all ten confirmed results")
for index, tile in tiles do
        check(tile:GetAttribute("FigureId") == ids[index], "summary tiles retain confirmed roll order")
        local isNew = index == 2 or index == 4
        check(within(tile, "Sub").Text == (if isNew then "NEW! · " else "") .. Catalog.byId[ids[index]].rarity, "summary tiles retain correct NEW marks")
end
pullSummary.destroy()
pullSummary.destroy()
check(not summaryFocus and not pullSummary.isOpen(), "summary teardown is idempotent and releases focus")

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
check(within(Engine.find(rejoinedGui, "Hud"), "Balance").Text == "5,000,000", "rebuilt UI starts with exact wallet")
local disposed = 0
rejoined.onCoinInterrupted(function() end, function() disposed += 1 end)
check(not Engine.find(rejoinedGui, "GoalTracker").Visible and not Engine.find(rejoinedGui, "GoalChip").Visible, "claimed snapshot hides goal on new client tree")
Engine.click(Engine.find(rejoinedGui, "DockGoals"))
check(Engine.find(rejoinedGui, "NoActiveGoals").Visible, "rejoin opens empty goal state")
Engine.click(Engine.find(rejoinedGui, "ClaimGoal"))
rejoined.destroy()
check(disposed == 1, "UI teardown disposes collection presentation owner once")
check(Engine.pending() == 0, "recreated UI releases countdown")
-- Daily Login auto-opens once on join for returning players, never for brand-new ones.
local function joined(owned: boolean): boolean
	local client = Interface.create(function() end)
	local first = snapshot()
	first.loginReady, first.loginStreak = true, 1
	if owned then
		first.owned["grove.star"], first.discovered["grove.star"] = 1, true
	else
		first.step = 1 -- A brand-new player starting the Welcome Quest.
	end
	client.update(first)
	local shown = Engine.find(Engine.playerGui:FindFirstChild("PocketGrove"), "LoginPresentation").Visible
	client.destroy()
	return shown
end
check(joined(true), "returning player with a claimable reward sees Login on join")
check(not joined(false), "brand-new player keeps onboarding uncovered")
-- Short safe areas: exercise the real screen sizing code rather than a duplicate pixel formula.
-- The engine double does not render; native Studio checks additionally measure clipping/scrolling.
local ShopScreen = require("./ShopScreen")
local ShelvesScreen = require("./ShelvesScreen")
local Layout = require("./UILayout")
for _, viewport in { { 705, 338 }, { 666, 374 }, { 1280, 720 } } do
	Engine.screen.X, Engine.screen.Y = viewport[1], viewport[2]
	local menus = Interface.create(function() end)
	menus.update(snapshot())
	local menuGui = Engine.playerGui:FindFirstChild("PocketGrove")
	local settings = Engine.find(menuGui, "Settings")
	check(
		settings.Position.Y.Offset >= 0
			and settings.Position.Y.Offset + settings.Size.Y.Offset <= viewport[2],
		"Settings remains inside the safe height"
	)
	menus.destroy()
	local geometry = Layout.frame(viewport[1], viewport[2], { left = 96, right = viewport[1] })
	local panel = geometry.panel
	check(
		panel.x >= 0
			and panel.y >= 0
			and panel.x + panel.width <= geometry.width
			and panel.y + panel.height <= geometry.height,
		"sheet stays in the safe area"
	)
	local parent = Engine.Instance.new("Frame")
	local scope = Scope.create()
	local data = snapshot()
	local ctx = {
		scope = scope,
		effects = function()
			return false
		end,
		scale = function()
			return geometry.scale
		end,
		snapshot = function()
			return data
		end,
		canAct = function()
			return true
		end,
		send = function() end,
		navigate = function() end,
		close = function() end,
		message = function() end,
	}
	local screen = ShopScreen.create(parent, ctx)
	screen.layout(panel.width, panel.height, geometry.phone)
	for _, collection in Catalog.collections do
		data.discovered = {}
		screen.route({ collection = collection.id })
		local contents = within(screen.root, "Contents")
		local members = UI.members(collection.id)
		-- Discover after rendering the unknown state: a target-only check on empty data is insufficient.
		for _, id in members do
			data.discovered[id] = true
		end
		screen.update(data)
		local previous = nil
		for _, id in members do
			local tile = within(contents, id)
			check(tile.Visible and tile.Selectable, "discovered Shop figure is selectable")
			check(
				tile.Size.X.Offset >= 44 and tile.Size.Y.Offset >= 44,
				"Shop target >= 44 in both dimensions"
			)
			check(
				tile.Position.X.Offset >= 0
					and tile.Position.X.Offset + tile.Size.X.Offset <= contents.Size.X.Offset,
				"Shop figure fits the pane width"
			)
			if previous and previous.Position.Y.Offset == tile.Position.Y.Offset then
				check(
					tile.Position.X.Offset - previous.Position.X.Offset - previous.Size.X.Offset
						>= 8,
					"adjacent figures have readable separation"
				)
			end
			previous = tile
		end
		local Tile = require("./FigureTile")
		local states = Tile.create(contents, ctx, "tile", function() end)
		states.size(previous.Size.X.Offset, previous.Size.Y.Offset)
		for _, view in
			{
				{ discovered = false },
				{ discovered = true },
				{ discovered = true, selected = true },
				{ discovered = true, enabled = false },
			}
		do
			states.set(members[1], view)
			check(
				states.button.Size.X.Offset >= 44 and states.button.Size.Y.Offset >= 44,
				"all figure states preserve target geometry"
			)
			check(
				states.button.Selectable == (view.enabled ~= false),
				"disabled figure cannot be selected"
			)
			check(
				states.button:GetAttribute("Selected") == (view.selected == true),
				"selected figure style survives sizing"
			)
		end
		states.button:Destroy()
		for _, name in { "InsideTitle", "OddsTitle", "OddsBar" } do
			check(within(contents, name).Visible, "Shop keeps contents and odds")
		end
		local product = within(screen.root, "Product")
		for _, name in { "BuyBox", "BuyTen", "DailyBox" } do
			local action = within(product, name)
			check(
				action.Visible and action.Size.Y.Offset >= 44,
				"Shop retains purchase/free actions"
			)
			local bottom = action.Position.Y.Offset + action.Size.Y.Offset + 4
			check(
				bottom <= math.max(product.Size.Y.Offset, product.CanvasSize.Y.Offset),
				"Shop action scroll-reachable"
			)
		end
	end
	screen.root:Destroy()
	local shelves = ShelvesScreen.create(parent, ctx)
	shelves.layout(panel.width, panel.height, geometry.phone)
	shelves.update(data)
	local scroll = within(shelves.root, "CabinetScroll")
	local cabinet = within(shelves.root, "Cabinet")
	local body = within(shelves.root, "Body")
	check(
		scroll.Position.Y.Offset + scroll.Size.Y.Offset <= body.Size.Y.Offset,
		"cabinet viewport stays inside clipping body"
	)
	for index = 1, 9 do
		local spot = within(cabinet, "Spot" .. index)
		check(
			spot.Size.X.Offset >= 44 and spot.Size.Y.Offset >= 44,
			"Shelf positions retain touch size"
		)
		local bottom = cabinet.Position.Y.Offset + spot.Position.Y.Offset + spot.Size.Y.Offset
		check(
			bottom <= math.max(scroll.Size.Y.Offset, scroll.CanvasSize.Y.Offset),
			"all nine Shelf positions scroll-reachable"
		)
	end
	check(
		not within(shelves.root, "Picker"):IsDescendantOf(scroll),
		"picker and cabinet never nest scrollers"
	)
	for index = 1, 3 do
		check(within(shelves.root, "Shelf" .. index).Visible, "three visible Shelf tabs preserved")
	end
	scope.destroy()
	parent:Destroy()
end
print("PASS: " .. checks .. " screen routing, send, pending, countdown and lifetime checks")

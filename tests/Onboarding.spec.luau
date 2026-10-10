--!nocheck
-- Welcome Quest guidance: the pure guide follows only the server's stage (never wallet changes
-- or screen visits), and the real Interface rings exactly one control, keeps phone sheets
-- guided, quiets competing badges, offers the gifts in the Shop and skips with two taps.
-- Real Interface on the UIEngine double; no rendering is simulated.
local Engine = require("./UIEngine")
local Interface = require("./Interface")
local Onboarding = require("./Onboarding")
local Tutorial = require("./Tutorial")
local Rules = require("./Rules")
local Economy = require("./Economy")
local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end
local function snapshot(step, owned)
	return {
		shelves = {
			ownedCount = 3,
			canNavigate = false,
			carouselRevision = 1,
			visible = { { id = "shelf:1", index = 1, placements = {} } },
		},
		shelfAvailable = {},
		coins = 4500,
		earnings = {},
		owned = owned or {},
		discovered = {},
		slots = { "", "", "" },
		revision = 0,
		sequence = 1,
		rate = 0,
		step = step or Tutorial.welcome,
		tutorialHidden = false,
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
		loginReady = true,
		loginStreak = 1,
		goalProgress = 3,
		goalClaimed = false,
		goalReward = Economy.goalReward,
		nextDay = 86400 * 2,
		saveStatus = "Ready",
		ready = true,
		bonus = 0,
		offlinePending = 0,
		offlineSeconds = 0,
		sfxVolume = 100,
		musicVolume = 100,
	}
end
local guide = Onboarding.guide

-- Pure guide: one action per stage, from the saved stage only.
local state = snapshot()
check(guide(state, nil, false).target == "Shop", "new player is pointed at the Shop")
check(guide(state, "Shop", false).target == "WelcomeGift", "inside the Shop the Welcome Box is the target")
check(guide(state, "Shop", false).badge ~= nil, "the gift carries its own badge, not a floating arrow")
check(guide(state, "Shelves", false).step == Tutorial.welcome, "visiting other screens changes nothing")
state.owned = { ["grove.moth"] = 1 }
check(guide(state, nil, false).step == Tutorial.welcome, "owning a figure does not skip the Welcome Box")

state.step = Tutorial.display
check(guide(state, nil, false).target == "Display", "display step points at the Display tile")
local inside = guide(state, "Display", false)
check(inside.step == Tutorial.display and inside.target == "Pick" and inside.figure == "grove.moth", "inside Display the figure to place is ringed")

state.step = Tutorial.collect
state.slots = { "grove.moth", "", "" }
local collect = guide(state, nil, true)
check(collect.world and collect.text:find("Tap") ~= nil, "collect points at the world figure with touch wording")
check(guide(state, nil, false).text:find("Click") ~= nil, "desktop wording says Click")
state.coins += 500 -- Daily Login, goals, offline Coins, a Studio grant...
check(guide(state, nil, false).step == Tutorial.collect, "a wallet change never completes collection")
check(guide(state, "Display", false).target == "Close", "with a screen open, close it to collect")
state.slots = { "", "", "" }
check(guide(state, nil, false).target == "Display", "a removed figure must go back on Display first")
state.slots = { "grove.moth", "", "" }

state.step = Tutorial.buy
check(guide(state, nil, false).target == "Shop", "buy step points back at the Shop")
local buy = guide(state, "Shop", false)
check(buy.step == Tutorial.buy and buy.target == "BuyBox", "opening the Shop rings the paid box, without completing")
state.coins = 10
local broke = guide(state, nil, false)
check(broke.world and broke.step == Tutorial.buy, "without enough Coins, collect more first")
state.coins = 4500

state.step = Tutorial.reward
check(guide(state, "Shop", false).target == "WelcomeGift", "the free x10 waits on the Shop gift")
state.step = Tutorial.shelves
check(guide(state, nil, false).target == "Shelves", "after the x10 the optional tip points at Shelves")
local spot = guide(state, "Shelves", false)
check(spot.target == "Spot" and spot.spot == 1, "inside Shelves an empty spot is ringed")
check(guide(state, "Shelves", false).step == Tutorial.shelves, "opening Shelves does not finish the tip")
state.step = Tutorial.done
check(guide(state, nil, false) == nil, "a finished quest shows nothing")
state.step = Tutorial.display
state.tutorialHidden = true
check(guide(state, nil, false) == nil, "skipped guidance stays hidden")
state.tutorialHidden = false
state.ready = false
check(guide(state, nil, false) == nil, "nothing before the profile is ready")

-- Interface: card, one ring, gifts in the Shop, quiet badges, phone sheets, two-tap skip.
local requests = {}
local ui = Interface.create(function(action, ...)
	table.insert(requests, { action = action, ... })
end)
local gui = Engine.playerGui:FindFirstChild("PocketGrove")
local card = Engine.find(gui, "Onboarding")
check(not card.Visible, "hidden before the first snapshot")
ui.update(snapshot())
local ring = Engine.find(gui, "OnboardingRing")
check(card.Visible and Engine.find(card, "Hint").Text:find("Welcome Box") ~= nil, "new session shows the quest")
check(Engine.find(card, "Reward").Visible, "the free x10 reward is visible from the start")
check(Engine.find(card, "Pip1").BackgroundColor3 ~= Engine.find(card, "Pip2").BackgroundColor3, "progress marks the current step")
check(ring.Parent.Name == "DockShop", "first hint rings the Shop tile")
check(Engine.find(ring, "Pointer").Visible and not Engine.find(ring, "Callout").Visible, "dock tiles get the pointer")
check(not Engine.find(gui, "LoginPresentation").Visible, "Daily Login does not cover a brand-new player")
check(Engine.find(Engine.find(gui, "DockDisplay"), "Badge").Visible == false, "competing dock badges are quiet")
check(Engine.find(gui, "GoalTracker").Visible == false, "the daily goal card is quiet during the quest")
Engine.click(Engine.find(gui, "DockShop"))
local gift = Engine.find(gui, "WelcomeGift")
check(gift.Visible and Engine.find(gift, "Label").Text == "Open your free Welcome Box", "the Shop offers the Welcome Box")
check(not Engine.find(gui, "DailyBox").Visible, "the Daily free box stays out of the way")
check(ring.Parent == gift, "inside the Shop the ring sits on the gift itself")
check(not Engine.find(ring, "Pointer").Visible and Engine.find(ring, "Callout").Visible, "an in-screen target gets its own badge, no arrow")
Engine.click(gift)
check(#requests == 1 and requests[1].action == "Welcome", "the gift sends the one-time Welcome request")
check(Engine.find(gui, "Onboarding").Visible, "the quest stays until the server moves it")

-- Phone: the sheet covers the card, so the ring and badge carry the guidance.
Engine.screen.X, Engine.screen.Y = 844, 390
Engine.find(gui, "SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(not card.Visible and ring.Parent == gift and Engine.find(ring, "Callout").Visible, "phone sheet keeps the target guided")
local paid = snapshot(Tutorial.buy, { ["grove.moth"] = 1 })
paid.slots = { "grove.moth", "", "" }
ui.update(paid)
check(ring.Parent == Engine.find(gui, "BuyBox"), "buy step rings the paid box in the open Shop")
check(Engine.find(gui, "BuyBox").Visible and not gift.Visible, "no gift while the quest asks for a paid box")
local display = snapshot(Tutorial.display, { ["grove.moth"] = 1 })
ui.update(display)
check(ring.Parent and ring.Parent.Name == "Close", "on phone the covered dock step starts by closing the sheet")
check(Engine.find(ring, "Callout").AnchorPoint.Y == 0, "the Close badge hangs below, clear of the sheet's top edge")
-- Short desktop: the card fits between the coins pill and the top-right row (UI audit 2026-10-09).
Engine.screen.X, Engine.screen.Y = 1023, 599
Engine.find(gui, "SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
local hud = Engine.find(gui, "Hud")
local coins, daily = Engine.find(hud, "Coins"), Engine.find(hud, "DailyButton")
-- The double does not auto-size: give the pill a real width and let the card re-place.
coins.AbsoluteSize = Engine.Vector2.new(170, 52)
coins:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(
	card.Position.Y.Offset == coins.Position.Y.Offset
		and card.Position.X.Offset >= coins.Position.X.Offset + coins.AbsoluteSize.X + 12
		and card.Position.X.Offset + card.Size.X.Offset <= daily.Position.X.Offset - 12,
	"desktop quest card stays between the coins pill and the HUD row"
)
Engine.screen.X, Engine.screen.Y = 1280, 720
Engine.find(gui, "SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(ring.Parent and ring.Parent.Name == "DockDisplay", "desktop keeps the dock tile ringed while the Shop is open")
check(not Engine.find(ring, "Pointer").Visible, "but no arrow over the open panel's buttons")

-- The x10 waits in the Shop and the dock says so, guided or not.
local ready = snapshot(Tutorial.reward, { ["grove.moth"] = 1 })
ready.tutorialHidden = true
ui.update(ready)
check(gift.Visible and Engine.find(gift, "Label").Text == "Open your FREE ×10", "a skipped player still gets the x10 gift")
check(not card.Visible and ring.Parent == nil, "but no guidance")
Engine.click(gift)
check(requests[#requests].action == "WelcomeTen", "the gift opens the Welcome x10")

-- Two-tap skip: the first tap only asks.
ui.update(snapshot())
local count = #requests
Engine.click(Engine.find(gui, "SkipTutorial"))
check(card.Visible and Engine.find(gui, "SkipTutorial").Text == "Sure?", "one tap only asks")
check(#requests == count, "asking sends nothing")
Engine.advance(4)
check(Engine.find(gui, "SkipTutorial").Text == "Skip", "the question times out")
Engine.click(Engine.find(gui, "SkipTutorial"))
Engine.click(Engine.find(gui, "SkipTutorial"))
check(not card.Visible and ring.Parent == nil, "the second tap hides every hint immediately")
check(requests[#requests].action == "SkipTutorial", "the skip is saved by the server")
ui.update(snapshot())
check(not card.Visible, "skipped guidance does not restart while unconfirmed")
local confirmed = snapshot()
confirmed.tutorialHidden = true
ui.update(confirmed)
check(not card.Visible and Engine.find(gui, "WelcomeGift").Visible, "confirmed skip keeps the Welcome Box claimable")
ui.destroy()
check(Engine.playerGui:FindFirstChild("OnboardingCollect") == nil, "world pointer released")

-- Returning / finished players see no quest; their badges and goal card are back.
local returning = Interface.create(function() end)
gui = Engine.playerGui:FindFirstChild("PocketGrove")
returning.update(snapshot(Tutorial.done, { ["grove.pebble"] = 2 }))
check(not Engine.find(gui, "Onboarding").Visible, "returning player sees no tutorial")
check(not Engine.find(gui, "WelcomeGift").Visible, "no Welcome gifts for a finished quest")
check(Engine.find(Engine.find(gui, "DockDisplay"), "Badge").Visible, "normal badges return")
returning.destroy()
-- A player who left after the Welcome Box resumes at the Display step.
local resumed = Interface.create(function() end)
gui = Engine.playerGui:FindFirstChild("PocketGrove")
resumed.update(snapshot(Tutorial.display, { ["grove.moth"] = 1 }))
check(Engine.find(gui, "Onboarding").Visible and Engine.find(gui, "OnboardingRing").Parent.Name == "DockDisplay", "rejoin resumes at Display")
resumed.destroy()
print("PASS: " .. checks .. " Welcome Quest guidance, Shop gift, phone, skip and returning-player checks")

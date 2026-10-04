--!nocheck
-- First-session onboarding: pure step order, returning-player bypass, skip, and that hints
-- never send intents. Real Interface on the UIEngine double; no rendering is simulated.
local Engine = require("./UIEngine")
local Interface = require("./Interface")
local Onboarding = require("./Onboarding")
local Rules = require("./Rules")
local Economy = require("./Economy")
local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end
local function snapshot(owned)
	return {
		shelves = { ownedCount = 3, canNavigate = false, carouselRevision = 1, visible = {} },
		shelfAvailable = {},
		coins = 4500,
		earnings = {},
		owned = owned or {},
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
		offlinePending = 0,
		offlineSeconds = 0,
	}
end

-- Step machine: box -> Display -> collect -> Shelves -> buy again.
local state = snapshot()
local progress = Onboarding.advance(nil, state, nil)
check(progress.step == "shop", "new player starts at the free box")
check(
	Onboarding.advance(nil, snapshot({ ["grove.pebble"] = 1 }), nil).step == "done",
	"returning player who owns a figure skips"
)
progress = Onboarding.advance(progress, state, "Shelves")
check(progress.step == "shop", "no step skips ahead without the action")
state.owned = { ["grove.pebble"] = 1 }
progress = Onboarding.advance(progress, state, nil)
check(progress.step == "display", "owning a figure moves to Display")
state.slots = { "grove.pebble", "", "" }
progress = Onboarding.advance(progress, state, nil)
check(progress.step == "collect" and progress.mark == 4500, "placement moves to collect")
progress = Onboarding.advance(progress, state, nil)
check(progress.step == "collect", "waits for a collection")
state.coins = 4512
progress = Onboarding.advance(progress, state, nil)
check(progress.step == "shelves", "collecting moves to Shelves")
progress = Onboarding.advance(progress, state, "Shelves")
check(progress.step == "again", "opening Shelves moves to buy again")
progress = Onboarding.advance(progress, state, "Shop")
check(progress.step == "done", "returning to the Shop completes the loop")

-- Interface: hint card + ring, skip, no intents.
local requests = 0
local ui = Interface.create(function()
	requests += 1
end)
local gui = Engine.playerGui:FindFirstChild("PocketGrove")
local card = Engine.find(gui, "Onboarding")
check(not card.Visible, "hidden before the first snapshot")
ui.update(snapshot())
local ring = Engine.find(gui, "OnboardingRing")
check(card.Visible, "new session shows the hint")
check(ring.Parent.Name == "DockShop", "first hint rings the Shop tile")
Engine.click(Engine.find(gui, "DockShop"))
check(ring.Parent and ring.Parent.Name == "DailyBox", "inside the Shop the free box is ringed")
Engine.click(Engine.find(gui, "SkipTutorial"))
check(not card.Visible and ring.Parent == nil, "skip hides every hint immediately")
ui.update(snapshot())
check(not card.Visible, "skipped tutorial never restarts in the session")
check(requests == 0, "hints and skip send no intents")
ui.destroy()
check(Engine.playerGui:FindFirstChild("OnboardingCollect") == nil, "world pointer released")

local returning = Interface.create(function() end)
gui = Engine.playerGui:FindFirstChild("PocketGrove")
returning.update(snapshot({ ["grove.pebble"] = 2 }))
check(not Engine.find(gui, "Onboarding").Visible, "returning player sees no tutorial")
returning.destroy()
print("PASS: " .. checks .. " onboarding step, skip and returning-player checks")

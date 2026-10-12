--!strict
local Rules = require("./Rules")
local Collect = require("./AutoCollect")
local Economy = require("./Economy")
local Tutorial = require("./Tutorial")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local now, ready, owned, fresh, enabled = 0, true, true, true, true
local state = Rules.new(0)
state.owned = { ["grove.pebble"] = 1, ["grove.sprout"] = 1, ["grove.moss"] = 1 }
state.display.slots = { "grove.pebble", "", "", "grove.sprout" }
state.earnings = { ["grove.pebble"] = 10.75, ["grove.sprout"] = 99.25, ["grove.moss"] = 44.5 }
state.step, state.tutorialHidden = Tutorial.collect, true
state.offlinePending = 123
local startCoins = state.coins
local targets = {}
local collect = Collect.create({
	now = function()
		return now
	end,
	ready = function()
		return ready
	end,
	ownership = function()
		return owned, fresh
	end,
	enabled = function()
		return enabled
	end,
	state = function()
		return state
	end,
	transferBank = function(profile, id)
		check(profile == state, "only authoritative owner state")
		table.insert(targets, id)
		return Rules.transferBank(profile, id)
	end,
})
check(
	collect.step() == 0 and state.coins == startCoins and state.step == Tutorial.collect,
	"hidden guidance does not skip genuine lesson"
)
local ok = Rules.collect(state, 1, "grove.pebble")
check(ok and state.step == Tutorial.buy, "manual genuine collection advances lesson")
state.earnings["grove.pebble"] += 10
now += 1
local revision = state.revision
check(
	collect.step() == 10 and state.revision == revision + 1,
	"one revision for automatic transfer"
)
check(
	state.step == Tutorial.buy and state.earnings["grove.pebble"] == 0.75,
	"fractions and quest preserved"
)
check(#targets == 1 and targets[1] == "grove.pebble", "only occupied unlocked Display targeted")
check(
	state.earnings["grove.sprout"] == 99.25
		and state.earnings["grove.moss"] == 44.5
		and state.offlinePending == 123,
	"locked/inventory/offline banks untouched"
)
state.earnings["grove.pebble"] = 50.75
check(collect.step() == 0, "one second cadence")
now += 1
check(collect.step() == 50, "whole bank transferred once")
check(
	not Rules.collect(state, 1, "grove.pebble"),
	"simultaneous subsequent manual cannot pay twice"
)
state.earnings["grove.pebble"] = 50.75
Rules.collect(state, 1, "grove.pebble")
now += 1
check(collect.step() == 0, "manual first cannot pay twice")
state.coins = Economy.coinLimit - 3
state.earnings["grove.pebble"] = 10.75
now += 1
check(
	collect.step() == 3 and state.earnings["grove.pebble"] == 7.75,
	"partial full-wallet overflow retained"
)
now += 1
revision = state.revision
check(
	collect.step() == 0 and state.revision == revision,
	"full wallet does not revise or erase bank"
)
state.coins -= 100
now += 1
check(
	collect.step() == 7 and state.earnings["grove.pebble"] == 0.75,
	"wallet capacity resumes existing opt-in"
)
for _, flag in { "ready", "owned", "fresh", "enabled" } do
	state.earnings["grove.pebble"] = 20.5
	if flag == "ready" then
		ready = false
	elseif flag == "owned" then
		owned = false
	elseif flag == "fresh" then
		fresh = false
	else
		enabled = false
	end
	now += 1
	check(collect.step() == 0 and state.earnings["grove.pebble"] == 20.5, "pause on " .. flag)
	ready, owned, fresh, enabled = true, true, true, true
end
state.display.slots[1] = ""
now += 1
check(collect.step() == 0 and state.earnings["grove.pebble"] == 20.5, "removed figure excluded")
state.display.slots[1] = "grove.pebble"
state.owned["tide.ray"], state.discovered["tide.ray"] = 1, true
state.earnings["tide.ray"] = 4.5
local beforeSwap = state.coins
local placed = Rules.mutate(
	state,
	{ action = "Place", id = "swap", revision = state.revision, figure = "tide.ray", slot = 1 },
	0,
	0,
	state.time
)
check(
	placed and state.coins == beforeSwap + 20 and state.earnings["grove.pebble"] == 0.5,
	"swap collects old bank through same helper"
)
now += 1
check(
	collect.step() == 4 and state.earnings["grove.pebble"] == 0.5,
	"automation follows new slot and cannot repeat swap transfer"
)
state.display.slots[1] = "grove.pebble"
state.earnings["grove.pebble"] = 20.5
collect.pause()
now += 20
check(collect.step() == 0, "AFK freeze stops automation")
collect.resume()
check(collect.step() == 0, "recovery creates no catch-up burst")
now += 1
check(collect.step() == 20, "ready recovery resumes collection without new loop")
collect.destroy()
collect.destroy()
now += 10
state.earnings["grove.pebble"] = 99
check(collect.step() == 0, "destroyed collector stays inert")
print(`PASS: {checks} Auto Collect checks (actual bank helper exposed only in test fixture)`)

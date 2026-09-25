--!strict
local State = require("./OpeningState")
local Config = require("./OpeningConfig")
local Result = require("./OpeningResult")
local checks = 0
local function check(condition: boolean, message: string)
	checks += 1
	assert(condition, message)
end

-- Drive actual presentation logic with a deterministic clock, independent of Roblox rendering.
local order = {
	"Enter",
	"Anticipation",
	"Shake",
	"Await",
	"Open",
	"Silhouette",
	"Reveal",
	"Result",
	"Closing",
	"Done",
}
for rarity, profile in Config.rarities do
	for _, reduced in { false, true } do
		local state = State.create(profile.timing, reduced, false)
		local elapsed = 0
		for index, phase in order do
			check(state.phase == phase, rarity .. " order " .. phase)
			if phase == "Await" then
				check(not State.animated(state), "waiting must release frame connection")
				State.advance(state, 300)
				check(state.phase == "Await", "waiting cannot auto-open")
				check(State.activate(state), "tap opens waiting box")
			elseif phase == "Result" then
				check(not State.activate(state), "same-frame click cannot dismiss result")
				State.advance(state, 0.36)
				check(not State.animated(state), "settled result must release frame connection")
				check(not State.skip(state), "skip cannot dismiss result")
				State.advance(state, 300)
				check(state.phase == "Result", "result must not disappear on a timer")
				check(State.activate(state), "continue closes result")
			elseif phase == "Done" then
				check(not State.animated(state), "done must release frame connection")
				check(not State.activate(state) and not State.skip(state), "done cannot restart")
			else
				local duration = State.duration(state)
				elapsed += duration
				for _ = 1, 15 do
					check(not State.activate(state), "rapid input cannot advance " .. phase)
				end
				State.advance(state, duration * 0.5)
				check(
					state.phase == phase and math.abs(State.progress(state) - 0.5) < 0.001,
					"midpoint"
				)
				State.advance(state, duration * 0.5 + 0.001)
				check(state.phase == order[index + 1], "timed transition")
			end
		end
		check(elapsed < (if reduced then 1.5 else 4.5), "sequence stays short")
	end
	for _, reduced in { false, true } do
		for _, phase in order do
			local state = State.create(profile.timing, reduced, false)
			state.phase = phase
			local expected = phase ~= "Enter"
				and phase ~= "Result"
				and phase ~= "Closing"
				and phase ~= "Done"
			check(State.skip(state) == expected, "skip gating " .. phase)
			if expected then
				check(state.phase == "Result", "skip must always land on actual result")
				for _ = 1, 20 do
					check(
						not State.activate(state) and not State.skip(state),
						"skip spam cannot close result"
					)
				end
			end
			State.cancel(state)
			check(state.phase == "Done" and not State.animated(state), "cancel during every phase")
		end
	end
end
check(
	Config.profile("FutureRarity") == Config.rarities.Common,
	"unknown rarity gets safe visual fallback"
)
check(
	State.create(Config.rarities.Common.timing, false, true).phase == "Silhouette",
	"redemption bypasses sealed box"
)
check(
	Config.rarities.Rare.rings > Config.rarities.Uncommon.rings
		and Config.rarities.Uncommon.particles > Config.rarities.Common.particles,
	"rarity intensity is data-driven"
)

local id = "grove.pebble"
local before = { owned = {}, discovered = {} }
local after = { owned = { [id] = 1 }, discovered = { [id] = true } }
local request = { id = "request-1", action = "Buy", revision = 7 }
local reply = { id = "request-1", ok = true, message = "Not parsed by presentation", figure = id }
local result = Result.fromReply(request, before, after, reply)
check(result ~= nil and result.isNew and result.quantity == 1, "new from authoritative snapshots")
check(result ~= nil and table.isfrozen(result), "handoff cannot mutate confirmed metadata")
local laterSnapshot = { owned = { [id] = 5 }, discovered = { [id] = true } }
local delayed = Result.fromReply(request, before, laterSnapshot, reply)
check(
	delayed ~= nil and delayed.isNew,
	"passive updates before reply do not replace request baseline"
)
local duplicate = Result.fromReply(request, after, laterSnapshot, reply)
check(
	duplicate ~= nil and not duplicate.isNew and duplicate.quantity == 5,
	"positive duplicate quantity"
)
local recycledBefore = { owned = {}, discovered = { [id] = true } }
local rediscovered = Result.fromReply(request, recycledBefore, after, reply)
check(rediscovered ~= nil and not rediscovered.isNew, "zero owned does not erase discovery history")
check(
	next(before.owned) == nil and next(before.discovered) == nil and after.owned[id] == 1,
	"presentation never grants or mutates snapshots"
)
request.action = "Daily"
local daily = Result.fromReply(request, before, after, reply)
check(daily ~= nil and not daily.direct, "daily uses box")
request.action = "Redeem"
local redeemed = Result.fromReply(request, before, after, reply)
check(redeemed ~= nil and redeemed.direct, "redemption uses direct spotlight")
request.action = "Place"
check(Result.fromReply(request, before, after, reply) == nil, "non-acquisition cannot reveal")
request.action = "Buy"
reply.ok = false
check(Result.fromReply(request, before, after, reply) == nil, "failed acquisition cannot reveal")
reply.ok = true
reply.id = "older-request"
check(Result.fromReply(request, before, after, reply) == nil, "unmatched retry reply cannot reveal")
reply.id = request.id
reply.figure = "missing-figure"
check(Result.fromReply(request, before, after, reply) == nil, "invalid catalog ID cannot render")
reply.figure = id
check(
	Result.fromReply(request, before, before, reply) == nil,
	"unconfirmed ownership cannot reveal"
)
print("PASS: " .. checks .. " opening state and confirmed-result checks")

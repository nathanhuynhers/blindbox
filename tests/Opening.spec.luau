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
	"Arrival",
	"Anticipation",
	"Charge",
	"Shake",
	"Await",
	"Break",
	"Flight",
	"RarityTease",
	"Impact",
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
				check(State.animated(state) ~= reduced, "only normal mode keeps floating at Await")
				State.advance(state, 300)
				check(state.phase == "Await", "waiting cannot auto-open")
				check(State.activate(state), "tap opens waiting box")
			elseif phase == "Result" then
				check(not State.activate(state), "same-frame click cannot dismiss result")
				State.advance(state, 0.36)
				check(State.animated(state) ~= reduced, "only normal mode keeps figure idle loop")
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
		check(
			elapsed < (if reduced then 4.7 else 7.8),
			"sequence includes readable rarity hold and calm impact"
		)
	end
	for _, reduced in { false, true } do
		for _, phase in order do
			local state = State.create(profile.timing, reduced, false)
			state.phase = phase
			local expected = phase ~= "Enter"
				and phase ~= "Arrival"
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
	State.create(Config.rarities.Common.timing, false, true).phase == "Enter",
	"redemption also transitions safely into cinematic camera"
)
check(
	Config.rarities.Rare.rings > Config.rarities.Uncommon.rings
		and Config.rarities.Uncommon.particles > Config.rarities.Common.particles,
	"rarity intensity is data-driven"
)

local Catalog = require("./Catalog")
for _, figure in Catalog.figures do
	check(Config.rarities[figure.rarity] ~= nil, "every actual rarity has a profile")
	local collection = Config.collection(figure.collection)
	check(
		collection.name ~= figure.collection
			and collection.emblem ~= ""
			and collection.pattern ~= "",
		"catalog-driven collection packaging"
	)
end
check(Config.collection("future").motif == "mote", "future collection gets neutral presentation")
local direct = State.create(Config.rarities.Rare.timing, true, true)
State.advance(direct, State.duration(direct))
check(direct.phase == "Silhouette", "direct acquisition bypasses box after safe camera transition")
local invalidDelta = State.create(Config.rarities.Common.timing, false, false)
State.advance(invalidDelta, 0 / 0)
State.advance(invalidDelta, math.huge)
State.advance(invalidDelta, -4)
check(invalidDelta.elapsed == 0, "invalid and negative clock deltas cannot corrupt progress")
local totalTimes = {}
for rarity, profile in Config.rarities do
	local total, reducedTotal = 0, 0
	for _, phase in order do
		local full = State.create(profile.timing, false, false)
		local reduced = State.create(profile.timing, true, false)
		full.phase, reduced.phase = phase, phase
		local duration = State.duration(full)
		if duration < math.huge and phase ~= "Closing" then
			total += duration
			reducedTotal += State.duration(reduced)
			check(State.duration(reduced) <= duration, "reduced motion never lengthens a phase")
		end
	end
	totalTimes[rarity] = total
	check(total >= 5.2 and total <= 7.5, "five-tier pacing target")
	check(reducedTotal < total * 0.65, "reduced motion substantially shortens travel")
	local beat = Config.teaseBeat(profile, 0)
	check(
		beat.color == profile.tint and Config.sounds[beat.cue] ~= nil,
		"data-driven rarity color and cue"
	)
end
check(
	totalTimes.Common < totalTimes.Uncommon and totalTimes.Uncommon < totalTimes.Rare,
	"rarity extends anticipation through data"
)
local future = table.clone(Config.rarities.Rare)
future.tease = {
	{ at = 0, color = future.tint, secondary = future.accent, cue = "rarityRare" },
	{
		at = 0.3,
		color = future.tint,
		secondary = future.accent,
		cue = "",
		quiet = true,
		freeze = true,
	},
	{
		at = 0.5,
		color = Config.rarities.Uncommon.tint,
		secondary = future.accent,
		cue = "futureSting",
		shatter = true,
	},
}
check(Config.teaseBeat(future, 0.4).freeze == true, "future profile can freeze and go quiet")
check(Config.teaseBeat(future, 0.6).shatter == true, "future profile can shatter into another tint")
check(
	Config.teaseMotion(future, 0.3) == Config.teaseMotion(future, 0.49),
	"freeze holds path position"
)
check(Config.teaseMotion(future, 1) == 1, "multi-beat profile still lands before impact")
check(
	Catalog.byId["secret"] == nil and Config.rarities.Secret == nil,
	"extensibility adds no fake catalog drops"
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
local batchIds = { "grove.pebble", "grove.star", "grove.pebble" }
local batchAfter = { owned = { ["grove.pebble"] = 2, ["grove.star"] = 1 }, discovered = { ["grove.pebble"] = true, ["grove.star"] = true } }
local batchRequest = { id = "ten", action = "BuyTen", revision = 7 }
local batch = Result.fromBatch(batchRequest, before, batchAfter, { id = "ten", ok = true, message = "", figures = batchIds })
check(#batch == 4 and batch[1].tease == "Rare" and not batch[1].direct and batch[1].sequence == "first", "Open 10 opens one box that teases the best rarity")
check(batch[2].figureId == "grove.pebble" and batch[3].figureId == "grove.star" and batch[4].figureId == "grove.pebble", "figures follow in roll order")
check(batch[2].direct and batch[2].sequence == "middle" and batch[4].sequence == "last" and batch[4].tease == nil, "figures reveal without boxes")
check(batch[2].isNew and not batch[4].isNew and batch[4].quantity == 2, "only a figure's first copy in a batch is new")
check(batch[1].requestId ~= batch[2].requestId and batch[2].requestId ~= batch[4].requestId, "each step has its own presentation id")
check(#Result.fromBatch(request, before, batchAfter, { id = request.id, ok = true, message = "", figures = batchIds }) == 0, "only BuyTen replies batch")
local teaseState = State.create(Config.rarities.Rare.timing, false, false, true)
for _ = 1, 40 do
	if teaseState.phase == "Await" then
		State.activate(teaseState)
	end
	State.advance(teaseState, State.duration(teaseState))
	check(teaseState.phase ~= "Silhouette" and teaseState.phase ~= "Result", "the tease box never reveals a figure")
end
check(teaseState.phase == "Done", "the tease box closes after the rarity impact")
local finishing = State.create(Config.rarities.Rare.timing, false, true)
State.advance(finishing, State.duration(finishing))
check(State.finish(finishing) and finishing.phase == "Closing" and finishing.skipped, "Skip ends an Open 10 step")
check(not State.finish(finishing), "finish is idempotent")
request.action = "Daily"
local daily = Result.fromReply(request, before, after, reply)
check(daily ~= nil and not daily.direct, "daily uses box")
request.action = "Redeem"
local redeemed = Result.fromReply(request, before, after, reply)
check(redeemed == nil, "retired redemption cannot reveal a result")
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

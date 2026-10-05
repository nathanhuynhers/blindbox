--!strict
local Engine = require("./OpeningEngine")
local Controller = require("./OpeningController")
local Camera = require("./OpeningCamera")
local Scope = require("./OpeningScope")
local Config = require("./OpeningConfig")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local focused, reports = false, 0
local baseline = Engine.connections
local controller = Controller.create(function(value)
	focused = value
end, function()
	reports += 1
end)
local sequence = 0
local function result(id)
	sequence += 1
	return table.freeze({
		requestId = "opening-" .. sequence,
		figureId = id or "tide.pearl",
		isNew = false,
		quantity = 7,
		direct = false,
	})
end
local function reach(phase)
	for _ = 1, 400 do
		if Engine.state.phase == phase then
			return
		end
		if Engine.state.phase == "Await" then
			Engine.key("A")
		else
			Engine.render:Fire(0.05)
		end
	end
	error("Could not reach " .. phase)
end
local function clean()
	check(not controller.isActive() and not focused, "session and UI restored")
	check(not Engine.playerGui:FindFirstChild("BlindboxOpening"), "GUI removed")
	check(not Engine.workspace:FindFirstChild("BlindboxCinematic"), "stage removed")
	check(not Engine.workspace:FindFirstChild("OpeningSounds"), "sounds removed")
	check(next(Engine.actions.bound) == nil, "input and movement released")
	check(
		Engine.camera.CameraType == "Custom" and Engine.camera.FieldOfView == 73,
		"camera type/FOV restored"
	)
	check(
		Engine.camera.CFrame == "original-frame" and Engine.camera.Focus == "original-focus",
		"camera pose/focus restored"
	)
	check(Engine.camera.CameraSubject == Engine.humanoid, "camera subject restored")
	check(Engine.connections == baseline + 2, "session signal/render connections removed")
end
for _, reduced in { false, true } do
	for _, phase in
		{
			"Enter",
			"Arrival",
			"Charge",
			"Await",
			"Break",
			"Flight",
			"RarityTease",
			"Impact",
			"Silhouette",
			"Reveal",
			"Result",
			"Closing",
		}
	do
		local awarded = result()
		check(controller.present(awarded, reduced), "can start")
		check(not controller.present(awarded, reduced), "cannot overlap")
		reach(if phase == "Closing" then "Result" else phase)
		if phase == "Closing" then
			Engine.render:Fire(0.4)
			Engine.key("A")
		end
		controller.cancel()
		controller.cancel()
		clean()
		check(not controller.present(awarded, reduced), "cannot replay a closed receipt")
	end
end
for _, phase in
	{
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
	}
do
	local awarded = result()
	controller.present(awarded, false)
	reach(phase)
	local revealCount = 0
	for _, cue in Engine.cues do
		if cue == Config.profile("Rare").cues.reveal then
			revealCount += 1
		end
	end
	local wasRevealed = phase == "Reveal"
	controller.skip()
	check(Engine.state.phase == "Result", "skip reaches result from " .. phase)
	check(
		Engine.result == awarded and not awarded.isNew and awarded.quantity == 7,
		"skip preserves confirmed metadata"
	)
	for _ = 1, 10 do
		controller.skip()
		Engine.key("A")
	end
	check(
		controller.isActive() and Engine.state.phase == "Result",
		"skip spam cannot dismiss reward"
	)
	local afterCount = 0
	for _, cue in Engine.cues do
		if cue == Config.profile("Rare").cues.reveal then
			afterCount += 1
		end
	end
	check(afterCount == revealCount + (if wasRevealed then 0 else 1), "no double reveal cue")
	Engine.render:Fire(0.4)
	Engine.key("A")
	Engine.render:Fire(0.12)
	check(Engine.camera.CameraType == "Custom", "camera restored behind closing curtain")
	Engine.render:Fire(0.12)
	clean()
end
controller.present(result(), false)
reach("Await")
Engine.click("hitTarget")
check(Engine.state.phase == "Break", "mouse/touch activation reaches Break")
controller.cancel()
controller.present(result(), false)
reach("Await")
Engine.key("Space")
check(Engine.state.phase == "Break", "Space opens")
controller.cancel()
controller.present(result(), false)
reach("Flight")
Engine.playerGui:FindFirstChild("BlindboxOpening"):Destroy()
clean()
controller.present(result(), false)
reach("Await")
Engine.playerGui:FindFirstChild("BlindboxOpening").Enabled = false
clean()
for _, event in
	{ Engine.player.CharacterRemoving, Engine.player.CharacterAdded, Engine.humanoid.Died }
do
	controller.present(result(), false)
	reach("RarityTease")
	event:Fire()
	clean()
end
controller.present(result(), false)
reach("Flight")
local replacement = Engine.Instance.new("Camera")
replacement.Parent, replacement.CameraType = Engine.workspace, "Custom"
Engine.workspace.CurrentCamera = replacement
clean()
check(
	Engine.workspace.CurrentCamera == replacement and replacement.CameraType == "Custom",
	"replacement camera is respected"
)
Engine.workspace.CurrentCamera = Engine.camera
Engine.failConstruct = true
check(not controller.present(result(), false), "constructor failure is caught")
Engine.failConstruct = false
clean()
Engine.failDraw = true
check(not controller.present(result(), false), "initial draw failure is caught")
Engine.failDraw = false
clean()
controller.present(result(), false)
reach("Charge")
Engine.failDraw = true
Engine.render:Fire(0.02)
Engine.failDraw = false
clean()
check(reports == 3, "failure reports explain confirmed ownership")
Engine.input.last = "Gamepad1"
controller.present(result(), false)
reach("Await")
check(Engine.guiService.SelectedObject == Engine.view.primary, "Await focuses Open for gamepad A")
Engine.key("A")
check(Engine.state.phase == "Break", "gamepad A opens instead of inherited Skip selection")
Engine.key("B")
check(Engine.state.phase == "Result", "gamepad B skips independently of selection")
controller.cancel()
Engine.input.last = "MouseButton1"
clean()
-- Preview capability is gated before allocation/receipt tracking and never rewrites results.
local previewResult = result()
Engine.studio = false
check(
	not controller.present(previewResult, false, "Mythical"),
	"production rejects presentation override"
)
Engine.studio = true
check(
	not controller.present(previewResult, false, "mythical"),
	"override validation is case-sensitive"
)
check(not controller.present(previewResult, false, "Unknown"), "unknown preview tier rejected")
for _, rarity in { "Legendary", "Mythical" } do
	for _, reduced in { false, true } do
		table.clear(Engine.cues)
		local awarded = result()
		check(controller.present(awarded, reduced, rarity), "Studio preview accepted")
		check(
			Engine.profile.rarity == rarity and Engine.result == awarded,
			"profile override preserves authoritative result"
		)
		reach("RarityTease")
		if rarity == "Legendary" then
			Engine.render:Fire(
				Config.profile(rarity).signature.pulses[1].at
					* Config.profile(rarity).flight.transition
			)
		end
		if rarity == "Mythical" then
			for _, cue in Engine.cues do
				check(
					cue ~= "transformMythical" and cue ~= "rarityMythical",
					"pearl suspense has no premature sting"
				)
			end
			Engine.render:Fire(0.15)
		end
		local cues = {}
		for _, cue in Engine.cues do
			cues[cue] = true
		end
		check(
			cues["rarity" .. rarity] and cues["transform" .. rarity],
			"tier-specific audio signature hooks"
		)
		reach("Impact")
		check(Engine.cues[#Engine.cues] == "impact" .. rarity, "tier impact cue")
		Engine.render:Fire(Config.impactCalmAt(Config.profile(rarity)) + 0.001)
		check(Engine.cues[#Engine.cues] == "postImpactShimmer", "profile calm and audio agree")
		controller.skip()
		check(
			Engine.result == awarded and awarded.quantity == 7 and not awarded.isNew,
			"high-tier Skip preserves result metadata"
		)
		check(Engine.cues[#Engine.cues] == "reveal" .. rarity, "tier reveal cue on Skip")
		controller.cancel()
		clean()
	end
end
for _, reduced in { false, true } do
	table.clear(Engine.cues)
	controller.present(result(), reduced, "Mythical")
	reach("RarityTease")
	Engine.render:Fire(0.1)
	controller.skip()
	Engine.render:Fire(0.2)
	for _, cue in Engine.cues do
		check(
			cue ~= "transformMythical" and cue ~= "rarityMythical",
			"Skip invalidates pending Mythical bloom cue"
		)
	end
	controller.cancel()
	clean()
end
Engine.studio = false
for _, fixture in
	{ { "grove.pebble", "Common" }, { "grove.moth", "Uncommon" }, { "tide.pearl", "Rare" } }
do
	table.clear(Engine.cues)
	controller.present(result(fixture[1]), false)
	local profile = Config.rarities[fixture[2]]
	local function countCue(key)
		local count = 0
		for _, cue in Engine.cues do
			if cue == key then
				count += 1
			end
		end
		return count
	end
	reach("Flight")
	check(
		countCue("launch") == 1 and countCue("acceleration") == 1,
		"launch and acceleration audio hooks"
	)
	reach("RarityTease")
	check(
		countCue("rarityTransformation") == 1 and countCue("rarity" .. fixture[2]) == 1,
		"one profile transformation cue"
	)
	Engine.render:Fire(profile.flight.transition + profile.flight.hold - 0.01)
	check(countCue("dive") == 0, "no dive audio during recognition hold")
	Engine.render:Fire(profile.flight.apex + 0.02)
	check(countCue("dive") == 1, "dive audio begins after apex")
	reach("Impact")
	check(
		countCue(profile.cues.impact) == 1 and countCue("postImpactShimmer") == 0,
		"contact precedes quiet shimmer"
	)
	Engine.render:Fire(Config.flight.impactCalmAt + 0.01)
	check(countCue("postImpactShimmer") == 1, "post-impact shimmer at calm boundary")
	controller.skip()
	Engine.render:Fire(0.1)
	check(
		countCue("dive") == 1
			and countCue(profile.cues.impact) == 1
			and countCue("postImpactShimmer") == 1,
		"skip cannot replay flight audio"
	)
	controller.cancel()
	clean()
end
controller.destroy()
controller.destroy()
check(Engine.connections == baseline, "controller lifetime subscriptions released")
check(not controller.present(result(), false), "destroyed controller cannot reopen")

-- Reveal choices: dispatched only after the session has fully closed; Keep/B/cancel do nothing.
local chosen = {}
local chooser
chooser = Controller.create(function(value)
	focused = value
end, function() end, function(choice, awarded)
	table.insert(chosen, {
		choice = choice,
		id = awarded.figureId,
		active = chooser.isActive(),
		focused = focused,
	})
end)
local model = { label = "reveal model" }
chooser.present(result("echo.feather-hush"), false, nil, model)
check(Engine.reveal == model, "reveal model reaches the view")
reach("Result")
Engine.click("display")
check(Engine.state.phase == "Result" and #chosen == 0, "choices wait for the result guard")
Engine.render:Fire(0.4)
local refreshed = { label = "live" }
chooser.refresh(refreshed)
check(Engine.reveal == refreshed, "refresh forwards live affordability to the card")
Engine.click("display")
check(Engine.state.phase == "Closing" and #chosen == 0, "choice closes first")
Engine.render:Fire(0.12)
Engine.render:Fire(0.12)
check(
	#chosen == 1
		and chosen[1].choice == "display"
		and chosen[1].id == "echo.feather-hush"
		and not chosen[1].active
		and not chosen[1].focused,
	"choice runs after the opening released focus"
)
for _, key in { "B", "A" } do
	chooser.present(result(), false, nil, model)
	reach("Result")
	Engine.render:Fire(0.4)
	Engine.key(key)
	Engine.render:Fire(0.12)
	Engine.render:Fire(0.12)
	check(not chooser.isActive() and #chosen == 1, key .. " with no selected choice keeps the figure")
end
chooser.present(result(), false, nil, model)
reach("Result")
chooser.cancel()
check(#chosen == 1, "reset/cancel during the reveal sends nothing")

-- Open 10 steps always report back so the next step can take over in the same frame.
local function step(extra)
	sequence += 1
	local value = {
		requestId = "opening-" .. sequence,
		figureId = "tide.pearl",
		isNew = false,
		quantity = 1,
		direct = true,
		sequence = "middle",
	}
	for key, item in extra do
		value[key] = item
	end
	return table.freeze(value)
end
table.clear(chosen)
chooser.present(step({ direct = false, tease = "Mythical", sequence = "first" }), false, nil, model)
check(Engine.profile.rarity == "Mythical", "the box teases the batch's best rarity")
reach("Done")
check(#chosen == 1 and chosen[1].choice == "keep" and not chosen[1].active, "the tease box hands off when it closes")
chooser.present(step({}), false, nil, model)
reach("Result")
Engine.render:Fire(0.4)
Engine.click("shield")
Engine.render:Fire(0.12)
Engine.render:Fire(0.12)
check(#chosen == 2 and chosen[2].choice == "keep", "clicking anywhere moves to the next figure")
chooser.present(step({ sequence = "last" }), false, nil, model)
reach("Silhouette")
Engine.click("skip")
check(Engine.state.phase == "Closing", "Skip ends the step instead of jumping to its result")
Engine.render:Fire(0.12)
Engine.render:Fire(0.12)
check(#chosen == 3 and chosen[3].choice == "skip", "Skip reports skip-all")
-- Settled first/ninth results: mouse, touch, selected gamepad A and the skip API
-- all close once, respect the guard, and retain the confirmed receipt.
for _, index in { 1, 9 } do
	for _, input in { "MouseButton1", "Touch", "Gamepad1", "B", "X", "api" } do
		for _, reduced in { false, true } do
			local awarded = step({ requestId = "batch-" .. index .. "-" .. input .. "-" .. tostring(reduced) })
			local count = #chosen
			chooser.present(awarded, reduced, nil, { skip = "View all results" })
			reach("Result")
			local function activate()
				if input == "api" then
					chooser.skip()
				elseif input == "B" or input == "X" then
					Engine.input.last = "Gamepad1"
					Engine.key(input)
				elseif input == "Gamepad1" then
					Engine.input.last = "Gamepad1"
					Engine.guiService.SelectedObject = Engine.view.summary
					Engine.key("A")
				else
					Engine.click("summary", input)
				end
			end
			for _ = 1, 20 do activate() end
			check(Engine.state.phase == "Result" and #chosen == count, "summary waits for result guard")
			Engine.render:Fire(0.4)
			activate()
			check(Engine.state.phase == "Closing", "settled summary choice closes immediately")
			for _ = 1, 20 do activate() end
			Engine.render:Fire(0.12)
			Engine.render:Fire(0.12)
			check(#chosen == count + 1 and chosen[#chosen].choice == "skip", "summary spam dispatches skip-all once")
			check(chosen[#chosen].id == awarded.figureId and not chooser.isActive(), "confirmed figure preserved after close")
			Engine.input.last = "MouseButton1"
		end
	end
end
-- A late skip cannot replace Next after the result's accepted choice.
chooser.present(step({}), false, nil, { skip = "View all results" })
reach("Result")
Engine.render:Fire(0.4)
Engine.click("keep")
chooser.skip()
local count = #chosen
Engine.render:Fire(0.12)
Engine.render:Fire(0.12)
check(#chosen == count + 1 and chosen[#chosen].choice == "keep", "closing locks the accepted Next choice")
chooser.present(result(), false, nil, model)
reach("Result")
Engine.render:Fire(0.4)
Engine.click("shield")
Engine.render:Fire(0.12)
check(chooser.isActive() and Engine.state.phase == "Result", "a single opening ignores clicks outside its choices")
chooser.cancel()
chooser.destroy()
chooser.refresh(model)
check(Engine.connections == baseline, "chooser lifetime subscriptions released")

local scope = Scope.create()
local order = {}
scope.add(function()
	table.insert(order, 1)
end)
scope.add(function()
	error("Expected isolated cleanup failure")
end)
scope.add(function()
	table.insert(order, 3)
end)
scope.destroy()
scope.destroy()
scope.add(function()
	table.insert(order, 4)
end)
check(
	table.concat(order, ",") == "3,1,4",
	"cleanup is reverse-order, fault isolated and idempotent"
)
local cameraScope = Scope.create()
local owner = Camera.create(cameraScope, function()
	cameraScope.destroy()
end)
owner.take()
Engine.camera.FieldOfView = 42
owner.restore()
owner.restore()
cameraScope.destroy()
check(
	Engine.camera.FieldOfView == 73 and Engine.camera.CameraType == "Custom",
	"explicit camera restoration is idempotent"
)
check(Engine.connections == baseline, "camera watchers released")
print(
	"PASS: "
		.. checks
		.. " opening controller/camera lifecycle checks (engine doubles, not a Studio playtest)"
)

--!strict
local E = require("./OpeningVisualEngine")
E.Cinematic, E.Audio = require("./OpeningCinematic"), require("./OpeningAudio")
local Controller = require("./OpeningController")
local Scope = require("./OpeningScope")
local Box = require("./OpeningBox")
local Effects = require("./OpeningEffects")
local Config = require("./OpeningConfig")
local State = require("./OpeningState")
local Catalog = require("./Catalog")
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local template = E.template()
local baseline = E.connections
local errors = {}
local controller = Controller.create(function() end, function(message)
	table.insert(errors, message)
end)
local request = 0
local function start(id, reduced, direct, rarity)
	request += 1
	check(
		controller.present({
			requestId = "resources-" .. request,
			figureId = id,
			isNew = true,
			quantity = 1,
			direct = direct or false,
		}, reduced, rarity),
		"start real cinematic: " .. tostring(E.warnings[#E.warnings])
	)
end
local function reach(phase)
	for _ = 1, 500 do
		check(#errors == 0, "real presentation failed: " .. tostring(E.warnings[#E.warnings]))
		if E.state.phase == phase then
			return
		end
		if E.state.phase == "Await" then
			E.key("A")
		else
			E.render:Fire(0.05)
		end
	end
	error("did not reach " .. phase)
end
local function stage()
	return E.workspace:FindFirstChild("BlindboxCinematic")
end
local function resultClean()
	local model = stage()
	for _, object in model:GetDescendants() do
		check(
			object.Name ~= "OpeningPackage"
				and object.Name ~= "CollectionNamePlate"
				and not object:IsA("SurfaceGui"),
			"no packaging survives Result"
		)
		check(
			object.Name ~= "BoxEffects"
				and object.Name ~= "FlightEffects"
				and object.Name ~= "ImpactEffects"
				and object.Name ~= "RevealEffects",
			"temporary phase family retired"
		)
		if object:IsA("Light") then
			check(
				string.find(object.Name, "OpeningStudioLight", 1, true) ~= nil,
				"only result studio lights remain"
			)
		end
		if object.Name == "FigureBody" then
			check(
				object.TextureID == "original-texture" and object.Material == "SmoothPlastic",
				"figure material restored"
			)
			check(math.abs(object.Color[2] - 170 / 255) < 0.00001, "figure original color restored")
		end
	end
	check(#E.camera:GetChildren() == 2, "one known post-effect pair")
end
local function clean()
	controller.cancel()
	controller.cancel()
	check(stage() == nil, "stage gone")
	check(#E.camera:GetChildren() == 0, "post effects gone")
	check(E.services.SoundService:FindFirstChild("OpeningSounds") == nil, "audio gone")
	check(E.playerGui:FindFirstChild("BlindboxOpening") == nil, "UI gone")
	check(E.connections == baseline + 2, "only controller lifetime watchers remain")
	check(next(E.actions.bound) == nil, "input/render ownership released")
	check(E.camera.CameraType == "Custom" and E.camera.FieldOfView == 73, "camera restored")
	local storageGone = true
	for _, object in E.nodes do
		if not object.destroyed and object.Name == "HiddenCinematicAssets" then
			storageGone = false
		end
	end
	check(storageGone, "detached storage destroyed")
end
local ids = {
	"tide.coral",
	"tide.coral",
	"grove.moth",
	"tide.pearl",
	"grove.pebble",
	"grove.star",
	"tide.jelly",
	"grove.moth",
	"tide.pearl",
	"tide.coral",
}
-- Use the catalog's Coral Cuddle identity, not a fabricated fixture ID.
for _, figure in Catalog.figures do
	if figure.name == "Coral Cuddle" then
		ids[1], ids[2], ids[10] = figure.id, figure.id, figure.id
	end
end
local first
for _, reduced in { false, true } do
	for index, id in ids do
		start(id, reduced)
		reach("Arrival")
		local box = stage():FindFirstChild("OpeningPackage")
		check(
			box and box:GetAttribute("OpeningSource") == "Models.BlindBoxBase",
			"production box used"
		)
		local plate = box:FindFirstChild("CollectionNamePlate", true)
		check(
			plate and plate:FindFirstChild("CollectionName"),
			"production nameplate exists during box"
		)
		local lights = 0
		for _, node in stage():GetDescendants() do
			if node:IsA("Light") then
				lights += node.Brightness
			end
		end
		first = first or lights
		check(
			math.abs(lights - first) < 0.00001,
			"opening 1 and 10 have identical arrival light state"
		)
		local extra = {}
		for _, class in
			{
				"PointLight",
				"SurfaceLight",
				"SpotLight",
				"BillboardGui",
				"Attachment",
				"ParticleEmitter",
				"Beam",
				"Trail",
				"Highlight",
				"Part",
			}
		do
			local child = E.Instance.new(class)
			child.Parent = box
			table.insert(extra, child)
		end
		reach("Flight")
		check(
			not stage():FindFirstChild("BoxEffects", true),
			"charge light/emitters retired at flight"
		)
		reach("RarityTease")
		check(
			box.destroyed and plate.destroyed,
			"whole package and nameplate destroyed after lid travel"
		)
		for _, child in extra do
			check(child.destroyed, "dynamic box descendant retired: " .. child.ClassName)
		end
		E.flushTasks(true) -- force even canceled loader/timeout work to fire late
		check(
			not stage():FindFirstChild("OpeningPackage"),
			"obsolete phase tasks cannot recreate packaging"
		)
		reach("Result")
		resultClean()
		local bloom = E.camera:FindFirstChild("OpeningBloom")
		local intensity = bloom.Intensity
		for _ = 1, 30 do
			E.render:Fire(0.5)
		end
		check(bloom.Intensity == intensity, "held result brightness does not increase")
		E.key("A")
		reach("Done")
		clean()
		check(index <= 10, "ten sequential openings")
	end
end
for _, reduced in { false, true } do
	for _, phase in
		{
			"Anticipation",
			"Charge",
			"Await",
			"Break",
			"Flight",
			"RarityTease",
			"Impact",
			"Silhouette",
			"Reveal",
		}
	do
		start(ids[1], reduced)
		reach(phase)
		controller.skip()
		resultClean()
		clean()
	end
	for _, phase in
		{ "Enter", "Arrival", "Charge", "Await", "Break", "Flight", "Impact", "Reveal", "Result" }
	do
		start(ids[1], reduced)
		reach(phase)
		clean()
	end
end
-- Skip after effects have started (phase-entry-only tests cannot catch live tail/light leakage).
for _, reduced in { false, true } do
	for _, fixture in
		{ { "Break", 0.65 }, { "Flight", 0.5 }, { "RarityTease", 0.92 }, { "Impact", 0.25 } }
	do
		start("grove.star", reduced)
		reach(fixture[1])
		E.render:Fire(State.duration(E.state) * fixture[2])
		local retired = stage():FindFirstChild(
			if fixture[1] == "Impact" then "ImpactEffects" else "FlightEffects",
			true
		)
		check(retired ~= nil, "transient effects exist before mid-beat Skip")
		controller.skip()
		check(retired.destroyed, "mid-beat Skip destroys active transient family")
		resultClean()
		clean()
	end
end
-- Physical pursuit/FOV and fixed reduced camera use actual Cinematic code.
for _, reduced in { false, true } do
	start("grove.star", reduced)
	reach("Flight")
	local beforePosition, beforeFov = E.camera.CFrame.Position, E.camera.FieldOfView
	for _ = 1, 8 do
		E.render:Fire(State.duration(E.state) / 10)
	end
	local distance = (E.camera.CFrame.Position - beforePosition).Magnitude
	check(
		if reduced then distance < 0.00001 else distance > 6,
		"camera travels with comet only in normal motion"
	)
	check(
		if reduced then E.camera.FieldOfView == beforeFov else E.camera.FieldOfView > beforeFov + 5,
		"pursuit FOV communicates acceleration"
	)
	clean()
end
E.studio = true
for _, rarity in { "Legendary", "Mythical" } do
	for _, reduced in { false, true } do
		local expectedCount
		for _ = 1, 10 do
			start("grove.pebble", reduced, false, rarity)
			reach("Flight")
			local count = #stage():GetDescendants()
			expectedCount = expectedCount or count
			check(count == expectedCount, "high-tier opening 10 has opening 1 resource baseline")
			reach("RarityTease")
			E.render:Fire(Config.profile(rarity).flight.transition)
			check(
				E.profile.rarity == rarity and Catalog.byId["grove.pebble"].rarity == "Common",
				"preview never mutates catalog"
			)
			reach("Silhouette")
			check(
				not stage():FindFirstChild("FlightEffects", true)
					and not stage():FindFirstChild("ImpactEffects", true),
				"high-tier transient families retired"
			)
			reach("Result")
			resultClean()
			clean()
		end
		for _, fixture in { { "RarityTease", 0.12 }, { "RarityTease", 0.9 }, { "Impact", 0.25 } } do
			start("grove.pebble", reduced, false, rarity)
			reach(fixture[1])
			E.render:Fire(State.duration(E.state) * fixture[2])
			controller.skip()
			resultClean()
			clean()
		end
	end
end
E.studio = false
start(ids[1], false, true)
reach("Result")
resultClean()
clean()
start(ids[1], false)
reach("Flight")
E.playerGui:FindFirstChild("BlindboxOpening"):Destroy()
clean()
start(ids[1], false)
reach("Impact")
E.player.CharacterRemoving:Fire()
clean()
start(ids[1], false)
local oldGui = E.playerGui:FindFirstChild("BlindboxOpening")
local queued = oldGui.Destroying:Capture()
clean()
start(ids[1], false)
for _, callback in queued do
	callback()
end
check(controller.isActive(), "queued old-session close cannot cancel the successor")
clean()
template.Parent = nil
start(ids[1], false)
reach("Arrival")
check(
	stage():FindFirstChild("OpeningPackage"):GetAttribute("OpeningSource") == "EmergencyFallback",
	"full presentation uses fallback when production is absent"
)
reach("Result")
resultClean()
clean()
template.Parent = E.replication
controller.destroy()
check(E.connections == baseline, "all controller/render/camera connections released")

-- Actual async production/fallback behavior, including callbacks forced past cancellation.
local holder = E.Instance.new("Folder")
local scope = Scope.create()
local box = Box.create(holder, "tide", scope, function()
	return true
end)
check(box.production, "production path")
local oldJobs = E.tasks
E.tasks = {}
scope.destroy()
local nextScope = Scope.create()
local nextBox = Box.create(holder, "grove", nextScope, function()
	return true
end)
for _, job in oldJobs do
	job.callback()
end
check(
	box.model.destroyed and #holder:GetChildren() == 1 and nextBox.production,
	"obsolete session work cannot mutate successor"
)
nextScope.destroy()
E.flushTasks(true)
template:Destroy()
local fallbackScope = Scope.create()
local fallback = Box.create(holder, "grove", fallbackScope, function()
	return true
end)
check(not fallback.production, "missing production falls back")
template = E.template()
E.replication.DescendantAdded:Fire()
check(fallback.production, "replication upgrades live fallback")
fallbackScope.destroy()
E.flushTasks(true)
check(fallback.model.destroyed, "upgraded hierarchy also retires")
local failedScope = Scope.create()
local failed = Box.create(holder, "tide", failedScope, function()
	return true
end)
E.failLoad = true
-- Run preload before its timeout.
local jobs = E.tasks
E.tasks = {}
for i = #jobs, 1, -1 do
	if not jobs[i].canceled and coroutine.status(jobs[i].thread) ~= "dead" then
		assert(coroutine.resume(jobs[i].thread))
	end
end
check(not failed.production, "failed delivery replaces production once")
E.failLoad = false
failedScope.destroy()
holder:Destroy()

-- Stale phase draws/cues and post-cleanup calls cannot turn retired lighting back on.
local effectsScope = Scope.create()
local parent = E.Instance.new("Model")
local effects = Effects.create(
	parent,
	E.camera,
	effectsScope,
	Config.rarities.Rare,
	Config.collection("tide"),
	false,
	false
)
local state = State.create(Config.rarities.Rare.timing, false, false)
for _, phase in
	{
		"Arrival",
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
	}
do
	for _, progress in { 0, 0.25, 0.5, 0.75, 1 } do
		local light = Config.lightState(phase, progress)
		check(
			light.studio + light.seam + light.comet <= Config.lighting.peak + 0.00001,
			"combined lighting budget: " .. phase
		)
		if phase == "Result" then
			check(light.seam == 0 and light.comet == 0, "result has no transient illumination")
		end
	end
end
state.phase = "Impact"
effects.enter(state.phase)
effects.update(state, E.CFrame.new(), E.Vector3.zero, 0)
state.phase = "Result"
effects.enter(state.phase)
effects.update(state, E.CFrame.new(), E.Vector3.zero, 0)
local bloom = E.camera:FindFirstChild("OpeningBloom")
local before = bloom.Intensity
state.phase = "Charge"
effects.enter("Charge")
effects.update(state, E.CFrame.new(), E.Vector3.zero, 0)
effects.tease({
	color = Config.neutral,
	secondary = Config.neutral,
	shatter = true,
	at = 0,
	cue = "",
})
check(bloom.Intensity == before, "obsolete phase draws/cues cannot mutate Result")
effects.suspend()
state.phase = "Result"
effects.update(state, E.CFrame.new(), E.Vector3.zero, 0)
check(not bloom.Enabled, "suspended effects cannot restart")
effectsScope.destroy()
effects.clear()
effects.enter("Charge")
parent:Destroy()
check(#E.camera:GetChildren() == 0, "temporary post effects destroyed idempotently")
local owner = Scope.create()
local called = 0
local callback = owner.guard(function()
	called += 1
end)
callback()
owner.destroy()
callback()
check(called == 1, "guard invalidates obsolete callbacks")
check(E.connections == baseline, "box loader subscriptions released")
check(#errors == 0, "no presentation errors")
print(
	"PASS: "
		.. checks
		.. " real opening resource/phase checks (engine primitives; visual acceptance requires Studio)"
)

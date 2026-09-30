--!strict
local Engine = require("./OpeningEngine")
local Controller = require("./OpeningController")
local Camera = require("./OpeningCamera")
local Scope = require("./OpeningScope")
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
local function result()
	sequence += 1
	return table.freeze({
		requestId = "opening-" .. sequence,
		figureId = "tide.pearl",
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
		if cue == "reveal" then
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
		if cue == "reveal" then
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
controller.destroy()
controller.destroy()
check(Engine.connections == baseline, "controller lifetime subscriptions released")
check(not controller.present(result(), false), "destroyed controller cannot reopen")

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

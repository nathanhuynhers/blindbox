--!strict
-- Paste into Studio's CLIENT Command Bar during Play. Never mapped by Rojo; no remotes/grants.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
assert(RunService:IsStudio(), "This presentation fixture is Studio-only")
local player = Players.LocalPlayer
assert(player, "Run in the CLIENT Command Bar during Play")
local playerGui = player:WaitForChild("PlayerGui")
assert(not playerGui:FindFirstChild("OpeningPreview"), "Exit the existing fixture first")
assert(not playerGui:FindFirstChild("BlindboxOpening"), "Finish the real opening first")
local source = player.PlayerScripts:WaitForChild("Client")
local Controller = require(source:WaitForChild("OpeningController") :: ModuleScript)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local main = playerGui:WaitForChild("PocketGrove") :: ScreenGui
local wasEnabled = main.Enabled
main.Enabled = false
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "OpeningPreview", false, 90
gui.Parent = playerGui
local panel = Instance.new("ScrollingFrame")
panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
panel.Size, panel.BackgroundColor3 = UDim2.fromScale(0.9, 0.9), Color3.fromRGB(25, 36, 42)
panel.AutomaticCanvasSize, panel.CanvasSize, panel.ScrollBarThickness =
	Enum.AutomaticSize.Y, UDim2.new(), 6
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize, limit.Parent = Vector2.new(460, 760), panel
local list = Instance.new("UIListLayout")
list.Padding, list.SortOrder, list.Parent = UDim.new(0, 7), Enum.SortOrder.LayoutOrder, panel
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom =
	UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 12)
padding.Parent = panel
local connections: { RBXScriptConnection } = {}
local jobs: { thread } = {}
local reduced, fresh, closed, runningLoop = false, true, false, false
local skipPhases = {
	"Manual",
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
local skipIndex, order = 1, 0
local controller = Controller.create(function(active: boolean)
	panel.Visible = not active and not runningLoop
end, warn)
local phaseConnection: RBXScriptConnection? = nil
local function disconnectPhase()
	if phaseConnection then
		phaseConnection:Disconnect()
		phaseConnection = nil
	end
end
local function button(text: string, callback: () -> ()): TextButton
	order += 1
	local object = Instance.new("TextButton")
	object.Size, object.BackgroundColor3, object.TextColor3 =
		UDim2.new(1, 0, 0, 44), Color3.fromRGB(230, 231, 216), Color3.fromRGB(25, 36, 42)
	object.Text, object.TextSize, object.TextWrapped, object.LayoutOrder = text, 14, true, order
	object.Parent = panel
	table.insert(connections, object.Activated:Connect(callback))
	return object
end
local function present(id: string, direct: boolean?)
	disconnectPhase()
	assert(Catalog.byId[id], "Use an existing catalog ID")
	local result = {
		requestId = HttpService:GenerateGUID(false),
		figureId = id,
		isNew = fresh,
		quantity = if fresh then 1 else 5,
		direct = direct == true,
	}
	assert(controller.present(result, reduced), "Opening should start")
	assert(not controller.present(result, reduced), "Concurrent/replayed opening must be rejected")
	local opening = playerGui:FindFirstChild("BlindboxOpening")
	if opening and skipIndex > 1 then
		phaseConnection = opening:GetAttributeChangedSignal("Phase"):Connect(function()
			if opening:GetAttribute("Phase") == skipPhases[skipIndex] then
				disconnectPhase()
				controller.skip()
			end
		end)
	end
end
for _, fixture in
	{
		{ "Pocket Grove / Common", "grove.pebble" },
		{ "Pocket Grove / Uncommon", "grove.moth" },
		{ "Pocket Grove / Rare", "grove.star" },
		{ "Tidepool Tales / Common", "tide.bubble" },
		{ "Tidepool Tales / Uncommon", "tide.jelly" },
		{ "Tidepool Tales / Rare", "tide.pearl" },
	}
do
	button(fixture[1], function()
		present(fixture[2])
	end)
end
local motionButton: TextButton? = nil
motionButton = button("Reduced motion: OFF", function()
	reduced = not reduced
	if motionButton then
		motionButton.Text = "Reduced motion: " .. (if reduced then "ON" else "OFF")
	end
end)
local newButton: TextButton? = nil
newButton = button("Result: NEW (1 owned)", function()
	fresh = not fresh
	if newButton then
		newButton.Text = if fresh then "Result: NEW (1 owned)" else "Result: duplicate (5 owned)"
	end
end)
local skipButton: TextButton? = nil
skipButton = button("Skip test: Manual (click to cycle phase)", function()
	skipIndex = skipIndex % #skipPhases + 1
	if skipButton then
		skipButton.Text = "Skip test: " .. skipPhases[skipIndex] .. " (click to cycle)"
	end
end)
order += 1
local idInput = Instance.new("TextBox")
idInput.Text, idInput.PlaceholderText, idInput.ClearTextOnFocus =
	"grove.star", "Existing catalog ID", false
idInput.Size, idInput.TextSize, idInput.LayoutOrder = UDim2.new(1, 0, 0, 42), 15, order
idInput.Parent = panel
button("Preview catalog ID above", function()
	present(idInput.Text)
end)
button("Redemption / direct figure spotlight", function()
	present(idInput.Text, true)
end)
local function assertClean(camera: Camera, beforeType: Enum.CameraType, beforeFov: number)
	assert(not controller.isActive(), "Session leaked")
	assert(not playerGui:FindFirstChild("BlindboxOpening"), "Opening GUI leaked")
	assert(not workspace:FindFirstChild("BlindboxCinematic"), "Stage leaked")
	assert(
		not game:GetService("SoundService"):FindFirstChild("OpeningSounds"),
		"Sound folder leaked"
	)
	assert(
		not camera:FindFirstChild("OpeningBloom") and not camera:FindFirstChild("OpeningGrade"),
		"Post effects leaked"
	)
	assert(
		camera.CameraType == beforeType and camera.FieldOfView == beforeFov,
		"Camera state not restored"
	)
	local actions = game:GetService("ContextActionService"):GetAllBoundActionInfo()
	assert(
		not actions.BlindboxOpeningInput and not actions.BlindboxOpeningMovement,
		"Action binding leaked"
	)
end
button("Lifecycle check: 20 interruptions AFTER camera takeover", function()
	if controller.isActive() then
		return
	end
	table.insert(
		jobs,
		task.spawn(function()
			local ok, reason = pcall(function(): boolean
				for index = 1, 20 do
					if closed then
						return true
					end
					local camera = workspace.CurrentCamera
					assert(camera, "No camera")
					local beforeType, beforeFov = camera.CameraType, camera.FieldOfView
					assert(
						controller.present({
							requestId = HttpService:GenerateGUID(false),
							figureId = "grove.star",
							isNew = true,
							quantity = 1,
							direct = false,
						}, index % 2 == 0),
						"Opening should start"
					)
					task.wait(0.3)
					assert(
						camera.CameraType == Enum.CameraType.Scriptable,
						"Camera never entered cinematic"
					)
					if index % 3 == 0 then
						local opening = playerGui:FindFirstChild("BlindboxOpening")
						assert(opening, "Missing opening")
						opening:Destroy()
					else
						controller.cancel()
					end
					controller.cancel()
					assertClean(camera, beforeType, beforeFov)
				end
				return true
			end)
			controller.cancel()
			if ok then
				print("PASS: 20 native camera/GUI/stage/audio/input interruption checks")
			else
				warn(reason)
			end
		end)
	)
end)
-- Manual Open/Continue preserve the real input path while the fixture queues ten sessions.
-- Diagnostics run only here in Studio, never in production output or a per-frame scan.
local function inspect(camera: Camera): { [string]: number }
	local counts = {
		postEffects = 0,
		lights = 0,
		particles = 0,
		beams = 0,
		trails = 0,
		boxes = 0,
		figures = 0,
		brightness = 0,
		bloom = 0,
		renderConnections = 0,
		tweens = 0,
		stages = 0,
	}
	for _, child in workspace:GetChildren() do
		if child.Name == "BlindboxCinematic" then
			counts.stages += 1
		end
	end
	local stage = workspace:FindFirstChild("BlindboxCinematic")
	if stage then
		for _, child in stage:GetDescendants() do
			if child:IsA("Light") then
				counts.lights += 1
				if child.Enabled then
					counts.brightness += child.Brightness
				end
			elseif child:IsA("ParticleEmitter") then
				counts.particles += 1
			elseif child:IsA("Beam") then
				counts.beams += 1
			elseif child:IsA("Trail") then
				counts.trails += 1
			end
			if child.Name == "OpeningPackage" then
				counts.boxes += 1
			end
		end
		for _, child in stage:GetChildren() do
			if child:IsA("Model") and child.Name ~= "OpeningPackage" then
				counts.figures += 1
			end
		end
	end
	for _, child in camera:GetChildren() do
		if child.Name == "OpeningBloom" or child.Name == "OpeningGrade" then
			counts.postEffects += 1
			if child:IsA("BloomEffect") then
				counts.bloom = child.Intensity
			end
		end
	end
	local opening = playerGui:FindFirstChild("BlindboxOpening")
	if opening then
		counts.renderConnections = (opening:GetAttribute("RenderConnections") :: number?) or 0
	end
	return counts
end
button("10-opening regression: manually Open / Continue each", function()
	if runningLoop or controller.isActive() then
		return
	end
	runningLoop, panel.Visible = true, false
	table.insert(
		jobs,
		task.spawn(function()
			local ok, reason = pcall(function(): boolean
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
				local Lighting = game:GetService("Lighting")
				local originalLighting = {
					Lighting.ExposureCompensation,
					Lighting.Brightness,
					Lighting.Ambient,
					Lighting.OutdoorAmbient,
				}
				local baselineCamera = workspace.CurrentCamera
				assert(baselineCamera, "No camera")
				local cameraChildren, lightingChildren =
					#baselineCamera:GetChildren(), #Lighting:GetChildren()
				local firstArrival: { [string]: number }? = nil
				for index, id in ids do
					if closed then
						return true
					end
					local camera = workspace.CurrentCamera
					assert(
						camera == baselineCamera,
						"Camera was replaced; rerun after interruption test"
					)
					local beforeType, beforeFov = camera.CameraType, camera.FieldOfView
					print(
						string.format(
							"Opening %d/10: %s — Open, inspect the result, then Continue",
							index,
							Catalog.byId[id].name
						)
					)
					present(id)
					local arrivalSeen, resultSeen = false, false
					local deadline = os.clock() + 180
					while controller.isActive() and not closed do
						assert(os.clock() < deadline, "Timed out waiting for Open/Continue")
						local opening = playerGui:FindFirstChild("BlindboxOpening")
						local phase = if opening then opening:GetAttribute("Phase") else nil
						if phase == "Arrival" and not arrivalSeen then
							arrivalSeen = true
							local counts = inspect(camera)
							if firstArrival then
								for key, value in firstArrival do
									-- Rarity changes ring geometry and Bloom; compare light/post/stage baselines.
									if
										key == "lights"
										or key == "brightness"
										or key == "postEffects"
										or key == "stages"
										or key == "boxes"
									then
										assert(
											math.abs(counts[key] - value) < 0.00001,
											"Arrival baseline drift: " .. key
										)
									end
								end
							else
								firstArrival = counts
							end
							print("Arrival resources: " .. HttpService:JSONEncode(counts))
						elseif phase == "Result" and not resultSeen then
							resultSeen = true
							local counts = inspect(camera)
							assert(
								counts.boxes == 0
									and counts.trails == 0
									and counts.lights == 3
									and counts.postEffects == 2,
								"Result resources leaked"
							)
							local stage = workspace:FindFirstChild("BlindboxCinematic")
							assert(stage, "Missing stage")
							for _, root in { stage, opening :: Instance } do
								for _, child in root:GetDescendants() do
									assert(
										child.Name ~= "CollectionNamePlate"
											and not child:IsA("SurfaceGui")
											and not child:IsA("BillboardGui"),
										"Packaging UI survived"
									)
								end
							end
							print("Result resources: " .. HttpService:JSONEncode(counts))
						end
						task.wait(0.05)
					end
					if closed then
						return true
					end
					assert(resultSeen, "Session interrupted before Result")
					assertClean(camera, beforeType, beforeFov)
					assert(
						#camera:GetChildren() == cameraChildren
							and #Lighting:GetChildren() == lightingChildren,
						"Global post effects accumulated"
					)
					assert(
						Lighting.ExposureCompensation == originalLighting[1]
							and Lighting.Brightness == originalLighting[2]
							and Lighting.Ambient == originalLighting[3]
							and Lighting.OutdoorAmbient == originalLighting[4],
						"Global Lighting changed"
					)
					local counts = inspect(camera)
					for key, value in counts do
						assert(value == 0, "Cleanup leaked " .. key)
					end
					print(
						string.format(
							"Opening %d/10 cleaned: %s",
							index,
							HttpService:JSONEncode(counts)
						)
					)
				end
				print(
					"PASS: 10 sequential presentations returned to baseline. Visually compare openings 1 and 10."
				)
				return true
			end)
			controller.cancel()
			runningLoop = false
			if not closed then
				panel.Visible = true
			end
			if not ok then
				warn(reason)
			end
		end)
	)
end)
local function cleanup()
	if closed then
		return
	end
	closed = true
	disconnectPhase()
	controller.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, job in jobs do
		if job ~= coroutine.running() and coroutine.status(job) ~= "dead" then
			task.cancel(job)
		end
	end
	gui:Destroy()
	main.Enabled = wasEnabled
	print("Opening fixture exited. No purchases or grants were made.")
end
button("Exit preview", cleanup)
table.insert(connections, gui.Destroying:Connect(cleanup))

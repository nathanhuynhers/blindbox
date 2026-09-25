--!strict
-- Paste into Studio's CLIENT Command Bar during Play. Presentation fixtures only; no remotes/grants.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
assert(player, "Run this in the client Command Bar during Play")
local playerGui = player:WaitForChild("PlayerGui")
assert(not playerGui:FindFirstChild("OpeningPreview"), "Exit the existing preview first")
assert(not playerGui:FindFirstChild("BlindboxOpening"), "Finish the real opening first")
local source = player.PlayerScripts:WaitForChild("Client")
local Controller = require(source:WaitForChild("OpeningController") :: ModuleScript)
local main = playerGui:WaitForChild("PocketGrove") :: ScreenGui
local enabledBefore = main.Enabled
main.Enabled = false
local gui = Instance.new("ScreenGui")
gui.Name = "OpeningPreview"
gui.ResetOnSpawn = false
gui.DisplayOrder = 90
gui.Parent = playerGui
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.9)
panel.BackgroundColor3 = Color3.fromRGB(25, 42, 47)
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(440, 620)
limit.Parent = panel
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel
local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingTop = UDim.new(0, 12)
padding.Parent = panel
local controller = Controller.create(function(_active: boolean) end, warn)
local connections: { RBXScriptConnection } = {}
local reduced = false
local closed = false
local order = 0
local function button(text: string, callback: () -> ()): TextButton
	order += 1
	local object = Instance.new("TextButton")
	object.Size = UDim2.new(1, 0, 0.1, -5)
	object.BackgroundColor3 = Color3.fromRGB(219, 234, 223)
	object.TextColor3 = Color3.fromRGB(25, 42, 47)
	object.Text = text
	object.TextSize = 15
	object.LayoutOrder = order
	object.Parent = panel
	table.insert(connections, object.Activated:Connect(callback))
	return object
end
local fixtures = {
	{ name = "Grove / Common / NEW", id = "grove.pebble", fresh = true, direct = false },
	{ name = "Tide / Common / 5 owned", id = "tide.bubble", fresh = false, direct = false },
	{ name = "Grove / Uncommon / NEW", id = "grove.moth", fresh = true, direct = false },
	{ name = "Tide / Uncommon / 5 owned", id = "tide.jelly", fresh = false, direct = false },
	{ name = "Grove / Rare / NEW", id = "grove.star", fresh = true, direct = false },
	{ name = "Tide / Rare / 5 owned", id = "tide.pearl", fresh = false, direct = false },
	{ name = "Redemption / direct spotlight", id = "grove.mushroom", fresh = true, direct = true },
}
for _, fixture in fixtures do
	button(fixture.name, function()
		local result = {
			requestId = HttpService:GenerateGUID(false),
			figureId = fixture.id,
			isNew = fixture.fresh,
			quantity = if fixture.fresh then 1 else 5,
			direct = fixture.direct,
		}
		assert(controller.present(result, reduced), "Opening should start")
		assert(
			not controller.present(result, reduced),
			"Overlapping/replayed opening must be rejected"
		)
	end)
end
local toggle: TextButton? = nil
toggle = button("Reduced motion: OFF", function()
	reduced = not reduced
	if toggle then
		toggle.Text = "Reduced motion: " .. (if reduced then "ON" else "OFF")
	end
end)
button("Lifecycle check: 20 interrupted openings", function()
	for index = 1, 20 do
		local started = controller.present({
			requestId = "cancel-" .. HttpService:GenerateGUID(false),
			figureId = "grove.star",
			isNew = true,
			quantity = 1,
			direct = false,
		}, index % 2 == 0)
		assert(started, "Opening should start")
		controller.cancel()
		assert(not controller.isActive(), "Cancellation left a session")
		assert(not playerGui:FindFirstChild("BlindboxOpening"), "Opening GUI leaked")
		assert(
			not game:GetService("SoundService"):FindFirstChild("OpeningSounds"),
			"Opening audio leaked"
		)
		local actions = game:GetService("ContextActionService"):GetAllBoundActionInfo()
		assert(
			not actions.BlindboxOpeningInput and not actions.BlindboxOpeningMovement,
			"Input binding leaked"
		)
	end
	print(
		"PASS: 20 engine construction/cancellation cycles; GUI, audio and action bindings removed"
	)
end)
local function cleanup()
	if closed then
		return
	end
	closed = true
	controller.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	gui:Destroy()
	main.Enabled = enabledBefore
	assert(not playerGui:FindFirstChild("BlindboxOpening"), "Opening GUI leaked")
	assert(
		not game:GetService("SoundService"):FindFirstChild("OpeningSounds"),
		"Opening audio leaked"
	)
	print(
		"Opening preview exited; GUI/audio containers cleaned. Check Output and visual checklist."
	)
end
button("Exit preview (no items were granted)", cleanup)
table.insert(connections, gui.Destroying:Connect(cleanup))

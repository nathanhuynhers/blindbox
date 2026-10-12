--!strict
-- Private CLIENT Command Bar fixture. First install tests/StoreFixtures.luau as a temporary
-- ModuleScript named StoreFixtures under the client's Client script (see handoff).
-- No remotes/purchases/rewards. Close removes this fixture and every owned listener/task.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
assert(RunService:IsStudio(), "Studio-only fixture")
local player = Players.LocalPlayer
assert(player, "Run in the client Command Bar")
local client = player.PlayerScripts:WaitForChild("Client")
local Fixtures = require(client:WaitForChild("StoreFixtures") :: ModuleScript)
local Store = require(client:WaitForChild("StoreScreen") :: ModuleScript)
local Offline = require(client:WaitForChild("OfflineEarnings") :: ModuleScript)
local Scope = require(client:WaitForChild("UIScope") :: ModuleScript)
local Layout = require(client:WaitForChild("UILayout") :: ModuleScript)
local Style = require(client:WaitForChild("UIStyle") :: ModuleScript)
local Kit = require(client:WaitForChild("UIKit") :: ModuleScript)
local existing = player.PlayerGui:FindFirstChild("StorePresentationFixture")
assert(not existing, "Close the existing fixture first")
local scope = Scope.create()
local priorFocus = GuiService.SelectedObject
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "StorePresentationFixture", false, 80
gui.ScreenInsets, gui.ZIndexBehavior =
	Enum.ScreenInsets.DeviceSafeInsets, Enum.ZIndexBehavior.Sibling
local safe = Kit.frame(gui, "SafeArea", Style.dim)
safe.Size = UDim2.fromScale(1, 1)
local stage = Kit.frame(safe, "Stage")
local scale = Instance.new("UIScale")
scale.Parent = stage
local host = Kit.frame(stage, "Host")
local running, effects, index = true, false, 1
local fixture = Fixtures.make("available")
local observed = os.clock()
local screen: Store.PresentationScreen
local popup = Offline.create(function()
	return effects
end, function()
	error("Fixture attempted a real free claim")
end)
local function close()
	if not running then
		return
	end
	running = false
	screen.shown(false)
	popup.destroy()
	scope.destroy()
	gui:Destroy()
	GuiService.SelectedObject = if priorFocus and priorFocus.Parent then priorFocus else nil
end
screen = Store.create(host, {
	scope = scope,
	effects = function()
		return effects
	end,
	scale = function()
		return scale.Scale
	end,
	snapshot = function()
		return nil
	end,
	canAct = function()
		return false
	end,
	send = function()
		error("Store fixture attempted a request")
	end,
	navigate = function() end,
	close = close,
	message = function() end,
})
local controls = Kit.frame(safe, "FixtureControls", Style.white)
local label = Kit.text(controls, "State", "", 13, Style.body(Enum.FontWeight.Heavy))
label.TextWrapped = true
local function button(name: string, text: string, callback: () -> ()): TextButton
	local made = Instance.new("TextButton")
	made.Name, made.Text, made.FontFace, made.TextSize = name, text, Style.display(), 15
	made.BackgroundColor3, made.TextColor3, made.BorderSizePixel = Style.violet, Style.white, 0
	made.Parent = controls
	Kit.corner(made, 10)
	Kit.stroke(made, Style.ink, Style.outlineSmall)
	scope.connect(made.Activated, callback)
	return made
end
local function showState()
	fixture = Fixtures.make(Fixtures.states[index])
	observed = os.clock()
	screen.present(fixture)
	label.Text = `PREVIEW ONLY · {Fixtures.states[index]} · No purchases/rewards`
	if Fixtures.states[index] == "perks" then
		screen.route({ tab = "perks" })
	end
end
local prev = button("Previous", "← State", function()
	index = (index - 2) % #Fixtures.states + 1
	showState()
end)
local nextState = button("Next", "State →", function()
	index = index % #Fixtures.states + 1
	showState()
end)
local offlineIndex = 1
local offlineStates =
	{ "idle", "prompting", "verifying", "saving", "recovering", "granted", "cancelled", "failed" }
local offlineButton = button("Offline", "Offline", function()
	popup.present(Fixtures.offline(offlineStates[offlineIndex]))
	popup.show("10,000", "3h 12m")
	offlineIndex = offlineIndex % #offlineStates + 1
end)
local motion = button("Motion", "Motion OFF", function()
	effects = not effects
	local target = controls:FindFirstChild("Motion") :: TextButton
	target.Text = if effects then "Motion ON" else "Motion OFF"
end)
local stop = button("EndFixture", "Close", close)
scope.connect(Input.InputBegan, function(value)
	if value.KeyCode == Enum.KeyCode.F8 then
		controls.Visible = not controls.Visible
	elseif value.KeyCode == Enum.KeyCode.F9 then
		close()
	elseif value.KeyCode == Enum.KeyCode.F7 then
		popup.present(Fixtures.offline(offlineStates[offlineIndex]))
		popup.show("10,000", "3h 12m")
		offlineIndex = offlineIndex % #offlineStates + 1
	end
end)
local function resize()
	local size = safe.AbsoluteSize
	local frame = Layout.frame(size.X, size.Y, { left = 0, right = size.X })
	scale.Scale = frame.scale
	stage.Size = UDim2.fromOffset(frame.width, frame.height)
	local panel = frame.panel
	-- Fixture toolbar uses the HUD space on desktop; phone viewport retains the real sheet size.
	Kit.rect(host, panel.x, panel.y, panel.width, panel.height)
	screen.layout(panel.width, panel.height, frame.phone)
	Kit.rect(controls, 0, 0, size.X, 44)
	local w = math.max(44, math.min(88, (size.X - 180) / 5))
	for position, target in { prev, nextState, offlineButton, motion, stop } do
		Kit.rect(target, (position - 1) * (w + 4), 0, w, 44)
	end
	Kit.rect(label, 5 * (w + 4), 0, size.X - 5 * (w + 4), 44)
	print(`Store fixture viewport {size.X}×{size.Y}; scale {frame.scale}; phone {frame.phone}`)
end
scope.connect(safe:GetPropertyChangedSignal("AbsoluteSize"), resize)
scope.connect(GuiService:GetPropertyChangedSignal("SelectedObject"), function()
	local selected = GuiService.SelectedObject
	if not selected or not selected:IsDescendantOf(gui) then
		return
	end
	local ancestor = selected.Parent
	while ancestor and ancestor ~= gui do
		if ancestor:IsA("ScrollingFrame") then
			local top = selected.AbsolutePosition.Y - ancestor.AbsolutePosition.Y
			local bottom = top + selected.AbsoluteSize.Y
			local window = ancestor.AbsoluteWindowSize.Y
			local shift = if top < 4
				then top - 4
				elseif bottom > window - 4 then bottom - window + 4
				else 0
			local limit = math.max(0, ancestor.CanvasSize.Y.Offset - window / scale.Scale)
			ancestor.CanvasPosition = Vector2.new(
				0,
				math.clamp(ancestor.CanvasPosition.Y + shift / scale.Scale, 0, limit)
			)
			break
		end
		ancestor = ancestor.Parent
	end
end)
Actions:BindActionAtPriority("StoreFixtureInput", function(_, state, input)
	if state == Enum.UserInputState.Begin and not popup.isOpen() then
		if input.KeyCode == Enum.KeyCode.ButtonB then
			if not screen.back() then
				close()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
			screen.cycle(-1)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			screen.cycle(1)
		end
	end
	return Enum.ContextActionResult.Sink
end, false, 4000, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
scope.add(function()
	Actions:UnbindAction("StoreFixtureInput")
end)
local timer: thread? = nil
local function tick()
	if not running then
		return
	end
	screen.tick(fixture.now + os.clock() - observed)
	timer = task.delay(1, tick)
end
scope.add(function()
	if timer then
		task.cancel(timer)
		timer = nil
	end
end)
gui.Parent = player.PlayerGui
showState()
screen.shown(true)
resize()
GuiService.SelectedObject = screen.root:FindFirstChild("Close", true) :: GuiObject?
tick()
print(
	"Store fixture ready. State arrows cover 24 cases. F7 cycles offline outcomes; F8 hides toolbar for capture; F9 tears down."
)

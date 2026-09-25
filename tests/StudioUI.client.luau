--!strict
-- Read-only checks in the CLIENT Command Bar during Play. Repeat on every screen/device.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio-only UI check")
local player = Players.LocalPlayer
assert(player, "Use the client Command Bar")
local gui = player.PlayerGui:WaitForChild("PocketGrove") :: ScreenGui
assert(gui.Enabled, "Finish the opening before checking the normal UI")
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
local function visible(object: GuiObject): boolean
	local ancestor: Instance? = object
	while ancestor and ancestor ~= gui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end
local buttons, scrolls = 0, 0
for _, object in gui:GetDescendants() do
	if object:IsA("GuiButton") and visible(object) and object.Selectable then
		buttons += 1
		assert(
			object.AbsoluteSize.X >= 43.9 and object.AbsoluteSize.Y >= 43.9,
			"Small target: " .. object:GetFullName()
		)
	elseif object:IsA("ScrollingFrame") and visible(object) then
		local layout = object:FindFirstChildOfClass("UIGridLayout")
			or object:FindFirstChildOfClass("UIListLayout")
		if layout then
			scrolls += 1
			local padding = object:FindFirstChildOfClass("UIPadding")
			local extra = if padding
				then padding.PaddingTop.Offset + padding.PaddingBottom.Offset
				else 0
			assert(
				object.CanvasSize.Y.Offset >= math.ceil(layout.AbsoluteContentSize.Y + extra),
				"Truncated scroll: " .. object:GetFullName()
			)
			assert(
				object.AbsoluteWindowSize.X > 0 and object.AbsoluteWindowSize.Y > 0,
				"Empty viewport: " .. object:GetFullName()
			)
		end
	end
end
local bounds = gui:WaitForChild("SafeArea") :: Frame
local screens = bounds:WaitForChild("Screens") :: Frame
for _, host in screens:GetChildren() do
	if host:IsA("Frame") and visible(host) then
		assert(
			host.AbsolutePosition.X >= bounds.AbsolutePosition.X,
			"Presentation left edge leaves safe area"
		)
		assert(
			host.AbsolutePosition.Y >= bounds.AbsolutePosition.Y,
			"Presentation top leaves safe area"
		)
		assert(
			host.AbsolutePosition.X + host.AbsoluteSize.X
				<= bounds.AbsolutePosition.X + bounds.AbsoluteSize.X + 1,
			"Presentation right edge leaves safe area"
		)
		assert(
			host.AbsolutePosition.Y + host.AbsoluteSize.Y
				<= bounds.AbsolutePosition.Y + bounds.AbsoluteSize.Y + 1,
			"Presentation bottom leaves safe area"
		)
	end
end
assert(
	not bounds:WaitForChild("Hud"):FindFirstChild("SaveStatus"),
	"Saving must not occupy a permanent HUD control"
)

print(
	string.format(
		"PASS: %d visible interactive targets, %d measured scroll containers. UI descendants: %d. Compare after repeated navigation without gameplay changes.",
		buttons,
		scrolls,
		#gui:GetDescendants()
	)
)

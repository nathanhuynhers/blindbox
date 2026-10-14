--!strict
-- Read-only CLIENT check while StudioStore fixture is visible. Run at each viewport/state,
-- after scrolling to both endpoints, and again after repeated navigation. Rendering review
-- and physical input acceptance are separate. F8 hides the fixture toolbar before captures.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio-only check")
local player = Players.LocalPlayer
assert(player, "Use the client Command Bar")
local fixture = player.PlayerGui:FindFirstChild("StorePresentationFixture") :: ScreenGui?
assert(fixture, "Start StudioStore first")
local offline = player.PlayerGui:FindFirstChild("OfflineEarnings") :: ScreenGui?
local gui = offline or fixture
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
local function visible(target: GuiObject): boolean
	local ancestor: Instance? = target
	while ancestor and ancestor ~= gui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end
local safe = if offline
	then offline.AbsoluteSize
	else (fixture:FindFirstChild("SafeArea") :: Frame).AbsoluteSize
local origin = if offline
	then Vector2.zero
	else (fixture:FindFirstChild("SafeArea") :: Frame).AbsolutePosition
local targets, text = 0, 0
for _, object in gui:GetDescendants() do
	if not object:IsA("GuiObject") or not visible(object) then
		continue
	end
	if object:IsA("TextLabel") and object.Text ~= "" then
		assert(
			object.TextFits,
			"Text does not fit: " .. object:GetFullName() .. " · " .. object.Text
		)
		text += 1
	end
	if not object:IsA("GuiButton") or not object.Selectable then
		continue
	end
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	assert(size.X >= 43.9 and size.Y >= 43.9, "Small target: " .. object:GetFullName())
	local scroller: ScrollingFrame? = nil
	local ancestor = object.Parent
	while ancestor and ancestor ~= gui do
		if ancestor:IsA("ScrollingFrame") then
			scroller = ancestor
			break
		end
		ancestor = ancestor.Parent
	end
	if scroller then
		local y = position.Y - scroller.AbsolutePosition.Y + scroller.CanvasPosition.Y
		local extent = math.max(scroller.AbsoluteCanvasSize.Y, scroller.AbsoluteWindowSize.Y)
		assert(
			y >= -1 and y + size.Y <= extent + 1,
			"Unreachable scroll target: " .. object:GetFullName()
		)
	else
		assert(
			position.X >= origin.X - 1
				and position.Y >= origin.Y - 1
				and position.X + size.X <= origin.X + safe.X + 1
				and position.Y + size.Y <= origin.Y + safe.Y + 1,
			"Target outside safe area: " .. object:GetFullName()
		)
	end
	targets += 1
end
print(
	`PASS: {targets} selectable targets and {text} text labels at {safe.X}×{safe.Y}; actual visual/input review still required`
)

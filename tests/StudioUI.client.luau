--!strict
-- Read-only checks in the CLIENT Command Bar during Play. Repeat on every screen and device size.
-- Run once, switch between screens many times (dock, Y, L1/R1), then run again: the second run
-- compares descendant counts with the first and fails on instance growth.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
assert(RunService:IsStudio(), "Studio-only UI check")
local player = Players.LocalPlayer
assert(player, "Use the client Command Bar")
local gui = player.PlayerGui:WaitForChild("PocketGrove") :: ScreenGui
assert(gui.Enabled, "Finish the opening before checking the normal UI")
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
local bounds = gui:WaitForChild("SafeArea") :: Frame
local stage = bounds:WaitForChild("Stage") :: Frame
local uiScale = stage:FindFirstChildOfClass("UIScale")
assert(uiScale, "Stage must carry the desktop UIScale")
local scale = uiScale.Scale
assert(scale >= 1 and scale <= 2, "UIScale bounded to 1-2 so touch targets never shrink")
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
		if layout and object.ScrollingDirection == Enum.ScrollingDirection.Y then
			scrolls += 1
			local padding = object:FindFirstChildOfClass("UIPadding")
			local extra = if padding
				then padding.PaddingTop.Offset + padding.PaddingBottom.Offset
				else 0
			-- AbsoluteContentSize is in screen pixels; CanvasSize is in design units.
			assert(
				object.CanvasSize.Y.Offset + 1 >= math.ceil(layout.AbsoluteContentSize.Y / scale + extra),
				"Truncated vertical scroll: " .. object:GetFullName()
			)
			assert(
				object.CanvasSize.Y.Offset <= math.ceil(layout.AbsoluteContentSize.Y / scale + extra) + 2,
				"Inflated vertical scroll (scale not applied): " .. object:GetFullName()
			)
		end
	end
	if object:IsA("GuiObject") and visible(object) then
		local name = string.lower(object.Name)
		assert(
			not string.find(name, "scrap", 1, true)
				and not string.find(name, "recycle", 1, true)
				and not string.find(name, "redeem", 1, true),
			"Scrap UI must be gone: " .. object:GetFullName()
		)
	end
end
assert(
	not game:GetService("Lighting"):FindFirstChild("InterfaceBackgroundBlur"),
	"The old blur treatment must be gone"
)
local screens = stage:WaitForChild("Screens") :: Frame
local open: Frame? = nil
for _, host in screens:GetChildren() do
	if host:IsA("Frame") and host.Visible then
		assert(open == nil, "Only one screen may be open")
		open = host
		local inside = host.AbsolutePosition.X >= bounds.AbsolutePosition.X - 1
			and host.AbsolutePosition.Y >= bounds.AbsolutePosition.Y - 1
			and host.AbsolutePosition.X + host.AbsoluteSize.X
				<= bounds.AbsolutePosition.X + bounds.AbsoluteSize.X + 1
			and host.AbsolutePosition.Y + host.AbsoluteSize.Y
				<= bounds.AbsolutePosition.Y + bounds.AbsoluteSize.Y + 1
		assert(inside, "Screen leaves the safe area: " .. host.Name)
	end
end
local dim = stage:WaitForChild("Backdrop") :: GuiObject
assert(dim.Visible == (open ~= nil), "World dim shows exactly while a screen is open")
local phone = bounds.AbsoluteSize.Y < 560 or bounds.AbsoluteSize.X < 900
local dock = stage:WaitForChild("Dock") :: Frame
assert(dock.Visible == (open == nil or not phone), "Dock: always on desktop, hidden under phone sheets")
local coins = stage:WaitForChild("Hud"):WaitForChild("Coins") :: GuiObject
if coins.Visible then
	local inset = GuiService.TopbarInset
	assert(
		coins.AbsolutePosition.X >= inset.Min.X - 1,
		"Coins pill must sit right of Roblox's top-bar buttons"
	)
end
if open then
	local close = open:FindFirstChild("Close", true) :: GuiObject?
	assert(close and visible(close), "Open screen needs its Close button")
end
local count = #gui:GetDescendants()
local baseline = gui:GetAttribute("StudioDescendants")
local key = (if open then open.Name else "World") .. "@" .. bounds.AbsoluteSize.X .. "x" .. bounds.AbsoluteSize.Y
if typeof(baseline) == "number" and gui:GetAttribute("StudioDescendantsKey") == key then
	assert(count == baseline, string.format("Instance growth: %d -> %d descendants", baseline, count))
	print("PASS: no instance growth since the previous run on " .. key)
else
	gui:SetAttribute("StudioDescendants", count)
	gui:SetAttribute("StudioDescendantsKey", key)
	print("Baseline stored for " .. key .. ". Switch screens repeatedly, return here, run again.")
end
print(
	string.format(
		"PASS: %d visible targets >= 44px, %d measured scrollers at UIScale %.2f, %d descendants (%s).",
		buttons,
		scrolls,
		scale,
		count,
		key
	)
)

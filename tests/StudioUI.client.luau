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
local summary = player.PlayerGui:FindFirstChild("OpenTenResults") :: ScreenGui?
if summary and summary.Enabled then
	local safe = summary:WaitForChild("Results") :: Frame
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	local origin, extent = safe.AbsolutePosition, safe.AbsoluteSize
	local count = 0
	local results, actions = 0, 0
	for _, target in safe:GetDescendants() do
		if not target:IsA("GuiButton") then
			continue
		end
		local visible = true
		local ancestor: Instance? = target
		while ancestor and ancestor ~= summary do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then
				visible = false
			end
			ancestor = ancestor.Parent
		end
		if not visible then
			continue
		end
		local position, size = target.AbsolutePosition, target.AbsoluteSize
		assert(
			position.X >= origin.X - 1
				and position.Y >= origin.Y - 1
				and position.X + size.X <= origin.X + extent.X + 1
				and position.Y + size.Y <= origin.Y + extent.Y + 1,
			"Summary target escapes safe area: " .. target.Name
		)
		if target.Selectable then
			assert(size.X >= 43.9 and size.Y >= 43.9, "Small summary target: " .. target.Name)
			actions += 1
		end
		if target.Parent == safe and target:GetAttribute("FigureId") then
			results += 1
		end
		count += 1
	end
	local title = safe:FindFirstChild("Title") :: TextLabel?
	assert(results > 0 and actions > 0, "Summary needs its results and a Done action")
	if title and title.Text == "Open 10 results" then
		assert(results == 10, "Open 10 must show all ten results")
	end
	print(string.format("PASS: %d summary tiles/controls inside %s", count, tostring(extent)))
	return
end
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
-- A descendant may be outside a scroll window only when its complete target is reachable
-- in that canvas. Once crossing a scroller, test the viewport against outer clipping frames.
local function reachable(target: GuiObject)
	local position, size = target.AbsolutePosition, target.AbsoluteSize
	local ancestor = target.Parent
	while ancestor and ancestor ~= gui do
		if ancestor:IsA("ScrollingFrame") then
			local origin = ancestor.AbsolutePosition
			local window = ancestor.AbsoluteWindowSize
			local canvas = ancestor.AbsoluteCanvasSize
			local offset = ancestor.CanvasPosition * scale
			local x, y = position.X - origin.X + offset.X, position.Y - origin.Y + offset.Y
			local direction = ancestor.ScrollingDirection
			local horizontal = direction == Enum.ScrollingDirection.X
				or direction == Enum.ScrollingDirection.XY
			local vertical = direction == Enum.ScrollingDirection.Y
				or direction == Enum.ScrollingDirection.XY
			assert(
				x >= -1
					and y >= -1
					and x + size.X <= (if horizontal then math.max(canvas.X, window.X) else window.X) + 1
					and y + size.Y <= (if vertical then math.max(canvas.Y, window.Y) else window.Y) + 1
					and size.X <= window.X + 1
					and size.Y <= window.Y + 1,
				"Unreachable scroll target: " .. target:GetFullName()
			)
			position, size = origin, ancestor.AbsoluteSize
		elseif ancestor:IsA("GuiObject") and ancestor.ClipsDescendants then
			local origin, extent = ancestor.AbsolutePosition, ancestor.AbsoluteSize
			assert(
				position.X >= origin.X - 1
					and position.Y >= origin.Y - 1
					and position.X + size.X <= origin.X + extent.X + 1
					and position.Y + size.Y <= origin.Y + extent.Y + 1,
				"Clipped descendant: "
					.. target:GetFullName()
					.. " inside "
					.. ancestor:GetFullName()
			)
		end
		ancestor = ancestor.Parent
	end
	local origin, extent = bounds.AbsolutePosition, bounds.AbsoluteSize
	assert(
		position.X >= origin.X - 1
			and position.Y >= origin.Y - 1
			and position.X + size.X <= origin.X + extent.X + 1
			and position.Y + size.Y <= origin.Y + extent.Y + 1,
		"Target leaves device safe area: " .. target:GetFullName()
	)
end
for _, object in gui:GetDescendants() do
	if object:IsA("GuiButton") and visible(object) and object.Selectable then
		buttons += 1
		assert(
			object.AbsoluteSize.X >= 43.9 and object.AbsoluteSize.Y >= 43.9,
			"Small target: " .. object:GetFullName()
		)
		reachable(object)
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
				object.CanvasSize.Y.Offset + 1
					>= math.ceil(layout.AbsoluteContentSize.Y / scale + extra),
				"Truncated vertical scroll: " .. object:GetFullName()
			)
			assert(
				object.CanvasSize.Y.Offset
					<= math.ceil(layout.AbsoluteContentSize.Y / scale + extra) + 2,
				"Inflated vertical scroll (scale not applied): " .. object:GetFullName()
			)
		elseif not layout and object.AutomaticCanvasSize == Enum.AutomaticSize.None then
			-- Manually positioned Shop product/odds and Shelf cabinet canvases must contain
			-- their real visible children; checking only UIGridLayout misses these panes.
			local bottom = 0
			for _, child in object:GetDescendants() do
				if child:IsA("GuiObject") and visible(child) then
					local nested = false
					local ancestor = child.Parent
					while ancestor and ancestor ~= object do
						if ancestor:IsA("ScrollingFrame") then
							nested = true
							break
						end
						ancestor = ancestor.Parent
					end
					-- Nested scrollers own their canvas; only their viewport belongs here.
					if not nested then
						bottom = math.max(
							bottom,
							(
								child.AbsolutePosition.Y
								- object.AbsolutePosition.Y
								+ child.AbsoluteSize.Y
							)
									/ scale
								+ object.CanvasPosition.Y
						)
					end
				end
			end
			local window = object.AbsoluteWindowSize.Y / scale
			assert(
				bottom <= math.max(window, object.CanvasSize.Y.Offset) + 1,
				"Truncated manual canvas: " .. object:GetFullName()
			)
			assert(
				object.CanvasSize.Y.Offset <= math.max(window, bottom + 32) + 1,
				"Inflated manual canvas: " .. object:GetFullName()
			)
			scrolls += 1
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
			and host.AbsolutePosition.X + host.AbsoluteSize.X <= bounds.AbsolutePosition.X + bounds.AbsoluteSize.X + 1
			and host.AbsolutePosition.Y + host.AbsoluteSize.Y
				<= bounds.AbsolutePosition.Y + bounds.AbsoluteSize.Y + 1
		assert(inside, "Screen leaves the safe area: " .. host.Name)
	end
end
local dim = stage:WaitForChild("Backdrop") :: GuiObject
assert(dim.Visible == (open ~= nil), "World dim shows exactly while a screen is open")
local phone = bounds.AbsoluteSize.Y < 560 or bounds.AbsoluteSize.X < 900
local dock = stage:WaitForChild("Dock") :: Frame
assert(
	dock.Visible == (open == nil or not phone),
	"Dock: always on desktop, hidden under phone sheets"
)
local coins = stage:WaitForChild("Hud"):WaitForChild("Coins") :: GuiObject
if coins.Visible then
	local inset = GuiService.TopbarInset
	assert(
		coins.AbsolutePosition.X >= inset.Min.X - 1,
		"Coins pill must sit right of Roblox's top-bar buttons"
	)
end
assert(gui.DisplayOrder > 0, "PocketGrove must render above Roblox's TouchGui")
assert(
	GuiService.TouchControlsEnabled == (open == nil),
	"Touch controls must hide while a screen is open and return in the world"
)
if open then
	local close = open:FindFirstChild("Close", true) :: GuiObject?
	assert(close and visible(close), "Open screen needs its Close button")
	for _, name in { "DailyButton", "HomeButton", "SettingsButton" } do
		local button = stage:FindFirstChild(name, true) :: GuiObject?
		assert(not button or not visible(button), name .. " must not obstruct a modal screen")
	end
else
	-- Top-right HUD row [Daily][Home][gear]: 44px targets, 8px gaps, safe area and top bar,
	-- clear of the other HUD pieces, and first in the real hit order (TouchGui included).
	local row: { GuiObject } = {}
	for _, name in { "DailyButton", "HomeButton", "SettingsButton" } do
		local button = stage:FindFirstChild(name, true) :: GuiObject
		assert(button and visible(button), name .. " must show in the world")
		table.insert(row, button)
	end
	local origin, extent = bounds.AbsolutePosition, bounds.AbsoluteSize
	local inset = GuiService.TopbarInset
	-- An open settings popover's outside-tap catcher covers the row on purpose.
	local popover = stage:FindFirstChild("Settings", true) :: GuiObject?
	local catching = popover ~= nil and visible(popover)
	for index, button in row do
		local position, size = button.AbsolutePosition, button.AbsoluteSize
		assert(size.X >= 43.9 and size.Y >= 43.9, "Small HUD target: " .. button.Name)
		assert(
			position.X >= math.max(origin.X, inset.Min.X) - 1
				and position.Y >= origin.Y - 1
				and position.X + size.X <= origin.X + extent.X + 1
				and position.Y + size.Y <= origin.Y + extent.Y + 1,
			button.Name .. " escapes the safe area or sits under the Roblox buttons"
		)
		if index > 1 then
			local previous = row[index - 1]
			assert(
				position.X - (previous.AbsolutePosition.X + previous.AbsoluteSize.X) >= 7.9,
				"HUD row gap under 8px before " .. button.Name
			)
		end
		for _, other in { "Coins", "GoalChip", "GoalTracker", "Settings" } do
			local piece = stage:FindFirstChild(other, true) :: GuiObject?
			if piece and visible(piece) then
				local p, q = piece.AbsolutePosition, piece.AbsoluteSize
				assert(
					p.X + q.X <= position.X
						or position.X + size.X <= p.X
						or p.Y + q.Y <= position.Y
						or position.Y + size.Y <= p.Y,
					button.Name .. " overlaps " .. other
				)
			end
		end
		if catching then
			continue
		end
		local point = position + size / 2
		local first: Instance? = nil
		for _, hit in player.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y) do
			if hit:IsA("GuiButton") and hit.Active then
				first = hit
				break
			end
		end
		assert(
			first == button,
			button.Name .. " is behind " .. (if first then first:GetFullName() else "no hit")
		)
	end
	print("PASS: HUD row [Daily][Home][gear] targets, gaps, safe area and hit order")
end
-- Check actual PlayerGui hit order (including TouchGui), not just visual rectangles.
-- Off-window scroll targets are covered by reachability above; check their input after scrolling.
local settings = stage:FindFirstChild("Settings", true)
local activePanel = if settings
		and settings:IsA("GuiObject")
		and visible(settings)
	then settings
	else open
local samples = {
	Vector2.new(0.5, 0.5),
	Vector2.new(0, 0),
	Vector2.new(1, 0),
	Vector2.new(0, 1),
	Vector2.new(1, 1),
	Vector2.new(0.5, 0),
	Vector2.new(0.5, 1),
	Vector2.new(0, 0.5),
	Vector2.new(1, 0.5),
}
local hitPoints = 0
if activePanel then
	for _, target in activePanel:GetDescendants() do
		if target:IsA("GuiButton") and target.Selectable and visible(target) then
			-- Sample the whole target (center, edge midpoints, corners inset 3px), not only its
			-- center: a world control over one corner still steals taps (AQ01).
			local position, size = target.AbsolutePosition, target.AbsoluteSize
			for _, fraction in samples do
				local point = position
					+ Vector2.new(
						math.clamp(size.X * fraction.X, 3, math.max(3, size.X - 3)),
						math.clamp(size.Y * fraction.Y, 3, math.max(3, size.Y - 3))
					)
				local onScreen = true
				local ancestor = target.Parent
				while ancestor and ancestor ~= gui do
					if ancestor:IsA("GuiObject") and ancestor.ClipsDescendants then
						local origin, extent = ancestor.AbsolutePosition, ancestor.AbsoluteSize
						if
							point.X < origin.X
							or point.Y < origin.Y
							or point.X > origin.X + extent.X
							or point.Y > origin.Y + extent.Y
						then
							onScreen = false
						end
					end
					ancestor = ancestor.Parent
				end
				if not onScreen then
					continue
				end
				local first: GuiButton? = nil
				for _, hit in player.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y) do
					local at: Instance? = hit
					while at and at ~= player.PlayerGui do
						if at:IsA("GuiButton") and at.Active then
							first = at
							break
						end
						at = at.Parent
					end
					if first then
						break
					end
				end
				assert(
					first ~= nil and (first == target or first:IsDescendantOf(target)),
					string.format(
						"Obstructed control at (%d,%d): %s behind %s",
						point.X,
						point.Y,
						target:GetFullName(),
						if first then first:GetFullName() else "no hit"
					)
				)
				hitPoints += 1
			end
		end
	end
end
local count = #gui:GetDescendants()
local baseline = gui:GetAttribute("StudioDescendants")
local key = (if open then open.Name else "World")
	.. "@"
	.. bounds.AbsoluteSize.X
	.. "x"
	.. bounds.AbsoluteSize.Y
if typeof(baseline) == "number" and gui:GetAttribute("StudioDescendantsKey") == key then
	assert(
		count == baseline,
		string.format("Instance growth: %d -> %d descendants", baseline, count)
	)
	print("PASS: no instance growth since the previous run on " .. key)
else
	gui:SetAttribute("StudioDescendants", count)
	gui:SetAttribute("StudioDescendantsKey", key)
	print("Baseline stored for " .. key .. ". Switch screens repeatedly, return here, run again.")
end
print(
	string.format(
		"PASS: %d visible targets >= 44px, %d whole-target hit points, %d measured scrollers at UIScale %.2f, %d descendants (%s).",
		buttons,
		hitPoints,
		scrolls,
		scale,
		count,
		key
	)
)

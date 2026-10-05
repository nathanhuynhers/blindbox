--!strict
-- CLIENT Command Bar during Play. Open Collection (All), Shop or Shelves on each device.
-- Checks real canvas endpoints, including manual product/contents/cabinet canvases.
-- Restores scroll positions; never sends requests or grants discoveries.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio-only regression check")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("PocketGrove")
local stage = gui:WaitForChild("SafeArea"):WaitForChild("Stage") :: Frame
local scale = (stage:FindFirstChildOfClass("UIScale") :: UIScale).Scale
local screens = stage:WaitForChild("Screens")
local checked = 0
local function visible(object: GuiObject): boolean
	local ancestor: Instance? = object
	while ancestor and ancestor ~= gui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		ancestor = ancestor.Parent
	end
	return ancestor == gui
end
for _, host in screens:GetChildren() do
	if not host:IsA("Frame") or not host.Visible then
		continue
	end
	local collection = host:FindFirstChild("Collection")
	if collection then
		assert(collection:GetAttribute("Filter") == "all", "Choose All first")
	end
	for _, object in host:GetDescendants() do
		if
			not object:IsA("ScrollingFrame")
			or not visible(object)
			or object.ScrollingDirection ~= Enum.ScrollingDirection.Y
		then
			continue
		end
		if
			object.Name ~= "FigureGrid"
			and object.Name ~= "Contents"
			and object.Name ~= "Product"
			and object.Name ~= "CabinetScroll"
			and object.Name ~= "Figures"
		then
			continue
		end
		RunService.Heartbeat:Wait()
		local final: GuiButton? = nil
		local lastBottom = -math.huge
		for _, child in object:GetDescendants() do
			if not child:IsA("GuiButton") or not visible(child) then
				continue
			end
			local ancestor = child.Parent
			local nested = false
			while ancestor and ancestor ~= object do
				if ancestor:IsA("ScrollingFrame") then
					nested = true
					break
				end
				ancestor = ancestor.Parent
			end
			if not nested then
				local bottom = child.AbsolutePosition.Y + child.AbsoluteSize.Y
				if bottom > lastBottom then
					final, lastBottom = child, bottom
				end
			end
		end
		if not final then
			continue
		end
		local saved = object.CanvasPosition
		object.CanvasPosition = Vector2.new(0, object.AbsoluteCanvasSize.Y / scale)
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
		local top, bottom =
			final.AbsolutePosition.Y, final.AbsolutePosition.Y + final.AbsoluteSize.Y
		local windowTop = object.AbsolutePosition.Y
		local windowBottom = windowTop + object.AbsoluteWindowSize.Y
		local reached = top >= windowTop - 1 and bottom <= windowBottom + 1
		object.CanvasPosition = saved
		assert(
			reached,
			"Final target is not fully reachable at scroll end: " .. final:GetFullName()
		)
		checked += 1
	end
end
assert(checked > 0, "Open Collection (All), Shop or Shelves first")
print(string.format("PASS: %d native scroll endpoints at UIScale %.2f", checked, scale))

--!strict
-- Run in the CLIENT Command Bar during Studio Play, after opening Collection.
-- Not included in the game build. Repeat with each collection and mobile viewport.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio-only visual regression check")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("PocketGrove")
local bounds = gui:WaitForChild("SafeArea")
local menu = bounds:WaitForChild("Menu")
local page = menu:WaitForChild("Collection") :: ScrollingFrame
local layout = page:FindFirstChildOfClass("UIListLayout")
assert(layout)
RunService.Heartbeat:Wait()
assert(page.CanvasSize.Y.Offset >= math.ceil(layout.AbsoluteContentSize.Y + 16), "Canvas truncates content")
local cards, visible = 0, 0
for _, child in page:GetChildren() do
	if child:IsA("TextButton") and (string.match(child.Name, "^grove%.") or string.match(child.Name, "^tide%.")) then
		cards += 1
		if child.Visible then visible += 1 end
	end
end
assert(cards == 12, "All collection figures must exist")
assert(visible == 6, "Disable owned-only filtering before running this check")
page.CanvasPosition = Vector2.new(0, math.max(0, page.AbsoluteCanvasSize.Y - page.AbsoluteWindowSize.Y))
print("PASS: 12 figures exist; selected collection's 6 cards fit the canvas. Inspect the final visible card.")

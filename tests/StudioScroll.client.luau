--!strict
-- Run in the CLIENT Command Bar during Play with Collection open on "All" for the largest
-- collection (Tender Echoes or We Are All Stars). Scrolls the grid to the end and checks the
-- last card is fully reachable at the current UIScale.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio-only regression check")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("PocketGrove")
local stage = gui:WaitForChild("SafeArea"):WaitForChild("Stage") :: Frame
local scale = (stage:FindFirstChildOfClass("UIScale") :: UIScale).Scale
local host = stage:WaitForChild("Screens"):WaitForChild("CollectionPresentation") :: Frame
assert(host.Visible, "Open Collection first")
local root = host:WaitForChild("Collection") :: Frame
assert(root:GetAttribute("Filter") == "all", "Choose All before this check")
local grid = root:FindFirstChild("FigureGrid", true) :: ScrollingFrame
local layout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
assert(layout, "Collection must use a measured UIGridLayout")
RunService.Heartbeat:Wait()
local padding = grid:FindFirstChildOfClass("UIPadding")
local extra = if padding then padding.PaddingTop.Offset + padding.PaddingBottom.Offset else 0
assert(
	grid.CanvasSize.Y.Offset + 1 >= math.ceil(layout.AbsoluteContentSize.Y / scale + extra),
	"Canvas truncates the grid"
)
local final: TextButton? = nil
for _, child in grid:GetChildren() do
	if child:IsA("TextButton") and child.Visible then
		if not final or child.LayoutOrder > final.LayoutOrder then
			final = child
		end
	end
end
assert(final, "No visible cards")
grid.CanvasPosition = Vector2.new(0, math.max(0, grid.CanvasSize.Y.Offset))
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
local bottom = final.AbsolutePosition.Y + final.AbsoluteSize.Y
local windowBottom = grid.AbsolutePosition.Y + grid.AbsoluteWindowSize.Y
assert(bottom <= windowBottom + 1, "Last card is cut off at the end of the scroll")
grid.CanvasPosition = Vector2.zero
print(string.format("PASS: last card reachable at UIScale %.2f (%s)", scale, final.Name))

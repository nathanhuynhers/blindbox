--!strict
-- Read-only: paste in Studio's CLIENT Command Bar with Collection open. No remotes/grants.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
assert(RunService:IsStudio(), "Studio-only collection check")
local player = Players.LocalPlayer
assert(player, "Use the client Command Bar")
local gui = player.PlayerGui:WaitForChild("PocketGrove") :: ScreenGui
local safe = gui:WaitForChild("SafeArea") :: Frame
local screens = safe:WaitForChild("Screens") :: Frame
local host = screens:WaitForChild("CollectionPresentation") :: Frame
local collection = host:WaitForChild("Collection") :: Frame
assert(
	gui.Enabled and screens.Visible and host.Visible,
	"Open Collection after finishing the reveal"
)
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
local physical = collection:WaitForChild("PhysicalBook") :: Frame
local pages = collection:WaitForChild("Pages") :: Frame
local book = pages:WaitForChild("Book") :: Frame
local details = pages:WaitForChild("FigureDetails") :: Frame
local tabs = collection:WaitForChild("CollectionTabs") :: ScrollingFrame
assert(
	tabs.AbsolutePosition.X < physical.AbsolutePosition.X,
	"Index tabs must protrude left of the book"
)
local native = physical:WaitForChild("BookSkin"):WaitForChild("Native")
local left = native:WaitForChild("LeftVolume") :: Frame
local right = native:WaitForChild("RightVolume") :: Frame
for _, half in { left, right } do
	assert(
		half:FindFirstChild("Cover")
			and half:FindFirstChild("PageLayer5")
			and half:FindFirstChild("Paper"),
		"Physical book needs separate cover, page edges and paper"
	)
end
if collection:GetAttribute("Spread") then
	assert(
		left.Visible and right.Visible and book.Visible and details.Visible,
		"Desktop spread must have two pages"
	)
	local grid = book:WaitForChild("FigureGrid") :: ScrollingFrame
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	assert(layout and layout.FillDirectionMaxCells == 3, "Desktop grid must have three columns")
	if not collection:GetAttribute("OwnedOnly") then
		local count = 0
		for _, child in grid:GetChildren() do
			if child:IsA("TextButton") and child.Visible then
				count += 1
			end
		end
		assert(count == 6, "Shipped collection must show all six figures")
	end
end
local figureId = collection:GetAttribute("SelectedFigure")
assert(typeof(figureId) == "string" and Catalog.byId[figureId], "Selected figure missing")
assert(details:GetAttribute("FigureId") == figureId, "Right-page hero must match selection")
local grid = book:WaitForChild("FigureGrid") :: ScrollingFrame
local selected = grid:FindFirstChild(figureId) :: TextButton
assert(selected:GetAttribute("Selected"), "Selected portrait needs a visible selection state")
for _, card in grid:GetChildren() do
	if card:IsA("TextButton") and Catalog.byId[card.Name] then
		local portrait = card:WaitForChild("Portrait") :: ViewportFrame
		assert(
			portrait:FindFirstChildOfClass("Model"),
			"Every loaded card needs its real viewport model"
		)
		if not card:GetAttribute("Discovered") then
			local first: Color3? = nil
			for _, part in portrait:GetDescendants() do
				if part:IsA("BasePart") then
					first = first or part.Color
					assert(part.Color == first, "Unknown preview leaks model colors")
				end
			end
		end
	end
end
local controls = safe:WaitForChild("ScreenControls") :: Frame
assert(controls.AbsoluteSize.X == 44, "Collection should have a small integrated close control")
assert(
	not (controls:WaitForChild("MotionPreference") :: TextButton).Visible,
	"Motion bar competes with the book"
)
assert((safe:WaitForChild("Hud") :: Frame).Visible, "Currency pills belong outside the book")
print(
	"PASS: physical pages, side tabs, portrait models, selection, silhouettes and Collection controls. Compare art/proportions visually; this is not a visual approval."
)

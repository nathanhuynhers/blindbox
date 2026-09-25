--!strict
-- Run in the CLIENT Command Bar during Play, with Book open and All figures selected.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
assert(RunService:IsStudio(), "Studio-only regression check")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("PocketGrove")
local screens = gui:WaitForChild("SafeArea"):WaitForChild("Screens") :: Frame
local host = screens:WaitForChild("CollectionPresentation") :: Frame
local collection = host:WaitForChild("Collection") :: Frame
local book = collection:WaitForChild("Pages"):WaitForChild("Book") :: Frame
local page = book:WaitForChild("FigureGrid") :: ScrollingFrame
assert(
	screens.Visible and host.Visible and collection.Visible and book.Visible,
	"Open Book and return from figure details first"
)
assert(not collection:GetAttribute("OwnedOnly"), "Choose All figures before this check")
local layout = page:FindFirstChildOfClass("UIGridLayout")
assert(layout, "Collection must use a measured UIGridLayout")
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()
assert(
	page.CanvasSize.Y.Offset >= math.ceil(layout.AbsoluteContentSize.Y + 16),
	"Canvas truncates grid or bottom padding"
)
local expected = 0
for _, figure in Catalog.figures do
	if figure.collection == collection:GetAttribute("CollectionId") then
		expected += 1
	end
end
local cards, visible = 0, 0
local final: TextButton? = nil
for _, child in page:GetChildren() do
	if child:IsA("TextButton") and Catalog.byId[child.Name] then
		cards += 1
		if child.Visible then
			visible += 1
			assert(child.AbsoluteSize.X <= page.AbsoluteWindowSize.X, "Card wider than viewport")
			if not final or child.LayoutOrder > final.LayoutOrder then
				final = child
			end
		end
	end
end
assert(cards == #Catalog.figures, "Every figure must have a card")
assert(visible == expected, "Collection filtering lost a figure")
page.CanvasPosition =
	Vector2.new(0, math.max(0, page.AbsoluteCanvasSize.Y - page.AbsoluteWindowSize.Y))
RunService.Heartbeat:Wait()
assert(final, "No visible final card")
assert(
	final.AbsolutePosition.Y + final.AbsoluteSize.Y
		<= page.AbsolutePosition.Y + page.AbsoluteWindowSize.Y + 2,
	"Final card is clipped at maximum scroll"
)
print(
	"PASS: all catalog cards exist; collection grid and final card fit. Repeat after resize/filter/respawn."
)

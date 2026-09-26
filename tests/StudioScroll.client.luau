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
local spread = collection:GetAttribute("Spread") == true
assert(
	page.CanvasSize.Y.Offset >= math.ceil(layout.AbsoluteContentSize.Y + 20),
	"Canvas truncates grid or bottom padding"
)
local expected = 0
for _, figure in Catalog.figures do
	if figure.collection == collection:GetAttribute("CollectionId") then
		expected += 1
	end
end
local cards, visible = 0, 0
local visibleCards: { TextButton } = {}
local final: TextButton? = nil
for _, child in page:GetChildren() do
	if child:IsA("TextButton") and Catalog.byId[child.Name] then
		cards += 1
		if child.Visible then
			visible += 1
			table.insert(visibleCards, child)
			assert(child.AbsoluteSize.X <= page.AbsoluteWindowSize.X, "Card wider than viewport")
			if not final or child.LayoutOrder > final.LayoutOrder then
				final = child
			end
		end
	end
end
assert(cards == #Catalog.figures, "Every figure must have a card")
assert(visible == expected, "Collection filtering lost a figure")
assert(final, "No visible final card")
if spread then
	table.sort(visibleCards, function(first, second)
		return first.LayoutOrder < second.LayoutOrder
	end)
	assert(#visibleCards == 6, "Desktop Collection must expose all six cards")
	assert(layout.FillDirectionMaxCells == 3, "Desktop Collection must use three columns")
	assert(
		not page.ScrollingEnabled and page.ScrollBarThickness == 0,
		"Desktop grid must not scroll"
	)
	assert(
		layout.AbsoluteContentSize.Y + 20 <= page.AbsoluteWindowSize.Y + 2,
		"Six desktop figures must fit in two rows"
	)
	for index = 1, 3 do
		assert(
			math.abs(visibleCards[index].AbsolutePosition.Y - visibleCards[1].AbsolutePosition.Y)
				<= 1,
			"First three figures must share the first row"
		)
		assert(
			math.abs(
				visibleCards[index + 3].AbsolutePosition.Y - visibleCards[4].AbsolutePosition.Y
			) <= 1,
			"Final three figures must share the second row"
		)
	end
	assert(
		visibleCards[1].AbsolutePosition.X < visibleCards[2].AbsolutePosition.X
			and visibleCards[2].AbsolutePosition.X < visibleCards[3].AbsolutePosition.X,
		"Desktop rows must have three distinct columns"
	)
	assert(
		visibleCards[3].AbsolutePosition.X + visibleCards[3].AbsoluteSize.X
			<= page.AbsolutePosition.X + page.AbsoluteWindowSize.X + 1,
		"Third column must fit inside the padded grid"
	)
else
	page.CanvasPosition =
		Vector2.new(0, math.max(0, page.AbsoluteCanvasSize.Y - page.AbsoluteWindowSize.Y))
	RunService.Heartbeat:Wait()
end
assert(
	final.AbsolutePosition.Y + final.AbsoluteSize.Y
		<= page.AbsolutePosition.Y + page.AbsoluteWindowSize.Y + 2,
	"Final card is clipped at maximum scroll"
)
print(
	"PASS: all catalog cards exist; desktop grid fits six without scrolling; narrow grid remains reachable."
)

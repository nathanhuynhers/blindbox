--!strict
-- Read-only: paste in Studio's CLIENT Command Bar with Collection open. No remotes/grants.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Assets = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
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
local ornaments = native:WaitForChild("BookOrnaments")
local isGrove = collection:GetAttribute("CollectionId") == "grove"
local keys = if isGrove then Assets.Collection.PocketGrove else Assets.Collection.TidepoolTales
local cornerKeys =
	{ keys.CornerTopLeft, keys.CornerTopRight, keys.CornerBottomLeft, keys.CornerBottomRight }
for index, key in cornerKeys do
	local corner = ornaments:WaitForChild("Corner" .. index) :: Frame
	local artwork = corner:WaitForChild("Artwork") :: ImageLabel
	local fallback = corner:WaitForChild("Native") :: Frame
	local resolved = Assets.resolve(key)
	assert(artwork.Image == resolved, "Wrong collection/corner asset")
	assert(artwork.ScaleType == Enum.ScaleType.Fit, "Corner must preserve aspect ratio")
	assert(
		corner.Rotation == 0 and artwork.Rotation == 0,
		"Production corners must keep authored orientation"
	)
	assert(
		fallback.Rotation == (if index > 2 then 180 else 0),
		"Native fallback orientation changed"
	)
	assert(
		corner.BackgroundTransparency == 1 and artwork.BackgroundTransparency == 1,
		"Overlay must stay transparent"
	)
	assert(artwork.ImageColor3 == Color3.new(1, 1, 1), "Artwork must not be tinted")
	assert(#fallback:GetChildren() > 0, "Native fallback must remain available")
	assert(
		artwork.Visible == (resolved ~= "") and fallback.Visible == (resolved == ""),
		"Fallback must be mutually exclusive"
	)
	if index == 1 then
		local header = book:WaitForChild("BookHeader")
		for _, name in { "CollectionTitle", "DiscoveryProgress" } do
			local label = header:WaitForChild(name) :: TextLabel
			assert(
				corner.AbsolutePosition.X + corner.AbsoluteSize.X <= label.AbsolutePosition.X
					or corner.AbsolutePosition.Y + corner.AbsoluteSize.Y
						<= label.AbsolutePosition.Y,
				"Corner must stay clear of title/progress"
			)
		end
	end
	print(
		key,
		if resolved == ""
			then "Native fallback"
			elseif artwork.IsLoaded then "Loaded"
			else "Assigned; still loading"
	)
end
local emblemKeys: { [string]: Assets.CollectionKeys } = {
	grove = Assets.Collection.PocketGrove,
	tide = Assets.Collection.TidepoolTales,
}
for id, collectionKeys in emblemKeys do
	local emblem = tabs:WaitForChild("Index" .. id)
		:WaitForChild("Tab" .. id)
		:WaitForChild("EmblemSlot") :: Frame
	local artwork = emblem:WaitForChild("Artwork") :: ImageLabel
	local fallback = emblem:WaitForChild("Native") :: Frame
	local resolved = Assets.resolve(collectionKeys.Emblem)
	assert(artwork.Image == resolved, "Tab emblem must belong to its own collection")
	assert(artwork.ScaleType == Enum.ScaleType.Fit, "Emblem must preserve aspect ratio")
	assert(
		artwork.Visible == (resolved ~= "") and fallback.Visible == (resolved == ""),
		"Emblem fallback must be exclusive"
	)
end
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
	assert(
		not grid.ScrollingEnabled and grid.ScrollBarThickness == 0,
		"Desktop grid must not scroll"
	)
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
local detailsScroll = details:WaitForChild("DetailsScroll") :: ScrollingFrame
local figureName = detailsScroll:WaitForChild("FigureName") :: TextLabel
local figureStats = detailsScroll:WaitForChild("FigureStats") :: TextLabel
local badgeRow = detailsScroll:WaitForChild("BadgeRow") :: Frame
local selectedDefinition = Catalog.byId[figureId]
assert(badgeRow.Visible, "Rarity must remain visible for undiscovered figures")
assert(string.find(figureStats.Text, "Pull chance", 1, true), "Details must show pull chance")
local secondary = detailsScroll:WaitForChild("SecondaryActions") :: Frame
assert(
	secondary:FindFirstChild("Recycle") and secondary:FindFirstChild("Redeem"),
	"Secondary actions must share one deliberate row"
)
local grid = book:WaitForChild("FigureGrid") :: ScrollingFrame
local selected = grid:FindFirstChild(figureId) :: TextButton
assert(selected:GetAttribute("Selected"), "Selected portrait needs a visible selection state")
if not selected:GetAttribute("Discovered") then
	assert(figureName.Text == "???", "Undiscovered figure name must remain hidden")
	assert(
		string.upper(
			(badgeRow:WaitForChild("RarityBadge"):FindFirstChildOfClass("TextLabel") :: TextLabel).Text
		) == string.upper(selectedDefinition.rarity),
		"Undiscovered figure must still show rarity"
	)
end
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

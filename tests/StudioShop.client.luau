--!strict
-- Read-only: run in Studio's CLIENT Command Bar with Shop open.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Assets = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)

assert(RunService:IsStudio(), "Studio-only Shop check")
local gui = Players.LocalPlayer.PlayerGui:WaitForChild("PocketGrove") :: ScreenGui
local shop = gui:WaitForChild("SafeArea")
	:WaitForChild("Screens")
	:WaitForChild("ShopPresentation")
	:WaitForChild("Shop") :: Frame
assert(shop.Visible, "Open Shop before running this check")
RunService.Heartbeat:Wait()
RunService.Heartbeat:Wait()

local content = shop:WaitForChild("ShopContent") :: ScrollingFrame
local carousel = content
	:WaitForChild("CollectionCarouselSection")
	:WaitForChild("CollectionCarousel") :: ScrollingFrame
local cards = 0
for _, collection in Catalog.collections do
	local card = carousel:WaitForChild("CollectionCard_" .. collection.id) :: TextButton
	assert(card.Visible, "Every catalog collection needs one carousel card")
	cards += 1
end
assert(cards == #Catalog.collections, "Carousel must derive its count from Catalog.collections")

local selected = shop:GetAttribute("SelectedCollection")
assert(
	typeof(selected) == "string" and Catalog.collectionIds[selected],
	"Selected collection invalid"
)
local keys = if selected == "grove"
	then Assets.Collection.PocketGrove
	else Assets.Collection.TidepoolTales
local details = content:WaitForChild("ProductDetails") :: Frame
local emblem = details:WaitForChild("CollectionEmblem")
local emblemArt = emblem:WaitForChild("Artwork") :: ImageLabel
assert(emblemArt.Image == Assets.resolve(keys.Emblem), "Shop emblem semantic asset mismatch")
assert(emblemArt.ScaleType == Enum.ScaleType.Fit, "Shop emblem must preserve aspect ratio")
assert(
	emblemArt.Visible ~= (emblem:WaitForChild("Native") :: Frame).Visible,
	"Emblem fallback must be exclusive"
)

local stage = content:WaitForChild("ProductStage") :: Frame
local standardBox = stage:WaitForChild("StandardBox") :: Frame
local pattern = standardBox:WaitForChild("Body"):WaitForChild("Pattern")
local patternArt = pattern:WaitForChild("Artwork") :: ImageLabel
assert(
	patternArt.Image == Assets.resolve(keys.ShopPattern),
	"Shop box pattern semantic asset mismatch"
)
assert(patternArt.ScaleType == Enum.ScaleType.Tile, "Shop pattern must remain repeatable")
assert(
	patternArt.Visible ~= (pattern:WaitForChild("Native") :: Frame).Visible,
	"Pattern fallback must be exclusive"
)

local possible =
	details:WaitForChild("PossibleFigures"):WaitForChild("FigureStrip") :: ScrollingFrame
local visibleFigures = 0
local rowY: number? = nil
for _, child in possible:GetChildren() do
	if child:IsA("Frame") and Catalog.byId[child.Name] and child.Visible then
		visibleFigures += 1
		if details.AbsoluteSize.X >= 480 then
			assert(
				math.abs(child.AbsolutePosition.Y - (rowY or child.AbsolutePosition.Y)) < 1,
				"Figures must share one desktop row"
			)
			rowY = child.AbsolutePosition.Y
			assert(
				child.AbsolutePosition.X >= possible.AbsolutePosition.X - 1,
				"Figure clipped at left"
			)
			assert(
				child.AbsolutePosition.X + child.AbsoluteSize.X
					<= possible.AbsolutePosition.X + possible.AbsoluteWindowSize.X + 1,
				"Figure clipped at right"
			)
		end
		assert(
			Catalog.byId[child.Name].collection == selected,
			"Possible figure crossed collections"
		)
	end
end
local expectedFigures = 0
for _, figure in Catalog.figures do
	if figure.collection == selected then
		expectedFigures += 1
	end
end
assert(visibleFigures == expectedFigures, "Every selected catalog figure must render")
local purchase = details:WaitForChild("Purchase") :: Frame
assert(
	purchase.Position.Y.Offset + purchase.AbsoluteSize.Y <= details.AbsoluteSize.Y + 1,
	"Purchase exceeds details surface"
)
assert(standardBox:FindFirstChild("SideFace"), "Dimensional package side missing")
for tier = 1, 3 do
	assert(stage:FindFirstChild("PedestalTier" .. tier), "Neutral pedestal layer missing")
end
assert(
	(details:WaitForChild("Purchase"):WaitForChild("BuyBox") :: TextButton).Visible,
	"Buy action missing"
)
print(
	"PASS: scalable Shop cards, semantic artwork, exclusive fallbacks and selected figures are wired."
)

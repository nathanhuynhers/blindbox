--!strict
-- Read-only: run in Studio's CLIENT Command Bar with Shop open.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Assets = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
local Box = require(game:GetService("ReplicatedStorage").Shared.BlindBoxModel)
local Theme = require(Players.LocalPlayer.PlayerScripts.Client.ShopTheme)

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
local theme = Theme.get(selected :: string)
local details = content:WaitForChild("ProductDetails") :: Frame
local progressGroup = details:WaitForChild("DiscoveryProgress") :: Frame
local progressLabel = progressGroup:WaitForChild("Discovery") :: TextLabel
local progressTrack = progressGroup:WaitForChild("DiscoveryTrack") :: Frame
assert(progressLabel.Text ~= "", "Discovery progress label missing")
assert(
	progressTrack.Position.Y.Offset
			- (progressLabel.Position.Y.Offset + progressLabel.Size.Y.Offset)
		<= 8,
	"Discovery label and progress bar must read as one compact component"
)
local emblem = details:WaitForChild("CollectionEmblem")
local emblemArt = emblem:WaitForChild("Artwork") :: ImageLabel
assert(emblemArt.Image == Assets.resolve(theme.emblemKey), "Shop emblem semantic asset mismatch")
assert(emblemArt.ScaleType == Enum.ScaleType.Fit, "Shop emblem must preserve aspect ratio")
assert(
	emblemArt.Visible ~= (emblem:WaitForChild("Native") :: Frame).Visible,
	"Emblem fallback must be exclusive"
)

local stage = content:WaitForChild("ProductStage") :: Frame
local preview = stage:WaitForChild("BlindBoxPreview") :: Frame
local viewport = preview:WaitForChild("ProductViewport") :: ViewportFrame
local fallback = preview:WaitForChild("Fallback") :: Frame
local timeout = os.clock() + 35
while preview:GetAttribute("PreviewStatus") == "Loading" and os.clock() < timeout do
	task.wait(0.25)
end
local templates = game:GetService("ReplicatedStorage"):FindFirstChild("ProductionModels")
print(
	"Model status:",
	if templates then templates:GetAttribute("BlindBoxBaseStatus") else "Missing",
	"Preview:",
	preview:GetAttribute("PreviewStatus"),
	preview:GetAttribute("PreviewReason")
)
if templates then
	for _, child in templates:GetDescendants() do
		print(child:GetFullName(), child.ClassName)
	end
end
assert(
	preview:GetAttribute("PreviewStatus") == "Ready",
	"Production preview failed: " .. tostring(preview:GetAttribute("PreviewReason"))
)
assert(
	viewport.Visible ~= fallback.Visible,
	"3D production model and neutral fallback must be exclusive"
)
if viewport.Visible then
	local product = viewport:WaitForChild("Scene"):WaitForChild("ProductModel") :: Model
	local bound, reason = Box.surfaces(product)
	assert(bound, reason)
	assert(product:GetAttribute("CollectionId") == selected, "Product theme is stale")
	for _, name in
		{
			"BoxBody",
			"FrontPatternPanel",
			"SidePatternPanel",
			"TopPatternPanel",
			"EmblemBadge",
			"CollectionNamePlate",
		}
	do
		assert(product:FindFirstChild(name, true), "3D product is missing semantic part " .. name)
	end
	for _, name in { "FrontPatternPanel", "SidePatternPanel", "TopPatternPanel" } do
		for _, surface in bound[name] do
			local pattern = surface:FindFirstChild("CollectionPattern") :: Texture?
			assert(
				pattern and pattern.Texture == Assets.resolve(theme.patternKey),
				"3D pattern mismatch"
			)
		end
	end
	local emblemFound = product:FindFirstChild("CollectionEmblem", true)
	assert(emblemFound and emblemFound:IsA("Decal"), "Viewport-compatible emblem missing")
	assert((emblemFound :: Decal).Texture == Assets.resolve(theme.emblemKey), "3D emblem mismatch")
	local title = preview:WaitForChild("ProjectedCollectionName") :: TextLabel
	assert(title.Visible and title.Text ~= "", "Projected plate name missing")
	for _, child in product:GetDescendants() do
		assert(not child:IsA("SurfaceGui"), "Unsupported viewport branding surface")
	end
	local right, up, front = Box.axes(bound)
	local camera = viewport.CurrentCamera :: Camera
	local bounds = product:GetBoundingBox()
	local direction = (camera.CFrame.Position - bounds.Position).Unit
	assert(
		direction:Dot(right) > 0 and direction:Dot(up) > 0 and direction:Dot(front) > 0,
		"Camera must show front, right and top"
	)
end

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
for _, name in { "PedestalBase", "PedestalTop" } do
	assert(stage:FindFirstChild(name), "Neutral pedestal layer missing")
end
assert(
	(details:WaitForChild("Purchase"):WaitForChild("BuyBox") :: TextButton).Visible,
	"Buy action missing"
)
local priceGroup = purchase:WaitForChild("PriceGroup") :: Frame
assert(priceGroup:FindFirstChild("CoinsIcon"), "Existing Coins icon must accompany price")
local daily = purchase:WaitForChild("DailyBox") :: TextButton
assert(
	daily:GetAttribute("Surface") ~= nil and daily:GetAttribute("RestingStrokeTransparency") == 0.55,
	"Daily claim must retain its secondary button treatment"
)
local blur = game:GetService("Lighting"):FindFirstChild("InterfaceBackgroundBlur")
assert(
	blur and blur:IsA("BlurEffect") and blur.Enabled and blur.Size == 8,
	"Shop world blur missing"
)
local safeArea = gui:WaitForChild("SafeArea")
local backdrop = safeArea:WaitForChild("Backdrop") :: TextButton
assert(backdrop.Visible and backdrop.BackgroundTransparency == 0.62, "Shop world dimming missing")

for _, collection in Catalog.collections do
	local card = carousel:WaitForChild("CollectionCard_" .. collection.id) :: TextButton
	assert(
		card:GetAttribute("Selected") == (collection.id == selected),
		"Collection card selected state is stale"
	)
	local collectionTheme = Theme.get(collection.id)
	assert(
		collectionTheme.collectionId == collection.id
			and Assets.resolve(collectionTheme.emblemKey) ~= ""
			and Assets.resolve(collectionTheme.patternKey) ~= "",
		"Production collection presentation is incomplete"
	)
end
print(
	"PASS: current collection skin, both collection definitions, compact progress, price icon, daily action and world treatment are wired. Repeat after switching collections."
)

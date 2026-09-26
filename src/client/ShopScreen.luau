--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local State = require(script.Parent.UIState)
local ShopState = require(script.Parent.ShopState)
local ShopTheme = require(script.Parent.ShopTheme)
local ShopLayout = require(script.Parent.ShopLayout)
local ShopArtwork = require(script.Parent.ShopArtwork)
local ShopBox = require(script.Parent.ShopBox)
local Style = require(script.Parent.CollectionStyle)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)

local Shop = {}

local function panel(parent: Instance, name: string, color: Color3, radius: number?): Frame
	local root = W.frame(parent, name, color)
	W.corner(root, radius or 16)

	return root
end

local function fallbackMark(parent: Instance, color: Color3): TextLabel
	local mark = W.label(parent, "✦", 44, 30)
	mark.Size = UDim2.fromScale(1, 1)
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.TextColor3 = color
	return mark
end

function Shop.create(parent: Instance, ctx: Context.Context): Context.Screen
	local root = panel(parent, "Shop", Color3.fromRGB(126, 88, 56), 20)
	root.ClipsDescendants = true
	local shellGradient =
		W.gradient(root, Color3.fromRGB(224, 193, 149), Color3.fromRGB(109, 72, 44), 90)
	shellGradient.Transparency = NumberSequence.new(0, 0.18)

	local sidebar = panel(root, "ShopNavigation", Color3.fromRGB(82, 60, 47), 18)
	local shopTitle = W.title(sidebar, "Shop", 42)
	shopTitle.Position = UDim2.fromOffset(16, 12)
	shopTitle.Size = UDim2.new(1, -32, 0, 42)
	shopTitle.Font = Enum.Font.FredokaOne
	shopTitle.TextSize = 34
	shopTitle.TextColor3 = Color3.fromRGB(255, 246, 220)
	local shopSubtitle = W.label(sidebar, "Discover figures from different worlds.", 52, 13)
	shopSubtitle.Position = UDim2.fromOffset(16, 54)
	shopSubtitle.Size = UDim2.new(1, -32, 0, 52)
	shopSubtitle.TextColor3 = Color3.fromRGB(231, 215, 190)
	local category = panel(sidebar, "SelectedCategory", Color3.fromRGB(255, 244, 200), 12)
	category.Position = UDim2.fromOffset(10, 118)
	category.Size = UDim2.new(1, -20, 0, 48)
	local categoryLabel = W.label(category, "▣  Blind Boxes", 48, 15)
	categoryLabel.Position = UDim2.fromOffset(12, 0)
	categoryLabel.Size = UDim2.new(1, -24, 1, 0)
	categoryLabel.Font = Enum.Font.GothamBold
	categoryLabel.TextColor3 = Color3.fromRGB(91, 64, 35)
	W.gradient(category, Color3.fromRGB(255, 246, 197), Color3.fromRGB(235, 195, 113), 90)
	W.outline(category, Color3.fromRGB(255, 236, 177), 0.1).Thickness = 2
	local categoryNotes: { Frame } = {}
	for order, value in { "Decorations", "Currencies", "Limited" } do
		local unavailable = W.frame(sidebar, value)
		unavailable.Position = UDim2.fromOffset(18, 182 + (order - 1) * 72)
		unavailable.Size = UDim2.new(1, -36, 0, 62)
		local label = W.label(unavailable, value, 28, 16)
		label.TextColor3 = Color3.fromRGB(240, 227, 205)
		local note = W.label(unavailable, "COMING SOON", 22, 10)
		note.Position = UDim2.fromOffset(0, 29)
		note.TextColor3 = Color3.fromRGB(196, 176, 151)
		local divider = W.frame(unavailable, "Divider", Color3.fromRGB(217, 184, 143))
		divider.Position = UDim2.new(0, 0, 1, -1)
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.BackgroundTransparency = 0.83
		table.insert(categoryNotes, unavailable)
	end

	local main = Instance.new("ScrollingFrame")
	main.Name = "ShopContent"
	main.BackgroundTransparency = 1
	main.BorderSizePixel = 0
	main.CanvasSize = UDim2.fromOffset(0, 0)
	main.ScrollBarThickness = 5
	main.ScrollBarImageColor3 = Color3.fromRGB(176, 139, 88)
	main.ScrollingDirection = Enum.ScrollingDirection.Y
	main.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	main.Parent = root

	local carouselSection =
		panel(main, "CollectionCarouselSection", Color3.fromRGB(255, 248, 234), 16)
	carouselSection.BackgroundTransparency = 1
	local shelf = panel(carouselSection, "Shelf", Color3.fromRGB(176, 124, 72), 5)
	shelf.Position = UDim2.new(0, 0, 1, -12)
	shelf.Size = UDim2.new(1, 0, 0, 12)
	W.gradient(shelf, Color3.fromRGB(244, 208, 147), Color3.fromRGB(131, 84, 48), 90)
	local carousel = Instance.new("ScrollingFrame")
	carousel.Name = "CollectionCarousel"
	carousel.BackgroundTransparency = 1
	carousel.BorderSizePixel = 0
	carousel.CanvasSize = UDim2.fromOffset(0, 0)
	carousel.ScrollBarThickness = 4
	carousel.ScrollBarImageColor3 = Color3.fromRGB(191, 151, 91)
	carousel.ScrollingDirection = Enum.ScrollingDirection.X
	carousel.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	carousel.SelectionGroup = true
	carousel.Parent = carouselSection
	local carouselPadding = Instance.new("UIPadding")
	carouselPadding.PaddingLeft = UDim.new(0, 10)
	carouselPadding.PaddingRight = UDim.new(0, 10)
	carouselPadding.Parent = carousel
	carouselPadding.PaddingTop = UDim.new(0, 5)
	local carouselList = W.list(carousel, 14)
	carouselList.FillDirection = Enum.FillDirection.Horizontal

	type CarouselCard = {
		action: W.Action,
		face: Frame,
		outline: UIStroke,
		glow: UIStroke,
		progress: TextLabel,
		fill: Frame,
	}
	local carouselCards: { [string]: CarouselCard } = {}
	local orderedCarouselActions: { W.Action } = {}
	local selectedCollection = Catalog.collections[1].id
	local currentSnapshot: Types.Snapshot? = nil
	local refresh: () -> () = function() end
	local resize: () -> () = function() end

	for order, collection in Catalog.collections do
		local collectionId = collection.id
		local collectionTheme = ShopTheme.get(collectionId)
		local action = W.action(carousel, "", ctx.scope, ctx.effects, function()
			selectedCollection = collectionId
			refresh()
		end, true)
		action.button.Name = "CollectionCard_" .. collectionId
		action.button.LayoutOrder = order
		action.button:SetAttribute("Quiet", true)
		action.button:SetAttribute("Accent", collectionTheme.primary)
		table.insert(orderedCarouselActions, action)
		local halo = panel(action.button, "SelectionHalo", Color3.fromRGB(248, 202, 114), 16)
		halo.Position = UDim2.fromOffset(-2, -2)
		halo.Size = UDim2.new(1, 4, 1, 0)
		halo.BackgroundTransparency = 1
		local glow = W.outline(halo, Color3.fromRGB(255, 213, 129), 1)
		glow.Thickness = 5
		local face = panel(action.button, "CardFace", collectionTheme.wash, 14)
		W.gradient(face, Color3.new(1, 1, 1), collectionTheme.secondary, 90)
		W.outline(face, collectionTheme.primary, 0.4)
		face.Position = UDim2.fromOffset(2, 2)
		face.Size = UDim2.new(1, -4, 1, -8)
		local outline = face:FindFirstChildOfClass("UIStroke")
		assert(outline, "Carousel card outline missing")
		local pattern = ShopArtwork.mount(face, "Pattern", Enum.ScaleType.Tile)
		pattern.image.TileSize = UDim2.fromOffset(250, 250)
		pattern.image.ImageTransparency = 0.48
		pattern.set(collectionTheme.patternKey)
		local emblem = ShopArtwork.mount(face, "Emblem", Enum.ScaleType.Fit)
		emblem.root.Position = UDim2.fromOffset(10, 8)
		emblem.root.Size = UDim2.fromOffset(32, 32)
		fallbackMark(emblem.native, collectionTheme.primary)
		emblem.set(collectionTheme.emblemKey)
		local name = W.title(face, collection.name, 32)
		name.Position = UDim2.fromOffset(46, 6)
		name.Size = UDim2.new(1, -54, 0, 38)
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 18
		name.TextColor3 = collectionTheme.ink
		local product = ShopBox.create(face)
		product.root.AnchorPoint = Vector2.new(0.5, 0)
		product.root.Position = UDim2.fromScale(0.5, 0.20)
		product.root.Size = UDim2.fromScale(0.68, 0.60)
		product.set(collectionTheme, collection.name)
		local progressSurface = panel(face, "ProgressSurface", Color3.fromRGB(66, 53, 42), 10)
		progressSurface.Position = UDim2.new(0, 10, 1, -43)
		progressSurface.Size = UDim2.new(1, -20, 0, 37)
		progressSurface.BackgroundTransparency = 0.12
		local progress = W.label(progressSurface, "", 22, 13)
		progress.Position = UDim2.fromOffset(4, 0)
		progress.Size = UDim2.new(1, -8, 0, 22)
		progress.TextColor3 = Color3.fromRGB(255, 248, 230)
		progress.TextXAlignment = Enum.TextXAlignment.Center
		local track = W.frame(progressSurface, "ProgressTrack", Color3.fromRGB(218, 207, 187))
		track.Position = UDim2.new(0, 12, 1, -12)
		track.Size = UDim2.new(1, -24, 0, 7)
		W.corner(track, 10)
		local fill = W.frame(track, "Fill", collectionTheme.primary)
		fill.Size = UDim2.fromScale(0, 1)
		W.corner(fill, 10)
		carouselCards[collectionId] = {
			action = action,
			face = face,
			outline = outline,
			glow = glow,
			progress = progress,
			fill = fill,
		}
	end
	for index, action in orderedCarouselActions do
		action.button.NextSelectionLeft =
			orderedCarouselActions[(index - 2) % #orderedCarouselActions + 1].button
		action.button.NextSelectionRight =
			orderedCarouselActions[index % #orderedCarouselActions + 1].button
		ctx.scope.connect(action.button.SelectionGained, function()
			local left = action.button.AbsolutePosition.X - carousel.AbsolutePosition.X
			local right = left + action.button.AbsoluteSize.X
			local shift = if left < 4
				then left - 4
				elseif right > carousel.AbsoluteWindowSize.X - 4 then right
					- carousel.AbsoluteWindowSize.X
					+ 4
				else 0
			carousel.CanvasPosition = Vector2.new(
				math.clamp(
					carousel.CanvasPosition.X + shift,
					0,
					math.max(0, carousel.AbsoluteCanvasSize.X - carousel.AbsoluteWindowSize.X)
				),
				0
			)
		end)
	end

	local function updateCarouselCanvas()
		carousel.CanvasSize =
			UDim2.fromOffset(math.ceil(carouselList.AbsoluteContentSize.X + 20), 0)
	end
	ctx.scope.connect(
		carouselList:GetPropertyChangedSignal("AbsoluteContentSize"),
		updateCarouselCanvas
	)

	local hero = panel(main, "ProductStage", Color3.fromRGB(255, 248, 233), 18)
	local stageBack = W.frame(hero, "StageGlow", Color3.fromRGB(247, 226, 188))
	stageBack.Position = UDim2.fromScale(0.08, 0.06)
	stageBack.Size = UDim2.fromScale(0.84, 0.79)
	stageBack.BackgroundTransparency = 0.34
	W.corner(stageBack, 160)
	W.gradient(stageBack, Color3.fromRGB(255, 255, 250), Color3.fromRGB(233, 205, 161), 90)
	W.outline(stageBack, Color3.fromRGB(237, 208, 158), 0.55).Thickness = 3
	local pedestalShadow = W.frame(hero, "PedestalShadow", Color3.fromRGB(102, 74, 48))
	pedestalShadow.AnchorPoint = Vector2.new(0.5, 1)
	pedestalShadow.Position = UDim2.fromScale(0.5, 0.96)
	pedestalShadow.Size = UDim2.fromScale(0.90, 0.10)
	pedestalShadow.BackgroundTransparency = 0.64
	W.corner(pedestalShadow, 100)
	-- Shared ivory plinth: stacked rims, fascia and top catch light independently.
	for tier = 1, 3 do
		local width = 0.92 - (tier - 1) * 0.09
		local y = 0.94 - (tier - 1) * 0.065
		local base = panel(hero, "PedestalTier" .. tier, Color3.fromRGB(240, 221, 191), 60)
		base.AnchorPoint = Vector2.new(0.5, 1)
		base.Position = UDim2.fromScale(0.5, y)
		base.Size = UDim2.fromScale(width, 0.105)
		W.gradient(base, Color3.fromRGB(255, 251, 235), Color3.fromRGB(185, 145, 95), 90)
		local trim = W.outline(base, Color3.fromRGB(212, 169, 96), 0.08)
		trim.Thickness = 2
		local top = panel(hero, "PedestalTop" .. tier, Color3.fromRGB(255, 247, 224), 100)
		top.AnchorPoint = Vector2.new(0.5, 1)
		top.Position = UDim2.fromScale(0.5, y - 0.047)
		top.Size = UDim2.fromScale(width - 0.02, 0.064)
		W.gradient(top, Color3.fromRGB(255, 254, 246), Color3.fromRGB(235, 213, 173), 90)
	end
	local box = ShopBox.create(hero)
	box.root.AnchorPoint = Vector2.new(0.5, 1)
	box.root.Position = UDim2.fromScale(0.5, 0.79)
	box.root.Size = UDim2.fromScale(0.84, 0.79)
	local plaque = W.label(hero, "", 34, 15)
	plaque.AnchorPoint = Vector2.new(0.5, 1)
	plaque.Position = UDim2.fromScale(0.5, 0.925)
	plaque.Size = UDim2.fromScale(0.58, 0.075)
	plaque.BackgroundColor3 = Color3.fromRGB(222, 177, 104)
	plaque.BackgroundTransparency = 0.05
	plaque.TextXAlignment = Enum.TextXAlignment.Center
	plaque.Font = Enum.Font.FredokaOne
	W.corner(plaque, 10)
	W.outline(plaque, Color3.fromRGB(150, 105, 57), 0.28)
	local previous = W.action(hero, "<", ctx.scope, ctx.effects, function()
		local index = 1
		for order, collection in Catalog.collections do
			if collection.id == selectedCollection then
				index = order
			end
		end
		selectedCollection = Catalog.collections[(index - 2) % #Catalog.collections + 1].id
		refresh()
	end, true)
	local nextCollection = W.action(hero, ">", ctx.scope, ctx.effects, function()
		local index = 1
		for order, collection in Catalog.collections do
			if collection.id == selectedCollection then
				index = order
			end
		end
		selectedCollection = Catalog.collections[index % #Catalog.collections + 1].id
		refresh()
	end, true)
	previous.button.Name, nextCollection.button.Name = "PreviousCollection", "NextCollection"
	previous.button.AnchorPoint, nextCollection.button.AnchorPoint =
		Vector2.new(0, 0.5), Vector2.new(1, 0.5)
	previous.button.Position, nextCollection.button.Position =
		UDim2.fromScale(0.03, 0.5), UDim2.fromScale(0.97, 0.5)
	previous.button.Size, nextCollection.button.Size =
		UDim2.fromOffset(44, 44), UDim2.fromOffset(44, 44)
	for _, control in { previous.button, nextCollection.button } do
		control.Font = Enum.Font.GothamBold
		control.TextSize = 26
		local rounding = control:FindFirstChildOfClass("UICorner")
		if rounding then
			rounding.CornerRadius = UDim.new(1, 0)
		end
	end

	local info = panel(main, "ProductDetails", Color3.fromRGB(255, 250, 240), 18)
	local detailEmblem = ShopArtwork.mount(info, "CollectionEmblem", Enum.ScaleType.Fit)
	detailEmblem.root.Position = UDim2.fromOffset(14, 12)
	detailEmblem.root.Size = UDim2.fromOffset(62, 62)
	local detailFallback = fallbackMark(detailEmblem.native, Color3.fromRGB(151, 126, 91))
	local detailTitle = W.title(info, "", 34)
	detailTitle.Position = UDim2.fromOffset(84, 10)
	detailTitle.Size = UDim2.new(1, -98, 0, 34)
	detailTitle.Font = Enum.Font.FredokaOne
	detailTitle.TextSize = 30
	local description = W.label(info, "", 38, 14)
	description.Position = UDim2.fromOffset(84, 46)
	description.Size = UDim2.new(1, -98, 0, 28)
	description.TextColor3 = Color3.fromRGB(101, 82, 68)
	local detailProgress = W.label(info, "", 24, 13)
	detailProgress.Position = UDim2.fromOffset(14, 76)
	detailProgress.Size = UDim2.new(1, -28, 0, 24)
	detailProgress.TextXAlignment = Enum.TextXAlignment.Right
	detailProgress.Font = Enum.Font.GothamBold

	local figuresPanel = panel(info, "PossibleFigures", Color3.fromRGB(253, 247, 236), 12)
	figuresPanel.BackgroundTransparency = 1
	local figuresTitle = W.label(figuresPanel, "Possible Figures", 24, 18)
	figuresTitle.Position = UDim2.fromOffset(10, 4)
	figuresTitle.Size = UDim2.new(1, -20, 0, 24)
	figuresTitle.Font = Enum.Font.GothamBold
	local figureStrip = Instance.new("ScrollingFrame")
	figureStrip.Name = "FigureStrip"
	figureStrip.Position = UDim2.fromOffset(8, 30)
	figureStrip.Size = UDim2.new(1, -16, 1, -36)
	figureStrip.BackgroundTransparency = 1
	figureStrip.BorderSizePixel = 0
	figureStrip.CanvasSize = UDim2.fromOffset(0, 0)
	figureStrip.ScrollBarThickness = 3
	figureStrip.ScrollBarImageColor3 = Color3.fromRGB(188, 151, 102)
	figureStrip.ScrollingDirection = Enum.ScrollingDirection.X
	figureStrip.Parent = figuresPanel
	local figureList = W.list(figureStrip, 8)
	figureList.FillDirection = Enum.FillDirection.Horizontal
	type FigureSlot = { root: Frame, preview: Preview.Preview, question: TextLabel }
	local figureSlots: { [string]: FigureSlot } = {}
	for order, figure in Catalog.figures do
		local slot = panel(figureStrip, figure.id, Color3.fromRGB(239, 229, 211), 10)
		slot.LayoutOrder = order
		slot.Size = UDim2.fromOffset(64, 64)
		local preview = Preview.create(slot, ctx.scope, true)
		preview.frame.Position = UDim2.fromOffset(3, 3)
		preview.frame.Size = UDim2.new(1, -6, 1, -6)
		local question = W.label(slot, "?", 40, 22)
		question.Size = UDim2.fromScale(1, 1)
		question.TextXAlignment = Enum.TextXAlignment.Center
		question.Font = Enum.Font.FredokaOne
		question.TextColor3 = Color3.fromRGB(255, 248, 230)
		figureSlots[figure.id] = { root = slot, preview = preview, question = question }
	end
	local function updateFigureCanvas()
		figureStrip.CanvasSize = UDim2.fromOffset(math.ceil(figureList.AbsoluteContentSize.X), 0)
	end
	ctx.scope.connect(
		figureList:GetPropertyChangedSignal("AbsoluteContentSize"),
		updateFigureCanvas
	)

	local oddsPanel = panel(info, "RarityOdds", Color3.fromRGB(253, 247, 236), 12)
	oddsPanel.BackgroundTransparency = 1
	local oddsTitle = W.label(oddsPanel, "Rarity Odds", 28, 18)
	oddsTitle.Position = UDim2.fromOffset(10, 4)
	oddsTitle.Size = UDim2.new(1, -20, 0, 28)
	oddsTitle.Font = Enum.Font.GothamBold
	type OddsVisual = { root: Frame, value: TextLabel }
	local oddsVisuals: { [string]: OddsVisual } = {}
	for _, figure in Catalog.figures do
		if not oddsVisuals[figure.rarity] then
			local row = W.frame(oddsPanel, figure.rarity)
			local dot = W.frame(row, "Dot", Style.rarity(figure.rarity))
			dot.Position = UDim2.fromOffset(10, 8)
			dot.Size = UDim2.fromOffset(12, 12)
			W.corner(dot, 12)
			local name = W.label(row, figure.rarity, 28, 14)
			name.Position = UDim2.fromOffset(28, 0)
			name.Size = UDim2.new(0.58, -28, 1, 0)
			name.Font = Enum.Font.GothamBold
			local value = W.label(row, "", 28, 14)
			value.Position = UDim2.fromScale(0.58, 0)
			value.Size = UDim2.fromScale(0.42, 1)
			value.TextXAlignment = Enum.TextXAlignment.Right
			oddsVisuals[figure.rarity] = { root = row, value = value }
		end
	end

	local purchase = panel(info, "Purchase", Color3.fromRGB(253, 247, 236), 12)
	purchase.BackgroundTransparency = 1
	local quantityValue = W.label(purchase, "1 Box", 42, 15)
	quantityValue.Position = UDim2.fromOffset(10, 2)
	quantityValue.Size = UDim2.fromOffset(68, 34)
	quantityValue.BackgroundColor3 = Color3.fromRGB(245, 236, 219)
	quantityValue.BackgroundTransparency = 1
	quantityValue.TextXAlignment = Enum.TextXAlignment.Center
	W.corner(quantityValue, 10)
	local price = W.label(purchase, "", 34, 24)
	price.Position = UDim2.fromOffset(88, 2)
	price.Size = UDim2.new(1, -98, 0, 34)
	price.Font = Enum.Font.GothamBold
	price.TextXAlignment = Enum.TextXAlignment.Right
	local buy = W.action(purchase, "Buy 1 Box", ctx.scope, ctx.effects, function()
		ctx.send("Buy", nil, nil, selectedCollection)
	end)
	buy.button.Name = "BuyBox"
	buy.button.Position = UDim2.fromOffset(10, 44)
	buy.button.Size = UDim2.new(1, -20, 0, 58)
	buy.button.Font = Enum.Font.GothamBold
	buy.button.TextSize = 22
	W.gradient(buy.button, Color3.fromRGB(255, 255, 255), Color3.fromRGB(180, 193, 184), 90)
	local daily = W.action(purchase, "Daily Free Box", ctx.scope, ctx.effects, function()
		ctx.send("Daily", nil, nil, selectedCollection)
	end, true)
	daily.button.Name = "DailyBox"
	daily.button.Position = UDim2.fromOffset(10, 108)
	daily.button.Size = UDim2.new(1, -20, 0, 40)
	daily.button:SetAttribute("Quiet", true)

	local function collectionDefinition()
		for _, collection in Catalog.collections do
			if collection.id == selectedCollection then
				return collection
			end
		end
		return Catalog.collections[1]
	end

	local function layoutInfo(width: number)
		local wide = width >= 680
		detailTitle.TextSize = if width < 480 then 24 else 30
		figuresPanel.Position = UDim2.fromOffset(12, 104)
		figuresPanel.Size = if wide then UDim2.new(0.64, -12, 0, 142) else UDim2.new(1, -24, 0, 104)
		if width < 480 then
			oddsPanel.Position = UDim2.fromOffset(12, 218)
			oddsPanel.Size = UDim2.new(1, -24, 0, 124)
			purchase.Position = UDim2.fromOffset(12, 352)
			purchase.Size = UDim2.new(1, -24, 0, 158)
		elseif wide then
			oddsPanel.Position = UDim2.new(0.64, 0, 0, 104)
			oddsPanel.Size = UDim2.new(0.36, -12, 0, 142)
			purchase.Position = UDim2.fromOffset(12, 260)
			purchase.Size = UDim2.new(1, -24, 0, 110)
		else
			oddsPanel.Position = UDim2.fromOffset(12, 218)
			oddsPanel.Size = UDim2.new(0.43, -12, 0, 124)
			purchase.Position = UDim2.new(0.43, 0, 0, 218)
			purchase.Size = UDim2.new(0.57, -12, 0, 152)
		end
		quantityValue.Position = UDim2.fromOffset(10, if wide then 4 else 2)
		price.Position = if wide then UDim2.fromOffset(10, 34) else UDim2.fromOffset(88, 2)
		price.Size = if wide then UDim2.new(0.32, -20, 0, 34) else UDim2.new(1, -98, 0, 34)
		price.TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		price.TextSize = if width < 680 and width >= 480 then 20 else 24
		buy.button.Position = if wide then UDim2.new(0.32, 0, 0, 4) else UDim2.fromOffset(10, 44)
		buy.button.Size = if wide then UDim2.new(0.68, -10, 0, 64) else UDim2.new(1, -20, 0, 58)
		daily.button.Position = if wide
			then UDim2.new(0.32, 0, 0, 72)
			else UDim2.fromOffset(10, 108)
		daily.button.Size = if wide then UDim2.new(0.68, -10, 0, 38) else UDim2.new(1, -20, 0, 40)
		local stripWidth = (if wide then width * 0.64 - 12 else width - 24) - 19
		local count = #ShopState.figures(selectedCollection)
		local slotSize = math.min(if wide then 78 else 64, ShopLayout.figureSize(stripWidth, count))
		for _, slot in figureSlots do
			slot.root.Size = UDim2.fromOffset(slotSize, slotSize)
		end
	end

	resize = function()
		local geometry = ShopLayout.calculate(root.AbsoluteSize.X, root.AbsoluteSize.Y)
		sidebar.Position = UDim2.fromOffset(12, 12)
		sidebar.Size = UDim2.new(
			if geometry.compact then 1 else 0,
			if geometry.compact then -24 else geometry.sidebarWidth,
			0,
			geometry.sidebarHeight
		)
		shopTitle.Position = if geometry.compact
			then UDim2.fromOffset(14, 4)
			else UDim2.fromOffset(16, 12)
		shopTitle.Size = if geometry.compact
			then UDim2.new(0.38, -14, 0, 42)
			else UDim2.new(1, -32, 0, 42)
		shopSubtitle.Visible = not geometry.compact
		category.Position = if geometry.compact
			then UDim2.new(0.4, 0, 0, 8)
			else UDim2.fromOffset(10, 118)
		category.Size = if geometry.compact
			then UDim2.new(0.58, -12, 0, 44)
			else UDim2.new(1, -20, 0, 48)
		for _, label in categoryNotes do
			label.Visible = not geometry.compact
		end
		main.Position = UDim2.fromOffset(geometry.contentX, geometry.contentY)
		main.Size = UDim2.fromOffset(geometry.contentWidth, geometry.contentHeight)
		main.CanvasSize = UDim2.fromOffset(0, geometry.canvasHeight)
		main.ScrollBarThickness = if geometry.canvasHeight > geometry.contentHeight then 5 else 0
		carouselSection.Position = UDim2.fromOffset(0, 0)
		carouselSection.Size = UDim2.fromOffset(geometry.contentWidth, geometry.carouselHeight)
		carousel.Position = UDim2.fromOffset(4, 0)
		carousel.Size = UDim2.new(1, -8, 1, -10)
		local cardWidth = math.clamp(math.floor(geometry.carouselHeight * 1.28), 230, 320)
		local carouselWidth =
			math.min(geometry.contentWidth - 8, #Catalog.collections * (cardWidth + 14) + 10)
		carousel.AnchorPoint = Vector2.new(0.5, 0)
		carousel.Position = UDim2.fromScale(0.5, 0)
		carousel.Size = UDim2.fromOffset(carouselWidth, geometry.carouselHeight - 10)
		for _, card in carouselCards do
			card.action.button.Size = UDim2.fromOffset(cardWidth, geometry.carouselHeight - 24)
		end
		hero.Position = UDim2.fromOffset(0, geometry.detailY)
		hero.Size = UDim2.fromOffset(geometry.heroWidth, geometry.heroHeight)
		info.Position = UDim2.fromOffset(geometry.infoX, geometry.infoY)
		info.Size = UDim2.fromOffset(geometry.infoWidth, geometry.infoHeight)
		layoutInfo(geometry.infoWidth)
		updateCarouselCanvas()
		updateFigureCanvas()
	end

	refresh = function()
		local snapshot = currentSnapshot
		if not snapshot then
			return
		end
		local definition = collectionDefinition()
		local selectedTheme = ShopTheme.get(selectedCollection)
		for _, collection in Catalog.collections do
			local card = carouselCards[collection.id]
			local found, total = ShopState.progress(snapshot, collection.id)
			local selected = collection.id == selectedCollection
			card.action.set("", true, selected)
			card.outline.Color = if selected
				then Color3.fromRGB(255, 249, 220)
				else ShopTheme.get(collection.id).primary
			card.glow.Transparency = if selected then 0.14 else 1
			card.outline.Transparency = if selected then 0 else 0.48
			card.outline.Thickness = if selected then 3 else 1
			card.progress.Text = string.format("%d / %d discovered", found, total)
			card.fill.Size = UDim2.fromScale(if total > 0 then found / total else 0, 1)
		end
		box.set(selectedTheme, definition.name)
		plaque.Text = definition.name
		plaque.TextColor3 = selectedTheme.ink
		detailEmblem.set(selectedTheme.emblemKey)
		detailFallback.TextColor3 = selectedTheme.primary
		detailTitle.Text = definition.name
		detailTitle.TextColor3 = selectedTheme.ink
		description.Text = definition.description or ""
		local found, total = ShopState.progress(snapshot, selectedCollection)
		detailProgress.Text = string.format("%d / %d discovered", found, total)
		detailProgress.TextColor3 = selectedTheme.ink
		local visibleFigures = 0
		for _, figure in Catalog.figures do
			local slot = figureSlots[figure.id]
			local visible = figure.collection == selectedCollection
			local discovered = snapshot.discovered[figure.id] == true
			slot.root.Visible = visible
			slot.preview.figure(figure.id, discovered)
			slot.question.Visible = visible and not discovered
			if visible then
				visibleFigures += 1
				slot.root.LayoutOrder = visibleFigures
			end
		end
		for _, visual in oddsVisuals do
			visual.root.Visible = false
		end
		for order, odds in ShopState.rarityOdds(snapshot, selectedCollection) do
			local visual = oddsVisuals[odds.rarity]
			if visual then
				visual.root.Visible = true
				visual.root.Position = UDim2.fromOffset(0, 30 + (order - 1) * 28)
				visual.root.Size = UDim2.new(1, -20, 0, 28)
				visual.value.Text = if odds.minimum == odds.maximum
					then State.percent(odds.minimum) .. (if odds.count > 1 then " each" else "")
					else State.percent(odds.minimum) .. " - " .. State.percent(odds.maximum)
			end
		end
		price.Text = State.number(snapshot.price) .. " Coins"
		buy.button:SetAttribute("Accent", selectedTheme.primary)
		buy.set(
			if not ctx.canAct()
				then "Please wait..."
				elseif snapshot.coins >= snapshot.price then "Buy 1 Box"
				else "Need " .. State.number(snapshot.price - snapshot.coins) .. " more Coins",
			ctx.canAct() and snapshot.coins >= snapshot.price
		)
		daily.button:SetAttribute("Accent", selectedTheme.primary)
		daily.set(
			if snapshot.dailyReady then "Claim Daily Free Box" else "Daily Box Claimed",
			ctx.canAct() and snapshot.dailyReady
		)
		layoutInfo(info.AbsoluteSize.X)
		root:SetAttribute("SelectedCollection", selectedCollection)
		figureStrip.CanvasPosition = Vector2.zero
	end

	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	return {
		root = root,
		update = function(snapshot: Types.Snapshot)
			currentSnapshot = snapshot
			refresh()
		end,
	}
end

return Shop

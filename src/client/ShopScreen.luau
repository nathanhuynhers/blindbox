--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local State = require(script.Parent.UIState)
local ShopState = require(script.Parent.ShopState)
local Theme = require(script.Parent.ShopTheme)
local Layout = require(script.Parent.ShopLayout)
local Artwork = require(script.Parent.ShopArtwork)
local Card = require(script.Parent.ShopCollectionCard)
local Product = require(script.Parent.ShopProductStage)
local Style = require(script.Parent.ShopStyle)
local Rarity = require(script.Parent.CollectionStyle)
local Icons = require(script.Parent.UIIcons)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Shop = {}

function Shop.create(parent: Instance, ctx: Context.Context): Context.Screen
	local root = W.frame(parent, "Shop")
	root.ClipsDescendants = true
	local selected = Catalog.collections[1].id
	local snapshot: Types.Snapshot? = nil
	local refresh: () -> () = function() end
	local resize: () -> () = function() end

	local nav = Style.panel(root, "ShopNavigation", Style.surface, 22)
	W.outline(nav, Style.gold, 0.65)
	local title = Style.label(nav, "ShopTitle", "Shop", 34, true)
	title.Position = UDim2.fromOffset(18, 14)
	title.Size = UDim2.new(1, -36, 0, 44)
	title.Font = Enum.Font.FredokaOne
	local subtitle = Style.label(nav, "Subtitle", "Discover new figures from different worlds.", 13)
	subtitle.Position = UDim2.fromOffset(18, 64)
	subtitle.Size = UDim2.new(1, -36, 0, 50)
	local category = Style.panel(nav, "SelectedCategory", Style.secondary, 12)
	category.Position = UDim2.fromOffset(10, 130)
	category.Size = UDim2.new(1, -20, 0, 52)
	W.gradient(category, Color3.fromRGB(255, 246, 209), Color3.fromRGB(242, 218, 157), 90)
	W.outline(category, Style.gold, 0.3)
	local categoryIcon = Icons.create(category, "Shop", Style.ink)
	categoryIcon.Position = UDim2.fromOffset(12, 14)
	local categoryText = Style.label(category, "Label", "Blind Boxes", 15, true)
	categoryText.Position = UDim2.fromOffset(44, 0)
	categoryText.Size = UDim2.new(1, -52, 1, 0)
	local disabled: { Frame } = {}
	for order, name in { "Decorations", "Currencies", "Limited" } do
		local row = W.frame(nav, name)
		row.Position = UDim2.fromOffset(18, 198 + (order - 1) * 74)
		row.Size = UDim2.new(1, -36, 0, 62)
		local icon = Icons.create(row, "Lock", Style.muted)
		icon.Position = UDim2.fromOffset(0, 9)
		icon.Size = UDim2.fromOffset(18, 18)
		local label = Style.label(row, "Label", name, 15)
		label.Position = UDim2.fromOffset(28, 0)
		label.Size = UDim2.new(1, -28, 0, 30)
		local soon = Style.label(row, "Availability", "COMING SOON", 10)
		soon.Position = UDim2.fromOffset(28, 31)
		soon.Size = UDim2.new(1, -28, 0, 20)
		table.insert(disabled, row)
	end

	local main = Instance.new("ScrollingFrame")
	main.Name = "ShopContent"
	main.BackgroundTransparency = 1
	main.BorderSizePixel = 0
	main.ScrollBarThickness = 4
	main.ScrollBarImageColor3 = Style.gold
	main.ScrollingDirection = Enum.ScrollingDirection.Y
	main.CanvasSize = UDim2.fromOffset(0, 0)
	main.Parent = root
	local shelf = W.frame(main, "CollectionCarouselSection")
	local browseTitle = Style.label(shelf, "Heading", "Collections", 17, true)
	browseTitle.Position = UDim2.fromOffset(8, 0)
	browseTitle.Size = UDim2.new(1, -112, 0, 26)
	local carousel = Instance.new("ScrollingFrame")
	carousel.Name = "CollectionCarousel"
	carousel.BackgroundTransparency = 1
	carousel.BorderSizePixel = 0
	carousel.Position = UDim2.fromOffset(0, 44)
	carousel.Size = UDim2.new(1, 0, 1, -53)
	carousel.ScrollBarThickness = 3
	carousel.ScrollBarImageColor3 = Style.gold
	carousel.ScrollingDirection = Enum.ScrollingDirection.X
	carousel.CanvasSize = UDim2.fromOffset(0, 0)
	carousel.SelectionGroup = true
	carousel.Parent = shelf
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 3)
	pad.Parent = carousel
	local list = W.list(carousel, 12)
	list.FillDirection = Enum.FillDirection.Horizontal
	local edge = Style.panel(shelf, "ShelfEdge", Style.wood, 3)
	edge.Position = UDim2.new(0, 0, 1, -5)
	edge.Size = UDim2.new(1, 0, 0, 5)
	W.gradient(edge, Style.secondary, Style.wood, 90)
	local cards: { [string]: Card.Card } = {}
	local ordered: { Card.Card } = {}
	for order, collection in Catalog.collections do
		local id = collection.id
		local card = Card.create(carousel, ctx, id, collection.name, function()
			selected = id
			refresh()
		end)
		card.button.LayoutOrder = order
		card.button.Size = UDim2.fromOffset(240, 118)
		cards[id] = card
		table.insert(ordered, card)
	end
	for index, card in ordered do
		card.button.NextSelectionLeft = ordered[(index - 2) % #ordered + 1].button
		card.button.NextSelectionRight = ordered[index % #ordered + 1].button
		ctx.scope.connect(card.button.SelectionGained, function()
			local left = card.button.AbsolutePosition.X - carousel.AbsolutePosition.X
			local right = left + card.button.AbsoluteSize.X
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
	local browseButtons: { TextButton } = {}
	for index, direction in { -1, 1 } do
		local button = W.action(
			shelf,
			if direction < 0 then "\u{2039}" else "\u{203A}",
			ctx.scope,
			ctx.effects,
			function()
				carousel.CanvasPosition = Vector2.new(
					math.clamp(
						carousel.CanvasPosition.X + direction * 252,
						0,
						math.max(0, carousel.AbsoluteCanvasSize.X - carousel.AbsoluteWindowSize.X)
					),
					0
				)
			end,
			true
		)
		button.button.Name = if direction < 0 then "BrowsePrevious" else "BrowseNext"
		button.button.Size = UDim2.fromOffset(44, 44)
		button.button.Position = UDim2.new(1, -100 + (index - 1) * 50, 0, -2)
		button.button:SetAttribute("Surface", Style.elevated)
		button.button:SetAttribute("Accent", Style.gold)
		button.button.TextSize = 24
		table.insert(browseButtons, button.button)
	end
	local function canvas()
		carousel.CanvasSize = UDim2.fromOffset(list.AbsoluteContentSize.X + 8, 0)
		for _, button in browseButtons do
			button.Visible = carousel.AbsoluteCanvasSize.X > carousel.AbsoluteWindowSize.X + 1
		end
	end
	ctx.scope.connect(list:GetPropertyChangedSignal("AbsoluteContentSize"), canvas)
	local function change(direction: number)
		local index = 1
		for i, collection in Catalog.collections do
			if collection.id == selected then
				index = i
			end
		end
		selected = Catalog.collections[(index - 1 + direction) % #Catalog.collections + 1].id
		refresh()
	end
	local product = Product.create(main, ctx, function()
		change(-1)
	end, function()
		change(1)
	end)
	local info = Style.panel(main, "ProductDetails", Style.elevated, 22)
	local emblem = Artwork.mount(info, "CollectionEmblem", Enum.ScaleType.Fit)
	emblem.root.Position = UDim2.fromOffset(20, 18)
	emblem.root.Size = UDim2.fromOffset(62, 62)
	local nativeMark = Style.label(emblem.native, "NativeMark", "\u{2726}", 40, true)
	nativeMark.TextXAlignment = Enum.TextXAlignment.Center
	nativeMark.Size = UDim2.fromScale(1, 1)
	local name = Style.label(info, "CollectionName", "", 30, true)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MinTextSize, nameLimit.MaxTextSize = 16, 30
	nameLimit.Parent = name
	name.Position = UDim2.fromOffset(94, 18)
	name.Size = UDim2.new(1, -114, 0, 38)
	local description = Style.label(info, "Description", "", 14)
	description.Position = UDim2.fromOffset(94, 58)
	description.Size = UDim2.new(1, -114, 0, 30)
	local progressGroup = W.frame(info, "DiscoveryProgress")
	progressGroup.Position = UDim2.fromOffset(20, 90)
	progressGroup.Size = UDim2.fromOffset(170, 32)
	local progress = Style.label(progressGroup, "Discovery", "", 13)
	progress.Size = UDim2.new(1, 0, 0, 18)
	local progressTrack = Style.panel(progressGroup, "DiscoveryTrack", Style.secondary, 6)
	progressTrack.Position = UDim2.fromOffset(0, 23)
	progressTrack.Size = UDim2.new(1, 0, 0, 7)
	local progressFill = Style.panel(progressTrack, "Fill", Style.gold, 6)
	local figures = W.frame(info, "PossibleFigures")
	local figuresTitle = Style.label(figures, "Heading", "Possible Figures", 17, true)
	figuresTitle.Size = UDim2.new(1, 0, 0, 30)
	local strip = Instance.new("ScrollingFrame")
	strip.Name = "FigureStrip"
	strip.Position = UDim2.fromOffset(0, 38)
	strip.Size = UDim2.new(1, 0, 1, -38)
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.ScrollBarThickness = 3
	strip.ScrollBarImageColor3 = Style.gold
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.Parent = figures
	local figureList = W.list(strip, 8)
	figureList.FillDirection = Enum.FillDirection.Horizontal
	type Slot = { root: Frame, preview: Preview.Preview, question: TextLabel }
	local slots: { [string]: Slot } = {}
	for order, figure in Catalog.figures do
		local slot = Style.panel(strip, figure.id, Style.secondary, 12)
		slot.LayoutOrder = order
		local portrait = Preview.create(slot, ctx.scope, true)
		portrait.frame.Position = UDim2.fromOffset(4, 4)
		portrait.frame.Size = UDim2.new(1, -8, 1, -8)
		local question = Style.label(slot, "Undiscovered", "?", 23, true)
		question.Size = UDim2.fromScale(1, 1)
		question.Font = Enum.Font.FredokaOne
		question.TextXAlignment = Enum.TextXAlignment.Center
		question.TextColor3 = Style.elevated
		slots[figure.id] = { root = slot, preview = portrait, question = question }
	end
	ctx.scope.connect(figureList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		strip.CanvasSize = UDim2.fromOffset(figureList.AbsoluteContentSize.X, 0)
	end)
	local odds = W.frame(info, "RarityOdds")
	local oddsTitle = Style.label(odds, "Heading", "Rarity Odds", 17, true)
	oddsTitle.Size = UDim2.new(1, 0, 0, 30)
	type Odds = { root: Frame, value: TextLabel }
	local rows: { [string]: Odds } = {}
	for _, figure in Catalog.figures do
		if rows[figure.rarity] then
			continue
		end
		local row = W.frame(odds, figure.rarity)
		local dot = Style.panel(row, "Rarity", Rarity.rarity(figure.rarity), 7)
		dot.Position = UDim2.fromOffset(0, 9)
		dot.Size = UDim2.fromOffset(10, 10)
		local label = Style.label(row, "Name", figure.rarity, 13, true)
		label.Position = UDim2.fromOffset(18, 0)
		label.Size = UDim2.new(0.60, -18, 1, 0)
		local value = Style.label(row, "Chance", "", 13)
		value.Position = UDim2.fromScale(0.60, 0)
		value.Size = UDim2.fromScale(0.40, 1)
		value.TextXAlignment = Enum.TextXAlignment.Right
		rows[figure.rarity] = { root = row, value = value }
	end
	local purchase = W.frame(info, "Purchase")
	local divider = W.frame(purchase, "Divider", Style.secondary)
	divider.Size = UDim2.new(1, 0, 0, 1)
	local quantity = Style.label(purchase, "Quantity", "1 Box", 14)
	local priceGroup = W.frame(purchase, "PriceGroup")
	local coinIcon = Icons.create(priceGroup, "Coins", Style.gold)
	coinIcon.Position = UDim2.fromOffset(0, 5)
	coinIcon.Size = UDim2.fromOffset(22, 22)
	local price = Style.label(priceGroup, "Price", "", 24, true)
	price.Position = UDim2.fromOffset(28, 0)
	price.Size = UDim2.new(1, -28, 1, 0)
	local buy = W.action(purchase, "Buy 1 Box", ctx.scope, ctx.effects, function()
		ctx.send("Buy", nil, nil, selected)
	end)
	buy.button.Name = "BuyBox"
	buy.button.TextSize = 22
	buy.button.Font = Enum.Font.GothamBold
	W.gradient(buy.button, Color3.new(1, 1, 1), Color3.fromRGB(193, 204, 196), 90)
	local daily = W.action(purchase, "Daily Free Box", ctx.scope, ctx.effects, function()
		ctx.send("Daily", nil, nil, selected)
	end, true)
	daily.button.Name = "DailyBox"
	daily.button:SetAttribute("Surface", Style.surface)
	daily.button:SetAttribute("Accent", Style.gold)
	daily.button:SetAttribute("RestingStrokeTransparency", 0.55)
	daily.button.TextSize = 13

	local function layoutDetails()
		local width = info.AbsoluteSize.X
		local rect = Layout.details(width)
		nameLimit.MaxTextSize = if width < 480 then 24 else 30
		figures.Position = UDim2.fromOffset(rect.figuresX, rect.figuresY)
		figures.Size = UDim2.fromOffset(rect.figuresWidth, rect.figuresHeight)
		odds.Position = UDim2.fromOffset(rect.oddsX, rect.oddsY)
		odds.Size = UDim2.fromOffset(rect.oddsWidth, 132)
		purchase.Position = UDim2.fromOffset(rect.purchaseX, rect.purchaseY)
		purchase.Size = UDim2.fromOffset(rect.purchaseWidth, rect.purchaseHeight)
		progressGroup.Size = UDim2.fromOffset(math.max(120, math.min(170, width - 40)), 32)
		local size = math.min(
			rect.figuresHeight - 42,
			Layout.figureSize(rect.figuresWidth - 3, #ShopState.figures(selected))
		)
		for _, slot in slots do
			slot.root.Size = UDim2.fromOffset(size, size)
		end
		quantity.Position = UDim2.fromOffset(0, 10)
		quantity.Size = UDim2.fromOffset(68, 24)
		priceGroup.Position = if rect.wide then UDim2.fromOffset(0, 36) else UDim2.fromOffset(78, 6)
		priceGroup.Size = if rect.wide
			then UDim2.new(0.32, -10, 0, 32)
			else UDim2.new(1, -78, 0, 34)
		price.TextSize = if rect.wide then 24 else 19
		price.TextXAlignment = if rect.wide
			then Enum.TextXAlignment.Left
			else Enum.TextXAlignment.Right
		buy.button.Position = if rect.wide
			then UDim2.new(0.32, 0, 0, 4)
			else UDim2.fromOffset(0, 44)
		buy.button.Size = if rect.wide then UDim2.new(0.68, 0, 0, 58) else UDim2.new(1, 0, 0, 58)
		daily.button.Position = if rect.wide
			then UDim2.new(0.32, 0, 0, 64)
			else UDim2.fromOffset(0, 106)
		daily.button.Size = if rect.wide then UDim2.new(0.68, 0, 0, 40) else UDim2.new(1, 0, 0, 40)
	end
	resize = function()
		local g = Layout.calculate(root.AbsoluteSize.X, root.AbsoluteSize.Y)
		nav.Position = UDim2.fromOffset(12, 12)
		nav.Size = UDim2.fromOffset(
			if g.compact then root.AbsoluteSize.X - 24 else g.sidebarWidth,
			if g.compact then 58 else math.min(g.sidebarHeight, 448)
		)
		title.Position = UDim2.fromOffset(18, if g.compact then 6 else 14)
		title.Size = if g.compact then UDim2.new(0.4, -18, 0, 44) else UDim2.new(1, -36, 0, 44)
		subtitle.Visible = not g.compact
		category.Position = if g.compact then UDim2.new(0.4, 0, 0, 6) else UDim2.fromOffset(10, 130)
		category.Size = if g.compact then UDim2.new(0.6, -10, 0, 46) else UDim2.new(1, -20, 0, 52)
		for _, row in disabled do
			row.Visible = not g.compact
		end
		main.Position = UDim2.fromOffset(g.contentX, g.contentY)
		main.Size = UDim2.fromOffset(g.contentWidth, g.contentHeight)
		main.CanvasSize = UDim2.fromOffset(0, g.canvasHeight)
		main.ScrollBarThickness = if g.canvasHeight > g.contentHeight then 4 else 0
		shelf.Size = UDim2.fromOffset(g.contentWidth, g.carouselHeight)
		product.root.Position = UDim2.fromOffset(0, g.detailY)
		product.root.Size = UDim2.fromOffset(g.heroWidth, g.heroHeight)
		info.Position = UDim2.fromOffset(g.infoX, g.infoY)
		info.Size = UDim2.fromOffset(g.infoWidth, g.infoHeight)
		layoutDetails()
		canvas()
	end
	refresh = function()
		local state = snapshot
		if not state then
			return
		end
		local theme = Theme.get(selected)
		for _, collection in Catalog.collections do
			local found, total = ShopState.progress(state, collection.id)
			cards[collection.id].set(found, total, collection.id == selected)
			if collection.id == selected then
				product.set(selected, collection.name)
				name.Text = collection.name
				description.Text = collection.description or ""
				progress.Text = string.format("%d / %d discovered", found, total)
				progressFill.Size = UDim2.fromScale(if total > 0 then found / total else 0, 1)
				progressFill.Visible = found > 0
			end
		end
		emblem.set(theme.emblemKey)
		progressFill.BackgroundColor3 = theme.primary
		local count = 0
		for _, figure in Catalog.figures do
			local slot = slots[figure.id]
			local visible = figure.collection == selected
			local discovered = state.discovered[figure.id] == true
			slot.root.Visible = visible
			slot.preview.figure(figure.id, discovered)
			slot.question.Visible = not discovered
			if visible then
				count += 1
				slot.root.LayoutOrder = count
			end
		end
		for _, row in rows do
			row.root.Visible = false
		end
		for order, row in ShopState.rarityOdds(state, selected) do
			local visual = rows[row.rarity]
			visual.root.Visible = true
			visual.root.Position = UDim2.fromOffset(0, 36 + (order - 1) * 29)
			visual.root.Size = UDim2.new(1, 0, 0, 29)
			visual.value.Text = if row.minimum == row.maximum
				then State.percent(row.minimum) .. (if row.count > 1 then " each" else "")
				else State.percent(row.minimum) .. " - " .. State.percent(row.maximum)
		end
		price.Text = State.number(state.price) .. " Coins"
		buy.button:SetAttribute("Accent", theme.primary)
		buy.set(
			if not ctx.canAct()
				then "Please wait..."
				elseif state.coins >= state.price then "Buy 1 Box"
				else "Need " .. State.number(state.price - state.coins) .. " more Coins",
			ctx.canAct() and state.coins >= state.price
		)
		daily.set(
			if state.dailyReady then "Claim Daily Free Box" else "Daily Box Claimed",
			ctx.canAct() and state.dailyReady
		)
		if root:GetAttribute("SelectedCollection") ~= selected then
			strip.CanvasPosition = Vector2.zero
		end
		root:SetAttribute("SelectedCollection", selected)
		layoutDetails()
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	ctx.scope.connect(info:GetPropertyChangedSignal("AbsoluteSize"), layoutDetails)
	resize()
	return {
		root = root,
		update = function(nextSnapshot: Types.Snapshot)
			snapshot = nextSnapshot
			refresh()
		end,
	}
end
return Shop

--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local State = require(script.Parent.UIState)
local Selection = require(script.Parent.CollectionSelection)
local Layout = require(script.Parent.CollectionLayout)
local Style = require(script.Parent.CollectionStyle)
local Skin = require(script.Parent.CollectionSkin)
local Tabs = require(script.Parent.CollectionTabs)
local Controls = require(script.Parent.CollectionControls)
local Scroll = require(script.Parent.Scroll)
local W = require(script.Parent.Widgets)
local Card = require(script.Parent.FigureCard)
local Details = require(script.Parent.FigureDetails)
local Collection = {}
function Collection.create(parent: Instance, ctx: Context.Context)
	local root = W.frame(parent, "Collection")
	local selected = Selection.create()
	local ownedOnly = false
	local initialized = false
	local resetGrid: () -> () = function() end
	local resize: () -> () = function() end
	local refresh: () -> () = function() end
	local detailsUpdate: (string) -> () = function() end
	local tabs = Tabs.create(root, ctx, function(id)
		resetGrid()
		selected.collection = id
		selected.figure = Selection.first(id, ctx.snapshot(), ownedOnly)
		selected.inspected, selected.acquired = false, false
		detailsUpdate(selected.figure)
		refresh()
		resize()
	end)
	local skin = Skin.create(root, ctx.scope)
	local pages = W.frame(root, "Pages")
	local browser = W.frame(pages, "Book")
	local header = W.frame(browser, "BookHeader")
	local title = W.title(header, "", 36)
	title.Name = "CollectionTitle"
	title.Position = UDim2.fromOffset(0, 20)
	title.Font = Enum.Font.FredokaOne
	local count = W.label(header, "", 28, 14)
	count.Name = "DiscoveryProgress"
	count.Position = UDim2.fromOffset(0, 58)
	count.Size = UDim2.new(1, -110, 0, 28)
	local filter: Controls.Action? = nil
	filter = Controls.action(header, "All figures", "filter", ctx, function()
		ownedOnly = not ownedOnly
		resetGrid()
		refresh()
	end)
	assert(filter, "Book filter missing")
	filter.button.Size = UDim2.fromOffset(Layout.filterWidth, 44)
	filter.button.Position = UDim2.new(1, -Layout.filterWidth, 0, 44)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "FigureGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.Parent = browser
	resetGrid = function()
		grid.CanvasPosition = Vector2.zero
	end
	W.padding(grid, Layout.gridPadding)
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.CellPadding = UDim2.fromOffset(Layout.gridGap, Layout.gridGap)
	gridLayout.Parent = grid
	ctx.scope.add(Scroll.bind(grid, gridLayout, Layout.gridPadding))
	local empty = W.label(browser, "Your next discovery is waiting in Shop.", 70, 16)
	empty.Position = UDim2.fromOffset(4, 110)
	empty.Size = UDim2.new(1, -8, 0, 70)
	empty.Visible = false
	local function backToGrid()
		selected.inspected = false
		resize()
		tabs.focus()
	end
	local details = Details.create(pages, ctx, backToGrid)
	detailsUpdate = function(id)
		details.show(id, false)
	end
	local strip = W.frame(details.root, "FigureStrip")
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.new(0.5, 0, 1, -2)
	strip.Size = UDim2.new(1, 0, 0, 56)
	local stripLayout = W.list(strip, Layout.thumbnailGap)
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local previous = Controls.action(details.hero, "<", "paper", ctx, function()
		Selection.step(selected, -1)
		detailsUpdate(selected.figure)
		refresh()
		resize()
	end)
	local nextFigure = Controls.action(details.hero, ">", "paper", ctx, function()
		Selection.step(selected, 1)
		detailsUpdate(selected.figure)
		refresh()
		resize()
	end)
	previous.button.Name, nextFigure.button.Name = "PreviousFigure", "NextFigure"
	previous.button.Size, nextFigure.button.Size =
		UDim2.fromOffset(Layout.arrowSize, Layout.arrowSize),
		UDim2.fromOffset(Layout.arrowSize, Layout.arrowSize)
	previous.button.AnchorPoint = Vector2.new(1, 0.5)
	nextFigure.button.AnchorPoint = Vector2.new(0, 0.5)
	local function alignHeroNavigation()
		local viewport = details.viewport
		local middle = UDim2.new(0, 0, viewport.Size.Y.Scale * 0.5, viewport.Size.Y.Offset * 0.5)
		previous.button.Position = viewport.Position + middle - UDim2.fromOffset(Layout.arrowGap, 0)
		nextFigure.button.Position = viewport.Position
			+ middle
			+ UDim2.new(viewport.Size.X.Scale, viewport.Size.X.Offset + Layout.arrowGap, 0, 0)
	end
	ctx.scope.connect(details.viewport:GetPropertyChangedSignal("Position"), alignHeroNavigation)
	ctx.scope.connect(details.viewport:GetPropertyChangedSignal("Size"), alignHeroNavigation)
	local cards: { [string]: Card.Card } = {}
	local thumbnails: { [string]: Card.Card } = {}
	for order, figure in Catalog.figures do
		local card = Card.create(grid, figure.id, ctx)
		card.root.LayoutOrder = order
		card.root.Visible = figure.collection == selected.collection
		cards[figure.id] = card
		local thumb = Card.create(strip, figure.id, ctx, true)
		thumb.root.LayoutOrder = order
		thumb.root.Visible = figure.collection == selected.collection
		thumb.root.Size = UDim2.fromOffset(Layout.thumbnailWidth, 52)
		thumbnails[figure.id] = thumb
	end
	resize = function()
		local geometry = Layout.book(root.AbsoluteSize.X, root.AbsoluteSize.Y)
		root:SetAttribute("Spread", geometry.spread)
		skin.root.Position = UDim2.fromOffset(geometry.tabs, 0)
		skin.root.Size = UDim2.new(1, -geometry.tabs, 1, 0)
		skin.set(selected.collection, geometry.spread)
		tabs.root.Position = UDim2.fromOffset(0, math.min(94, root.AbsoluteSize.Y * 0.18))
		tabs.root.Size =
			UDim2.new(0, geometry.tabs + 14, 1, -math.min(110, root.AbsoluteSize.Y * 0.22))
		tabs.layout(geometry.tabs < 100)
		pages.Position = UDim2.fromOffset(geometry.tabs + geometry.inset, geometry.inset)
		pages.Size = UDim2.new(1, -geometry.tabs - 2 * geometry.inset, 1, -2 * geometry.inset - 14)
		browser.Size = UDim2.new(0, geometry.pageWidth, 1, 0)
		browser.Visible = geometry.spread or not selected.inspected
		header.Size = UDim2.new(1, 0, 0, geometry.header)
		title.TextSize = if geometry.pageWidth < 300 then 21 else 28
		local heading = Layout.header(geometry.pageWidth, geometry.inset, geometry.spread)
		title.Position = UDim2.fromOffset(heading.x, heading.y)
		title.Size = UDim2.fromOffset(heading.width, 36)
		count.Position = UDim2.fromOffset(heading.x, heading.progressY)
		count.Size = UDim2.fromOffset(
			math.max(1, heading.width - Layout.filterWidth - Layout.contentGap),
			if geometry.pageWidth < 360 then 44 else 28
		)
		if filter then
			filter.button.Position = UDim2.fromOffset(heading.filterX, heading.filterY)
		end
		grid.Position = UDim2.fromOffset(-4, geometry.header)
		grid.Size = UDim2.new(1, 8, 1, -geometry.header)
		grid.ScrollingEnabled = not geometry.spread
		grid.ScrollBarThickness = if geometry.spread then 0 else 4
		local columns, width, height = Layout.grid(
			geometry.pageWidth + 8,
			geometry.pageHeight - geometry.header,
			geometry.spread
		)
		gridLayout.FillDirectionMaxCells = columns
		gridLayout.CellSize = UDim2.fromOffset(width, height)
		details.root.Position = if geometry.spread
			then UDim2.fromOffset(geometry.pageWidth + 28, 0)
			else UDim2.fromOffset(0, 0)
		details.root.Size = UDim2.new(0, geometry.pageWidth, 1, 0)
		details.root.Visible = geometry.spread or selected.inspected
		local detailGeometry =
			Layout.detail(geometry.pageWidth, geometry.pageHeight, geometry.inset)
		local figureCount = 0
		for _, figure in Catalog.figures do
			if figure.collection == selected.collection then
				figureCount += 1
			end
		end
		local stripCenter, stripWidth = Layout.strip(
			geometry.pageWidth,
			detailGeometry.heroX,
			detailGeometry.heroWidth,
			figureCount
		)
		strip.Visible = detailGeometry.thumbnails and stripWidth <= geometry.pageWidth
		strip.Position = UDim2.new(
			0,
			if detailGeometry.sideBySide then stripCenter else geometry.pageWidth / 2,
			1,
			-2
		)
		strip.Size = UDim2.fromOffset(stripWidth, 56)
		local footer = if strip.Visible then detailGeometry.footer else 0
		details.layout(not geometry.spread, footer, geometry.inset)
		alignHeroNavigation()
		previous.button.Visible = detailGeometry.sideBySide
		nextFigure.button.Visible = detailGeometry.sideBySide
	end
	local function update(snapshot: Types.Snapshot)
		if not initialized then
			initialized = true
			if not selected.inspected then
				selected.figure = Selection.first(selected.collection, snapshot, ownedOnly)
				details.show(selected.figure, false)
			end
		end
		local definition = Catalog.collections[1]
		for _, collection in Catalog.collections do
			if collection.id == selected.collection then
				definition = collection
			end
		end
		local style = Style.get(selected.collection)
		local found, total = State.completion(snapshot, selected.collection)
		title.Text, title.TextColor3 = definition.name, style.ink
		count.TextColor3 = style.ink
		count.Text = string.format(
			"%d / %d discovered%s",
			found,
			total,
			if found == total then " - Complete!" else ""
		)
		grid.ScrollBarImageColor3 = style.accent
		local visible = 0
		for id, card in cards do
			card.update(snapshot, selected.figure == id)
			card.root.Visible = State.matches(snapshot, id, selected.collection, ownedOnly)
			if card.root.Visible then
				visible += 1
			end
			local thumb = thumbnails[id]
			thumb.update(snapshot, selected.figure == id)
			thumb.root.Visible = Catalog.byId[id].collection == selected.collection
		end
		empty.Visible = visible == 0
		if filter then
			filter.set(if ownedOnly then "Owned only" else "All figures", true, ownedOnly)
		end
		tabs.update(snapshot, selected.collection)
		root:SetAttribute("CollectionId", selected.collection)
		root:SetAttribute("OwnedOnly", ownedOnly)
		root:SetAttribute("SelectedFigure", selected.figure)
		details.update(snapshot)
	end
	refresh = function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	ctx.scope.connect(grid:GetPropertyChangedSignal("AbsoluteSize"), resize)
	detailsUpdate(selected.figure)
	resize()
	return {
		root = root,
		update = update,
		back = function(): boolean
			if not selected.inspected or root:GetAttribute("Spread") then
				return false
			end
			backToGrid()
			return true
		end,
		showBook = function(owned: boolean?)
			ownedOnly = owned == true
			local snapshot = ctx.snapshot()
			if owned and snapshot then
				local index = 1
				for order, definition in Catalog.collections do
					if definition.id == selected.collection then
						index = order
					end
				end
				selected.collection = Catalog.collections[State.ownedCollection(snapshot, index)].id
				selected.figure = Selection.first(selected.collection, snapshot, true)
			end
			Selection.open(selected, owned == true)
			detailsUpdate(selected.figure)
			refresh()
			resize()
		end,
		inspect = function(id: string)
			Selection.choose(selected, id)
			detailsUpdate(id)
			refresh()
			resize()
			if not root:GetAttribute("Spread") then
				W.focus(details.back)
			end
		end,
		selectAcquired = function(id: string)
			Selection.choose(selected, id, true)
			ownedOnly = false
			detailsUpdate(id)
			refresh()
			resize()
		end,
	}
end
return Collection

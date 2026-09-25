--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Style = require(script.Parent.CollectionStyle)
local Art = require(script.Parent.CollectionArt)
local State = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Card = require(script.Parent.FigureCard)
local Details = require(script.Parent.FigureDetails)
local Collection = {}
function Collection.create(parent: Instance, ctx: Context.Context)
	local root = W.frame(parent, "Collection")
	local tabs = W.frame(root, "CollectionTabs")
	tabs.Size = UDim2.new(1, 0, 0, 48)
	local cover = W.frame(root, "Binding", Style.get("grove").cover)
	cover.Position = UDim2.fromOffset(0, 52)
	cover.Size = UDim2.new(1, 0, 1, -52)
	W.corner(cover, 14)
	local edge = W.frame(cover, "PageEdges", Style.get("grove").page)
	edge.Position = UDim2.fromOffset(5, 5)
	edge.Size = UDim2.new(1, -10, 1, -13)
	W.corner(edge, 10)
	W.outline(edge, Style.get("grove").trim, 0.45)
	local body = W.frame(cover, "Pages")
	body.Position = UDim2.fromOffset(8, 7)
	body.Size = UDim2.new(1, -16, 1, -22)
	local art = Art.create(body)
	local browser = W.frame(body, "Book")
	local header = W.frame(browser, "BookHeader")
	header.Size = UDim2.new(1, 0, 0, 92)
	local title = W.title(header, "", 32)
	title.Position = UDim2.fromOffset(22, 10)
	title.Size = UDim2.new(1, -44, 0, 32)
	title.Font = Enum.Font.FredokaOne
	local count = W.label(header, "", 24, 13)
	count.Position = UDim2.fromOffset(22, 50)
	count.Size = UDim2.new(1, -146, 0, 30)
	local index, ownedOnly, inspected = 1, false, false
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "FigureGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.Parent = browser
	grid.Position = UDim2.fromOffset(0, 92)
	grid.Size = UDim2.new(1, 0, 1, -92)
	local layout = W.grid(grid, ctx.scope, 112, 3, 202)
	local empty = W.label(browser, "Your next discovery is waiting in Shop.", 72, 16)
	empty.Position = UDim2.fromOffset(24, 100)
	empty.Size = UDim2.new(1, -48, 0, 72)
	empty.Visible = false
	local seam = W.frame(body, "BookSpine", Color3.new(1, 1, 1))
	seam.Position = UDim2.new(0.5, -12, 0, 0)
	seam.Size = UDim2.new(0, 24, 1, 0)
	local fold = W.gradient(seam, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0)
	local resize: () -> () = function() end
	local refresh: () -> () = function() end
	local tabActions: { W.Action } = {}
	local function closeDetail()
		inspected = false
		resize()
		W.focus(tabActions[index].button)
	end
	local details = Details.create(body, ctx, closeDetail)
	local cards: { [string]: { root: TextButton, update: (Types.Snapshot) -> () } } = {}
	local function firstFigure(): string
		for _, figure in Catalog.figures do
			if figure.collection == Catalog.collections[index].id then
				return figure.id
			end
		end
		return Catalog.figures[1].id
	end
	local function selectCollection(nextIndex: number)
		index = nextIndex
		inspected = false
		grid.CanvasPosition = Vector2.zero
		details.show(firstFigure(), false)
		refresh()
		resize()
	end
	for order, definition in Catalog.collections do
		local style = Style.get(definition.id)
		local action = W.action(tabs, definition.name, ctx.scope, ctx.effects, function()
			selectCollection(order)
		end, true)
		action.button.Name = "Tab" .. definition.id
		action.button:SetAttribute("Accent", style.accent)
		action.button:SetAttribute("Surface", style.page)
		action.button.Position = UDim2.new((order - 1) / #Catalog.collections, 2, 0, 0)
		action.button.Size = UDim2.new(1 / #Catalog.collections, -4, 0, 44)
		tabActions[order] = action
	end
	local filter: W.Action? = nil
	filter = W.action(header, "All figures", ctx.scope, ctx.effects, function()
		ownedOnly = not ownedOnly
		grid.CanvasPosition = Vector2.zero
		refresh()
	end, true)
	assert(filter, "Collection filter was not created")
	filter.button.Position = UDim2.new(1, -116, 0, 44)
	filter.button.Size = UDim2.fromOffset(104, 44)
	filter.button:SetAttribute("Quiet", true)
	for order, figure in Catalog.figures do
		local card = Card.create(grid, figure.id, ctx)
		card.root.LayoutOrder = order
		cards[figure.id] = card
	end
	resize = function()
		local short = root.AbsoluteSize.Y < 290 and root.AbsoluteSize.X >= 440
		tabs.Size = if short then UDim2.new(0, 122, 1, 0) else UDim2.new(1, 0, 0, 48)
		for order, action in tabActions do
			action.button.Position = if short
				then UDim2.fromOffset(0, (order - 1) * 48)
				else UDim2.new((order - 1) / #Catalog.collections, 2, 0, 0)
			action.button.Size = if short
				then UDim2.fromOffset(118, 44)
				else UDim2.new(1 / #Catalog.collections, -4, 0, 44)
		end
		cover.Position = if short then UDim2.fromOffset(128, 0) else UDim2.fromOffset(0, 52)
		cover.Size = if short then UDim2.new(1, -128, 1, 0) else UDim2.new(1, 0, 1, -52)
		local headerHeight = if short then 52 else 92
		header.Size = UDim2.new(1, 0, 0, headerHeight)
		title.Position = UDim2.fromOffset(16, if short then 0 else 10)
		title.Size = UDim2.new(1, if short then -130 else -44, 0, 30)
		count.Position = UDim2.fromOffset(16, if short then 28 else 50)
		if filter then
			filter.button.Position = UDim2.new(1, -116, 0, if short then 0 else 44)
		end
		grid.Position = UDim2.fromOffset(0, headerHeight)
		grid.Size = UDim2.new(1, 0, 1, -headerHeight)
		local spread = body.AbsoluteSize.X >= 800
		browser.Visible = spread or not inspected
		browser.Size = if spread then UDim2.new(0.5, -12, 1, 0) else UDim2.fromScale(1, 1)
		seam.Visible = spread
		details.root.Visible = spread or inspected
		details.root.Position = if spread then UDim2.new(0.5, 12, 0, 0) else UDim2.fromOffset(0, 0)
		details.root.Size = if spread then UDim2.new(0.5, -12, 1, 0) else UDim2.fromScale(1, 1)
		details.back.Visible = inspected
		local columns, width = State.grid(grid.AbsoluteSize.X, 112, 3)
		layout.FillDirectionMaxCells = columns
		layout.CellSize = UDim2.fromOffset(
			width,
			if short then 136 elseif body.AbsoluteSize.Y < 380 then 164 else 202
		)
		title.TextSize = if short then 17 elseif browser.AbsoluteSize.X < 350 then 23 else 28
		root:SetAttribute("Spread", spread)
	end
	local painted = ""
	local function update(snapshot: Types.Snapshot)
		local definition = Catalog.collections[index]
		local style = Style.get(definition.id)
		if painted ~= definition.id then
			painted = definition.id
			art.set(definition.id)
			cover.BackgroundColor3 = style.cover
			edge.BackgroundColor3 = style.page
			title.TextColor3 = style.ink
			count.TextColor3 = style.ink
			grid.ScrollBarImageColor3 = style.accent
			fold.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, style.page),
				ColorSequenceKeypoint.new(0.48, style.cover:Lerp(style.page, 0.5)),
				ColorSequenceKeypoint.new(1, style.page),
			})
		end
		local found, total = State.completion(snapshot, definition.id)
		title.Text = definition.name
		count.Text = string.format(
			"%d / %d discovered%s",
			found,
			total,
			if found == total then " - Complete" else ""
		)
		for order, action in tabActions do
			action.set(Catalog.collections[order].name, true, order == index)
		end
		local visible = 0
		for id, card in cards do
			card.update(snapshot)
			card.root.Visible = State.matches(snapshot, id, definition.id, ownedOnly)
			if card.root.Visible then
				visible += 1
			end
		end
		empty.Visible = visible == 0
		if filter then
			filter.set(if ownedOnly then "Owned only" else "All figures", true, ownedOnly)
		end
		root:SetAttribute("CollectionId", definition.id)
		root:SetAttribute("OwnedOnly", ownedOnly)
		details.update(snapshot)
	end
	refresh = function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	ctx.scope.connect(body:GetPropertyChangedSignal("AbsoluteSize"), resize)
	ctx.scope.connect(grid:GetPropertyChangedSignal("AbsoluteSize"), resize)
	details.show(firstFigure(), false)
	resize()
	return {
		root = root,
		update = update,
		back = function(): boolean
			if not inspected then
				return false
			end
			closeDetail()
			return true
		end,
		showBook = function(owned: boolean?)
			if owned ~= nil then
				ownedOnly = owned
			end
			local snapshot = ctx.snapshot()
			if owned and snapshot then
				index = State.ownedCollection(snapshot, index)
			end
			selectCollection(index)
		end,
		inspect = function(id: string)
			inspected = true
			details.show(id)
			resize()
		end,
		selectAcquired = function(id: string)
			for newIndex, definition in Catalog.collections do
				if definition.id == Catalog.byId[id].collection then
					index = newIndex
				end
			end
			ownedOnly = false
			inspected = true
			details.show(id, false)
			refresh()
			resize()
		end,
	}
end
return Collection

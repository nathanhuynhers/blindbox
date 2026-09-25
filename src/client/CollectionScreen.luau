--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local State = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Card = require(script.Parent.FigureCard)
local Details = require(script.Parent.FigureDetails)
local Collection = {}
type ReturnCard = { root: TextButton, update: (Types.Snapshot) -> () }
function Collection.create(parent: Instance, ctx: Context.Context)
	local root = W.frame(parent, "Collection")
	local browser = W.frame(root, "Book")
	local header = W.frame(browser, "BookHeader")
	local index, ownedOnly = 1, false
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "FigureGrid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Theme.primary
	grid.SelectionGroup = true
	grid.Parent = browser
	local layout = W.grid(grid, ctx.scope, 126, 3, 200)
	local title = W.title(header, "", 28)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local count = W.label(header, "", 22, 14)
	count.TextXAlignment = Enum.TextXAlignment.Center
	local progressRoot = W.frame(header, "BookProgress")
	local progress = W.progress(progressRoot)
	local cards: { [string]: ReturnCard } = {}
	local update: (Types.Snapshot) -> () = function() end
	local function refresh()
		grid.CanvasPosition = Vector2.zero
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end
	local previous = W.action(header, "<", ctx.scope, ctx.effects, function()
		index = (index - 2) % #Catalog.collections + 1
		refresh()
	end, true)
	local nextButton = W.action(header, ">", ctx.scope, ctx.effects, function()
		index = index % #Catalog.collections + 1
		refresh()
	end, true)
	local filter: W.Action? = nil
	filter = W.action(header, "All figures", ctx.scope, ctx.effects, function()
		ownedOnly = not ownedOnly
		refresh()
	end, true)
	local empty = W.label(browser, "No figures here yet. Find your first box in Shop.", 74, 17)
	empty.Visible = false
	empty.Position = UDim2.fromOffset(20, 130)
	empty.Size = UDim2.new(1, -40, 0, 74)
	local details = Details.create(root, ctx, function()
		browser.Visible = true
	end)
	ctx.scope.connect(details.back.Activated, function()
		details.root.Visible = false
		W.focus(previous.button)
	end)
	for order, figure in Catalog.figures do
		local card = Card.create(grid, figure.id, ctx)
		card.root.LayoutOrder = order
		card.root.Visible = figure.collection == Catalog.collections[index].id
		cards[figure.id] = card
	end
	local function resize()
		local compact = root.AbsoluteSize.Y < 320 and root.AbsoluteSize.X > 340
		header.Size = UDim2.new(1, 0, 0, if compact then 52 else 100)
		previous.button.Size = UDim2.fromOffset(44, 44)
		previous.button.Position = UDim2.fromOffset(12, 0)
		nextButton.button.Size = UDim2.fromOffset(44, 44)
		nextButton.button.Position = UDim2.new(1, -56, 0, 0)
		title.Position = UDim2.fromOffset(60, 0)
		title.Size = UDim2.new(1, if compact then -224 else -120, 0, 26)
		title.TextSize = if compact then 18 else 23
		count.Position = UDim2.fromOffset(60, 26)
		count.Size = title.Size
		count.Size = UDim2.new(count.Size.X.Scale, count.Size.X.Offset, 0, 20)
		local filterAction = filter
		if filterAction then
			filterAction.button.Size = UDim2.fromOffset(104, 44)
			filterAction.button.Position = if compact
				then UDim2.new(1, -164, 0, 0)
				else UDim2.new(1, -116, 0, 50)
		end
		progressRoot.Visible = not compact
		progressRoot.Position = UDim2.fromOffset(12, 66)
		progressRoot.Size = UDim2.new(1, -144, 0, 10)
		grid.Position = UDim2.fromOffset(0, if compact then 52 else 100)
		grid.Size = UDim2.new(1, 0, 1, if compact then -52 else -100)
		local columns, width = State.grid(grid.AbsoluteSize.X, 126, 3)
		layout.FillDirectionMaxCells = columns
		layout.CellSize = UDim2.fromOffset(width, if compact then 158 else 200)
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	ctx.scope.connect(grid:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	update = function(snapshot: Types.Snapshot)
		local collection = Catalog.collections[index]
		local found, total = State.completion(snapshot, collection.id)
		title.Text = collection.name
		count.Text = string.format(
			"%d / %d discovered%s",
			found,
			total,
			if found == total then "  ·  Complete!" else ""
		)
		progress(found, total)
		local visible = 0
		for id, card in cards do
			card.update(snapshot)
			card.root.Visible = State.matches(snapshot, id, collection.id, ownedOnly)
			if card.root.Visible then
				visible += 1
			end
		end
		empty.Visible = visible == 0
		if filter then
			filter.set(if ownedOnly then "Owned only" else "All figures", true, ownedOnly)
		end
		root:SetAttribute("CollectionId", collection.id)
		root:SetAttribute("OwnedOnly", ownedOnly)
		details.update(snapshot)
	end
	return {
		root = root,
		update = update,
		back = function(): boolean
			if not details.root.Visible then
				return false
			end
			details.root.Visible = false
			browser.Visible = true
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
			browser.Visible = true
			details.root.Visible = false
			refresh()
		end,
		inspect = function(id: string)
			browser.Visible = false
			details.show(id)
		end,
		selectAcquired = function(id: string)
			for newIndex, collection in Catalog.collections do
				if collection.id == Catalog.byId[id].collection then
					index = newIndex
				end
			end
			ownedOnly = false
			refresh()
			details.show(id)
			browser.Visible = false
		end,
	}
end
return Collection

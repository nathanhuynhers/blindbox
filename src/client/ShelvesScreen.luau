--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Context = require(script.Parent.UIContext)
local Style = require(script.Parent.SystemStyle)
local Layout = require(script.Parent.SystemLayout)
local State = require(script.Parent.SystemState)
local W = require(script.Parent.Widgets)
local Card = require(script.Parent.ShelfFigureCard)
local Shelves = {}
function Shelves.create(parent: Instance, ctx: Context.Context): Context.Screen
	local shell = Style.shell(parent, "Shelves", ctx)
	local root, content = shell.root, shell.content
	Style.header(
		content,
		"My Shelves",
		"Made to be seen. Arrange the figures you have discovered.",
		"Shelves"
	)
	local selected, selectedShelfId, pickerPage = 1, "", 1
	local slotIds = Config.slots()
	local refresh: () -> () = function() end
	local navigation = W.frame(content, "ShelfNavigation")
	local previous = Style.action(navigation, "\u{2039}", ctx, function()
		ctx.send("ShelfPrevious", nil, nil, nil)
	end, true)
	local following = Style.action(navigation, "\u{203A}", ctx, function()
		ctx.send("ShelfNext", nil, nil, nil)
	end, true)
	previous.button.Name, following.button.Name = "PreviousShelves", "NextShelves"
	previous.button.TextSize, following.button.TextSize = 28, 28
	local units: { W.Action } = {}
	for position = 1, Config.visibleShelfUnits do
		units[position] = Style.action(navigation, "Shelf " .. position, ctx, function()
			local snapshot = ctx.snapshot()
			local unit = if snapshot then snapshot.shelves.visible[position] else nil
			if unit then
				selectedShelfId = unit.id
				refresh()
			end
		end, true)
	end
	local status = Style.text(content, "VisibleShelves", "Loading your shelves...", 13)
	Style.rect(status, 0, 150, 300, 22)
	local cabinet = Style.panel(content, "SelectedShelf", Style.oak, 18)
	local inset = Style.panel(cabinet, "Recess", Style.inset, 12)
	inset.Position = UDim2.fromOffset(9, 9)
	inset.Size = UDim2.new(1, -18, 1, -18)
	W.gradient(inset, Style.card, Style.inset, 90)
	local shelfTitle = Style.text(cabinet, "ShelfTitle", "Your shelf", 19, true)
	W.inset(shelfTitle, 8, 32)
	local boards: { Frame } = {}
	for row = 1, Config.rowsPerShelfUnit do
		local board = Style.panel(cabinet, "ShelfBoard" .. row, Style.oak, 3)
		local light = W.frame(board, "WarmLight", Style.gold)
		light.Position = UDim2.fromOffset(4, 0)
		light.Size = UDim2.new(1, -8, 0, 3)
		boards[row] = board
	end
	local slots = {}
	for index, slotId in slotIds do
		local card = Card.create(cabinet, ctx, slotId, function()
			selected = index
			refresh()
		end)
		card.root:SetAttribute("ShelfSlotId", slotId)
		slots[index] = card
	end
	local editor = Style.panel(content, "ArrangementTools", Style.card)
	local selection = Style.text(editor, "SelectedPosition", "Choose a shelf position", 16, true)
	W.inset(selection, 10, 46)
	local selectedName = Style.text(editor, "CurrentFigure", "An empty space for a favorite", 14)
	selectedName.Position = UDim2.fromOffset(12, 60)
	selectedName.Size = UDim2.new(1, -112, 0, 40)
	local remove = Style.action(editor, "Remove", ctx, function()
		ctx.send("ShelfRemove", nil, selected, selectedShelfId)
	end, true)
	remove.button:SetAttribute("Quiet", true)
	remove.button.Position = UDim2.new(1, -92, 0, 58)
	remove.button.Size = UDim2.fromOffset(80, 44)
	local heading = Style.text(editor, "PickerTitle", "Choose a discovered figure", 15, true)
	W.inset(heading, 112, 36)
	local pickerIds: { string } = {}
	local picks = {}
	for index = 1, 6 do
		picks[index] = Card.create(editor, ctx, "FigureChoice" .. index, function()
			local id = pickerIds[index]
			if id then
				ctx.send("ShelfPlace", id, selected, selectedShelfId)
			end
		end)
		picks[index].root.Visible = false
	end
	local empty = Style.text(
		editor,
		"NoDiscoveries",
		"Your first discovery belongs here.\nOpen a box to start arranging.",
		17,
		true
	)
	W.inset(empty, 174, 94)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.Visible = false
	local shop = Style.action(editor, "Explore Shop", ctx, function()
		ctx.navigate("Shop")
	end)
	W.inset(shop.button, 286, 48)
	shop.button.Visible = false
	local pageBack = Style.action(editor, "\u{2039}", ctx, function()
		pickerPage -= 1
		refresh()
	end, true)
	local pageNext = Style.action(editor, "\u{203A}", ctx, function()
		pickerPage += 1
		refresh()
	end, true)
	pageBack.button.Name, pageNext.button.Name = "PreviousFigures", "NextFigures"
	local pageStatus = Style.text(editor, "PickerPage", "", 13)
	pageStatus.TextXAlignment = Enum.TextXAlignment.Center
	local note =
		Style.text(cabinet, "CosmeticNote", "For everyone to see. No effect on income.", 12)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.Position = UDim2.new(0, 12, 1, -30)
	note.Size = UDim2.new(1, -24, 0, 26)
	local function resize()
		local width = shell.width()
		local g = Layout.shelves(width, Config.rowsPerShelfUnit, Config.slotsPerRow)
		Style.rect(navigation, 0, 100, width, 48)
		Style.rect(previous.button, 0, 0, 44, 48)
		Style.rect(following.button, width - 44, 0, 44, 48)
		local unitWidth = (width - 100) / Config.visibleShelfUnits
		for index, action in units do
			Style.rect(action.button, 50 + (index - 1) * unitWidth, 0, unitWidth - 4, 48)
		end
		status.Size = UDim2.fromOffset(width, 22)
		Style.rect(cabinet, 0, 176, g.shelfWidth, g.shelfHeight)
		for row, board in boards do
			Style.rect(board, 12, 42 + row * (g.slotHeight + 18) - 10, g.shelfWidth - 24, 10)
		end
		for index, card in slots do
			local row, column = Config.parseSlot(slotIds[index])
			assert(row and column, "Configured shelf slot must have a row and position")
			Style.rect(
				card.root,
				20 + (column - 1) * (g.slotWidth + 8),
				42 + (row - 1) * (g.slotHeight + 18),
				g.slotWidth,
				g.slotHeight
			)
		end
		Style.rect(editor, g.pickerX, g.pickerY, g.pickerWidth, g.pickerHeight)
		for index, card in picks do
			Style.rect(
				card.root,
				12 + (index - 1) % g.columns * (g.cell + 12),
				162 + math.floor((index - 1) / g.columns) * 144,
				g.cell,
				132
			)
		end
		Style.rect(pageBack.button, 12, g.pickerHeight - 52, 44, 44)
		Style.rect(pageNext.button, g.pickerWidth - 56, g.pickerHeight - 52, 44, 44)
		Style.rect(pageStatus, 64, g.pickerHeight - 52, g.pickerWidth - 128, 44)
		shell.fit(g.height)
	end
	local function update(snapshot: Types.Snapshot)
		local unit = State.shelf(snapshot, selectedShelfId)
		if not unit then
			return
		end
		selectedShelfId = unit.id
		root:SetAttribute("SelectedShelfId", unit.id)
		root:SetAttribute("SelectedSlotId", slotIds[selected])
		local indices: { string } = {}
		for position, action in units do
			local visible = snapshot.shelves.visible[position]
			action.button.Visible = visible ~= nil
			if visible then
				table.insert(indices, tostring(visible.index))
				action.set("Shelf " .. visible.index, true, visible.id == unit.id)
			end
		end
		status.Text = "Viewing "
			.. table.concat(indices, ", ")
			.. " of "
			.. snapshot.shelves.ownedCount
			.. " shelves"
		shelfTitle.Text = "Shelf " .. unit.index .. "  /  Your arrangement"
		previous.set("\u{2039}", ctx.canAct() and snapshot.shelves.canNavigate)
		following.set("\u{203A}", ctx.canAct() and snapshot.shelves.canNavigate)
		for index, card in slots do
			card.set(unit.placements[slotIds[index]], index == selected, true)
		end
		local row, column = Config.parseSlot(slotIds[selected])
		selection.Text =
			string.format("Shelf %d  /  Row %d, position %d", unit.index, row or 1, column or 1)
		local current = unit.placements[slotIds[selected]]
		selectedName.Text = if current
			then Catalog.byId[current].name
			else "An empty space for a favorite"
		remove.set("Remove", ctx.canAct() and current ~= nil)
		local ids = State.discovered(snapshot)
		local pages: number
		pickerIds, pickerPage, pages = State.picker(ids, pickerPage, #picks)
		for index, card in picks do
			local id = pickerIds[index]
			card.root.Visible = id ~= nil
			card.set(id, id ~= nil and id == current, ctx.canAct() and id ~= nil)
		end
		empty.Visible, shop.button.Visible = #ids == 0, #ids == 0
		pageStatus.Text = string.format("%d / %d\n%d discovered", pickerPage, pages, #ids)
		pageBack.set("\u{2039}", pickerPage > 1)
		pageNext.set("\u{203A}", pickerPage < pages)
	end
	refresh = function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	return { root = root, update = update }
end
return Shelves

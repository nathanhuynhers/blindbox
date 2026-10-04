--!strict
-- Shelves: shelf tabs + prev/next, a 3x3 wooden cabinet of selectable spots, and a picker of
-- owned figures with collection filter chips. Shelf placements are cosmetic but use owned copies.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Button = require(script.Parent.UIButton)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Shell = require(script.Parent.ScreenShell)
local Tile = require(script.Parent.FigureTile)
local Preview = require(script.Parent.UIPreview)
local Shelves = {}

type Spot = {
	button: TextButton,
	stroke: UIStroke,
	preview: Preview.Preview,
	add: TextLabel,
}

local rowNames = { "Top shelf", "Middle shelf", "Bottom shelf" }
local spotNames = { "left", "middle", "right" }

local function arrow(
	parent: Instance,
	name: string,
	ctx: Context.Context,
	callback: () -> ()
): Button.Button
	local button = Button.create(parent, name, {
		variant = "white",
		text = "",
		size = 14,
		radius = 14,
		drop = 0,
		outline = Style.outlineSmall,
	}, ctx.scope, ctx.effects, callback)
	local icon = Icons.create(
		button.face,
		if name == "PreviousShelves" then "Left" else "Right",
		Style.ink,
		18
	)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	button.button:SetAttribute(
		"AccessibleName",
		if name == "PreviousShelves" then "Previous shelf" else "Next shelf"
	)
	return button
end

function Shelves.create(parent: Instance, ctx: Context.Context): Context.Screen
	local shell = Shell.create(parent, ctx, {
		id = "Shelves",
		title = "Shelves",
		subtitle = "Arrange the figures you own. Shelf figures are cosmetic and earn no Coins.",
	})
	local root, body = shell.root, shell.body
	local slotIds = Config.slots()
	local selectedShelf, selectedSpot = "", 1
	local filter: string? = nil
	local refresh: () -> () = function() end
	local left = Kit.frame(body, "ShelfSide")
	local previous = arrow(left, "PreviousShelves", ctx, function()
		ctx.send("ShelfPrevious", nil, nil, nil)
	end)
	local following = arrow(left, "NextShelves", ctx, function()
		ctx.send("ShelfNext", nil, nil, nil)
	end)
	local tabs: { Button.Button } = {}
	for position = 1, Config.visibleShelfUnits do
		tabs[position] = Button.create(
			left,
			"Shelf" .. position,
			{
				variant = "white",
				text = "Shelf " .. position,
				size = 15,
				radius = 14,
				drop = 0,
				outline = Style.outlineSmall,
				font = Style.body(Enum.FontWeight.ExtraBold),
			},
			ctx.scope,
			ctx.effects,
			function()
				local snapshot = ctx.snapshot()
				local unit = if snapshot then snapshot.shelves.visible[position] else nil
				if unit then
					selectedShelf = unit.id
					refresh()
				end
			end
		)
	end
	-- Header action: buy the next Shelf Unit. Hidden at the cap; disabled while unaffordable.
	local buy = Button.create(
		shell.chips,
		"BuyShelf",
		{
			variant = "gold",
			text = "",
			size = 14,
			radius = 14,
			drop = 0,
			outline = Style.outlineSmall,
			icon = "Plus",
			font = Style.body(Enum.FontWeight.ExtraBold),
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.send("BuyShelf", nil, nil, nil)
		end
	)
	buy.button.Size = UDim2.fromOffset(190, 44)
	local cabinet = Kit.frame(left, "Cabinet", Style.wood)
	Kit.corner(cabinet, 20)
	Kit.stroke(cabinet, Style.woodDark, 4)
	local boards: { Frame } = {}
	local lips: { Frame } = {}
	for row = 1, Config.rowsPerShelfUnit do
		local board = Kit.frame(cabinet, "Row" .. row, Style.woodInner)
		Kit.corner(board, 10)
		local lip = Kit.frame(cabinet, "Lip" .. row, Style.woodLip)
		Kit.corner(lip, 6)
		Kit.stroke(lip, Style.woodDark, 2)
		boards[row], lips[row] = board, lip
	end
	local spots: { Spot } = {}
	for index, slotId in slotIds do
		local spot = Instance.new("TextButton")
		spot.Name = "Spot" .. index
		spot.Text = ""
		spot.AutoButtonColor = false
		spot.BackgroundColor3 = Style.woodSpot
		spot.Parent = cabinet
		spot:SetAttribute("ShelfSlotId", slotId)
		spot.ZIndex = 3
		Kit.corner(spot, 12)
		local stroke = Kit.stroke(spot, Style.woodDash)
		local preview = Preview.create(spot, ctx.scope, true)
		local add = Kit.text(spot, "Add", "+ Add", 13, nil, Style.woodDark)
		add.Size = UDim2.fromScale(1, 1)
		add.TextXAlignment = Enum.TextXAlignment.Center
		ctx.scope.connect(spot.Activated, function()
			selectedSpot = index
			refresh()
		end)
		spots[index] = { button = spot, stroke = stroke, preview = preview, add = add }
	end
	-- Picker side
	local side = Kit.column(body, "Picker", Style.surface2, "right", 28)
	local spotLabel =
		Kit.text(side, "SpotLabel", "", 12, Style.body(Enum.FontWeight.Heavy), Style.muted)
	local spotTitle = Kit.text(side, "SpotTitle", "", 22, Style.display())
	local clear = Button.create(
		side,
		"ClearSpot",
		{
			variant = "white",
			text = "Clear spot",
			size = 14,
			radius = 14,
			drop = 0,
			outline = Style.outlineSmall,
			font = Style.body(Enum.FontWeight.ExtraBold),
		},
		ctx.scope,
		ctx.effects,
		function()
			local index = selectedSpot
			if selectedShelf ~= "" then
				ctx.send("ShelfRemove", nil, index, selectedShelf)
			end
		end
	)
	local chipRow = Kit.frame(side, "Filters")
	chipRow.ClipsDescendants = true
	local chipScroll = Instance.new("ScrollingFrame")
	chipScroll.Name = "FilterChips"
	chipScroll.BackgroundTransparency = 1
	chipScroll.BorderSizePixel = 0
	chipScroll.Size = UDim2.fromScale(1, 1)
	chipScroll.ScrollingDirection = Enum.ScrollingDirection.X
	chipScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	chipScroll.CanvasSize = UDim2.fromOffset(0, 0)
	chipScroll.ScrollBarThickness = 0
	chipScroll.Parent = chipRow
	Kit.padding(chipScroll, 4, 4, 4, 4)
	Kit.list(chipScroll, Enum.FillDirection.Horizontal, 6, Enum.VerticalAlignment.Center)
	local chips: { [string]: Button.Button } = {}
	local function chip(id: string, order: number)
		local button = Button.create(
			chipScroll,
			"Filter_" .. id,
			{
				variant = "white",
				text = "",
				size = 13,
				radius = 17,
				drop = 0,
				outline = Style.outlineSmall,
				font = Style.body(Enum.FontWeight.ExtraBold),
			},
			ctx.scope,
			ctx.effects,
			function()
				filter = if id == "all" then nil else id
				refresh()
			end
		)
		button.button.LayoutOrder = order
		chips[id] = button
	end
	chip("all", 0)
	for index, collection in Catalog.collections do
		chip(collection.id, index)
	end
	local gridLayout = Kit.grid(side, 8)
	local grid = Kit.scroll(side, "Figures", ctx.scope, gridLayout, 5, ctx.scale)
	local picks: { Tile.Tile } = {}
	local empty = Kit.text(
		side,
		"NoDiscoveries",
		"Open boxes to get figures for your Shelves.",
		16,
		nil,
		Style.muted
	)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.TextWrapped = true
	local shop = Button.create(
		side,
		"ExploreShop",
		{
			variant = "gold",
			text = "Explore the Shop",
			size = 17,
			radius = 14,
			drop = 3,
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.navigate("Shop")
		end
	)
	local width, height, phone = 0, 0, false
	local cell, cellHeight = 90, 112
	local function pick(index: number): Tile.Tile
		local existing = picks[index]
		if existing then
			return existing
		end
		-- Grows to the largest filter shown (bounded by the catalog) and is reused after.
		local created = Tile.create(grid, ctx, "shelf", function(id)
			if selectedShelf ~= "" then
				ctx.send("ShelfPlace", id, selectedSpot, selectedShelf)
			end
		end)
		created.button.LayoutOrder = index
		created.size(cell, cellHeight)
		picks[index] = created
		return created
	end
	local function arrange()
		local leftWidth = if phone
			then math.floor(width * 0.48)
			else math.min(560, math.floor(width * 0.5))
		Kit.rect(left, 0, 0, leftWidth, height)
		Kit.rect(side, leftWidth, 0, width - leftWidth, height)
		local pad = if phone then 12 else 20
		local inner = leftWidth - pad * 2
		Kit.rect(previous.button, pad, 14, 44, 44)
		Kit.rect(following.button, pad + inner - 44, 14, 44, 44)
		local tabWidth = State.cells(inner - 104, Config.visibleShelfUnits, 6)
		for index, tab in tabs do
			Kit.rect(tab.button, pad + 52 + (index - 1) * (tabWidth + 6), 14, tabWidth, 44)
		end
		local cabinetY = 68
		local cabinetHeight = math.max(if phone then 228 else 300, height - cabinetY - 16)
		Kit.rect(cabinet, pad, cabinetY, inner, cabinetHeight)
		local rowGap = 8
		local rowHeight = math.floor((cabinetHeight - 20 - rowGap * 2) / 3)
		local spotWidth = State.cells(inner - 20 - 16, 3, 8)
		local spotHeight = rowHeight - 12 - 4
		for row = 1, Config.rowsPerShelfUnit do
			local y = 10 + (row - 1) * (rowHeight + rowGap)
			Kit.rect(boards[row], 10, y, inner - 20, rowHeight - 12)
			Kit.rect(lips[row], 10, y + rowHeight - 12, inner - 20, 12)
		end
		for index, slotId in slotIds do
			local row, column = Config.parseSlot(slotId)
			if row and column then
				local y = 10 + (row - 1) * (rowHeight + rowGap) + 4
				Kit.rect(
					spots[index].button,
					18 + (column - 1) * (spotWidth + 8),
					y,
					spotWidth,
					spotHeight
				)
			end
		end
		local sideWidth = width - leftWidth
		local spad = if phone then 12 else 20
		local sinner = sideWidth - spad * 2
		Kit.rect(spotLabel, spad, 14, sinner - 130, 16)
		Kit.rect(spotTitle, spad, 32, sinner - 130, 28)
		spotTitle.TextSize = if phone then 17 else 22
		Kit.rect(clear.button, spad + sinner - 120, 14, 120, 44)
		Kit.rect(chipRow, spad - 4, 64, sinner + 8, 52)
		for _, button in chips do
			button.button.Size = UDim2.fromOffset(0, 44)
		end
		Kit.rect(grid, spad - 2, 122, sinner + 4, height - 122)
		local columns = if phone then 3 else 5
		cell = State.cells(sinner - 14, columns, 8)
		cellHeight = if phone then 96 else 112
		gridLayout.CellSize = UDim2.fromOffset(cell, cellHeight)
		for _, item in picks do
			item.size(cell, cellHeight)
		end
		Kit.rect(empty, spad, 140, sinner, 48)
		shop.button.AnchorPoint = Vector2.new(0.5, 0)
		shop.button.Position = UDim2.new(0.5, 0, 0, 196)
		shop.button.Size = UDim2.fromOffset(220, 50)
	end
	local function update(snapshot: Types.Snapshot)
		shell.update(snapshot)
		local view = snapshot.shelves
		local unit: Types.VisibleShelf? = nil
		for _, visible in view.visible do
			if visible.id == selectedShelf then
				unit = visible
			end
		end
		unit = unit or view.visible[1]
		selectedShelf = if unit then unit.id else ""
		root:SetAttribute("SelectedShelfId", selectedShelf)
		root:SetAttribute("SelectedSlotId", slotIds[selectedSpot])
		local canAct = ctx.canAct() and unit ~= nil
		for position, tab in tabs do
			local visible = view.visible[position]
			tab.button.Visible = visible ~= nil
			if visible then
				tab.set("Shelf " .. visible.index, true)
				tab.variant(if unit and visible.id == unit.id then "selected" else "white")
				tab.button:SetAttribute("Selected", unit ~= nil and visible.id == unit.id)
			end
		end
		local price = snapshot.shelfPrice
		buy.button.Visible = price > 0
		buy.set("Buy Shelf · " .. State.compact(price), ctx.canAct() and snapshot.coins >= price)
		buy.button:SetAttribute(
			"AccessibleName",
			"Buy Shelf for " .. State.number(price) .. " Coins"
		)
		-- Prev/next only page beyond three owned shelves.
		previous.set("", ctx.canAct() and view.canNavigate)
		following.set("", ctx.canAct() and view.canNavigate)
		local placements = if unit then unit.placements else {}
		for index, spot in spots do
			local placed = placements[slotIds[index]]
			local on = index == selectedSpot
			spot.preview.figure(placed, true)
			spot.add.Visible = placed == nil
			spot.button.BackgroundColor3 = if on
				then Style.violetWash
				elseif placed then Style.woodSpot
				else Style.woodInner
			spot.stroke.Color = if on
				then Style.violet
				elseif placed then Style.woodSpot
				else Style.woodDash
			spot.button:SetAttribute("Selected", on)
			local row, column = Config.parseSlot(slotIds[index])
			spot.button:SetAttribute(
				"AccessibleName",
				string.format(
					"%s, %s: %s",
					rowNames[row or 1] or "Shelf",
					spotNames[column or 1] or "spot",
					if placed then Catalog.byId[placed].name else "empty"
				)
			)
		end
		local current = placements[slotIds[selectedSpot]]
		local row, column = Config.parseSlot(slotIds[selectedSpot])
		spotLabel.Text = string.upper(
			(rowNames[row or 1] or "Shelf") .. " · " .. (spotNames[column or 1] or "") .. " spot"
		)
		spotTitle.Text = if current
			then Catalog.byId[current].name .. " is here. Tap a figure to swap"
			else "Tap a figure to place it"
		clear.button.Visible = current ~= nil
		clear.set("Clear spot", canAct)
		local owned: { string } = {}
		local counts: { [string]: number } = {}
		for _, figure in Catalog.figures do
			if (snapshot.owned[figure.id] or 0) > 0 then
				counts[figure.collection] = (counts[figure.collection] or 0) + 1
				if filter == nil or figure.collection == filter then
					table.insert(owned, figure.id)
				end
			end
		end
		local total = 0
		for _, count in counts do
			total += count
		end
		if filter and not counts[filter] then
			filter = nil
			refresh()
			return
		end
		for id, button in chips do
			local count = if id == "all" then total else counts[id] or 0
			button.button.Visible = id == "all" or count > 0
			button.set(if id == "all" then "All " .. total else State.collectionName(id), true)
			button.button.Size = UDim2.fromOffset(math.max(64, #button.label.Text * 8 + 30), 44)
			local on = (id == "all" and filter == nil) or id == filter
			button.variant(if on then "selected" else "white")
			button.button:SetAttribute("Selected", on)
		end
		for index = 1, math.max(#owned, #picks) do
			local id = owned[index]
			if id then
				pick(index).set(id, {
					discovered = true,
					selected = id == current,
					count = snapshot.owned[id] or 0,
					enabled = canAct and State.shelfAvailable(snapshot, id) > 0,
				})
			elseif picks[index] then
				picks[index].set(nil, { discovered = false })
			end
		end
		empty.Visible = total == 0
		chipRow.Visible = total > 0
		shop.button.Visible = total == 0
		grid.Visible = total > 0
	end
	refresh = function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end
	return {
		root = root,
		update = update,
		layout = function(nextWidth: number, nextHeight: number, nextPhone: boolean)
			phone = nextPhone
			width, height = shell.layout(nextWidth, nextHeight, nextPhone)
			arrange()
			refresh()
		end,
	}
end

return Shelves

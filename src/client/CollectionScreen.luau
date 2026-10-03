--!strict
-- Collection: collection list | All/Found/Missing chips + figure grid | detail panel.
-- Replaces the physical book. Arriving from a Display slot picker places into that slot.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local Badge = require(script.Parent.UIBadge)
local State = require(script.Parent.UIState)
local Layout = require(script.Parent.UILayout)
local Context = require(script.Parent.UIContext)
local Shell = require(script.Parent.ScreenShell)
local List = require(script.Parent.CollectionList)
local Tile = require(script.Parent.FigureTile)
local Preview = require(script.Parent.UIPreview)
local Collection = {}

local largest = 0
for _, collection in Catalog.collections do
	largest = math.max(largest, #State.members(collection.id))
end

type Stat = { root: Frame, label: TextLabel, value: TextLabel }

function Collection.create(parent: Instance, ctx: Context.Context): Context.Screen
	local shell = Shell.create(parent, ctx, {
		id = "Collection",
		title = "Collection",
		subtitle = "",
		coins = false,
	})
	local root, body = shell.root, shell.body
	local selected = Catalog.collections[1].id
	local figure: string? = nil
	local filter: State.Filter = "all"
	local targetSlot: number? = nil
	local refresh: () -> () = function() end
	local list = List.create(body, ctx, function(id)
		if id ~= selected then
			selected, figure, filter = id, nil, "all"
		end
		refresh()
	end)
	-- Filter chips live in the middle pane on desktop and in the header on phone.
	local chips = Kit.frame(body, "Filters")
	local chipList =
		Kit.list(chips, Enum.FillDirection.Horizontal, 8, Enum.VerticalAlignment.Center)
	chipList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local filters: { [State.Filter]: Button.Button } = {}
	local order: { State.Filter } = { "all", "found", "missing" }
	for index, id in order do
		local chip = Button.create(
			chips,
			"Filter_" .. id,
			{
				variant = "white",
				text = id,
				size = 14,
				radius = 20,
				drop = 0,
				outline = Style.outlineSmall,
				font = Style.body(Enum.FontWeight.ExtraBold),
			},
			ctx.scope,
			ctx.effects,
			function()
				filter = id
				figure = nil
				refresh()
			end
		)
		chip.button.LayoutOrder = index
		filters[id] = chip
	end
	local gridLayout = Kit.grid(body, 10)
	local grid = Kit.scroll(body, "FigureGrid", ctx.scope, gridLayout, 5, ctx.scale)
	local cards: { Tile.Tile } = {}
	for index = 1, largest do
		local card = Tile.create(grid, ctx, "card", function(id)
			figure = id
			refresh()
		end)
		card.button.LayoutOrder = index
		cards[index] = card
	end
	-- Detail
	local detail = Kit.frame(body, "FigureDetails")
	local rarityBar = Kit.frame(detail, "RarityBar", Style.track)
	Kit.corner(rarityBar, 18)
	local well = Kit.frame(rarityBar, "Portrait", Style.disabledFill)
	well.ClipsDescendants = true
	Kit.corner(well, 18)
	local portrait = Preview.create(well, ctx.scope, true)
	local unknown = Kit.text(well, "Unknown", "?", 72, Style.display(), Style.unknownInk)
	unknown.Size = UDim2.fromScale(1, 1)
	unknown.TextXAlignment = Enum.TextXAlignment.Center
	local name = Kit.text(detail, "FigureName", "", 26, Style.display())
	name.AutomaticSize = Enum.AutomaticSize.X
	name.TextTruncate = Enum.TextTruncate.None
	local pill = Badge.rarity(detail, 26, 12)
	local stats: { Stat } = {}
	for index, label in { "Earns", "You own", "Box chance" } do
		local box = Kit.frame(detail, "Stat" .. index, Style.surface2)
		Kit.corner(box, 14)
		local caption = Kit.text(box, "Label", label, 12, nil, Style.muted)
		local value = Kit.text(box, "Value", "", 18, Style.display())
		stats[index] = { root = box, label = caption, value = value }
	end
	stats[1].value.TextColor3 = Style.mintText
	local action = Button.create(
		detail,
		"FigureAction",
		{
			variant = "violet",
			text = "Put on Display",
			size = 21,
			radius = 18,
			drop = 4,
		},
		ctx.scope,
		ctx.effects,
		function()
			local snapshot = ctx.snapshot()
			local id = figure
			if not snapshot or not id then
				return
			end
			if not snapshot.discovered[id] or (snapshot.owned[id] or 0) < 1 then
				ctx.navigate("Shop", { collection = Catalog.byId[id].collection })
			elseif State.displayed(snapshot, id) then
				ctx.navigate("Display")
			elseif targetSlot then
				ctx.send("Place", id, targetSlot, nil)
				targetSlot = nil
				ctx.navigate("Display")
			else
				local empty = State.emptySlots(snapshot)
				if #empty > 0 then
					ctx.send("Place", id, empty[1], nil)
				else
					ctx.navigate("Display", { placing = id })
				end
			end
		end
	)
	local width, height, phone = 0, 0, false
	local cardHeight = 148
	local function arrange()
		local listWidth, middle, side
		if phone then
			listWidth, middle, side = Layout.panes(width, 72, 250, 200)
		else
			listWidth, middle, side = Layout.panes(width, 256, 360, 300)
		end
		list.layout(listWidth, height, phone)
		Kit.rect(list.root, 0, 0, listWidth, height)
		local pad = if phone then 10 else 16
		local columns = if phone then 3 else 4
		cardHeight = if phone then 108 else 148
		if phone then
			chips.Parent = shell.chips
			chips.Size = UDim2.fromOffset(250, 44)
			chips.LayoutOrder = 1
			Kit.rect(grid, listWidth + pad, pad, middle - pad * 2, height - pad)
		else
			chips.Parent = body
			Kit.rect(chips, listWidth + pad, 12, middle - pad * 2, 44)
			Kit.rect(grid, listWidth + pad, 66, middle - pad * 2, height - 66)
		end
		for _, chip in filters do
			chip.button.Size = UDim2.fromOffset(if phone then 76 else 112, 44)
		end
		local cell = State.cells(middle - pad * 2 - 16, columns, if phone then 8 else 10)
		gridLayout.CellPadding = UDim2.fromOffset(if phone then 8 else 10, if phone then 8 else 10)
		gridLayout.CellSize = UDim2.fromOffset(cell, cardHeight)
		for _, card in cards do
			card.size(cell, cardHeight)
		end
		local x = listWidth + middle
		Kit.rect(detail, x, 0, side, height)
		local dpad = if phone then 12 else 18
		local inner = side - dpad * 2
		local wellHeight = if phone then 84 else 150
		local edge = if phone then 5 else 6
		Kit.rect(rarityBar, dpad, if phone then 10 else 16, inner, wellHeight + edge)
		Kit.rect(well, 0, 0, inner, wellHeight)
		local y = (if phone then 10 else 16) + wellHeight + edge + (if phone then 10 else 14)
		name.TextSize = if phone then 19 else 26
		name.Position = UDim2.fromOffset(dpad, y)
		name.Size = UDim2.fromOffset(0, if phone then 24 else 32)
		pill.root.Position = UDim2.fromOffset(dpad, y + (if phone then 28 else 36))
		y += if phone then 56 else 72
		local statWidth = State.cells(inner, 3, if phone then 5 else 8)
		for index, stat in stats do
			Kit.rect(
				stat.root,
				dpad + (index - 1) * (statWidth + (if phone then 5 else 8)),
				y,
				statWidth,
				if phone then 46 else 58
			)
			stat.label.TextSize = if phone then 11 else 12
			stat.value.TextSize = if phone then 15 else 18
			Kit.rect(stat.label, 8, if phone then 4 else 8, statWidth - 12, 16)
			Kit.rect(stat.value, 8, if phone then 20 else 26, statWidth - 12, 22)
		end
		stats[2].label.Text = if phone then "Own" else "You own"
		stats[3].label.Text = if phone then "Chance" else "Box chance"
		y += if phone then 54 else 70
		Kit.rect(action.button, dpad, y, inner, if phone then 48 else 56)
	end
	local function update(snapshot: Types.Snapshot)
		shell.update(snapshot)
		list.update(snapshot, selected)
		root:SetAttribute("CollectionId", selected)
		root:SetAttribute("Filter", filter)
		local foundAll, totalAll = State.totalCompletion(snapshot)
		local found, total = State.completion(snapshot, selected)
		shell.subtitle.Text = string.format("%d of %d figures discovered", foundAll, totalAll)
		shell.title.Text = if phone
			then State.collectionName(selected) .. "  " .. found .. " / " .. total
			else "Collection"
		local counts: { [string]: number } = { all = total, found = found, missing = total - found }
		local labels: { [string]: string } = { all = "All", found = "Found", missing = "Missing" }
		for id, chip in filters do
			chip.set(if phone then labels[id] else labels[id] .. " " .. counts[id], true)
			chip.variant(if id == filter then "selected" else "white")
			chip.button:SetAttribute("Selected", id == filter)
		end
		local ids = State.filtered(snapshot, selected, filter)
		if figure and (not table.find(ids, figure)) then
			figure = nil
		end
		if not figure then
			for _, id in ids do
				if snapshot.discovered[id] then
					figure = id
					break
				end
			end
		end
		figure = figure or ids[1]
		root:SetAttribute("FigureId", figure)
		for index, card in cards do
			local id = ids[index]
			if id then
				local discovered = snapshot.discovered[id] == true
				local owned = snapshot.owned[id] or 0
				card.set(id, {
					discovered = discovered,
					selected = id == figure,
					sub = if discovered
						then State.rate(State.figureRate(snapshot, id))
						else Catalog.byId[id].rarity,
					subColor = if discovered then Style.mintText else Style.muted,
					count = owned,
					onDisplay = State.displayed(snapshot, id),
				})
			else
				card.set(nil, { discovered = false })
			end
		end
		detail.Visible = figure ~= nil
		local id = figure
		if not id then
			return
		end
		local data = Catalog.byId[id]
		local discovered = snapshot.discovered[id] == true
		local accent = Style.collection(data.collection)
		well.BackgroundColor3 = if discovered then accent.wash else Style.disabledFill
		rarityBar.BackgroundColor3 = Style.rarity(data.rarity)
		portrait.figure(if discovered then id else nil, true)
		unknown.Visible = not discovered
		unknown.TextSize = if phone then 40 else 72
		name.Text = if discovered then data.name else "???"
		pill.rarity(data.rarity)
		local owned = snapshot.owned[id] or 0
		stats[1].value.Text = State.amount(State.figureRate(snapshot, id))
			.. (if phone then "/s" else " coins/s")
		stats[2].value.Text = if owned > 0 then "×" .. owned else "None yet"
		stats[3].value.Text = State.percent(State.figureOdds(snapshot, id))
		local displayed = State.displayed(snapshot, id)
		local _, free = State.copies(snapshot, id)
		if displayed then
			action.variant("mint")
			action.label.FontFace = Style.display()
			action.label.TextSize = if phone then 16 else 19
			action.set("On your Display · View", true)
		elseif not discovered or owned < 1 or free < 1 then
			action.variant("white")
			action.label.FontFace = Style.body(Enum.FontWeight.ExtraBold)
			action.label.TextSize = if phone then 14 else 16
			action.set("Find it in " .. State.collectionName(data.collection) .. " boxes", true)
		else
			action.variant("violet")
			action.label.FontFace = Style.display()
			action.label.TextSize = if phone then 17 else 21
			action.set(
				if targetSlot then "Put in slot " .. targetSlot else "Put on Display",
				ctx.canAct()
			)
		end
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
		route = function(route: Context.Route?)
			targetSlot = if route then route.slot else nil
			if route and route.collection and Catalog.collectionIds[route.collection] then
				if route.collection ~= selected then
					selected, filter = route.collection, "all"
				end
			end
			figure = if route then route.figure else figure
			if targetSlot then
				filter = "found"
			end
			refresh()
		end,
	}
end

return Collection

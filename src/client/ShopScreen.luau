--!strict
-- Shop: collection list | 3D box preview + Open / free box | What's inside + Drop odds.
-- Price, odds and free-box options come from UIState projections, never hardcoded.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local State = require(script.Parent.UIState)
local Layout = require(script.Parent.UILayout)
local Context = require(script.Parent.UIContext)
local Shell = require(script.Parent.ScreenShell)
local List = require(script.Parent.CollectionList)
local Tile = require(script.Parent.FigureTile)
local BoxPreview = require(script.Parent.BlindBoxPreview)
local Shop = {}

local largest = 0
for _, collection in Catalog.collections do
	largest = math.max(largest, #State.members(collection.id))
end

type Row = { root: Frame, swatch: Frame, name: TextLabel, count: TextLabel, pct: TextLabel }

function Shop.create(parent: Instance, ctx: Context.Context): Context.Screen
	local shell = Shell.create(parent, ctx, {
		id = "Shop",
		title = "Shop",
		subtitle = "Every box holds one figure from its collection",
	})
	local root, body = shell.root, shell.body
	local selected = Catalog.collections[1].id
	local refresh: () -> () = function() end
	local list = List.create(body, ctx, function(id)
		selected = id
		refresh()
	end)
	-- Middle: product
	local product = Kit.frame(body, "Product")
	local stage = Kit.frame(product, "ProductStage")
	local preview = BoxPreview.create(stage, ctx.scope)
	local boxTitle = Kit.text(product, "BoxTitle", "", 24, Style.display())
	boxTitle.TextXAlignment = Enum.TextXAlignment.Center
	local progress =
		Kit.text(product, "Discovery", "", 14, Style.body(Enum.FontWeight.Bold), Style.muted)
	progress.TextXAlignment = Enum.TextXAlignment.Center
	progress.TextWrapped = true
	local buy = Button.create(
		product,
		"BuyBox",
		{
			variant = "gold",
			text = "Open 1 box",
			size = 24,
			radius = 20,
			drop = 5,
			price = true,
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.send("Buy", nil, nil, selected)
		end
	)
	local freeChoice: string? = nil
	local free = Button.create(
		product,
		"DailyBox",
		{
			variant = "mint",
			text = "Claim today's free box",
			size = 18,
			radius = 18,
			drop = 0,
			icon = "Gift",
		},
		ctx.scope,
		ctx.effects,
		function()
			if freeChoice then
				ctx.send("Daily", nil, nil, freeChoice)
			end
		end
	)
	-- Right: contents and odds
	local info = Kit.canvas(body, "Contents")
	local inside = Kit.text(info, "InsideTitle", "What's inside", 20, Style.display())
	local insideCount = Kit.text(info, "InsideCount", "", 13, nil, Style.muted)
	insideCount.TextXAlignment = Enum.TextXAlignment.Right
	local tiles: { Tile.Tile } = {}
	for index = 1, largest do
		local tile = Tile.create(info, ctx, "tile", function(id)
			ctx.navigate("Collection", { collection = Catalog.byId[id].collection, figure = id })
		end)
		tile.button.LayoutOrder = index
		tiles[index] = tile
	end
	local oddsTitle = Kit.text(info, "OddsTitle", "Drop odds", 20, Style.display())
	local perBox = Kit.text(info, "PerBox", "per box", 13, nil, Style.muted)
	perBox.TextXAlignment = Enum.TextXAlignment.Right
	local stack = Kit.frame(info, "OddsBar", Style.track)
	stack.ClipsDescendants = true
	Kit.corner(stack, 8)
	Kit.stroke(stack, Style.ink, Style.outlineSmall)
	local stackList = Kit.list(stack, Enum.FillDirection.Horizontal, 0)
	stackList.VerticalAlignment = Enum.VerticalAlignment.Center
	local parts: { Frame } = {}
	local rows: { Row } = {}
	for index, rarity in Rarity.order do
		local part = Kit.frame(stack, "Odds" .. rarity, (Style.rarity(rarity)))
		part.LayoutOrder = index
		parts[index] = part
		local row = Kit.frame(info, "OddsRow" .. index)
		local swatch = Kit.frame(row, "Swatch", Style.track)
		Kit.corner(swatch, 4)
		Kit.stroke(swatch, Style.ink, Style.outlineSmall)
		local name = Kit.text(row, "Rarity", "", 14)
		local count =
			Kit.text(row, "Figures", "", 14, Style.body(Enum.FontWeight.Bold), Style.muted)
		local pct = Kit.text(row, "Chance", "", 16, Style.display())
		pct.TextXAlignment = Enum.TextXAlignment.Right
		rows[index] = { root = row, swatch = swatch, name = name, count = count, pct = pct }
	end
	local width, height, phone = 0, 0, false
	local infoWidth = 0
	local function arrange()
		local listWidth, middle, side
		if phone then
			listWidth, middle, side = Layout.panes(width, 72, math.max(220, width - 72 - 264), 220)
		else
			listWidth, middle, side = Layout.panes(width, 256, 404, 300)
		end
		list.layout(listWidth, height, phone)
		Kit.rect(list.root, 0, 0, listWidth, height)
		Kit.rect(product, listWidth, 0, middle, height)
		Kit.rect(info, listWidth + middle, 0, side, height)
		infoWidth = side
		local buttonWidth = math.min(300, middle - 32)
		if phone then
			Kit.rect(stage, 14, 10, 92, 92)
			boxTitle.TextXAlignment = Enum.TextXAlignment.Left
			progress.TextXAlignment = Enum.TextXAlignment.Left
			boxTitle.TextSize = 20
			Kit.rect(boxTitle, 118, 22, middle - 130, 26)
			Kit.rect(progress, 118, 50, middle - 130, 40)
			Kit.rect(buy.button, 14, 114, middle - 28, 54)
			Kit.rect(free.button, 14, 182, middle - 28, 46)
		else
			local stageSize = math.clamp(height - 230, 120, 200)
			local total = stageSize + 12 + 30 + 20 + 12 + 64 + 14 + 52
			local top = math.max(12, (height - total) / 2)
			Kit.rect(stage, (middle - stageSize) / 2, top, stageSize, stageSize)
			boxTitle.TextXAlignment = Enum.TextXAlignment.Center
			progress.TextXAlignment = Enum.TextXAlignment.Center
			boxTitle.TextSize = 24
			Kit.rect(boxTitle, 12, top + stageSize + 12, middle - 24, 30)
			Kit.rect(progress, 12, top + stageSize + 42, middle - 24, 20)
			Kit.rect(buy.button, (middle - buttonWidth) / 2, top + stageSize + 74, buttonWidth, 64)
			Kit.rect(
				free.button,
				(middle - buttonWidth) / 2,
				top + stageSize + 152,
				buttonWidth,
				52
			)
		end
	end
	local function arrangeInfo(count: number, rowCount: number)
		local pad = if phone then 14 else 20
		local inner = infoWidth - pad * 2
		local y = if phone then 10 else 16
		Kit.rect(inside, pad, y, inner - 90, 26)
		inside.TextSize = if phone then 17 else 20
		Kit.rect(insideCount, pad + inner - 90, y, 90, 26)
		y += 34
		local gap = if phone then 5 else 6
		local cell = State.cells(inner, 7, gap)
		local tileHeight = if phone then 44 else 48
		for index, tile in tiles do
			local column, line = (index - 1) % 7, (index - 1) // 7
			tile.size(cell, tileHeight)
			tile.button.Position =
				UDim2.fromOffset(pad + column * (cell + gap), y + line * (tileHeight + gap))
		end
		y += math.ceil(count / 7) * (tileHeight + gap) + 8
		Kit.rect(oddsTitle, pad, y, inner - 90, 26)
		oddsTitle.TextSize = if phone then 17 else 20
		Kit.rect(perBox, pad + inner - 90, y, 90, 26)
		y += 32
		Kit.rect(stack, pad, y, inner, if phone then 14 else 16)
		y += if phone then 22 else 26
		local rowHeight = if phone then 20 else 24
		for index, row in rows do
			if phone then
				-- Two columns: rarity and its total chance.
				local half = (inner - 14) / 2
				local column, line = (index - 1) % 2, (index - 1) // 2
				Kit.rect(
					row.root,
					pad + column * (half + 14),
					y + line * rowHeight,
					half,
					rowHeight
				)
				row.swatch.Visible, row.count.Visible = false, false
				Kit.rect(row.name, 0, 0, half - 60, rowHeight)
				row.name.TextSize = 13
				row.pct.TextSize = 13
				row.pct.FontFace = Style.body()
				Kit.rect(row.pct, half - 60, 0, 60, rowHeight)
			else
				Kit.rect(row.root, pad, y + (index - 1) * (rowHeight + 6), inner, rowHeight)
				Kit.rect(row.swatch, 0, 6, 12, 12)
				Kit.rect(row.name, 22, 0, 92, rowHeight)
				Kit.rect(row.count, 124, 0, inner - 124 - 70, rowHeight)
				Kit.rect(row.pct, inner - 70, 0, 70, rowHeight)
			end
		end
		y += if phone then math.ceil(rowCount / 2) * rowHeight else rowCount * (rowHeight + 6)
		-- Room is left under the rows for a later "current vs base chance" line.
		info.CanvasSize = UDim2.fromOffset(0, y + 24)
	end
	local function update(snapshot: Types.Snapshot)
		shell.update(snapshot)
		local name = State.collectionName(selected)
		list.update(snapshot, selected)
		preview.set(selected)
		root:SetAttribute("SelectedCollection", selected)
		boxTitle.Text = name .. " box"
		progress.Text = State.progressText(snapshot, selected)
		if phone then
			progress.Text = string.gsub(progress.Text, " · ", "\n")
		end
		local price = State.price(snapshot, selected)
		local need = State.need(snapshot, price)
		buy.setPrice(State.compact(price))
		buy.set("Open 1 box", ctx.canAct() and need == nil, need)
		local options = State.freeBoxOptions(snapshot)
		freeChoice = if table.find(options, selected)
			then selected
			elseif #options == 1 then options[1]
			else nil
		free.button.Visible = snapshot.dailyReady and freeChoice ~= nil
		free.set(
			if freeChoice == selected
				then "Claim today's free box"
				else "Claim free " .. State.collectionName(freeChoice or selected) .. " box",
			ctx.canAct()
		)
		local members = State.members(selected)
		insideCount.Text = #members .. " figures"
		for index, tile in tiles do
			local id = members[index]
			local found = id ~= nil and snapshot.discovered[id] == true
			tile.set(id, { discovered = found })
		end
		local odds = State.rarityOdds(snapshot, selected)
		local byRarity: { [string]: State.OddsRow } = {}
		for _, row in odds do
			byRarity[row.rarity] = row
		end
		local sum = 0
		for _, row in odds do
			sum += row.total
		end
		local shown = 0
		for index, rarity in Rarity.order do
			local row = byRarity[rarity]
			parts[index].Visible = row ~= nil
			parts[index].Size = UDim2.fromScale(if row and sum > 0 then row.total / sum else 0, 1)
		end
		for _, view in rows do
			view.root.Visible = false
		end
		for _, row in odds do
			shown += 1
			local view = rows[shown]
			view.root.Visible = true
			view.swatch.BackgroundColor3 = Style.rarity(row.rarity)
			view.name.Text = row.rarity
			view.count.Text = State.oddsLabel(row)
			view.pct.Text = State.percent(row.total)
		end
		arrangeInfo(#members, shown)
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
			if route and route.collection and Catalog.collectionIds[route.collection] then
				selected = route.collection
			end
			refresh()
		end,
	}
end

return Shop

--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local State = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Art = require(script.Parent.CollectionArt)
local Style = require(script.Parent.CollectionStyle)
local Shop = {}
function Shop.create(parent: Instance, ctx: Context.Context): Context.Screen
	local root = W.frame(parent, "Shop", Theme.paper)
	W.corner(root, 16)
	W.outline(root, Theme.card, 0.1)
	local page = W.scroll(root, "BoxShop", ctx.scope)
	local heading = W.title(page, "BLIND BOXES", 44)
	heading.LayoutOrder = 1
	heading.TextXAlignment = Enum.TextXAlignment.Center
	heading.TextSize = 23
	local tiles = W.tiles(page, ctx.scope, 230, math.min(3, #Catalog.collections), 504)
	tiles.LayoutOrder = 2
	local note = W.label(page, "One figure per box. Extras can become Scrap.", 42, 14)
	note.LayoutOrder = 3
	note.TextColor3 = Theme.muted
	local odds = W.frame(root, "BoxOdds")
	odds.Visible = false
	local oddsOpener: GuiObject? = nil
	local back = W.action(odds, "<  Boxes", ctx.scope, ctx.effects, function()
		odds.Visible = false
		page.Visible = true
		if oddsOpener then
			W.focus(oddsOpener)
		end
	end, true)
	back.button.Position = UDim2.fromOffset(12, 0)
	back.button.Size = UDim2.fromOffset(130, 44)
	local oddsPage = W.scroll(odds, "OddsList", ctx.scope)
	oddsPage.Position = UDim2.fromOffset(0, 52)
	oddsPage.Size = UDim2.new(1, 0, 1, -52)
	local oddsTitle = W.title(oddsPage, "", 50)
	oddsTitle.LayoutOrder = 1
	local rows: { [string]: { root: Frame, value: TextLabel } } = {}
	for order, figure in Catalog.figures do
		local row = W.card(oddsPage, figure.id, 70)
		row.LayoutOrder = order + 1
		local portrait = Preview.create(row, ctx.scope)
		portrait.frame.Size = UDim2.fromOffset(62, 62)
		portrait.frame.Position = UDim2.fromOffset(2, 4)
		portrait.figure(figure.id, true)
		local name = W.label(row, figure.name .. "\n" .. figure.rarity, 62, 14)
		name.Position = UDim2.fromOffset(70, 4)
		name.Size = UDim2.new(1, -142, 0, 62)
		local value = W.label(row, "", 62, 18)
		value.Position = UDim2.new(1, -70, 0, 4)
		value.Size = UDim2.fromOffset(60, 62)
		value.TextXAlignment = Enum.TextXAlignment.Right
		rows[figure.id] = { root = row, value = value }
	end
	local cards: { [string]: { price: TextLabel, open: W.Action, daily: W.Action } } = {}
	for order, collection in Catalog.collections do
		local card = W.card(tiles, collection.id, 504)
		card.LayoutOrder = order
		local style = Style.get(collection.id)
		card.BackgroundColor3 = style.page
		W.outline(card, style.trim, 0.45)
		local art = W.frame(card, "BoxArt")
		art.Size = UDim2.new(1, -8, 0, 302)
		art.Position = UDim2.fromOffset(4, 4)
		Art.create(art).set(collection.id)
		Preview.create(art, ctx.scope).box(collection.id)
		local title = W.title(card, collection.name, 34)
		W.inset(title, 310, 34)
		title.TextSize = 24
		title.Font = Enum.Font.FredokaOne
		title.TextColor3 = style.ink
		title.TextXAlignment = Enum.TextXAlignment.Center
		local total = 0
		for _, figure in Catalog.figures do
			if figure.collection == collection.id then
				total += 1
			end
		end
		local count = W.label(card, total .. " to collect", 24, 14)
		W.inset(count, 346, 24)
		count.TextXAlignment = Enum.TextXAlignment.Center
		local price = W.label(card, "", 30, 19)
		W.inset(price, 374, 30)
		price.TextXAlignment = Enum.TextXAlignment.Center
		local open = W.action(card, "Open box", ctx.scope, ctx.effects, function()
			ctx.send("Buy", nil, nil, collection.id)
		end)
		W.inset(open.button, 408, 48)
		open.button:SetAttribute("Accent", style.accent)
		local chances = W.action(card, "i  Odds", ctx.scope, ctx.effects, function()
			local opener = card:FindFirstChild("i  Odds")
			if opener and opener:IsA("GuiObject") then
				oddsOpener = opener
			end
			oddsTitle.Text = collection.name .. " · Odds"
			for id, row in rows do
				row.root.Visible = Catalog.byId[id].collection == collection.id
			end
			oddsPage.CanvasPosition = Vector2.zero
			odds.Visible = true
			page.Visible = false
			W.focus(back.button)
		end, true)
		chances.button.Position = UDim2.new(1, -88, 0, 12)
		chances.button.Size = UDim2.fromOffset(76, 44)
		local daily = W.action(card, "Daily free", ctx.scope, ctx.effects, function()
			ctx.send("Daily", nil, nil, collection.id)
		end, true)
		daily.button.Position = UDim2.fromOffset(12, 458)
		daily.button.Size = UDim2.new(1, -24, 0, 44)
		daily.button:SetAttribute("Quiet", true)
		cards[collection.id] = { price = price, open = open, daily = daily }
	end
	return {
		root = root,
		back = function(): boolean
			if not odds.Visible then
				return false
			end
			odds.Visible = false
			page.Visible = true
			return true
		end,
		update = function(snapshot: Types.Snapshot)
			for _, card in cards do
				card.price.Text = State.number(snapshot.price) .. " Coins"
				card.open.set(
					if snapshot.coins >= snapshot.price then "OPEN" else "Need more Coins",
					ctx.canAct() and snapshot.coins >= snapshot.price
				)
				card.daily.set(
					if snapshot.dailyReady then "Daily free" else "Daily claimed",
					ctx.canAct() and snapshot.dailyReady
				)
			end
			for id, row in rows do
				row.value.Text = string.format("%g%%", snapshot.odds[id] or 0)
			end
		end,
	}
end
return Shop

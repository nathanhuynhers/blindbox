--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local State = require(script.Parent.UIState)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Details = {}
function Details.create(parent: Instance, ctx: Context.Context, back: () -> ())
	local root = W.frame(parent, "FigureDetails")
	root.Visible = false
	local backButton = W.action(root, "<  Collection", ctx.scope, ctx.effects, back, true)
	backButton.button.Size = UDim2.fromOffset(150, 44)
	backButton.button.Position = UDim2.fromOffset(12, 0)
	local page = W.scroll(root, "DetailsScroll", ctx.scope)
	local hero = W.card(page, "FigureHero", 210)
	hero.LayoutOrder = 1
	local portrait = Preview.create(hero, ctx.scope)
	local name = W.title(page, "", 52)
	name.LayoutOrder = 2
	local rarity = W.label(page, "", 42, 16)
	rarity.LayoutOrder = 3
	local stats = W.card(page, "FigureStats", 64)
	stats.LayoutOrder = 4
	stats.BackgroundColor3 = Theme.soft
	local quantity = W.label(stats, "", 60, 17)
	W.inset(quantity, 2, 60)
	local display = W.label(page, "", 30, 15)
	display.LayoutOrder = 5
	local place = W.action(page, "Display figure", ctx.scope, ctx.effects, function()
		ctx.place(root:GetAttribute("FigureId") :: string)
	end)
	place.button.LayoutOrder = 6
	local redeem = W.action(page, "", ctx.scope, ctx.effects, function()
		ctx.send("Redeem", root:GetAttribute("FigureId") :: string, nil, nil)
	end, true)
	redeem.button.LayoutOrder = 7
	local recycle = W.action(page, "Recycle extra  +1 Scrap", ctx.scope, ctx.effects, function()
		ctx.send("Recycle", root:GetAttribute("FigureId") :: string, nil, nil)
	end, true)
	recycle.button.LayoutOrder = 8
	local recycling = W.label(page, "Keeps your last copy & displayed figures.", 40, 14)
	recycling.LayoutOrder = 9
	recycling.TextColor3 = Theme.muted
	local odds = W.label(page, "", 36, 14)
	odds.LayoutOrder = 10
	local function resize()
		local wide = root.AbsoluteSize.X >= 650
		hero.Parent = if wide then root else page
		hero.Position = if wide then UDim2.new(0.02, 0, 0, 56) else UDim2.fromOffset(0, 0)
		hero.Size = if wide then UDim2.new(0.42, 0, 1, -72) else UDim2.new(1, -4, 0, 210)
		page.Position = if wide then UDim2.new(0.46, 0, 0, 52) else UDim2.fromOffset(0, 52)
		page.Size = if wide then UDim2.new(0.54, 0, 1, -52) else UDim2.new(1, 0, 1, -52)
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	local function update(snapshot: Types.Snapshot)
		local id = root:GetAttribute("FigureId")
		if typeof(id) ~= "string" then
			return
		end
		local figure = Catalog.byId[id]
		local discovered = snapshot.discovered[id] == true
		local owned, free = State.copies(snapshot, id)
		portrait.figure(id, discovered)
		hero.BackgroundColor3 = Theme.rarity(figure.rarity)
		name.Text = if discovered then figure.name else "A little mystery"
		local collectionName = figure.collection
		for _, collection in Catalog.collections do
			if collection.id == figure.collection then
				collectionName = collection.name
			end
		end
		rarity.Text = figure.rarity .. "  /  " .. collectionName
		quantity.Text = string.format(
			"%d owned   ·   %d free\n%g Coins/sec when displayed",
			owned,
			free,
			snapshot.rates[id] or 0
		)
		display.Text = if owned - free > 0
			then tostring(owned - free) .. " on your display"
			else "Not on display"
		place.set(
			if free > 0
				then "Display figure"
				elseif owned > 0 then "All copies displayed"
				else "Not owned yet",
			ctx.canAct() and free > 0
		)
		redeem.set(
			"Redeem  ·  " .. snapshot.redeemCost .. " Scrap",
			ctx.canAct() and snapshot.scrap >= snapshot.redeemCost
		)
		recycle.set("Recycle extra  ·  +1 Scrap", ctx.canAct() and State.recycle(snapshot, id))
		odds.Text = string.format("%g%% per %s box", snapshot.odds[id] or 0, collectionName)
	end
	return {
		root = root,
		update = update,
		show = function(id: string)
			root:SetAttribute("FigureId", id)
			page.CanvasPosition = Vector2.zero
			root.Visible = true
			W.focus(backButton.button)
			local snapshot = ctx.snapshot()
			if snapshot then
				update(snapshot)
			end
		end,
		back = backButton.button,
	}
end
return Details

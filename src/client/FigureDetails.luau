--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local State = require(script.Parent.UIState)
local Theme = require(script.Parent.UITheme)
local Style = require(script.Parent.CollectionStyle)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Details = {}
function Details.create(parent: Instance, ctx: Context.Context, back: () -> ())
	local root = W.frame(parent, "FigureDetails")
	local page = W.scroll(root, "DetailsScroll", ctx.scope)
	local backButton = W.action(page, "<  All figures", ctx.scope, ctx.effects, back, true)
	backButton.button.Size = UDim2.new(1, -4, 0, 44)
	backButton.button.LayoutOrder = 0
	backButton.button:SetAttribute("Quiet", true)
	local hero = W.frame(page, "FigureHero")
	hero.Size = UDim2.new(1, -4, 0, 238)
	hero.LayoutOrder = 1
	local halo = W.frame(hero, "Halo", Theme.soft)
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(0.8, 0.9)
	W.corner(halo, 200)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = halo
	halo.BackgroundTransparency = 0.4
	local plinth = W.frame(hero, "Plinth", Theme.soft)
	plinth.Size = UDim2.new(0.6, 0, 0, 18)
	plinth.Position = UDim2.fromScale(0.2, 0.89)
	W.corner(plinth, 30)
	local portrait = Preview.create(hero, ctx.scope)
	portrait.frame.Size = UDim2.fromScale(1, 0.94)
	local name = W.title(page, "", 36)
	name.LayoutOrder = 2
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Font = Enum.Font.FredokaOne
	local rarity = W.label(page, "", 26, 13)
	rarity.LayoutOrder = 3
	rarity.TextXAlignment = Enum.TextXAlignment.Center
	local stats = W.label(page, "", 44, 16)
	stats.LayoutOrder = 4
	stats.TextXAlignment = Enum.TextXAlignment.Center
	local place = W.action(page, "Display", ctx.scope, ctx.effects, function()
		ctx.place(root:GetAttribute("FigureId") :: string)
	end)
	place.button.LayoutOrder = 5
	local recycle = W.action(page, "Recycle +1 Scrap", ctx.scope, ctx.effects, function()
		ctx.send("Recycle", root:GetAttribute("FigureId") :: string, nil, nil)
	end, true)
	recycle.button.LayoutOrder = 6
	recycle.button:SetAttribute("Surface", Color3.fromRGB(251, 219, 184))
	local redeem = W.action(page, "", ctx.scope, ctx.effects, function()
		ctx.send("Redeem", root:GetAttribute("FigureId") :: string, nil, nil)
	end, true)
	redeem.button.LayoutOrder = 7
	redeem.button:SetAttribute("Quiet", true)
	local note = W.label(page, "", 54, 12)
	note.LayoutOrder = 8
	note.TextColor3 = Theme.muted
	note.TextXAlignment = Enum.TextXAlignment.Center
	local function update(snapshot: Types.Snapshot)
		local id = root:GetAttribute("FigureId")
		if typeof(id) ~= "string" then
			return
		end
		local figure = Catalog.byId[id]
		local style = Style.get(figure.collection)
		local discovered = snapshot.discovered[id] == true
		local owned, free = State.copies(snapshot, id)
		portrait.figure(id, discovered)
		halo.BackgroundColor3 = Theme.rarity(figure.rarity)
		plinth.BackgroundColor3 = style.trim
		name.TextColor3 = style.ink
		name.Text = if discovered then figure.name else "A little mystery"
		local collectionName = figure.collection
		for _, definition in Catalog.collections do
			if definition.id == figure.collection then
				collectionName = definition.name
			end
		end
		rarity.Text = string.upper(figure.rarity) .. " / " .. collectionName
		rarity.TextColor3 = style.accent
		stats.Text = string.format(
			"Owned: %d  /  Available: %d\n%g Coins/sec",
			owned,
			free,
			snapshot.rates[id] or 0
		)
		place.button:SetAttribute("Accent", style.accent)
		place.set(
			if free > 0
				then "Display"
				elseif owned > 0 then "All copies displayed"
				else "Not owned yet",
			ctx.canAct() and free > 0
		)
		recycle.button.Visible = State.recycle(snapshot, id)
		recycle.set("Recycle extra  +1 Scrap", ctx.canAct() and State.recycle(snapshot, id))
		redeem.set(
			"Redeem for " .. snapshot.redeemCost .. " Scrap",
			ctx.canAct() and snapshot.scrap >= snapshot.redeemCost
		)
		note.Text = string.format(
			"%g%% per box. Recycling keeps your last copy and displayed figures.",
			snapshot.odds[id] or 0
		)
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), function()
		hero.Size = UDim2.new(1, -4, 0, if root.AbsoluteSize.Y < 350 then 160 else 238)
	end)
	return {
		root = root,
		update = update,
		back = backButton.button,
		show = function(id: string, focus: boolean?)
			root:SetAttribute("FigureId", id)
			page.CanvasPosition = Vector2.zero
			root.Visible = true
			if focus ~= false then
				W.focus(backButton.button)
			end
			local snapshot = ctx.snapshot()
			if snapshot then
				update(snapshot)
			end
		end,
	}
end
return Details

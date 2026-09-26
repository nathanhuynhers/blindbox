--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local State = require(script.Parent.UIState)
local Style = require(script.Parent.CollectionStyle)
local Layout = require(script.Parent.CollectionLayout)
local Assets = require(script.Parent.CollectionAssets)
local Controls = require(script.Parent.CollectionControls)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Details = {}
function Details.create(parent: Instance, ctx: Context.Context, back: () -> ())
	local root = W.frame(parent, "FigureDetails")
	local skin = Assets.mount(root, "DetailSkin", ctx.scope)
	local border = W.frame(skin.native, "PrintedShowcaseBorder")
	border.Position = UDim2.fromOffset(3, 4)
	border.Size = UDim2.new(1, -6, 1, -8)
	W.corner(border, 16)
	local outline = W.outline(border, Style.get("grove").trim, 0.62)
	local page = W.scroll(root, "DetailsScroll", ctx.scope)
	local padding = page:FindFirstChildOfClass("UIPadding")
	assert(padding, "Detail padding missing")
	local list = page:FindFirstChildOfClass("UIListLayout")
	assert(list, "Detail layout missing")
	list.Padding = UDim.new(0, 8)
	local hero = W.frame(page, "FigureHero")
	hero.LayoutOrder = 1
	local glow = W.frame(hero, "SoftSpotlight", Color3.new(1, 1, 1))
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.84, 0.72)
	glow.BackgroundTransparency = 0.5
	W.corner(glow, 300)
	local pedestal = W.frame(hero, "DisplayPlinth", Style.get("grove").trim)
	pedestal.Position = UDim2.fromScale(0.1, 0.86)
	pedestal.Size = UDim2.fromScale(0.8, 0.07)
	W.corner(pedestal, 100)
	local edge = W.outline(pedestal, Color3.fromRGB(255, 243, 209), 0.25)
	edge.Thickness = 2
	local portrait = Preview.create(hero, ctx.scope, true)
	portrait.frame.Position = UDim2.fromScale(0, 0.04)
	portrait.frame.Size = UDim2.fromScale(1, 0.87)
	local mystery = W.label(hero, "?", 62, 52)
	mystery.AnchorPoint = Vector2.new(0.5, 0.5)
	mystery.Position = UDim2.fromScale(0.5, 0.47)
	mystery.Size = UDim2.fromOffset(62, 62)
	mystery.Font = Enum.Font.FredokaOne
	mystery.TextXAlignment = Enum.TextXAlignment.Center
	mystery.TextColor3 = Color3.fromRGB(255, 251, 235)
	local name = W.title(page, "", 60)
	name.Name = "FigureName"
	name.LayoutOrder = 2
	name.Font = Enum.Font.FredokaOne
	name.TextSize = 26
	name.Size = UDim2.fromScale(1, 0)
	name.AutomaticSize = Enum.AutomaticSize.Y
	name.TextYAlignment = Enum.TextYAlignment.Top
	local badgeRow = W.frame(page, "BadgeRow")
	badgeRow.Size = UDim2.new(1, 0, 0, 26)
	badgeRow.LayoutOrder = 3
	local badge = Controls.badge(badgeRow, ctx)
	local stats = W.label(page, "", 60, 16)
	stats.Name = "FigureStats"
	stats.LayoutOrder = 4
	stats.TextYAlignment = Enum.TextYAlignment.Top
	local flavor = W.label(page, "", 42, 13)
	flavor.Name = "FigureFlavor"
	flavor.LayoutOrder = 5
	flavor.TextYAlignment = Enum.TextYAlignment.Top
	local place = Controls.action(page, "Display", "display", ctx, function()
		local id = root:GetAttribute("FigureId")
		if typeof(id) == "string" then
			ctx.place(id)
		end
	end)
	place.button.LayoutOrder = 6
	place.button.Size = UDim2.new(1, 0, 0, 44)
	local secondary = W.frame(page, "SecondaryActions")
	secondary.LayoutOrder = 7
	secondary.Size = UDim2.new(1, 0, 0, 44)
	local recycle = Controls.action(secondary, "Recycle\n+1 Scrap", "secondary", ctx, function()
		local id = root:GetAttribute("FigureId")
		if typeof(id) == "string" then
			ctx.send("Recycle", id, nil, nil)
		end
	end)
	recycle.button.Name = "Recycle"
	recycle.button.Size = UDim2.new(0.5, -3, 1, 0)
	local redeem = Controls.action(secondary, "", "secondary", ctx, function()
		local id = root:GetAttribute("FigureId")
		if typeof(id) == "string" then
			ctx.send("Redeem", id, nil, nil)
		end
	end)
	redeem.button.Name = "Redeem"
	redeem.button.Position = UDim2.new(0.5, 3, 0, 0)
	redeem.button.Size = UDim2.new(0.5, -3, 1, 0)
	local backButton = Controls.action(root, "<", "paper", ctx, back)
	backButton.button.Name = "BackToFigures"
	backButton.button.Position = UDim2.fromOffset(0, 0)
	backButton.button.Size = UDim2.fromOffset(44, 44)
	backButton.button.ZIndex = 5
	local footer = 0
	local mobileBack = false
	local pageInset = 26
	local function resize()
		local geometry = Layout.detail(root.AbsoluteSize.X, root.AbsoluteSize.Y, pageInset)
		local top = if mobileBack then 48 else 0
		hero.Parent = if geometry.sideBySide then root else page
		hero.Position = if geometry.sideBySide
			then UDim2.fromOffset(geometry.heroX, 20)
			else UDim2.fromOffset(0, 0)
		hero.Size = if geometry.sideBySide
			then UDim2.new(0, geometry.heroWidth, 1, -footer - 32)
			else UDim2.new(1, -4, 0, geometry.hero)
		local gutter = if geometry.sideBySide then Layout.arrowSize + Layout.arrowGap else 0
		portrait.frame.Position = UDim2.new(0, gutter, 0.04, 0)
		portrait.frame.Size = UDim2.new(1, -2 * gutter, 0.87, 0)
		-- Compensate for scroll padding so every item shares the same content origin.
		local infoTop = geometry.infoTop
		page.Position = if geometry.sideBySide
			then UDim2.fromOffset(
				geometry.infoX - padding.PaddingLeft.Offset,
				infoTop - padding.PaddingTop.Offset
			)
			else UDim2.fromOffset(0, top)
		page.Size = if geometry.sideBySide
			then UDim2.new(1, -geometry.infoX + padding.PaddingLeft.Offset, 1, -footer - infoTop)
			else UDim2.new(1, 0, 1, -footer - top)
		skin.root.Size = UDim2.new(1, 0, 1, -footer)
		backButton.button.Visible = mobileBack
		name.TextSize = if geometry.sideBySide then 23 else 28
	end
	local painted = ""
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
		if painted ~= figure.collection then
			painted = figure.collection
			skin.set(Assets.get(figure.collection).detail)
			outline.Color = style.trim
			pedestal.BackgroundColor3 = style.trim
			name.TextColor3 = style.ink
			stats.TextColor3 = style.ink
			flavor.TextColor3 = style.ink
		end
		glow.BackgroundColor3 = if discovered then Style.rarity(figure.rarity) else style.wash
		mystery.Visible = not discovered
		name.Text = if discovered then figure.name else "???"
		badge.set(figure.rarity)
		local chance = State.percent(snapshot.odds[id] or 0)
		stats.Size = UDim2.new(1, 0, 0, if discovered then 64 else 24)
		stats.Text = if discovered
			then string.format(
				"Pull chance    %s\nOwned          %d\nIncome         %g Coins/sec",
				chance,
				owned,
				snapshot.rates[id] or 0
			)
			else "Pull chance    " .. chance
		local description = figure.description
		flavor.Text = if discovered
			then if description and description ~= "" then description else ""
			else "A discovery waiting to happen."
		flavor.Visible = flavor.Text ~= ""
		place.button.Visible = discovered
		place.set(
			if free > 0 then "Display" elseif owned > 0 then "All displayed" else "Not owned",
			ctx.canAct() and free > 0
		)
		recycle.button.Visible = discovered
		recycle.button.Size = UDim2.new(0.5, -3, 1, 0)
		recycle.set("Recycle\n+1 Scrap", ctx.canAct() and State.recycle(snapshot, id))
		redeem.button.Position = if discovered
			then UDim2.new(0.5, 3, 0, 0)
			else UDim2.fromOffset(0, 0)
		redeem.button.Size = if discovered then UDim2.new(0.5, -3, 1, 0) else UDim2.fromScale(1, 1)
		redeem.set(
			if discovered
				then "Redeem\n" .. snapshot.redeemCost .. " Scrap"
				else "Redeem - " .. snapshot.redeemCost .. " Scrap",
			ctx.canAct() and snapshot.scrap >= snapshot.redeemCost
		)
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	return {
		root = root,
		hero = hero,
		viewport = portrait.frame,
		update = update,
		back = backButton.button,
		layout = function(backVisible: boolean, footerHeight: number, inset: number)
			pageInset = inset
			mobileBack, footer = backVisible, footerHeight
			resize()
		end,
		show = function(id: string, focus: boolean?)
			root:SetAttribute("FigureId", id)
			page.CanvasPosition = Vector2.zero
			local snapshot = ctx.snapshot()
			if snapshot then
				update(snapshot)
			end
			if focus then
				W.focus(backButton.button)
			end
		end,
	}
end
return Details

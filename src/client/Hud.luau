--!strict
-- World HUD: Coins pill (balance + income chip + green Store "+") right of Roblox's menu
-- buttons, the top-right STORE / Daily / Home / Plaza / settings row with the settings popover,
-- and the daily goal tracker. Nothing else covers the world.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Badge = require(script.Parent.UIBadge)
local State = require(script.Parent.UIState)
local Layout = require(script.Parent.UILayout)
local Context = require(script.Parent.UIContext)
local Menu = require(script.Parent.SettingsMenu)
local Tracker = require(script.Parent.GoalTracker)
local Sfx = require(script.Parent.Sfx)
local Button = require(script.Parent.UIButton)
local Navigation = require(script.Parent.NavigationConfig)
local TweenService = game:GetService("TweenService")
local Hud = {}

export type Hud = {
	root: Frame,
	coins: TextButton,
	home: TextButton,
	plaza: TextButton,
	store: TextButton,
	plus: TextButton,
	daily: TextButton,
	gear: TextButton,
	menu: Menu.Menu,
	layout: (Layout.Frame, opened: boolean) -> (),
	update: (Types.Snapshot, number?) -> (),
	displayCoins: (number) -> (),
}

function Hud.create(
	parent: Instance,
	ctx: Context.Context,
	setMotion: (boolean) -> (),
	travel: (destination: "Home" | "Plaza") -> ()
): Hud
	local root = Kit.frame(parent, "Hud")
	root.ZIndex = 30
	-- Coins pill sizes to its content; its hard shadow follows the measured size.
	local coinShadow = Kit.frame(root, "CoinsShadow", Style.ink)
	coinShadow.ZIndex = 1
	Kit.round(coinShadow)
	local coins = Instance.new("TextButton")
	coins.Name = "Coins"
	coins.Text = ""
	coins.AutoButtonColor = false
	coins.BackgroundColor3 = Style.white
	coins.AutomaticSize = Enum.AutomaticSize.X
	coins.ZIndex = 2
	coins.Parent = root
	Kit.round(coins)
	Kit.stroke(coins, Style.ink)
	Kit.padding(coins, 0, 6, 0, 10)
	Kit.list(coins, Enum.FillDirection.Horizontal, 10, Enum.VerticalAlignment.Center)
	local coin = Icons.create(coins, "Coin", Style.ink, 30)
	coin.LayoutOrder = 1
	local amount = Kit.text(coins, "Balance", "…", 24, Style.display())
	amount.AutomaticSize = Enum.AutomaticSize.X
	amount.Size = UDim2.fromScale(0, 1)
	amount.TextTruncate = Enum.TextTruncate.None
	amount.LayoutOrder = 2
	local rate = Badge.create(coins, "Rate", "", {
		fill = Style.mint,
		color = Style.mintText,
		height = 26,
		size = 14,
	})
	rate.root.LayoutOrder = 3
	-- Green "+" (Robux green): opens the Store on its Coins tab. A small circle in a narrow slot
	-- keeps the pill airy; the transparent 44px hit area overhangs the slot. It never pulses or
	-- badges, and does not change when Coins run low.
	local plusSlot = Kit.frame(coins, "PlusSlot")
	plusSlot.LayoutOrder = 4
	local plus = Instance.new("TextButton")
	plus.Name = "StorePlus"
	plus.Text = ""
	plus.AutoButtonColor = false
	plus.BackgroundTransparency = 1
	plus.AnchorPoint = Vector2.new(0.5, 0.5)
	plus.Position = UDim2.fromScale(0.5, 0.5)
	plus.Size = UDim2.fromOffset(Style.target, Style.target)
	plus.ZIndex = 3
	plus:SetAttribute("AccessibleName", "Get more Coins in the Store")
	plus.Parent = plusSlot
	local plusDisc = Kit.frame(plus, "Disc", Style.robux)
	plusDisc.AnchorPoint = Vector2.new(0.5, 0.5)
	plusDisc.Position = UDim2.fromScale(0.5, 0.5)
	plusDisc.ZIndex = 3
	Kit.round(plusDisc)
	Kit.stroke(plusDisc, Style.ink, Style.outlineSmall)
	local plusFill = Instance.new("UIGradient")
	plusFill.Rotation = 90
	plusFill.Color = ColorSequence.new(Style.robuxLight, Style.robuxDark)
	plusFill.Parent = plusDisc
	local plusIcon = Icons.create(plusDisc, "Plus", Style.white, 16)
	plusIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	plusIcon.Position = UDim2.fromScale(0.5, 0.5)
	plusIcon.ZIndex = 4
	ctx.scope.connect(plus.Activated, function()
		ctx.navigate("Store", { tab = "coins" })
	end)
	ctx.scope.connect(coins.Activated, function()
		local snapshot = ctx.snapshot()
		if snapshot then
			local status = string.lower(snapshot.saveStatus)
			ctx.message(
				State.number(snapshot.coins)
					.. " Coins · earning "
					.. State.amount(State.totalRate(snapshot))
					.. " per second\nClick or tap each displayed figure to collect its Coins. E nearby manages your Display."
					.. (
						if not snapshot.ready or string.find(status, "preview", 1, true)
							then "\n" .. snapshot.saveStatus
							else ""
					)
			)
		end
		Sfx.play("select")
	end)
	-- Top-right row [Daily] [Home] [Plaza] [gear]: one set of rounded white tiles with a hard ink
	-- shadow that drops on press. Daily, Home and Plaza are icon-over-label tiles like small
	-- dock tiles, so they read at a glance; the gear is the same tile, icon-only. Daily sits
	-- furthest from the corner, where its badge and nudge catch the eye; the gear keeps it.
	local right = Kit.frame(root, "Right")
	local function roundButton(name: string, accessible: string, callback: () -> ()): Button.Button
		local made = Button.create(right, name, {
			variant = "raised",
			text = "",
			size = 14,
			radius = 16,
			drop = 4,
			silent = true,
		}, ctx.scope, ctx.effects, callback)
		made.button.ZIndex = 2
		made.button:SetAttribute("AccessibleName", accessible)
		return made
	end
	type Tile = { icon: ImageLabel, caption: TextLabel }
	-- Glossy navigation art over its label. Without an uploaded image the label shows alone.
	local function art(made: Button.Button, id: string): Tile
		local icon = Kit.image(made.face, "Icon", Navigation.image(id))
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Visible = icon.Image ~= ""
		local caption = Kit.text(made.face, "Caption", id, 15, Style.display())
		caption.TextXAlignment = Enum.TextXAlignment.Center
		return { icon = icon, caption = caption }
	end
	local daily = roundButton("DailyButton", "Daily Login rewards", function()
		ctx.navigate("Login")
	end)
	local dailyTile = art(daily, "Daily")
	local dailyIcon = dailyTile.icon
	local dailyBadge = Badge.corner(daily.button, "Ready", {
		fill = Style.alert,
		color = Style.white,
		height = 22,
		size = 13,
		outline = Style.ink,
	}, Vector2.new(1, 0), Vector2.new(6, -8))
	local home = roundButton("HomeButton", "Return Home to your plot", function()
		travel("Home")
		Sfx.play("select")
	end)
	local homeTile = art(home, "Home")
	local plaza = roundButton("PlazaButton", "Go to the town Plaza", function()
		travel("Plaza")
		Sfx.play("select")
	end)
	local plazaTile = art(plaza, "Plaza")
	-- Idle nudge on Daily while a reward waits. Rotating the icon never moves layout;
	-- Motion Reduced keeps it still.
	local loginReady = false
	local nudge: Tween? = nil
	local function wiggle()
		local on = loginReady and ctx.effects()
		if on == (nudge ~= nil) then
			return
		end
		if nudge then
			nudge:Cancel()
			nudge = nil
			dailyIcon.Rotation = 0
		end
		if on then
			local tween = TweenService:Create(
				dailyIcon,
				TweenInfo.new(
					0.14,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true,
					1.8
				),
				{ Rotation = 10 }
			)
			nudge = tween
			tween:Play()
		end
	end
	ctx.scope.add(function()
		if nudge then
			nudge:Cancel()
		end
	end)
	local menu = Menu.create(parent, ctx, function(value: boolean)
		setMotion(value)
		wiggle()
	end)
	local gear = roundButton("SettingsButton", "Settings", function()
		menu.set(not menu.open())
		Sfx.play("select")
	end)
	-- STORE: a candy tile at the row's left end, the row's size. Frame-drawn gift until Store art
	-- exists.
	local store = Button.create(
		right,
		"StoreButton",
		{
			variant = "raised",
			text = "",
			size = 14,
			radius = 16,
			drop = 4,
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.navigate("Store", { tab = "featured" })
		end
	)
	store.button.ZIndex = 2
	store.button:SetAttribute("AccessibleName", "Open the Robux Store")
	local storeFill = Instance.new("UIGradient")
	storeFill.Rotation = 45
	storeFill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Style.candyPinkLight),
		ColorSequenceKeypoint.new(0.5, Style.candyPink),
		ColorSequenceKeypoint.new(1, Style.candyViolet),
	})
	storeFill.Parent = store.face
	local storeIcon = Icons.create(store.face, "Gift", Style.gold, 34)
	storeIcon.AnchorPoint = Vector2.new(0.5, 0)
	local storeCaption = Kit.text(store.face, "Caption", "STORE", 16, Style.display(), Style.white)
	storeCaption.TextXAlignment = Enum.TextXAlignment.Center
	local storeStroke = Instance.new("UIStroke")
	storeStroke.Color = Style.ink
	storeStroke.Thickness = 2.5
	storeStroke.Parent = storeCaption
	local gearIcon = Icons.create(gear.face, "Gear", Style.ink, 26)
	gearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gearIcon.Position = UDim2.fromScale(0.5, 0.5)
	-- Gamepad: left/right walks the row in reading order.
	store.button.NextSelectionRight = daily.button
	daily.button.NextSelectionLeft = store.button
	daily.button.NextSelectionRight = home.button
	home.button.NextSelectionLeft = daily.button
	home.button.NextSelectionRight = plaza.button
	plaza.button.NextSelectionLeft = home.button
	plaza.button.NextSelectionRight = gear.button
	gear.button.NextSelectionLeft = plaza.button
	local tracker = Tracker.create(right, ctx)
	local function place(made: Button.Button, rect: Layout.Rect, tile: Tile?, phone: boolean)
		Kit.rect(made.button, rect.x, rect.y, rect.width, rect.height)
		if not tile then
			return
		end
		-- Phone 50x56: 32px icon over a 12px label; desktop 64x64: 40px icon over 15px.
		local iconSize, labelSize = if phone then 32 else 40, if phone then 12 else 15
		tile.icon.Position = UDim2.new(0.5, 0, 0, 3)
		tile.icon.Size = UDim2.fromOffset(iconSize, iconSize)
		tile.caption.TextSize = labelSize
		local labelHeight = labelSize + 2
		if tile.icon.Visible then
			Kit.rect(tile.caption, 0, rect.height - labelHeight - 5, rect.width, labelHeight)
		else
			Kit.rect(tile.caption, 0, 0, rect.width, rect.height)
		end
	end
	local frame: Layout.Frame? = nil
	local function follow()
		local geometry = frame
		if not geometry then
			return
		end
		local width = coins.AbsoluteSize.X / math.max(0.01, ctx.scale())
		Kit.rect(
			coinShadow,
			geometry.hud.x,
			geometry.hud.y + (if geometry.phone then 3 else 4),
			width,
			geometry.hud.height
		)
	end
	ctx.scope.connect(coins:GetPropertyChangedSignal("AbsoluteSize"), follow)
	local function displayCoins(value: number)
		amount.Text = if value >= 1e7 then State.compact(value) else State.number(value)
		coins:SetAttribute("AccessibleName", amount.Text .. " coins, earning " .. rate.label.Text)
	end
	return {
		root = root,
		coins = coins,
		home = home.button,
		plaza = plaza.button,
		store = store.button,
		plus = plus,
		daily = daily.button,
		gear = gear.button,
		menu = menu,
		layout = function(geometry: Layout.Frame, opened: boolean)
			frame = geometry
			local phone = geometry.phone
			coins.Position = UDim2.fromOffset(geometry.hud.x, geometry.hud.y)
			coins.Size = UDim2.fromOffset(0, geometry.hud.height)
			coin.Size = UDim2.fromOffset(if phone then 24 else 30, if phone then 24 else 30)
			local slot, disc = if phone then 28 else 34, if phone then 26 else 30
			plusSlot.Size = UDim2.fromOffset(slot, geometry.hud.height)
			plusDisc.Size = UDim2.fromOffset(disc, disc)
			plusIcon.Size = UDim2.fromOffset(if phone then 13 else 15, if phone then 13 else 15)
			amount.TextSize = if phone then 19 else 24
			-- Phone sheets carry their own coins chip; the HUD hides under an open sheet.
			-- The top-right row follows the gear: hidden while any screen is open.
			coins.Visible = not (phone and opened)
			coinShadow.Visible = coins.Visible
			place(store, geometry.store, nil, phone)
			local storeIconSize = if phone then 28 else 34
			storeIcon.Position = UDim2.new(0.5, 0, 0, if phone then 6 else 6)
			storeIcon.Size = UDim2.fromOffset(storeIconSize, storeIconSize)
			storeCaption.TextSize = if phone then 13 else 15
			Kit.rect(
				storeCaption,
				0,
				geometry.store.height - (if phone then 20 else 22),
				geometry.store.width,
				if phone then 16 else 18
			)
			place(daily, geometry.daily, dailyTile, phone)
			place(home, geometry.home, homeTile, phone)
			place(plaza, geometry.plaza, plazaTile, phone)
			place(gear, geometry.gear, nil, phone)
			gearIcon.Size = UDim2.fromOffset(if phone then 26 else 30, if phone then 26 else 30)
			tracker.layout(geometry.tracker, phone)
			-- Below the row; on short phones beside it (left of Daily) rather than over it.
			local menuSize = menu.root.Size
			local below = geometry.gear.y + geometry.gear.height + 10
			if below + menuSize.Y.Offset + 8 <= geometry.height then
				menu.place(geometry.gear.x + geometry.gear.width - menuSize.X.Offset, below)
			else
				menu.place(
					math.max(8, geometry.store.x - 10 - menuSize.X.Offset),
					math.max(8, math.min(geometry.gear.y, geometry.height - menuSize.Y.Offset - 8))
				)
			end
			right.Visible = not opened
			if opened then
				menu.set(false)
			end
			follow()
		end,
		displayCoins = displayCoins,
		update = function(snapshot: Types.Snapshot, displayed: number?)
			menu.update(snapshot)
			rate.set(State.rate(State.totalRate(snapshot)))
			displayCoins(displayed or snapshot.coins)
			tracker.update(snapshot)
			local ready = State.badges(snapshot).Login
			dailyBadge.root.Visible = ready ~= nil
			dailyBadge.set(ready or "")
			loginReady = ready ~= nil
			wiggle()
		end,
	}
end

return Hud

--!strict
-- World HUD: Coins pill (balance + income chip) right of Roblox's menu buttons, the top-right
-- Daily / Home / settings row with the settings popover, and the daily goal tracker. Nothing
-- else covers the world.
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
	goHome: () -> ()
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
	Kit.padding(coins, 0, 12, 0, 10)
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
	-- Top-right row [Daily] [Home] [gear]: one set of rounded white tiles with a hard ink
	-- shadow that drops on press. Daily and Home are icon-over-label tiles like small dock
	-- tiles, so they read at a glance; the gear stays icon-only. Daily sits furthest from the
	-- corner, where its badge and nudge catch the eye; the gear keeps the corner.
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
		goHome()
		Sfx.play("select")
	end)
	local homeTile = art(home, "Home")
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
	local gearIcon = Icons.create(gear.face, "Gear", Style.ink, 26)
	gearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gearIcon.Position = UDim2.fromScale(0.5, 0.5)
	-- Gamepad: left/right walks the row in reading order.
	daily.button.NextSelectionRight = home.button
	home.button.NextSelectionLeft = daily.button
	home.button.NextSelectionRight = gear.button
	gear.button.NextSelectionLeft = home.button
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
		daily = daily.button,
		gear = gear.button,
		menu = menu,
		layout = function(geometry: Layout.Frame, opened: boolean)
			frame = geometry
			local phone = geometry.phone
			coins.Position = UDim2.fromOffset(geometry.hud.x, geometry.hud.y)
			coins.Size = UDim2.fromOffset(0, geometry.hud.height)
			coin.Size = UDim2.fromOffset(if phone then 24 else 30, if phone then 24 else 30)
			amount.TextSize = if phone then 19 else 24
			-- Phone sheets carry their own coins chip; the HUD hides under an open sheet.
			-- The top-right row follows the gear: hidden while any screen is open.
			coins.Visible = not (phone and opened)
			coinShadow.Visible = coins.Visible
			place(daily, geometry.daily, dailyTile, phone)
			place(home, geometry.home, homeTile, phone)
			place(gear, geometry.gear, nil, phone)
			gearIcon.Size = UDim2.fromOffset(if phone then 24 else 26, if phone then 24 else 26)
			tracker.layout(geometry.tracker.x, geometry.tracker.y, phone)
			-- Below the row; on short phones beside it (left of Daily) rather than over it.
			local menuSize = menu.root.Size
			local below = geometry.gear.y + geometry.gear.height + 10
			if below + menuSize.Y.Offset + 8 <= geometry.height then
				menu.place(geometry.gear.x + geometry.gear.width - menuSize.X.Offset, below)
			else
				menu.place(
					math.max(8, geometry.daily.x - 10 - menuSize.X.Offset),
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

--!strict
-- World HUD: Coins pill (balance + income chip) right of Roblox's menu buttons, settings gear
-- with its popover, and the daily goal tracker. Nothing else covers the world.
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
local Hud = {}

export type Hud = {
	root: Frame,
	coins: TextButton,
	home: TextButton,
	daily: TextButton,
	gear: TextButton,
	menu: Menu.Menu,
	layout: (Layout.Frame, opened: boolean) -> (),
	update: (Types.Snapshot) -> (),
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
	end)
	-- Functional placeholder only. Final iconography and positioning remain future UI work.
	local home = Instance.new("TextButton")
	home.Name = "HomeButton"
	home.Text = "Home"
	home.TextSize = 18
	home.FontFace = Style.display()
	home.TextColor3 = Style.ink
	home.AutoButtonColor = true
	home.BackgroundColor3 = Style.white
	home.ZIndex = 2
	home.Parent = root
	home:SetAttribute("AccessibleName", "Return Home to your plot")
	Kit.round(home)
	Kit.stroke(home, Style.ink)
	ctx.scope.connect(home.Activated, goHome)
	local daily = Instance.new("TextButton")
	daily.Name = "DailyButton"
	daily.Text = "Daily"
	daily.TextSize = 18
	daily.FontFace = Style.display()
	daily.TextColor3 = Style.ink
	daily.AutoButtonColor = true
	daily.BackgroundColor3 = Style.white
	daily.ZIndex = 2
	daily.Parent = root
	daily:SetAttribute("AccessibleName", "Daily Login rewards")
	Kit.round(daily)
	Kit.stroke(daily, Style.ink)
	local dailyBadge = Badge.corner(daily, "Ready", {
		fill = Style.alert,
		color = Style.white,
		height = 22,
		size = 13,
		outline = Style.ink,
	}, Vector2.new(1, 0), Vector2.new(6, -8))
	ctx.scope.connect(daily.Activated, function()
		ctx.navigate("Login")
	end)
	local right = Kit.frame(root, "Right")
	local gearShadow = Kit.frame(right, "GearShadow", Style.ink)
	gearShadow.ZIndex = 1
	Kit.round(gearShadow)
	local gear = Instance.new("TextButton")
	gear.Name = "SettingsButton"
	gear.Text = ""
	gear.AutoButtonColor = false
	gear.BackgroundColor3 = Style.white
	gear.ZIndex = 2
	gear.Parent = right
	gear:SetAttribute("AccessibleName", "Settings")
	Kit.round(gear)
	Kit.stroke(gear, Style.ink)
	local gearIcon = Icons.create(gear, "Gear", Style.ink, 26)
	gearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gearIcon.Position = UDim2.fromScale(0.5, 0.5)
	local tracker = Tracker.create(right, ctx)
	local menu = Menu.create(parent, ctx, setMotion)
	ctx.scope.connect(gear.Activated, function()
		menu.set(not menu.open())
	end)
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
	return {
		root = root,
		coins = coins,
		home = home,
		daily = daily,
		gear = gear,
		menu = menu,
		layout = function(geometry: Layout.Frame, opened: boolean)
			frame = geometry
			local phone = geometry.phone
			coins.Position = UDim2.fromOffset(geometry.hud.x, geometry.hud.y)
			coins.Size = UDim2.fromOffset(0, geometry.hud.height)
			coin.Size = UDim2.fromOffset(if phone then 24 else 30, if phone then 24 else 30)
			amount.TextSize = if phone then 19 else 24
			-- Phone sheets carry their own coins chip; the HUD hides under an open sheet.
			coins.Visible = not (phone and opened)
			coinShadow.Visible = coins.Visible
			Kit.rect(home, math.max(12, geometry.hud.x), geometry.dock.y - 54, 96, 44)
			home.Visible = not opened
			Kit.rect(daily, math.max(12, geometry.hud.x), geometry.dock.y - 106, 96, 44)
			daily.Visible = not opened
			Kit.rect(
				gear,
				geometry.gear.x,
				geometry.gear.y,
				geometry.gear.width,
				geometry.gear.height
			)
			Kit.rect(
				gearShadow,
				geometry.gear.x,
				geometry.gear.y + (if phone then 3 else 4),
				geometry.gear.width,
				geometry.gear.height
			)
			tracker.layout(geometry.tracker.x, geometry.tracker.y, phone)
			menu.place(
				geometry.gear.x + geometry.gear.width - 280,
				geometry.gear.y + geometry.gear.height + 10
			)
			right.Visible = not opened
			if opened then
				menu.set(false)
			end
			follow()
		end,
		update = function(snapshot: Types.Snapshot)
			amount.Text = if snapshot.coins >= 1e7
				then State.compact(snapshot.coins)
				else State.number(snapshot.coins)
			rate.set(State.rate(State.totalRate(snapshot)))
			coins:SetAttribute(
				"AccessibleName",
				amount.Text .. " coins, earning " .. rate.label.Text
			)
			tracker.update(snapshot)
			local ready = State.badges(snapshot).Login
			dailyBadge.root.Visible = ready ~= nil
			dailyBadge.set(ready or "")
		end,
	}
end

return Hud

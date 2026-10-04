--!strict
-- Owns the client UI tree: HUD, dock, the world dim, the five screens and gamepad routing.
-- Screens never mutate state; they request intents through ctx.send and render snapshots.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
local Tweens = game:GetService("TweenService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Scope = require(script.Parent.UIScope)
local Context = require(script.Parent.UIContext)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Layout = require(script.Parent.UILayout)
local State = require(script.Parent.UIState)
local Navigation = require(script.Parent.NavigationConfig)
local Hud = require(script.Parent.Hud)
local Dock = require(script.Parent.Dock)
local Notifications = require(script.Parent.Notifications)
local Collection = require(script.Parent.CollectionScreen)
local Shop = require(script.Parent.ShopScreen)
local Display = require(script.Parent.DisplayScreen)
local Goals = require(script.Parent.GoalsScreen)
local Shelves = require(script.Parent.ShelvesScreen)
local Login = require(script.Parent.LoginScreen)
local Onboarding = require(script.Parent.Onboarding)
local Sfx = require(script.Parent.Sfx)
local Interface = {}
export type Interface = {
	update: (Types.Snapshot) -> (),
	message: (string, string?) -> (),
	effects: () -> boolean,
	openingFocus: (boolean) -> (),
	pending: (boolean) -> (),
	openDisplay: () -> (),
	openShelves: () -> (),
	coinLanded: () -> (),
	destroy: () -> (),
}

local function gamepad(): boolean
	return string.find(Input:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

function Interface.create(
	send: (string, string?, number?, string?, number?) -> (),
	home: (() -> ())?
): Interface
	local scope = Scope.create()
	local snapshot: Types.Snapshot? = nil
	-- Daily Login opens itself at most once per session, on the first ready snapshot.
	local loginChecked = false
	local effects, focused, pending, opened, destroyed = true, false, false, false, false
	local current = "Collection"
	local blockedStatus: string? = nil
	local previewShown = false
	local scale = 1
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "PocketGrove"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Device-safe (notches) but under the top bar; the HUD reads TopbarInset to sit beside it.
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Parent = playerGui
	local bounds = Kit.frame(gui, "SafeArea")
	local stage = Kit.frame(bounds, "Stage")
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = stage
	-- One violet ring for gamepad selection everywhere.
	local ring = Instance.new("Frame")
	ring.Name = "SelectionRing"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	Kit.corner(ring, 16)
	Kit.stroke(ring, Style.violet, 4)
	local previousRing = playerGui.SelectionImageObject
	playerGui.SelectionImageObject = ring
	scope.add(function()
		if playerGui.SelectionImageObject == ring then
			playerGui.SelectionImageObject = previousRing
		end
		ring:Destroy()
	end)
	local dim = Instance.new("TextButton")
	dim.Name = "Backdrop"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BorderSizePixel = 0
	dim.BackgroundColor3 = Style.dim
	dim.BackgroundTransparency = Style.dimTransparency
	dim.Selectable = false
	dim.Modal = true
	dim.Visible = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = stage
	local screensRoot = Kit.frame(stage, "Screens")
	screensRoot.ZIndex = 10
	local hosts: { [string]: Frame } = {}
	for _, id in Navigation.pages do
		local host = Kit.frame(screensRoot, id .. "Presentation")
		host.SelectionGroup = true
		host.Visible = false
		hosts[id] = host
	end
	-- Daily Login is a routed screen without a dock tile; the HUD Daily button opens it.
	local loginHost = Kit.frame(screensRoot, "LoginPresentation")
	loginHost.SelectionGroup = true
	loginHost.Visible = false
	hosts.Login = loginHost
	local notices = Notifications.create(stage, scope)
	local navigate: (string, Context.Route?) -> () = function() end
	local close: () -> () = function() end
	local function canAct(): boolean
		return snapshot ~= nil and snapshot.ready and not pending and not focused and not destroyed
	end
	local ctx: Context.Context = {
		scope = scope,
		effects = function()
			return effects
		end,
		scale = function()
			return scale
		end,
		snapshot = function()
			return snapshot
		end,
		canAct = canAct,
		send = function(action, figure, slot, choice, volume)
			if canAct() then
				send(action, figure, slot, choice, volume)
			end
		end,
		navigate = function(page, route)
			navigate(page, route)
		end,
		close = function()
			close()
		end,
		message = function(text)
			notices.show(text, "info")
		end,
	}
	local now = function()
		return workspace:GetServerTimeNow()
	end
	local screens: { [string]: Context.Screen } = {
		Collection = Collection.create(hosts.Collection, ctx),
		Display = Display.create(hosts.Display, ctx),
		Shop = Shop.create(hosts.Shop, ctx),
		Goals = Goals.create(hosts.Goals, ctx, now),
		Shelves = Shelves.create(hosts.Shelves, ctx),
		Login = Login.create(hosts.Login, ctx),
	}
	local hud = Hud.create(stage, ctx, function(value: boolean)
		effects = value
	end, function()
		if canAct() and home then
			home()
		end
	end)
	local dock = Dock.create(stage, ctx, function(id)
		if opened and current == id then
			close()
		else
			navigate(id)
		end
	end)
	local tutorial = Onboarding.create(stage, scope, dock.tiles, hosts)
	local frame: Layout.Frame? = nil
	local laidOut: { [string]: string } = {}
	local function layoutScreen(id: string)
		local geometry = frame
		if not geometry then
			return
		end
		local panel = geometry.panel
		local key = `{panel.width}:{panel.height}:{geometry.phone}`
		if laidOut[id] ~= key then
			laidOut[id] = key
			screens[id].layout(panel.width, panel.height, geometry.phone)
		end
	end
	local function selectPage()
		if not gamepad() then
			return
		end
		local host = hosts[current]
		GuiService.SelectedObject = if opened
			then host:FindFirstChild("Close", true) :: GuiObject?
			else dock.tiles[current]
	end
	local function resize()
		local size = bounds.AbsoluteSize
		local inset = GuiService.TopbarInset
		local origin = bounds.AbsolutePosition
		local right = if inset.Max.X > inset.Min.X then inset.Max.X - origin.X else size.X
		local geometry = Layout.frame(size.X, size.Y, {
			left = math.max(0, inset.Min.X - origin.X),
			right = right,
		})
		frame = geometry
		scale = geometry.scale
		uiScale.Scale = scale
		stage.Size = UDim2.fromScale(1 / scale, 1 / scale)
		dim.Visible = opened
		hud.layout(geometry, opened)
		tutorial.layout(geometry, opened)
		dock.layout(geometry.dock, geometry.phone)
		dock.root.Visible = not opened or geometry.dockWhileOpen
		local panel = geometry.panel
		for id, host in hosts do
			Kit.rect(host, panel.x, panel.y, panel.width, panel.height)
			host.Visible = opened and current == id
		end
		if opened then
			layoutScreen(current)
		end
		local toastWidth = math.min(520, geometry.width - 32)
		local bottom = if not opened
			then geometry.dock.y - 12
			elseif geometry.dockWhileOpen then geometry.panel.y - 6
			else geometry.panel.y + geometry.panel.height - 12
		notices.place(geometry.width / 2, bottom, toastWidth)
	end
	local function refresh()
		local state = snapshot
		dock.set(if opened then current else nil, if state then State.badges(state) else nil)
		if not state then
			return
		end
		hud.update(state)
		tutorial.update(state, if opened then current else nil)
		if not state.ready and blockedStatus ~= state.saveStatus then
			notices.show(state.saveStatus, "error")
		elseif
			state.ready
			and not previewShown
			and string.find(string.lower(state.saveStatus), "preview", 1, true)
		then
			previewShown = true
			notices.show(state.saveStatus, "info")
		end
		blockedStatus = if state.ready then nil else state.saveStatus
		-- Only the visible screen renders snapshots; others refresh when they open.
		if opened then
			screens[current].update(state)
		end
	end
	local function show(id: string, value: boolean)
		local shown = screens[id].shown
		if shown then
			shown(value)
		end
	end
	navigate = function(id: string, route: Context.Route?)
		if focused or not screens[id] then
			return
		end
		if opened and current ~= id then
			show(current, false)
		end
		local wasOpen = opened and current == id
		if not wasOpen then
			Sfx.play(if opened then "tab" else "open")
		end
		current = id
		opened = true
		hud.menu.set(false)
		resize()
		local screen = screens[id]
		if screen.route then
			screen.route(route)
		end
		refresh()
		if not wasOpen then
			show(id, true)
		end
		selectPage()
	end
	close = function()
		if not opened then
			return
		end
		show(current, false)
		opened = false
		Sfx.play("close")
		resize()
		refresh()
		selectPage()
	end
	local function back()
		if hud.menu.open() then
			hud.menu.set(false)
			return
		end
		local screenBack = screens[current].back
		if opened and screenBack and screenBack() then
			return
		end
		close()
	end
	scope.connect(dim.Activated, back)
	scope.connect(bounds:GetPropertyChangedSignal("AbsoluteSize"), resize)
	scope.connect(GuiService:GetPropertyChangedSignal("TopbarInset"), resize)
	-- Keep the gamepad selection inside its scroller (CanvasPosition is in design units).
	scope.connect(GuiService:GetPropertyChangedSignal("SelectedObject"), function()
		local selected = GuiService.SelectedObject
		if not selected or not selected:IsDescendantOf(gui) then
			return
		end
		local ancestor = selected.Parent
		while ancestor and ancestor ~= gui do
			if
				ancestor:IsA("ScrollingFrame")
				and ancestor.ScrollingDirection ~= Enum.ScrollingDirection.X
			then
				local top = selected.AbsolutePosition.Y - ancestor.AbsolutePosition.Y
				local bottom = top + selected.AbsoluteSize.Y
				local window = ancestor.AbsoluteWindowSize.Y
				local shift = if top < 4
					then top - 4
					elseif bottom > window - 4 then bottom - window + 4
					else 0
				local limit = math.max(0, ancestor.CanvasSize.Y.Offset - window / scale)
				ancestor.CanvasPosition = Vector2.new(
					ancestor.CanvasPosition.X,
					math.clamp(ancestor.CanvasPosition.Y + shift / scale, 0, limit)
				)
				break
			end
			ancestor = ancestor.Parent
		end
	end)
	Actions:BindActionAtPriority(
		"CollectibleMenu",
		function(_, inputState, input)
			if focused then
				return Enum.ContextActionResult.Pass
			end
			local key = input.KeyCode
			local menuOpen = hud.menu.open()
			if not opened and not menuOpen and key ~= Enum.KeyCode.ButtonY then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin then
				if key == Enum.KeyCode.ButtonY then
					if opened then
						close()
					else
						navigate(current)
					end
				elseif key == Enum.KeyCode.ButtonB then
					back()
				elseif opened then
					local index = table.find(Navigation.pages, current) or 1
					local step = if key == Enum.KeyCode.ButtonR1 then 1 else -1
					navigate(Navigation.pages[(index - 1 + step) % #Navigation.pages + 1])
				end
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		2000,
		Enum.KeyCode.ButtonY,
		Enum.KeyCode.ButtonB,
		Enum.KeyCode.ButtonL1,
		Enum.KeyCode.ButtonR1
	)
	scope.add(function()
		Actions:UnbindAction("CollectibleMenu")
	end)
	resize()
	refresh()
	return {
		openDisplay = function()
			if canAct() and not opened then
				navigate("Display")
			end
		end,
		openShelves = function()
			if canAct() and not opened then
				navigate("Shelves")
			end
		end,
		update = function(state: Types.Snapshot)
			snapshot = state
			refresh()
			if not loginChecked and state.ready then
				loginChecked = true
				-- Skipped for brand-new players so onboarding's free-box hints stay uncovered.
				if state.loginReady and next(state.owned) ~= nil and not opened then
					navigate("Login")
				end
			end
		end,
		-- Each flying coin that reaches the player kicks the Coins pill.
		coinLanded = function()
			local pop = hud.coins:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			pop.Parent = hud.coins
			pop.Scale = 1.16
			Sfx.play("coinLand")
			Tweens:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end,
		message = notices.show,
		effects = ctx.effects,
		pending = function(value: boolean)
			pending = value
			refresh()
		end,
		openingFocus = function(value: boolean)
			focused = value
			gui.Enabled = not value
			if not value then
				resize()
			end
			refresh()
		end,
		destroy = function()
			destroyed = true
			if opened then
				show(current, false)
			end
			scope.destroy()
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
			gui:Destroy()
		end,
	}
end
return Interface

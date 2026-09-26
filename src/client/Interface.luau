--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Scope = require(script.Parent.UIScope)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local Layout = require(script.Parent.UILayout)
local Icons = require(script.Parent.UIIcons)
local W = require(script.Parent.Widgets)
local Hud = require(script.Parent.Hud)
local Navigation = require(script.Parent.Navigation)
local Notifications = require(script.Parent.Notifications)
local BackgroundTreatment = require(script.Parent.BackgroundTreatment)
local Collection = require(script.Parent.CollectionScreen)
local Shop = require(script.Parent.ShopScreen)
local Showroom = require(script.Parent.ShowroomScreen)
local Goals = require(script.Parent.GoalsScreen)
local Visits = require(script.Parent.VisitsScreen)
local Interface = {}
export type Interface = {
	update: (Types.Snapshot) -> (),
	message: (string, string?) -> (),
	effects: () -> boolean,
	selectAcquired: (string) -> (),
	openingFocus: (boolean) -> (),
	pending: (boolean) -> (),
	destroy: () -> (),
}
function Interface.create(
	send: (string, string?, number?, string?) -> (),
	visit: (number) -> ()
): Interface
	local scope = Scope.create()
	local snapshot: Types.Snapshot? = nil
	local effects, focused, pending, opened, destroyed = true, false, false, false, false
	local current = "Collection"
	local targetSlot: number? = nil
	local blockedStatus: string? = nil
	local previewShown = false
	local gui = Instance.new("ScreenGui")
	gui.Name = "PocketGrove"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local bounds = W.frame(gui, "SafeArea")
	local background = BackgroundTreatment.create(bounds, scope)
	local shade = background.overlay
	local pagesRoot = W.frame(bounds, "Screens")
	local controls = W.frame(bounds, "ScreenControls")
	controls.ZIndex = 5
	controls.Size = UDim2.fromOffset(154, 44)
	local hosts: { [string]: Frame } = {}
	for _, id in { "Collection", "Display", "Shop", "Goals", "Visits" } do
		local host = W.frame(pagesRoot, id .. "Presentation")
		host.SelectionGroup = true
		host.Active = true
		host:SetAttribute("Presentation", true)
		hosts[id] = host
		if id ~= "Collection" and id ~= "Shop" then
			local shadow = W.frame(host, "Shadow", Theme.shadow)
			shadow.Position = UDim2.fromOffset(0, 6)
			shadow.BackgroundTransparency = 0.84
			W.corner(shadow, 18)
		end
	end
	local notices = Notifications.create(bounds, scope)
	local navigate: (string) -> () = function() end
	local inspect: (string) -> () = function() end
	local place: (string) -> () = function() end
	local pick: (number) -> () = function() end
	local function canAct(): boolean
		return snapshot ~= nil and snapshot.ready and not pending and not focused and not destroyed
	end
	local ctx: Context.Context = {
		scope = scope,
		effects = function()
			return effects
		end,
		snapshot = function()
			return snapshot
		end,
		canAct = canAct,
		send = function(action, figure, slot, choice)
			if canAct() then
				send(action, figure, slot, choice)
			end
		end,
		visit = function(target)
			if not focused and snapshot and snapshot.ready then
				visit(target)
			end
		end,
		navigate = function(page)
			navigate(page)
		end,
		inspect = function(id)
			inspect(id)
		end,
		place = function(id)
			place(id)
		end,
		pick = function(slot)
			pick(slot)
		end,
		message = function(text)
			notices.show(text, "info")
		end,
	}
	local collection = Collection.create(hosts.Collection, ctx)
	local showroom = Showroom.create(hosts.Display, ctx)
	local pages: { [string]: Context.Screen } = {
		Collection = { root = collection.root, update = collection.update, back = collection.back },
		Display = { root = showroom.root, update = showroom.update, back = showroom.back },
		Shop = Shop.create(hosts.Shop, ctx),
		Goals = Goals.create(hosts.Goals, ctx),
		Visits = Visits.create(hosts.Visits, ctx),
	}
	local hud = Hud.create(bounds, ctx)
	local refresh: () -> () = function() end
	local resize: () -> () = function() end
	local selectPage: () -> () = function() end
	local nav = Navigation.create(bounds, ctx, function(id)
		if opened and current == id then
			opened = false
			targetSlot = nil
			resize()
			refresh()
			selectPage()
		else
			if id == "Collection" then
				collection.showBook()
			end
			navigate(id)
		end
	end)
	local close = W.action(controls, "", scope, ctx.effects, function()
		opened = false
		targetSlot = nil
		resize()
		refresh()
		selectPage()
	end, true)
	close.button.Name = "CloseMenu"
	close.button.Size = UDim2.fromOffset(44, 44)
	close.button.Position = UDim2.fromOffset(110, 0)
	local closeIcon = Icons.create(close.button, "Close", Theme.ink)
	closeIcon.Position = UDim2.fromOffset(10, 10)
	local motion: W.Action? = nil
	motion = W.action(controls, "Motion: on", scope, ctx.effects, function()
		effects = not effects
		if motion then
			motion.set(if effects then "Motion: on" else "Motion: low", true, not effects)
		end
	end, true)
	assert(motion, "Motion control was not created")
	motion.button.Name = "MotionPreference"
	motion.button.Size = UDim2.fromOffset(96, 44)
	motion.button.Position = UDim2.fromOffset(6, 0)
	local nextStep = W.action(bounds, "Find your first box", scope, ctx.effects, function()
		navigate(if snapshot and snapshot.step == 2 then "Collection" else "Shop")
	end)
	nextStep.button.Name = "NextStep"
	nextStep.button.AnchorPoint = Vector2.new(0.5, 1)
	nextStep.button.Position = UDim2.new(0.5, 0, 1, -84)
	nextStep.button.Size = UDim2.new(0.8, 0, 0, 48)
	local stepLimit = Instance.new("UISizeConstraint")
	stepLimit.MaxSize = Vector2.new(320, 48)
	stepLimit.Parent = nextStep.button
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DisplayRate"
	billboard.Size = UDim2.fromOffset(190, 38)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 45
	billboard.Parent = gui
	local rate = W.label(billboard, "", 38, 16)
	rate.BackgroundColor3 = Theme.paper
	rate.BackgroundTransparency = 0.12
	rate.TextXAlignment = Enum.TextXAlignment.Center
	W.corner(rate, 14)
	local function gamepad(): boolean
		return string.find(Input:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
	end
	selectPage = function()
		if gamepad() then
			GuiService.SelectedObject = if opened then close.button else nav.actions[current].button
		end
	end
	resize = function()
		local size = bounds.AbsoluteSize
		local desktop = Layout.desktop(size.X, size.Y, Input.TouchEnabled)
		for id, host in hosts do
			local rect = Layout.screen(id, size.X, size.Y, desktop)
			host.Position = UDim2.fromOffset(rect.x, rect.y)
			host.Size = UDim2.fromOffset(rect.width, rect.height)
			host.Visible = opened and current == id
		end
		pagesRoot.Visible = opened
		controls.Visible = opened
		local active = hosts[current]
		-- Short/touch layouts reserve a separate top row so controls never overlap currency.
		controls.Position = UDim2.fromOffset(size.X - 166, if size.X < 480 then 8 else 10)
		hud.root.Visible = not opened or size.X >= 480
		if current == "Collection" and opened then
			controls.Size = UDim2.fromOffset(44, 44)
			controls.Position = UDim2.fromOffset(
				active.Position.X.Offset + active.Size.X.Offset - 44,
				math.max(8, active.Position.Y.Offset - 22)
			)
			close.button.Position = UDim2.fromOffset(0, 0)
			motion.button.Visible = false
			hud.root.Visible = true
		else
			controls.Size = UDim2.fromOffset(154, 44)
			close.button.Position = UDim2.fromOffset(110, 0)
			motion.button.Visible = true
		end
		if opened and current == "Shop" then
			background.set({
				color = Color3.fromRGB(73, 52, 38),
				transparency = 0.62,
				blur = 8,
			})
		elseif opened and current == "Collection" then
			background.set({ color = Theme.shadow, transparency = 0.72, blur = 0 })
		else
			background.set(nil)
		end
		nav.layout(size, desktop)
		nav.root.Visible = not opened or size.Y >= 420
		nextStep.button.Position = UDim2.new(0.5, 0, 1, if desktop then -24 else -80)
		notices.root.Position = UDim2.new(
			0.5,
			if desktop then 48 else 0,
			1,
			if opened and size.Y < 420 then -12 elseif desktop then -16 else -76
		)
		notices.root.Size =
			UDim2.new(1, if desktop then -180 else -32, 0, notices.root.Size.Y.Offset)
		active:SetAttribute("SlotPicker", if targetSlot then targetSlot else nil)
	end
	refresh = function()
		for id, page in pages do
			page.root.Visible = current == id
		end
		local state = snapshot
		nav.set(if opened then current else nil, state ~= nil and state.dailyReady)
		nextStep.button.Visible = not opened and state ~= nil and state.ready and state.step <= 2
		if state then
			hud.update(state)
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
			nextStep.set(
				if state.step == 2 then "Display your first figure" else "Find your first box",
				true
			)
			for _, page in pages do
				page.update(state)
			end
			local rooms = workspace:FindFirstChild("Showrooms")
			local room = if rooms then rooms:FindFirstChild(tostring(state.visiting)) else nil
			local shelf = if room then room:FindFirstChild("Shelf") else nil
			billboard.Adornee = if shelf and shelf:IsA("BasePart") then shelf else nil
			billboard.Enabled = shelf ~= nil and not focused and not opened
			local income = state.rate
			for _, public in state.rooms do
				if public.userId == state.visiting then
					income = public.rate
				end
			end
			rate.Text = string.format("%g Coins/sec", income)
		end
	end
	navigate = function(id: string)
		if focused or not pages[id] then
			return
		end
		if id ~= "Collection" then
			targetSlot = nil
		end
		current = id
		opened = true
		resize()
		refresh()
		selectPage()
	end
	inspect = function(id: string)
		collection.inspect(id)
	end
	place = function(id: string)
		if targetSlot then
			ctx.send("Place", id, targetSlot, nil)
			targetSlot = nil
			showroom.select(nil)
		else
			showroom.select(id)
		end
		navigate("Display")
	end
	pick = function(slot: number)
		targetSlot = slot
		collection.showBook(true)
		navigate("Collection")
	end
	local function back()
		local page = pages[current]
		if not (page.back and page.back()) then
			opened = false
			targetSlot = nil
		end
		resize()
		refresh()
		selectPage()
	end
	scope.connect(shade.Activated, back)
	scope.connect(bounds:GetPropertyChangedSignal("AbsoluteSize"), resize)
	scope.connect(GuiService:GetPropertyChangedSignal("SelectedObject"), function()
		local selected = GuiService.SelectedObject
		if not selected or not selected:IsDescendantOf(gui) then
			return
		end
		local ancestor = selected.Parent
		while ancestor and ancestor ~= gui do
			if ancestor:IsA("ScrollingFrame") then
				local nextX, nextY = ancestor.CanvasPosition.X, ancestor.CanvasPosition.Y
				if ancestor.ScrollingDirection ~= Enum.ScrollingDirection.Y then
					local left = selected.AbsolutePosition.X - ancestor.AbsolutePosition.X
					local right = left + selected.AbsoluteSize.X
					local shift = if left < 4
						then left - 4
						elseif right > ancestor.AbsoluteWindowSize.X - 4 then right
							- ancestor.AbsoluteWindowSize.X
							+ 4
						else 0
					nextX = math.clamp(
						nextX + shift,
						0,
						math.max(0, ancestor.AbsoluteCanvasSize.X - ancestor.AbsoluteWindowSize.X)
					)
				end
				if ancestor.ScrollingDirection ~= Enum.ScrollingDirection.X then
					local top = selected.AbsolutePosition.Y - ancestor.AbsolutePosition.Y
					local bottom = top + selected.AbsoluteSize.Y
					local shift = if top < 4
						then top - 4
						elseif bottom > ancestor.AbsoluteWindowSize.Y - 4 then bottom
							- ancestor.AbsoluteWindowSize.Y
							+ 4
						else 0
					nextY = math.clamp(
						nextY + shift,
						0,
						math.max(0, ancestor.AbsoluteCanvasSize.Y - ancestor.AbsoluteWindowSize.Y)
					)
				end
				ancestor.CanvasPosition = Vector2.new(nextX, nextY)
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
			if not opened and input.KeyCode ~= Enum.KeyCode.ButtonY then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin then
				if input.KeyCode == Enum.KeyCode.ButtonY then
					if opened then
						back()
					else
						navigate(current)
					end
				elseif opened and input.KeyCode == Enum.KeyCode.ButtonB then
					back()
				elseif opened then
					local index = table.find(Navigation.pages, current) or 1
					navigate(
						Navigation.pages[(index - 1 + (if input.KeyCode
								== Enum.KeyCode.ButtonR1
							then 1
							else -1)) % #Navigation.pages + 1]
					)
				else
					return Enum.ContextActionResult.Pass
				end
			end
			return if opened
					or input.KeyCode == Enum.KeyCode.ButtonY
					or input.KeyCode == Enum.KeyCode.ButtonB
				then Enum.ContextActionResult.Sink
				else Enum.ContextActionResult.Pass
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
		update = function(state: Types.Snapshot)
			snapshot = state
			refresh()
		end,
		message = notices.show,
		effects = ctx.effects,
		pending = function(value: boolean)
			pending = value
			refresh()
		end,
		selectAcquired = function(id: string)
			collection.selectAcquired(id)
			-- The opening captures/restores this selection; keep it on the visible screen.
			selectPage()
		end,
		openingFocus = function(value: boolean)
			focused = value
			gui.Enabled = not value
			if value then
				background.set(nil)
			else
				resize()
			end
			refresh()
		end,
		destroy = function()
			destroyed = true
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

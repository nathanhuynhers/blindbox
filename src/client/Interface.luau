--!strict
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Scope = require(script.Parent.UIScope)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local State = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Hud = require(script.Parent.Hud)
local Navigation = require(script.Parent.Navigation)
local Notifications = require(script.Parent.Notifications)
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
	local gui = Instance.new("ScreenGui")
	gui.Name = "PocketGrove"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local bounds = W.frame(gui, "SafeArea")
	local shade = Instance.new("TextButton")
	shade.Name = "Backdrop"
	shade.Size = UDim2.fromScale(1, 1)
	shade.Text = ""
	shade.BackgroundColor3 = Theme.shadow
	shade.BackgroundTransparency = 0.6
	shade.BorderSizePixel = 0
	shade.Selectable = false
	shade.Modal = true
	shade.AutoButtonColor = false
	shade.Parent = bounds
	local shadow = W.frame(bounds, "MenuShadow", Theme.shadow)
	shadow.BackgroundTransparency = 0.72
	W.corner(shadow, 24)
	local panel = W.frame(bounds, "Menu", Theme.paper)
	W.corner(panel, 22)
	panel.SelectionGroup = true
	local title = W.title(panel, "Collection", 28)
	title.Position = UDim2.fromOffset(16, 2)
	title.Size = UDim2.new(1, -174, 0, 28)
	title.TextSize = 23
	local balance = W.label(panel, "Loading...", 18, 13)
	balance.Position = UDim2.fromOffset(16, 30)
	balance.Size = UDim2.new(1, -174, 0, 18)
	balance.TextColor3 = Theme.muted
	local pagesRoot = W.frame(panel, "Screens")
	pagesRoot.Position = UDim2.fromOffset(4, 56)
	pagesRoot.Size = UDim2.new(1, -8, 1, -64)
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
	local collection = Collection.create(pagesRoot, ctx)
	local showroom = Showroom.create(pagesRoot, ctx)
	local pages: { [string]: Context.Screen } = {
		Collection = { root = collection.root, update = collection.update, back = collection.back },
		Display = { root = showroom.root, update = showroom.update },
		Shop = Shop.create(pagesRoot, ctx),
		Goals = Goals.create(pagesRoot, ctx),
		Visits = Visits.create(pagesRoot, ctx),
	}
	local hud = Hud.create(bounds, ctx)
	local refresh: () -> () = function() end
	local resize: () -> () = function() end
	local nav = Navigation.create(bounds, ctx, function(id)
		if opened and current == id then
			opened = false
			targetSlot = nil
			resize()
			refresh()
		else
			if id == "Collection" then
				collection.showBook()
			end
			navigate(id)
		end
	end)
	local close = W.action(panel, "X", scope, ctx.effects, function()
		opened = false
		targetSlot = nil
		resize()
		refresh()
	end, true)
	close.button.Name = "CloseMenu"
	close.button.Size = UDim2.fromOffset(44, 44)
	close.button.Position = UDim2.new(1, -52, 0, 6)
	local motion: W.Action? = nil
	motion = W.action(panel, "Motion: on", scope, ctx.effects, function()
		effects = not effects
		if motion then
			motion.set(if effects then "Motion: on" else "Motion: low", true, not effects)
		end
	end, true)
	assert(motion, "Motion control was not created")
	motion.button.Name = "MotionPreference"
	motion.button.Size = UDim2.fromOffset(96, 44)
	motion.button.Position = UDim2.new(1, -156, 0, 6)
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
	local function selectPage()
		if gamepad() then
			GuiService.SelectedObject = if opened then close.button else nav.actions[current].button
		end
	end
	resize = function()
		local size = bounds.AbsoluteSize
		local rail = opened and size.Y < 500
		local width = if rail
			then math.max(160, size.X - 88)
			else math.min(1000, math.max(180, size.X - 24))
		local height = if rail then size.Y - 16 else math.min(680, math.max(140, size.Y - 156))
		panel.AnchorPoint = if rail then Vector2.zero else Vector2.new(0.5, 0)
		panel.Position = if rail then UDim2.fromOffset(80, 8) else UDim2.new(0.5, 0, 0, 72)
		panel.Size = UDim2.fromOffset(width, height)
		shadow.AnchorPoint = panel.AnchorPoint
		shadow.Size = panel.Size
		shadow.Position = panel.Position + UDim2.fromOffset(0, 6)
		panel.Visible = opened
		shadow.Visible = opened
		shade.Visible = opened
		hud.root.Visible = not rail
		balance.Visible = rail
		title.Position = UDim2.fromOffset(16, if rail then 2 else 12)
		nav.layout(size, rail)
		notices.root.Position = if rail
			then UDim2.new(0.5, 32, 1, -12)
			else UDim2.new(0.5, 0, 1, -82)
		notices.root.Size = UDim2.new(1, if rail then -104 else -32, 0, notices.root.Size.Y.Offset)
	end
	refresh = function()
		for id, page in pages do
			page.root.Visible = current == id
		end
		title.Text = if current == "Display"
			then "Showroom"
			elseif current == "Collection" and targetSlot then "Pick for slot " .. targetSlot
			else current
		local state = snapshot
		nav.set(if opened then current else nil, state ~= nil and state.dailyReady)
		nextStep.button.Visible = not opened and state ~= nil and state.ready and state.step <= 2
		if state then
			hud.update(state)
			if not state.ready and blockedStatus ~= state.saveStatus then
				notices.show(state.saveStatus, "error")
			end
			blockedStatus = if state.ready then nil else state.saveStatus
			balance.Text = if pending
				then "Waiting for server..."
				elseif not state.ready then "Progress paused"
				else State.number(state.coins)
					.. " Coins  ·  "
					.. State.number(state.scrap)
					.. " Scrap"
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
	scope.connect(panel:GetPropertyChangedSignal("Visible"), selectPage)
	scope.connect(bounds:GetPropertyChangedSignal("AbsoluteSize"), resize)
	scope.connect(GuiService:GetPropertyChangedSignal("SelectedObject"), function()
		local selected = GuiService.SelectedObject
		if not selected or not selected:IsDescendantOf(gui) then
			return
		end
		local ancestor = selected.Parent
		while ancestor and ancestor ~= gui do
			if ancestor:IsA("ScrollingFrame") then
				local top = selected.AbsolutePosition.Y - ancestor.AbsolutePosition.Y
				local bottom = top + selected.AbsoluteSize.Y
				local shift = if top < 4
					then top - 4
					elseif bottom > ancestor.AbsoluteWindowSize.Y - 4 then bottom
						- ancestor.AbsoluteWindowSize.Y
						+ 4
					else 0
				ancestor.CanvasPosition = Vector2.new(
					0,
					math.clamp(
						ancestor.CanvasPosition.Y + shift,
						0,
						math.max(0, ancestor.AbsoluteCanvasSize.Y - ancestor.AbsoluteWindowSize.Y)
					)
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

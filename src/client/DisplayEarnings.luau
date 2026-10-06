--!strict
-- Owner-only banked Coins above each displayed figure, plus the collect animation.
-- Presentation only: snapshot earnings stay authoritative; a local click/tap merely predicts
-- the burst, and the server's collect reply confirms the amount.
local Players = game:GetService("Players")
local Tweens = game:GetService("TweenService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local UIState = require(script.Parent.UIState)
local Style = require(script.Parent.UIStyle)
local CoinBurst = require(script.Parent.CoinBurst)
local Icons = require(script.Parent.UIIcons)
local Sfx = require(script.Parent.Sfx)
local Counter = require(script.Parent.CoinCounter)
local Scope = require(script.Parent.UIScope)
local Earnings = {}

local height = 3.9 -- Studs above the collector target's centre, just over the figure's head.
local reach = 12 -- Mirrors the server's collect distance so prediction matches its decision.
local hold = 1.5 -- Seconds a predicted "0" wins over older snapshots awaiting the reply.

type Flight = { count: number, impacts: number, complete: boolean, token: number? }
type Label = {
	gui: BillboardGui,
	text: TextLabel,
	scale: UIScale,
	target: BasePart?,
	click: RBXScriptConnection?,
	heldUntil: number,
	burstAt: number,
	flight: Flight?,
	pop: Tween?,
}
local temporary: { [Scope.Scope]: boolean } = {}
local function temporaryScope(): Scope.Scope
	local scope = Scope.create()
	temporary[scope] = true
	scope.add(function()
		temporary[scope] = nil
	end)
	return scope
end

local function ownCollectors(): Instance?
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = if plots then plots:FindFirstChild(tostring(Players.LocalPlayer.UserId)) else nil
	return if plot and plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId
		then plot:FindFirstChild("FigureCollectors")
		else nil
end

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local playing = Tweens:Create(instance, info, goal)
	playing:Play()
	return playing
end

local function newLabel(slot: number): Label
	local gui = Instance.new("BillboardGui")
	gui.Name = "FigureEarnings" .. slot
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.LightInfluence = 0 -- Full brightness at night.
	gui.MaxDistance = 70
	gui.ClipsDescendants = false
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	Icons.create(row, "Coin", Style.gold, 22).LayoutOrder = 1
	local text = Instance.new("TextLabel")
	text.Name = "Amount"
	text.LayoutOrder = 2
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromScale(0, 1)
	text.FontFace = Style.display()
	text.TextSize = 28
	text.TextColor3 = Style.gold
	text.TextStrokeColor3 = Style.ink
	text.TextStrokeTransparency = 0
	text.Text = ""
	text.Parent = row
	local scale = Instance.new("UIScale")
	scale.Parent = row
	return { gui = gui, text = text, scale = scale, heldUntil = 0, burstAt = -math.huge }
end

-- World-space coin fountain from the figure into the player; the number punches as it empties.
local function burst(label: Label, amount: number, landed: () -> (), completed: () -> ())
	label.burstAt = os.clock()
	label.scale.Scale = 1.5
	if label.pop then
		label.pop:Cancel()
	end
	label.pop = tween(label.scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	local target = label.target
	if target then
		CoinBurst.play(target.Position - Vector3.new(0, 2, 0), amount, landed, completed)
	else
		completed()
	end
end

-- Confirmed amount slams in, overshoots, then drifts up and fades.
local function float(label: Label, amount: number)
	local scope = temporaryScope()
	local text = Instance.new("TextLabel")
	scope.add(function()
		text:Destroy()
	end)
	text.Name = "Collected"
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.new(0.5, 0, 0.5, -34)
	text.Size = UDim2.fromScale(1, 1)
	text.FontFace = Style.display()
	text.TextSize = 40
	text.TextColor3 = Style.gold
	text.TextStrokeColor3 = Style.ink
	text.TextStrokeTransparency = 0
	text.Text = "+" .. UIState.compact(amount)
	text.Parent = label.gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = text
	local pop = tween(scale, 0.3, { Scale = 1.15 }, Enum.EasingStyle.Back)
	scope.add(function()
		pop:Cancel()
	end)
	local waiting = true
	local thread = task.delay(0.5, function()
		waiting = false
		if text.Parent then
			local drift = tween(text, 0.8, {
				Position = UDim2.new(0.5, 0, 0.5, -84),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			scope.add(function()
				drift:Cancel()
			end)
			scope.connect(drift.Completed, scope.destroy)
		else
			scope.destroy()
		end
	end)
	scope.add(function()
		if waiting then
			task.cancel(thread)
		end
	end)
end

export type Earnings = {
	update: (Types.Snapshot) -> number,
	receive: (Types.Snapshot?, Types.Snapshot, Types.Reply?) -> (),
	interrupt: () -> (),
	-- First placement: sparkle the slot and punch its counter so earning is visibly "here".
	celebrate: (slot: number) -> (),
	destroy: () -> (),
}

function Earnings.create(
	effects: () -> boolean,
	landed: () -> (),
	display: (number) -> ()
): Earnings
	local labels: { Label } = {}
	local scope = Scope.create()
	local counter = Counter.create(display)
	local destroyed = false
	local function interrupt()
		counter.reconcile()
		CoinBurst.destroy()
		for child in table.clone(temporary) do
			child.destroy()
		end
		for _, label in labels do
			label.flight = nil
			label.heldUntil = 0
			if label.pop then
				label.pop:Cancel()
				label.pop = nil
			end
			label.scale.Scale = 1
		end
	end
	local death: RBXScriptConnection? = nil
	local function characterRemoving()
		interrupt()
		if death then
			death:Disconnect()
			death = nil
		end
	end
	local function characterChanged()
		characterRemoving()
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			death = humanoid.Died:Connect(interrupt)
		end
	end
	scope.add(function()
		if death then
			death:Disconnect()
		end
	end)
	scope.connect(Players.LocalPlayer.CharacterRemoving, characterRemoving)
	scope.connect(Players.LocalPlayer.CharacterAdded, characterChanged)
	characterChanged()
	local function start(label: Label, amount: number): Flight
		local flight: Flight = { count = CoinBurst.count(amount), impacts = 0, complete = false }
		local ok, problem = pcall(function()
			burst(label, amount, function()
				if flight.complete or destroyed then
					return
				end
				flight.impacts += 1
				if flight.token then
					counter.impact(flight.token, flight.impacts)
				end
				landed()
			end, function()
				if flight.complete then
					return
				end
				flight.complete = true
				if flight.token then
					counter.finish(flight.token)
				end
			end)
			return nil
		end)
		if not ok then
			flight.complete = true
			interrupt()
			warn(problem)
		end
		return flight
	end
	local snapshot: Types.Snapshot? = nil
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for slot = 1, DisplayConfig.maxSlots do
		labels[slot] = newLabel(slot)
		labels[slot].gui.Parent = gui
	end

	-- Mirrors the server's checks so the predicted burst rarely disagrees with the reply.
	local function predict(slot: number)
		local state, label = snapshot, labels[slot]
		local id = if state then state.slots[slot] else nil
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			not state
			or not id
			or id == ""
			or UIState.earnings(state, id) < 1
			or os.clock() < label.heldUntil
			or not label.target
			or not root
			or not root:IsA("BasePart")
			or (root.Position - label.target.Position).Magnitude > reach
		then
			return
		end
		label.text.Text = "0"
		label.heldUntil = os.clock() + hold
		Sfx.play("collect") -- Predicted with the burst; the reply only plays it if unpredicted.
		if effects() then
			label.flight = start(label, UIState.earnings(state, id))
		end
	end

	-- Late replication and plot replacement rebind here, from the existing snapshot refresh.
	local function bind(slot: number, target: BasePart?)
		local label = labels[slot]
		if label.target == target then
			return
		end
		if label.target then
			interrupt()
		end
		if label.click then
			label.click:Disconnect()
			label.click = nil
		end
		label.target = target
		if target then
			label.gui.Adornee = target -- A lost target just disables the label in update().
		end
		local click = if target then target:FindFirstChildOfClass("ClickDetector") else nil
		if click then
			label.click = click.MouseClick:Connect(function()
				predict(slot)
			end)
		end
	end

	local function update(state: Types.Snapshot): number
		if destroyed then
			return 0
		end
		snapshot = state
		local folder = ownCollectors()
		local total = 0
		local now = os.clock()
		for slot, label in labels do
			local target = if folder then folder:FindFirstChild(tostring(slot)) else nil
			bind(slot, if target and target:IsA("BasePart") then target else nil)
			local id = if slot <= state.unlocked then state.slots[slot] else nil
			local amount = if id and id ~= "" then UIState.earnings(state, id) else 0
			total += amount
			label.gui.Enabled = label.target ~= nil and id ~= nil and id ~= ""
			if now >= label.heldUntil then
				label.text.Text = UIState.compact(amount)
			end
		end
		return total
	end

	-- Called only for newly accepted snapshots, before the HUD renders that snapshot.
	local function receive(before: Types.Snapshot?, after: Types.Snapshot, reply: Types.Reply?)
		if destroyed then
			return
		end
		local collection = reply and string.sub(reply.id, 1, 8) == "collect:"
		local amount = if before then after.coins - before.coins else 0
		local slot = if collection
				and reply
				and reply.figure
			then table.find(after.slots, reply.figure)
			else nil
		local label = if slot then labels[slot] else nil
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local animate = collection
			and reply
			and reply.ok
			and amount > 0
			and before
			and after.sequence == before.sequence + 1
			and after.ready
			and effects()
			and label
			and label.target
			and humanoid
			and humanoid.Health > 0
		if not animate then
			if
				collection
				and reply
				and reply.ok
				and amount > 0
				and label
				and os.clock() >= label.heldUntil
			then
				Sfx.play("collect")
			end
			counter.snapshot(after.coins)
			if (before and amount ~= 0) or (reply and not reply.ok) or not after.ready then
				interrupt()
			end
			update(after)
			return
		end
		local targetLabel = label :: Label
		local flight = targetLabel.flight
		targetLabel.flight = nil -- One prediction can confirm only one collection.
		if not flight then
			Sfx.play("collect")
			flight = start(targetLabel, amount)
		end
		local confirmed = flight :: Flight
		confirmed.token = counter.snapshot(after.coins, amount, confirmed.impacts, confirmed.count)
		if confirmed.complete and confirmed.token then
			counter.finish(confirmed.token)
		end
		targetLabel.heldUntil = 0
		update(after)
		local ok, problem = pcall(function()
			float(targetLabel, amount)
			return nil
		end)
		if not ok then
			interrupt()
			warn(problem)
		end
	end

	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		interrupt()
		scope.destroy()
		for _, label in labels do
			if label.click then
				label.click:Disconnect()
			end
			label.gui:Destroy()
		end
		table.clear(labels)
		CoinBurst.destroy()
	end

	local function celebrate(slot: number)
		if destroyed then
			return
		end
		local label = labels[slot]
		local target = if label then label.target else nil
		if not target or not effects() then
			return
		end
		CoinBurst.celebrate(target.Position - Vector3.new(0, 2, 0))
		label.scale.Scale = 1.6
		if label.pop then
			label.pop:Cancel()
		end
		label.pop = tween(label.scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	return {
		update = update,
		receive = receive,
		interrupt = interrupt,
		celebrate = celebrate,
		destroy = destroy,
	}
end
return Earnings

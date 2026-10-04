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
local Earnings = {}

local height = 3.9 -- Studs above the collector target's centre, just over the figure's head.
local reach = 12 -- Mirrors the server's collect distance so prediction matches its decision.
local hold = 1.5 -- Seconds a predicted "0" wins over older snapshots awaiting the reply.

type Label = {
	gui: BillboardGui,
	text: TextLabel,
	scale: UIScale,
	target: BasePart?,
	click: RBXScriptConnection?,
	heldUntil: number,
	burstAt: number,
}

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
local function burst(label: Label, amount: number, landed: () -> ())
	label.burstAt = os.clock()
	label.scale.Scale = 1.5
	tween(label.scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	local target = label.target
	if target then
		CoinBurst.play(target.Position - Vector3.new(0, 2, 0), amount, landed)
	end
end

-- Confirmed amount slams in, overshoots, then drifts up and fades.
local function float(label: Label, amount: number)
	local text = Instance.new("TextLabel")
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
	tween(scale, 0.3, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.delay(0.5, function()
		if text.Parent then
			tween(text, 0.8, {
				Position = UDim2.new(0.5, 0, 0.5, -84),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}).Completed:Connect(function()
				text:Destroy()
			end)
		end
	end)
end

export type Earnings = {
	update: (Types.Snapshot) -> number,
	collected: (Types.Snapshot, Types.Snapshot, Types.Reply) -> (),
	-- First placement: sparkle the slot and punch its counter so earning is visibly "here".
	celebrate: (slot: number) -> (),
	destroy: () -> (),
}

function Earnings.create(effects: () -> boolean, landed: () -> ()): Earnings
	local labels: { Label } = {}
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
			burst(label, UIState.earnings(state, id), landed)
		end
	end

	-- Late replication and plot replacement rebind here, from the existing snapshot refresh.
	local function bind(slot: number, target: BasePart?)
		local label = labels[slot]
		if label.target == target then
			return
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

	-- Authoritative confirmation: amount is the wallet delta; burst only if not predicted.
	local function collected(before: Types.Snapshot, after: Types.Snapshot, reply: Types.Reply)
		if not reply.ok then
			for _, label in labels do
				label.heldUntil = 0
			end
			update(after)
			return
		end
		local slot = if reply.figure then table.find(after.slots, reply.figure) else nil
		local label = if slot then labels[slot] else nil
		if not label then
			return
		end
		if os.clock() >= label.heldUntil then
			Sfx.play("collect")
		end
		label.heldUntil = 0
		local id = after.slots[slot :: number]
		label.text.Text = UIState.compact(UIState.earnings(after, id))
		if effects() then
			local amount = after.coins - before.coins
			if os.clock() - label.burstAt > hold then
				burst(label, amount, landed)
			end
			float(label, amount)
		end
	end

	local function destroy()
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
		local label = labels[slot]
		local target = if label then label.target else nil
		if not target or not effects() then
			return
		end
		CoinBurst.celebrate(target.Position - Vector3.new(0, 2, 0))
		label.scale.Scale = 1.6
		tween(label.scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	return { update = update, collected = collected, celebrate = celebrate, destroy = destroy }
end
return Earnings

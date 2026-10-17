--!strict
local Currency = require(game:GetService("ReplicatedStorage").Shared.Currency)
-- Dedicated Coin Shop/settings controls; Store purchase cards stay with P08.
local Client = require(script.Parent.ConvenienceClient)
local Scope = require(script.Parent.UIScope)
local Kit = require(script.Parent.UIKit)
local Style = require(script.Parent.UIStyle)
local State = require(script.Parent.UIState)
local Button = require(script.Parent.UIButton)
local Controls = {}
-- Mount on the existing safe-area opening overlay so Stop survives openingFocus.
function Controls.createStop(
	parent: Instance,
	scope: Scope.Scope,
	effects: () -> boolean,
	client: Client.Controller
): Button.Button
	local stop = Button.create(
		parent,
		"StopAutoOpen",
		{ variant = "ink", text = "Stop Auto Open", size = 16 },
		scope,
		effects,
		client.stop
	)
	stop.button.Size = UDim2.fromOffset(180, 44)
	stop.button.Position = UDim2.new(1, -196, 0, 16)
	scope.add(function()
		stop.button:Destroy()
	end)
	return stop
end
export type Collection = { id: string, name: string, price: number?, refusal: string? }
export type Panel = { root: ScrollingFrame, update: () -> (), layout: (number, number) -> () }
function Controls.create(
	parent: Instance,
	scope: Scope.Scope,
	effects: () -> boolean,
	client: Client.Controller,
	collection: () -> Collection
): Panel
	local root = Instance.new("ScrollingFrame")
	root.Name, root.BackgroundTransparency, root.BorderSizePixel = "ConvenienceControls", 1, 0
	root.ScrollingDirection, root.ScrollBarThickness = Enum.ScrollingDirection.Y, 4
	root.CanvasSize = UDim2.fromOffset(0, 480)
	root.Parent = parent
	scope.add(function()
		root:Destroy()
	end)
	local title = Kit.text(root, "Title", "Convenience", 21, Style.display())
	local chosen = Kit.text(root, "Collection", "", 16, Style.display())
	local status =
		Kit.text(root, "Status", "Waiting for confirmation", 14, Style.body(), Style.muted)
	status.TextWrapped, status.TextTruncate = true, Enum.TextTruncate.None
	local cost = Kit.text(root, "MaximumCost", "", 14, Style.body(), Style.muted)
	cost.TextWrapped, cost.TextTruncate = true, Enum.TextTruncate.None
	local limitLabel = Kit.text(root, "LimitLabel", "Boxes (1–100)", 14)
	local reserveLabel = Kit.text(root, "ReserveLabel", "Keep Coins", 14)
	local function field(name: string, text: string): TextBox
		local box = Instance.new("TextBox")
		box.Name, box.Text, box.ClearTextOnFocus = name, text, false
		box.FontFace, box.TextSize = Style.body(), 16
		box.BackgroundColor3, box.TextColor3 = Style.white, Style.ink
		box.Parent = root
		box:SetAttribute(
			"AccessibleName",
			if name == "RunLimit" then "Maximum boxes this run" else "Coins to keep after each box"
		)
		Kit.corner(box, 12)
		return box
	end
	local limit, reserve = field("RunLimit", "10"), field("CoinReserve", "0")
	local start: Button.Button
	local collect: Button.Button
	local movement: Button.Button
	local function values(): (number?, number?)
		local count, keep = tonumber(limit.Text), tonumber(reserve.Text)
		if
			not count
			or not keep
			or count ~= count
			or keep ~= keep
			or count % 1 ~= 0
			or keep % 1 ~= 0
			or count < 1
			or count > 100
			or keep < 0
			or keep > Currency.limit
		then
			return nil, nil
		end
		return count, keep
	end
	local function update()
		local selected, view = collection(), client.view()
		chosen.Text = selected.name
		local count, keep = values()
		cost.Text = if count
				and keep
				and selected.price
			then `Spends up to {State.number(count * selected.price)} Coins. Keeps at least {State.number(
				keep
			)} Coins.`
			else "Enter whole values. A confirmed collection price is required."
		local open = if view then view.open else nil
		status.Text = selected.refusal
			or if open
				then `{open.reason} · {open.completed}/{open.limit} boxes`
				else "Waiting for confirmation"
		start.set(
			"Start Auto Open",
			view ~= nil
				and view.openAllowed
				and count ~= nil
				and keep ~= nil
				and selected.price ~= nil
				and selected.refusal == nil
				and open ~= nil
				and not open.running
				and open.phase == "Idle"
		)
		collect.set(
			if view and view.collectEnabled then "Auto Collect: ON" else "Auto Collect: OFF",
			view ~= nil and (view.collectAllowed or view.collectEnabled),
			if view then view.collectReason else "Ownership unconfirmed"
		)
		movement.set(
			if view and view.movementEnabled
				then "Speed: 48 · select free 36"
				else "Speed: 36 · select 48",
			view ~= nil and (view.movementAllowed or view.movementEnabled)
		)
	end
	start = Button.create(
		root,
		"StartAutoOpen",
		{ variant = "violet", text = "Start Auto Open", size = 16 },
		scope,
		effects,
		function()
			local count, keep = values()
			if count and keep and collection().refusal == nil then
				client.start(collection().id, count, keep)
			end
		end
	)
	local stop = Button.create(
		root,
		"StopAutoOpen",
		{ variant = "ink", text = "Stop Auto Open", size = 16 },
		scope,
		effects,
		client.stop
	)
	collect = Button.create(
		root,
		"AutoCollect",
		{ variant = "white", text = "Auto Collect: OFF", size = 16 },
		scope,
		effects,
		function()
			local view = client.view()
			if view then
				client.collect(not view.collectEnabled)
			end
		end
	)
	movement = Button.create(
		root,
		"MovementSpeed",
		{ variant = "white", text = "Speed: 36", size = 16 },
		scope,
		effects,
		function()
			local view = client.view()
			if view then
				client.movement(not view.movementEnabled)
			end
		end
	)
	scope.connect(limit:GetPropertyChangedSignal("Text"), update)
	scope.connect(reserve:GetPropertyChangedSignal("Text"), update)
	update()
	return {
		root = root,
		update = update,
		layout = function(width, height)
			root.Size = UDim2.fromOffset(width, height)
			local w = math.max(44, width - 12)
			Kit.rect(title, 0, 0, w, 32)
			Kit.rect(chosen, 0, 36, w, 28)
			Kit.rect(status, 0, 70, w, 50)
			Kit.rect(limitLabel, 0, 124, w / 2 - 4, 22)
			Kit.rect(reserveLabel, w / 2 + 4, 124, w / 2 - 4, 22)
			Kit.rect(limit, 0, 150, w / 2 - 4, 44)
			Kit.rect(reserve, w / 2 + 4, 150, w / 2 - 4, 44)
			Kit.rect(cost, 0, 200, w, 50)
			Kit.rect(start.button, 0, 256, w, 44)
			Kit.rect(stop.button, 0, 310, w, 44)
			Kit.rect(collect.button, 0, 364, w, 44)
			Kit.rect(movement.button, 0, 418, w, 44)
		end,
	}
end
return Controls

--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Config = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Context = require(script.Parent.UIContext)
local Style = require(script.Parent.SystemStyle)
local Layout = require(script.Parent.SystemLayout)
local State = require(script.Parent.SystemState)
local UI = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Slot = require(script.Parent.DisplaySlotCard)
local Display = {}
function Display.create(parent: Instance, ctx: Context.Context)
	local shell = Style.shell(parent, "Display", ctx)
	local root, content = shell.root, shell.content
	local header = W.frame(content, "ShowcaseHeader")
	Style.header(
		header,
		"My Display",
		"Your favorites, earning around the clock while you play.",
		"Display"
	)
	local incomeCard = Style.panel(header, "IncomePlaque", Style.successWash)
	local income = Style.text(incomeCard, "TotalIncome", "-- Coins/sec", 28, true)
	W.inset(income, 6, 40)
	income.TextColor3 = Style.success
	local capacity = Style.text(incomeCard, "Capacity", "Loading your Display...", 14)
	W.inset(capacity, 48, 26)
	local bonusCard = Style.panel(header, "MatchingSet", Style.card)
	local bonus = Style.text(bonusCard, "BonusStatus", "Matching set", 16, true)
	W.inset(bonus, 6, 28)
	local rule = Style.text(bonusCard, "BonusRule", "3 different figures from one collection", 13)
	W.inset(rule, 34, 32)
	local segments: { Frame } = {}
	for index = 1, 3 do
		local segment = Style.panel(bonusCard, "SetSegment" .. index, Style.inset, 4)
		segment.Position = UDim2.new((index - 1) / 3, 12, 1, -12)
		segment.Size = UDim2.new(1 / 3, -16, 0, 5)
		segments[index] = segment
	end
	local selected: string? = nil
	local refresh: () -> () = function() end
	local placement = Style.panel(content, "PlacementBanner", Style.selection)
	placement.Visible = false
	local mini = Preview.create(placement, ctx.scope, true)
	Style.rect(mini.frame, 8, 8, 52, 64)
	local placing = Style.text(placement, "PlacingFigure", "", 15, true)
	placing.Position = UDim2.fromOffset(68, 8)
	placing.Size = UDim2.new(1, -158, 0, 68)
	placing.TextTruncate = Enum.TextTruncate.AtEnd
	local cancel = Style.action(placement, "Cancel", ctx, function()
		selected = nil
		refresh()
	end, true)
	cancel.button.Position = UDim2.new(1, -84, 0, 20)
	cancel.button.Size = UDim2.fromOffset(76, 48)
	local cards = {}
	for slot = 1, Config.maxSlots do
		cards[slot] = Slot.create(content, ctx, slot, function()
			local snapshot = ctx.snapshot()
			if not snapshot then
				return
			end
			local state = State.display(snapshot, slot, selected, ctx.canAct())
			if not state.enabled then
				return
			end
			if state.available then
				ctx.send("Expand", nil, nil, nil)
			elseif selected then
				ctx.send("Place", selected, slot, nil)
			else
				ctx.pick(slot)
			end
		end)
	end
	local function resize()
		local width = shell.width()
		local geometry = Layout.display(width, Config.maxSlots, selected ~= nil)
		Style.rect(header, 0, 0, width, geometry.header)
		-- Compact headers keep full-width earning and set summaries beneath the title.
		local narrow = width < 560
		Style.rect(incomeCard, 0, 102, if narrow then width else (width - 16) * 0.5, 82)
		Style.rect(
			bonusCard,
			if narrow then 0 else (width + 16) * 0.5,
			if narrow then 194 else 102,
			if narrow then width else (width - 16) * 0.5,
			84
		)
		local headerHeight = geometry.header
		local top = geometry.top
		Style.rect(placement, 0, headerHeight + 12, width, geometry.placementHeight)
		placing.Size = UDim2.new(1, if width < 420 then -80 else -158, 0, 68)
		cancel.button.Position = UDim2.new(1, -84, 0, geometry.placementHeight - 56)
		for index, card in cards do
			Style.rect(
				card.root,
				(index - 1) % geometry.columns * (geometry.cell + 12),
				top + math.floor((index - 1) / geometry.columns) * (geometry.card + 12),
				geometry.cell,
				geometry.card
			)
		end
		shell.fit(geometry.height)
	end
	local function update(snapshot: Types.Snapshot)
		income.Text = string.format("%g Coins/sec", snapshot.rate)
		capacity.Text = string.format("%d of %d Display slots", snapshot.unlocked, Config.maxSlots)
		local progress = UI.bonusProgress(snapshot)
		bonus.Text = if snapshot.bonus > 0
			then string.format("Set bonus  +%g/sec", snapshot.bonus)
			else string.format("Matching set  %d / 3", progress)
		bonus.TextColor3 = if snapshot.bonus > 0 then Style.success else Style.ink
		for index, segment in segments do
			segment.BackgroundColor3 = if index <= progress then Style.success else Style.inset
		end
		placement.Visible = selected ~= nil
		mini.figure(selected, true)
		if selected then
			local _, free = UI.copies(snapshot, selected)
			placing.Text = "Placing "
				.. Catalog.byId[selected].name
				.. (
					if free > 0
						then "\nChoose a highlighted slot"
						else "\nNo spare copies available"
				)
		end
		for _, card in cards do
			card.update(snapshot, selected)
		end
	end
	refresh = function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
		resize()
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	return {
		root = root,
		update = update,
		select = function(id: string?)
			selected = id
			refresh()
		end,
	}
end
return Display

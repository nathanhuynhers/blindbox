--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Style = require(script.Parent.SystemStyle)
local Layout = require(script.Parent.SystemLayout)
local State = require(script.Parent.UIState)
local CollectionTheme = require(script.Parent.ShopTheme)
local GoalCard = require(script.Parent.DailyGoalCard)
local W = require(script.Parent.Widgets)
local Icons = require(script.Parent.UIIcons)
local Goals = {}
function Goals.create(parent: Instance, ctx: Context.Context): Context.Screen
	local shell = Style.shell(parent, "Goals", ctx)
	local root, content = shell.root, shell.content
	Style.header(content, "Goals", "A little every day. A collection that's yours.", "Goals")
	local goal = GoalCard.create(content, ctx)
	local free = Style.panel(content, "DailySurprise", Style.card)
	local giftSeal = Style.panel(free, "GiftSeal", Style.gold, 20)
	Style.rect(giftSeal, 12, 12, 52, 52)
	local gift = Icons.create(giftSeal, "Shop", Style.goldInk)
	Style.rect(gift, 10, 10, 32, 32)
	local title = Style.text(free, "DailyBoxTitle", "Your daily surprise", 22, true)
	title.Position = UDim2.fromOffset(76, 12)
	title.Size = UDim2.new(1, -88, 0, 56)
	local status = Style.text(free, "DailyBoxStatus", "Loading your daily box...", 14)
	W.inset(status, 78, 52)
	local choices: { { action: W.Action, title: TextLabel, status: TextLabel, face: Frame } } = {}
	local progressCards: { { root: Frame, status: TextLabel, count: TextLabel, progress: (number, number) -> () } } =
		{}
	local collectionHeading =
		Style.text(content, "CollectionProgressTitle", "Your collection milestones", 22, true)
	for index, collection in Catalog.collections do
		local theme = CollectionTheme.get(collection.id)
		local action = Style.action(free, "", ctx, function()
			ctx.send("Daily", nil, nil, collection.id)
		end, true)
		action.button.Name = "Daily_" .. collection.id
		action.set("", false)
		W.inset(action.button, 136 + (index - 1) * 68, 60)
		local face = Style.panel(action.button, "CollectionChoice", theme.wash, 12)
		face.Position = UDim2.fromOffset(3, 3)
		face.Size = UDim2.new(1, -6, 1, -6)
		local mark = Icons.create(face, "Shop", theme.primary)
		Style.rect(mark, 10, 12, 28, 28)
		local name = Style.text(face, "CollectionName", collection.name, 15, true)
		name.Position = UDim2.fromOffset(48, 2)
		name.Size = UDim2.new(1, -60, 0, 32)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local hint = Style.text(face, "ActionHint", "Choose this free box", 12)
		hint.Position = UDim2.fromOffset(48, 32)
		hint.Size = UDim2.new(1, -60, 0, 20)
		choices[index] = { action = action, title = name, status = hint, face = face }
		local card = Style.panel(content, "CollectionProgress_" .. collection.id, Style.card)
		local bar = W.frame(card, "CollectionAccent", theme.primary)
		bar.Position = UDim2.fromOffset(0, 14)
		bar.Size = UDim2.fromOffset(4, 46)
		W.corner(bar, 2)
		local collectionTitle = Style.text(card, "CollectionName", collection.name, 18, true)
		W.inset(collectionTitle, 10, 42)
		local count = Style.text(card, "DiscoveredCount", "", 14)
		W.inset(count, 54, 26)
		local track = W.frame(card, "Progress")
		W.inset(track, 88, 8)
		local caption = Style.text(card, "CompletionState", "", 12)
		W.inset(caption, 102, 22)
		progressCards[index] = {
			root = card,
			count = count,
			status = caption,
			progress = Style.progress(track, ctx, theme.primary),
		}
	end
	local function resize()
		local width = shell.width()
		local g = Layout.goals(width, #Catalog.collections)
		Style.rect(goal.root, 0, 110, g.cardWidth, g.heroHeight)
		Style.rect(free, if g.wide then g.cardWidth + 16 else 0, g.freeY, g.cardWidth, g.freeHeight)
		Style.rect(collectionHeading, 0, g.progressY, width, 40)
		for index, card in progressCards do
			Style.rect(
				card.root,
				(index - 1) % g.columns * (g.cell + 12),
				g.progressY + 48 + math.floor((index - 1) / g.columns) * 142,
				g.cell,
				130
			)
		end
		shell.fit(g.height)
	end
	ctx.scope.connect(root:GetPropertyChangedSignal("AbsoluteSize"), resize)
	resize()
	return {
		root = root,
		update = function(snapshot: Types.Snapshot)
			goal.update(snapshot)
			status.Text = if snapshot.dailyReady
				then "One free Starter box each day."
				else "Collected for today. Your next box arrives at 00:00 UTC."
			status.TextColor3 = if snapshot.dailyReady then Style.ink else Style.success
			for index, collection in Catalog.collections do
				local choice = choices[index]
				local eligible = collection.id == snapshot.dailyCollection
				choice.action.button.Visible = eligible
				if eligible then
					W.inset(choice.action.button, 136, 60)
				end
				choice.action.set("", ctx.canAct() and snapshot.dailyReady and eligible)
				choice.status.Text = if snapshot.dailyReady
					then (if ctx.canAct() then "Choose this free box" else "Please wait...")
					else "Available tomorrow"
				choice.face.BackgroundColor3 = if snapshot.dailyReady
					then CollectionTheme.get(collection.id).wash
					else Style.paper
				local found, total = State.completion(snapshot, collection.id)
				local card = progressCards[index]
				card.count.Text = string.format("%d / %d discovered", found, total)
				card.status.Text = if total > 0 and found == total
					then "\u{2713}  Collection complete"
					else "Every discovery brings you closer"
				card.status.TextColor3 = if found == total then Style.success else Style.muted
				card.root:SetAttribute("Complete", total > 0 and found == total)
				card.progress(found, total)
			end
		end,
	}
end
return Goals

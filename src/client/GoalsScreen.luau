--!strict
-- Goals: daily goal | free box of the day | collection progress. The header countdown reads
-- the server's nextDay and refreshes at most once a minute, only while this screen is visible.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Badge = require(script.Parent.UIBadge)
local Button = require(script.Parent.UIButton)
local Progress = require(script.Parent.UIProgress)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Shell = require(script.Parent.ScreenShell)
local List = require(script.Parent.CollectionList)
local Sfx = require(script.Parent.Sfx)
local Goals = {}

type Choice = { button: TextButton, stroke: UIStroke, id: string }
type Row = { button: TextButton, name: TextLabel, status: TextLabel, bar: Progress.Bar, id: string }

local function heading(parent: Instance, text: string): TextLabel
	return Kit.text(parent, "Heading", text, 12, Style.body(Enum.FontWeight.Heavy), Style.muted)
end

function Goals.create(parent: Instance, ctx: Context.Context, now: () -> number): Context.Screen
	local shell = Shell.create(parent, ctx, {
		id = "Goals",
		title = "Goals",
		subtitle = "Daily rewards reset at 00:00 UTC",
	})
	local root = shell.root
	local countdown = Badge.create(shell.chips, "Countdown", "", {
		fill = Style.surface2,
		color = Style.hex(0x4A4062),
		height = 40,
		size = 14,
		icon = "Clock",
	})
	countdown.root.LayoutOrder = 1
	local body = Kit.canvas(shell.body, "GoalsBody")
	-- Daily goal
	local goal = Kit.card(body, "DailyGoal", Style.white, 22, 4)
	local empty = Kit.text(
		body,
		"NoActiveGoals",
		"All daily goals finished!\nNew goals at 00:00 UTC.",
		20,
		Style.display(),
		Style.muted
	)
	empty.TextWrapped = true
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.Visible = false
	local goalHeading = heading(goal.face, "DAILY GOAL")
	local goalChip = Badge.create(goal.face, "Status", "", {
		fill = Style.mint,
		color = Style.mintInk,
		height = 26,
		size = 13,
	})
	goalChip.root.AnchorPoint = Vector2.new(1, 0)
	local goalTitle = Kit.text(
		goal.face,
		"GoalTitle",
		"Display 3 different figures at the same time",
		22,
		Style.display()
	)
	goalTitle.TextWrapped = true
	goalTitle.TextYAlignment = Enum.TextYAlignment.Top
	goalTitle.TextTruncate = Enum.TextTruncate.None
	local segments = Progress.segments(goal.face, "GoalProgress", 3, 14, 6)
	local goalCount = Kit.text(goal.face, "GoalCount", "", 18, Style.display())
	goalCount.TextXAlignment = Enum.TextXAlignment.Right
	local reward = Kit.frame(goal.face, "Reward", Style.goldWash)
	Kit.corner(reward, 16)
	local rewardCoin = Icons.create(reward, "Coin", Style.ink, 56)
	rewardCoin.AnchorPoint = Vector2.new(0.5, 0)
	local rewardText = Kit.text(reward, "Amount", "", 26, Style.display())
	rewardText.TextXAlignment = Enum.TextXAlignment.Center
	local claim = Button.create(
		goal.face,
		"ClaimGoal",
		{
			variant = "gold",
			text = "Claim",
			size = 22,
			radius = 18,
			drop = 4,
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.send("Goal", nil, nil, nil)
		end
	)
	-- Free box
	local free = Kit.card(body, "FreeBox", Style.white, 22, 4)
	local freeHeading = heading(free.face, "FREE BOX OF THE DAY")
	local freeChip = Badge.create(free.face, "Status", "", {
		fill = Style.readyWash,
		color = Style.readyInk,
		height = 26,
		size = 13,
	})
	freeChip.root.AnchorPoint = Vector2.new(1, 0)
	local freeTitle = Kit.text(free.face, "FreeTitle", "", 22, Style.display())
	-- Single allowed collection: its emblem and progress fill the card instead of a chooser.
	local feature = Kit.frame(free.face, "FreeFeature", Style.surface2)
	Kit.corner(feature, 16)
	local featureIcon, featureEmblem, featureMono = List.icon(feature, "", "", 88)
	featureIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	local featureText =
		Kit.text(feature, "Detail", "", 14, Style.body(Enum.FontWeight.Bold), Style.muted)
	featureText.TextXAlignment = Enum.TextXAlignment.Center
	featureText.TextWrapped = true
	local chosen: string? = nil
	local refresh: () -> () = function() end
	local choices: { Choice } = {}
	for index, collection in Catalog.collections do
		local button = Instance.new("TextButton")
		button.Name = "Daily_" .. collection.id
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Style.white
		button.LayoutOrder = index
		button.Parent = free.face
		Kit.corner(button, 14)
		local stroke = Kit.stroke(button, Style.track)
		local icon = List.icon(button, collection.id, collection.name, 30)
		icon.Position = UDim2.fromOffset(6, 7)
		local label =
			Kit.text(button, "Name", Style.collection(collection.id).short or collection.name, 14)
		Kit.rect(label, 44, 0, 120, 44)
		label.Size = UDim2.new(1, -50, 1, 0)
		ctx.scope.connect(button.Activated, function()
			chosen = collection.id
			refresh()
			Sfx.play("select")
		end)
		choices[index] = { button = button, stroke = stroke, id = collection.id }
	end
	local open = Button.create(
		free.face,
		"OpenFreeBox",
		{
			variant = "mint",
			text = "Open free box",
			size = 20,
			radius = 18,
			drop = 4,
		},
		ctx.scope,
		ctx.effects,
		function()
			if chosen then
				ctx.send("Daily", nil, nil, chosen)
			end
		end
	)
	-- Collection progress
	local progress = Kit.frame(body, "CollectionProgress", Style.surface2)
	Kit.corner(progress, 22)
	local progressTitle =
		Kit.text(progress, "Title", "Complete your collections", 20, Style.display())
	-- Shrinks to fit the narrow desktop column rather than truncating.
	progressTitle.TextScaled = true
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MinTextSize = 12
	titleSize.Parent = progressTitle
	local progressTotal = Kit.text(progress, "Total", "", 13, nil, Style.muted)
	progressTotal.TextXAlignment = Enum.TextXAlignment.Right
	local rows: { Row } = {}
	for index, collection in Catalog.collections do
		local button = Instance.new("TextButton")
		button.Name = "Progress_" .. collection.id
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Style.white
		button.LayoutOrder = index
		button.Parent = progress
		Kit.corner(button, 16)
		Kit.stroke(button, Style.track, Style.outlineSmall)
		local icon = List.icon(button, collection.id, collection.name, 38)
		icon.Position = UDim2.fromOffset(10, 8)
		local name = Kit.text(button, "Name", collection.name, 15)
		local status = Kit.text(button, "Status", "", 15)
		status.TextXAlignment = Enum.TextXAlignment.Right
		local bar = Progress.bar(button, "Progress", 8, Style.collection(collection.id).color)
		ctx.scope.connect(button.Activated, function()
			ctx.navigate("Collection", { collection = collection.id })
		end)
		rows[index] =
			{ button = button, name = name, status = status, bar = bar, id = collection.id }
	end
	local width, height, phone = 0, 0, false
	local function arrange()
		local pad = if phone then 12 else 20
		local gap = if phone then 10 else 16
		-- Phone: goal and free box side by side, progress stacked full width below them so
		-- collection names and headings keep their width (the body canvas scrolls).
		local column = State.cells(width - pad * 2, if phone then 2 else 3, gap)
		local cardHeight = math.max(if phone then 330 else 360, height - 38)
		local top = 16
		local rowsBottom = 52 + math.max(0, #rows - 1) * 62 + 54
		local progressX = if phone then pad else pad + (column + gap) * 2
		local progressY = if phone then top + cardHeight + gap else top
		local progressWidth = if phone then width - pad * 2 else column
		local progressHeight = if phone then rowsBottom + 16 else cardHeight
		Kit.rect(goal.root, pad, top, column, cardHeight)
		Kit.rect(empty, pad + 18, top + 24, column - 36, 120)
		Kit.rect(free.root, pad + column + gap, top, column, cardHeight)
		Kit.rect(progress, progressX, progressY, progressWidth, progressHeight)
		local inner = column - 36
		-- Goal card
		Kit.rect(goalHeading, 18, 18, inner - 110, 26)
		goalChip.root.Position = UDim2.fromOffset(18 + inner, 18)
		Kit.rect(goalTitle, 18, 54, inner, 56)
		goalTitle.TextSize = if phone then 18 else 22
		Kit.rect(segments.root, 18, 120, inner - 60, 14)
		Kit.rect(goalCount, 18 + inner - 52, 112, 52, 30)
		local claimY = cardHeight - 18 - 60
		Kit.rect(reward, 18, 148, inner, math.max(80, claimY - 12 - 148))
		rewardCoin.Position = UDim2.new(0.5, 0, 0.5, -46)
		Kit.rect(rewardText, 0, 0, inner, 32)
		rewardText.Position = UDim2.new(0, 0, 0.5, 14)
		Kit.rect(claim.button, 18, claimY, inner, 60)
		-- Free box card
		Kit.rect(freeHeading, 18, 18, inner - 90, 26)
		freeChip.root.Position = UDim2.fromOffset(18 + inner, 18)
		Kit.rect(freeTitle, 18, 54, inner, 30)
		local half = State.cells(inner, 2, 8)
		for index, choice in choices do
			local col, line = (index - 1) % 2, (index - 1) // 2
			Kit.rect(choice.button, 18 + col * (half + 8), 94 + line * 52, half, 44)
		end
		Kit.rect(open.button, 18, cardHeight - 18 - 64, inner, 64)
		local featureHeight = math.max(120, cardHeight - 18 - 64 - 12 - 94)
		Kit.rect(feature, 18, 94, inner, featureHeight)
		featureIcon.Position = UDim2.new(0.5, 0, 0, math.floor(featureHeight / 2) - 18)
		Kit.rect(featureText, 12, math.floor(featureHeight / 2) + 34, inner - 24, 40)
		-- Progress list
		local pinner = progressWidth - 32
		Kit.rect(progressTitle, 16, 16, pinner - 60, 26)
		titleSize.MaxTextSize = if phone then 17 else 20
		Kit.rect(progressTotal, 16 + pinner - 60, 16, 60, 26)
		for index, row in rows do
			Kit.rect(row.button, 16, 52 + (index - 1) * 62, pinner, 54)
			Kit.rect(row.name, 60, 8, pinner - 60 - 90, 20)
			Kit.rect(row.status, pinner - 100, 8, 88, 20)
			Kit.rect(row.bar.root, 60, 34, pinner - 72, 8)
		end
		-- Include the last collection row even when the short-layout card is smaller
		-- than its contents; checking only the card bounds truncates that target.
		Kit.fit(body, progressY + math.max(progressHeight, rowsBottom) + 22, height)
	end
	local timer: thread? = nil
	local visible = false
	local remaining = ""
	local function stop()
		if timer then
			task.cancel(timer)
			timer = nil
		end
	end
	ctx.scope.add(stop)
	local function tick()
		timer = nil
		local snapshot = ctx.snapshot()
		if not visible or not snapshot then
			return
		end
		local text, delay = State.countdown(snapshot.nextDay, now())
		remaining = text
		countdown.set("New goals in " .. text)
		timer = task.delay(delay, tick)
		refresh()
	end
	local function update(snapshot: Types.Snapshot)
		shell.update(snapshot)
		if visible and not timer then
			-- First snapshot after the screen opened: start the minute clock.
			tick()
			return
		end
		local state = State.goal(snapshot)
		local done = math.clamp(snapshot.goalProgress, 0, 3)
		goal.root.Visible = state ~= "claimed"
		empty.Visible = state == "claimed"
		local amount = State.compact(State.goalReward(snapshot))
		goalChip.set(
			if state == "progress"
				then done .. " / 3"
				elseif state == "ready" then "Complete"
				else "Claimed"
		)
		goalChip.paint(
			if state == "progress" then Style.surface2 else Style.mint,
			if state == "progress" then Style.muted else Style.mintInk
		)
		segments.set(done)
		goalCount.Text = done .. " / 3"
		rewardText.Text = amount .. " coins"
		claim.set(
			if state == "claimed"
				then "Claimed · come back tomorrow"
				else "Claim " .. amount .. " coins",
			state == "ready" and ctx.canAct(),
			if state == "progress"
				then "Display " .. (3 - done) .. " more different figures"
				else nil
		)
		local options = State.freeBoxOptions(snapshot)
		if not chosen or not table.find(options, chosen) then
			chosen = options[1]
		end
		local single = #options == 1
		freeTitle.Text = if single
			then State.collectionName(options[1]) .. " box"
			else "Pick any collection"
		for _, choice in choices do
			local allowed = table.find(options, choice.id) ~= nil
			choice.button.Visible = allowed and not single
			local on = choice.id == chosen
			choice.button.BackgroundColor3 = if on then Style.violetWash else Style.white
			choice.stroke.Color = if on then Style.violet else Style.track
			choice.button:SetAttribute("Selected", on)
		end
		feature.Visible = single
		if single then
			local id = options[1]
			local accent = Style.collection(id)
			local name = State.collectionName(id)
			feature.BackgroundColor3 = accent.wash
			featureIcon.BackgroundColor3 = Style.white
			featureEmblem.Image = Style.emblem(id)
			featureEmblem.Visible = featureEmblem.Image ~= ""
			featureMono.Text = Style.mono(id, name)
			featureMono.TextColor3 = accent.color
			featureMono.Visible = not featureEmblem.Visible
			local found, total = State.completion(snapshot, id)
			featureText.Text =
				string.format("One free %s box every day · %d of %d found", name, found, total)
		end
		freeChip.set(if snapshot.dailyReady then "Ready" else "Claimed")
		freeChip.paint(
			if snapshot.dailyReady then Style.readyWash else Style.mint,
			if snapshot.dailyReady then Style.readyInk else Style.mintInk
		)
		local chosenName = if chosen then State.collectionName(chosen) else ""
		open.set(
			if snapshot.dailyReady then "Open free box" else "Claimed for today",
			snapshot.dailyReady and chosen ~= nil and ctx.canAct(),
			if snapshot.dailyReady then chosenName else "Next in " .. remaining
		)
		local found, total = State.totalCompletion(snapshot)
		progressTotal.Text = found .. " / " .. total
		for _, row in rows do
			local f, t = State.completion(snapshot, row.id)
			local complete = f >= t and t > 0
			row.status.Text = if complete then "Complete!" else f .. " / " .. t
			row.status.TextColor3 = if complete then Style.mintText else Style.muted
			row.bar.set(f, t)
		end
	end
	refresh = function()
		local snapshot = ctx.snapshot()
		if snapshot then
			update(snapshot)
		end
	end
	return {
		root = root,
		update = update,
		layout = function(nextWidth: number, nextHeight: number, nextPhone: boolean)
			phone = nextPhone
			width, height = shell.layout(nextWidth, nextHeight, nextPhone)
			arrange()
			refresh()
		end,
		shown = function(value: boolean)
			if visible == value then
				return
			end
			visible = value
			stop()
			if value then
				tick()
			end
		end,
	}
end

return Goals

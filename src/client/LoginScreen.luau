--!strict
-- Daily Login: one card per streak day (claimed / today / locked) and a single Claim button.
-- Rewards come from the shared LoginRewards table; the server decides every claim.
local LoginRewards = require(game:GetService("ReplicatedStorage").Shared.LoginRewards)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Badge = require(script.Parent.UIBadge)
local Button = require(script.Parent.UIButton)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Shell = require(script.Parent.ScreenShell)
local Login = {}

type Card = {
	card: Kit.Card,
	title: TextLabel,
	icon: Frame,
	reward: TextLabel,
	lock: Frame,
	claimed: Badge.Badge,
	today: Badge.Badge,
}

-- The final cycle day is the big one: a wider card on a gold wash.
local finalWidth = 1.5

function Login.create(parent: Instance, ctx: Context.Context): Context.Screen
	local shell = Shell.create(parent, ctx, {
		id = "Login",
		title = "Daily Login",
		subtitle = "Rewards grow every day in a row · miss a day and you restart at Day 1",
	})
	local root = shell.root
	local streak = Badge.create(shell.chips, "Streak", "", {
		fill = Style.goldWash,
		color = Style.ink,
		height = 40,
		size = 16,
		font = Style.display(),
		icon = "Star",
	})
	streak.root.LayoutOrder = 1
	local body = Kit.canvas(shell.body, "LoginBody")
	local count = #LoginRewards.days
	local cards: { Card } = {}
	for index, reward in LoginRewards.days do
		local final = index == count
		local card = Kit.card(body, "Day" .. index, Style.white, 18, 4)
		local title = Kit.text(
			card.face,
			"Day",
			"DAY " .. index,
			14,
			Style.body(Enum.FontWeight.Heavy),
			Style.muted
		)
		title.TextXAlignment = Enum.TextXAlignment.Center
		local boxes = reward.boxes
		local icon = Icons.create(
			card.face,
			if boxes then "Gift" else "Coin",
			if boxes then Style.collection(boxes.collection).color else Style.ink,
			56
		)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		local text = Kit.text(card.face, "Reward", State.loginReward(reward), 16, Style.display())
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.TextWrapped = true
		text.TextTruncate = Enum.TextTruncate.None
		local lock = Icons.create(card.face, "Lock", Style.disabledBorder, 18)
		lock.AnchorPoint = Vector2.new(1, 0)
		local claimed = Badge.corner(card.face, "Claimed", {
			fill = Style.mintFill,
			color = Style.white,
			height = 24,
			size = 12,
			outline = Style.ink,
			icon = "Check",
		}, Vector2.new(0.5, 1), Vector2.new(0, 10))
		claimed.set("CLAIMED")
		local today = Badge.corner(card.face, "Today", {
			fill = Style.violet,
			color = Style.white,
			height = 24,
			size = 12,
			outline = Style.ink,
		}, Vector2.new(0.5, 0), Vector2.new(0, -12))
		today.set("TODAY")
		if final then
			local star = Icons.create(card.face, "Star", Style.coinRing, 22)
			star.Position = UDim2.fromOffset(10, 8)
		end
		cards[index] = {
			card = card,
			title = title,
			icon = icon,
			reward = text,
			lock = lock,
			claimed = claimed,
			today = today,
		}
	end
	local claim = Button.create(
		body,
		"ClaimLogin",
		{ variant = "gold", text = "Claim", size = 22, radius = 18, drop = 4 },
		ctx.scope,
		ctx.effects,
		function()
			ctx.send("Login", nil, nil, nil)
		end
	)
	local width, height, phone = 0, 0, false
	local function arrange()
		local pad = if phone then 12 else 20
		local gap = if phone then 8 else 12
		local top = if phone then 20 else 30
		local buttonHeight = if phone then 52 else 64
		local unit = math.max(
			1,
			math.floor((width - pad * 2 - gap * (count - 1)) / (count - 1 + finalWidth))
		)
		local cardHeight = math.clamp(
			height - top - buttonHeight - (if phone then 44 else 64),
			if phone then 150 else 190,
			if phone then 200 else 250
		)
		local iconSize = if phone then 40 else 56
		local x = pad
		for index, entry in cards do
			local cardWidth = if index == count then math.floor(unit * finalWidth) else unit
			Kit.rect(entry.card.root, x, top, cardWidth, cardHeight)
			Kit.rect(entry.title, 4, 12, cardWidth - 8, 20)
			entry.title.TextSize = if phone then 12 else 14
			local iconY = math.floor(cardHeight * 0.4)
			entry.icon.Position = UDim2.fromOffset(cardWidth / 2, iconY)
			entry.icon.Size = UDim2.fromOffset(iconSize, iconSize)
			local textY = iconY + iconSize / 2 + 8
			Kit.rect(entry.reward, 6, textY, cardWidth - 12, cardHeight - textY - 14)
			entry.reward.TextSize = if phone then 13 else 16
			entry.lock.Position = UDim2.fromOffset(cardWidth - 8, 10)
			x += cardWidth + gap
		end
		local buttonWidth = math.min(420, width - pad * 2)
		local buttonY = top + cardHeight + (if phone then 24 else 36)
		Kit.rect(claim.button, (width - buttonWidth) / 2, buttonY, buttonWidth, buttonHeight)
		Kit.fit(body, buttonY + buttonHeight + 16, height)
	end
	local function update(snapshot: Types.Snapshot)
		shell.update(snapshot)
		local today, days, done = State.loginDays(snapshot)
		streak.set(done .. "-day streak")
		streak.root.Visible = done > 0
		for index, entry in cards do
			local status = days[index].status
			local final = index == count
			local face, stroke = entry.card.face, entry.card.stroke
			face.BackgroundColor3 = if status == "claimed"
				then Style.mint
				elseif status == "ready" then Style.readyWash
				elseif final then Style.goldWash
				else Style.lockedFill
			stroke.Color = if status == "ready"
				then Style.violet
				elseif status == "locked" then Style.lockedBorder
				else Style.ink
			stroke.Thickness = if status == "ready" then 4 else Style.outline
			entry.card.shadow.Visible = status ~= "locked"
			entry.title.TextColor3 = if status == "claimed"
				then Style.mintText
				elseif status == "ready" then Style.violetDark
				else Style.muted
			entry.reward.TextColor3 = if status == "locked" then Style.muted else Style.ink
			entry.lock.Visible = status == "locked"
			entry.claimed.root.Visible = status == "claimed"
			entry.today.root.Visible = index == today
			entry.card.root:SetAttribute("Status", status)
		end
		local ready = snapshot.loginReady
		claim.set(
			if ready then "Claim Day " .. today else "Claimed · come back tomorrow",
			ready and ctx.canAct(),
			if ready
				then (string.gsub(State.loginReward(LoginRewards.days[today]), "\n", " + "))
				else "Next reward at 00:00 UTC"
		)
	end
	return {
		root = root,
		update = update,
		layout = function(nextWidth: number, nextHeight: number, nextPhone: boolean)
			phone = nextPhone
			width, height = shell.layout(nextWidth, nextHeight, nextPhone)
			arrange()
			local snapshot = ctx.snapshot()
			if snapshot then
				update(snapshot)
			end
		end,
	}
end

return Login

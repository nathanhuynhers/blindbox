--!strict
-- Daily goal tracker in the HUD: a card under the gear on desktop, a "Goal done" chip on phone.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local Progress = require(script.Parent.UIProgress)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Tracker = {}

export type Tracker = {
	card: Frame,
	chip: TextButton,
	layout: (x: number, y: number, phone: boolean) -> (),
	update: (Types.Snapshot) -> (),
}

local CARD_WIDTH = 270

function Tracker.create(parent: Instance, ctx: Context.Context): Tracker
	local card = Kit.card(parent, "GoalTracker", Style.white, 18, 4)
	local open = Instance.new("TextButton")
	open.Name = "OpenGoals"
	open.Text = ""
	open.BackgroundTransparency = 1
	open.Size = UDim2.fromScale(1, 1)
	open.Parent = card.face
	open:SetAttribute("AccessibleName", "Open Goals")
	ctx.scope.connect(open.Activated, function()
		ctx.navigate("Goals")
	end)
	local heading = Kit.text(
		card.face,
		"Heading",
		"DAILY GOAL",
		13,
		Style.body(Enum.FontWeight.Heavy),
		Style.muted
	)
	Kit.rect(heading, 14, 10, 140, 18)
	local status =
		Kit.text(card.face, "Status", "", 13, Style.body(Enum.FontWeight.Heavy), Style.mintText)
	status.TextXAlignment = Enum.TextXAlignment.Right
	Kit.rect(status, CARD_WIDTH - 154, 10, 140, 18)
	local title =
		Kit.text(card.face, "GoalTitle", "Display 3 different figures", 17, Style.display())
	Kit.rect(title, 14, 32, CARD_WIDTH - 28, 22)
	local segments = Progress.segments(card.face, "GoalProgress", 3, 8, 4)
	Kit.rect(segments.root, 14, 60, CARD_WIDTH - 28, 8)
	local claim = Button.create(
		card.face,
		"Claim",
		{
			variant = "gold",
			text = "Claim",
			size = 17,
			radius = 12,
			drop = 0,
			outline = Style.outlineSmall,
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.send("Goal", nil, nil, nil)
		end
	)
	claim.button.ZIndex = 3
	Kit.rect(claim.button, 14, 78, CARD_WIDTH - 28, 44)
	local chip = Button.create(
		parent,
		"GoalChip",
		{
			variant = "gold",
			text = "Goal done · Claim",
			size = 16,
			radius = 22,
			drop = 3,
			icon = "Check",
		},
		ctx.scope,
		ctx.effects,
		function()
			ctx.send("Goal", nil, nil, nil)
		end
	)
	chip.button.AnchorPoint = Vector2.new(1, 0)
	local phone = false
	local function size(ready: boolean)
		card.root.Size = UDim2.fromOffset(CARD_WIDTH, if ready then 136 else 82)
	end
	return {
		card = card.root,
		chip = chip.button,
		layout = function(x: number, y: number, nextPhone: boolean)
			phone = nextPhone
			card.root.Position = UDim2.fromOffset(x, y)
			chip.button.Position = UDim2.fromOffset(x, y)
		end,
		update = function(snapshot: Types.Snapshot)
			local goal = State.goal(snapshot)
			local reward = State.compact(State.goalReward(snapshot))
			local progress = math.clamp(snapshot.goalProgress, 0, 3)
			status.Text = if goal == "claimed"
				then "Claimed"
				else string.format(
					"%d / 3%s",
					progress,
					if goal == "ready" then " done" else ""
				)
			status.TextColor3 = if goal == "progress" then Style.muted else Style.mintText
			segments.set(progress)
			claim.button.Visible = goal == "ready"
			claim.set("Claim " .. reward .. " coins", ctx.canAct())
			size(goal == "ready")
			chip.set("Goal done · Claim " .. reward, ctx.canAct())
			chip.button.Size = UDim2.fromOffset(170 + #reward * 10, 44)
			card.root.Visible = not phone
			chip.button.Visible = phone and goal == "ready"
		end,
	}
end

return Tracker

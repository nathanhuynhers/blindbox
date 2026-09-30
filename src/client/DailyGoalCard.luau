--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Style = require(script.Parent.SystemStyle)
local State = require(script.Parent.SystemState)
local UI = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Card = {}
function Card.create(parent: Instance, ctx: Context.Context)
	local root = Style.panel(parent, "DailyDisplayGoal", Style.card)
	local tag = Style.text(root, "DailyTag", "DAILY DISPLAY", 12, true)
	W.inset(tag, 12, 24)
	tag.TextColor3 = Style.accent
	local title = Style.text(root, "Requirement", "Display 3 unique figures", 23, true)
	W.inset(title, 40, 64)
	local segments: { { root: Frame, text: TextLabel } } = {}
	for index = 1, 3 do
		local segment = Style.panel(root, "Milestone" .. index, Style.inset, 12)
		segment.Position = UDim2.new((index - 1) / 3, 12, 0, 116)
		segment.Size = UDim2.new(1 / 3, -16, 0, 44)
		local text = Style.text(segment, "MilestoneNumber", tostring(index), 20, true)
		text.Size = UDim2.fromScale(1, 1)
		text.TextXAlignment = Enum.TextXAlignment.Center
		segments[index] = { root = segment, text = text }
	end
	local progress = Style.text(root, "ProgressStatus", "Loading today's progress...", 14)
	W.inset(progress, 170, 32)
	local reward = Style.panel(root, "RewardTicket", Style.gold, 10)
	W.inset(reward, 210, 72)
	local amount = Style.text(reward, "CoinReward", "", 22, true)
	amount.TextColor3 = Style.goldInk
	amount.Position = UDim2.fromOffset(12, 5)
	amount.Size = UDim2.new(1, -24, 0, 34)
	local rewardLabel = Style.text(reward, "RewardLabel", "TODAY'S REWARD", 12)
	rewardLabel.TextColor3 = Style.goldInk
	rewardLabel.Position = UDim2.fromOffset(12, 39)
	rewardLabel.Size = UDim2.new(1, -24, 0, 24)
	local claim = Style.action(root, "Claim reward", ctx, function()
		ctx.send("Goal", nil, nil, nil)
	end)
	W.inset(claim.button, 238, 48)
	claim.button.Visible = false
	return {
		root = root,
		update = function(snapshot: Types.Snapshot)
			local state = State.goal(snapshot)
			root:SetAttribute("GoalState", state)
			for index, segment in segments do
				local reached = snapshot.goalProgress >= index
				segment.root.BackgroundColor3 = if reached then Style.successWash else Style.inset
				segment.text.TextColor3 = if reached then Style.success else Style.muted
				segment.text.Text = if reached then "\u{2713}" else tostring(index)
			end
			progress.Text = if state == "claimed"
				then "Completed & collected. See you tomorrow!"
				elseif state == "ready" then "3 / 3 complete. Your reward is ready."
				else string.format("%d / 3 unique figures displayed", snapshot.goalProgress)
			progress.TextColor3 = if state == "progress" then Style.muted else Style.success
			amount.Text = "+" .. UI.number(snapshot.goalReward) .. " Coins"
			claim.button.Visible = state == "ready"
			claim.set(
				"Claim " .. UI.number(snapshot.goalReward) .. " Coins",
				ctx.canAct() and state == "ready"
			)
			reward.Visible = state ~= "ready"
			rewardLabel.Text = if state == "claimed" then "REWARD COLLECTED" else "TODAY'S REWARD"
		end,
	}
end
return Card

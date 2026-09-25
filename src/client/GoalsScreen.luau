--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local State = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Icons = require(script.Parent.UIIcons)
local Goals = {}
function Goals.create(parent: Instance, ctx: Context.Context): Context.Screen
	local page = W.scroll(parent, "Goals", ctx.scope)
	local goal = W.card(page, "DailyDisplay", 258)
	goal.LayoutOrder = 1
	local title = W.title(goal, "Daily display", 36)
	W.inset(title, 12, 36)
	local instruction = W.label(goal, "Display 3 unique figures", 26)
	W.inset(instruction, 52, 26)
	local dots: { Frame } = {}
	for index = 1, 3 do
		local dot = W.frame(goal, "Milestone" .. index, Theme.disabled)
		dot.Size = UDim2.fromOffset(28, 28)
		dot.Position = UDim2.fromOffset(12 + (index - 1) * 38, 92)
		W.corner(dot, 14)
		dots[index] = dot
	end
	local progress = W.label(goal, "", 32, 18)
	progress.Position = UDim2.fromOffset(136, 88)
	progress.Size = UDim2.new(1, -148, 0, 32)
	local reward = W.label(goal, "", 36, 22)
	W.inset(reward, 140, 36)
	local claim = W.action(goal, "Claim", ctx.scope, ctx.effects, function()
		ctx.send("Goal", nil, nil, nil)
	end)
	W.inset(claim.button, 194, 48)
	local free = W.card(page, "DailyBox", 126 + #Catalog.collections * 60)
	free.LayoutOrder = 2
	local gift = Icons.create(free, "Shop", Theme.primary)
	gift.Position = UDim2.fromOffset(16, 18)
	gift.Size = UDim2.fromOffset(42, 42)
	local dailyTitle = W.title(free, "Your daily surprise", 36)
	dailyTitle.Position = UDim2.fromOffset(70, 10)
	dailyTitle.Size = UDim2.new(1, -82, 0, 44)
	dailyTitle.TextSize = 22
	local status = W.label(free, "", 38, 14)
	W.inset(status, 62, 38)
	local choices: { W.Action } = {}
	for index, collection in Catalog.collections do
		local choice = W.action(free, collection.name, ctx.scope, ctx.effects, function()
			ctx.send("Daily", nil, nil, collection.id)
		end, true)
		W.inset(choice.button, 112 + (index - 1) * 60, 48)
		choices[index] = choice
	end
	local plaques: { [string]: { text: TextLabel, progress: (number, number) -> () } } = {}
	for index, collection in Catalog.collections do
		local plaque = W.card(page, "Plaque" .. collection.id, 118)
		plaque.LayoutOrder = 3 + index
		local text = W.label(plaque, "", 66, 17)
		W.inset(text, 10, 66)
		local track = W.frame(plaque, "Track")
		track.Position = UDim2.fromOffset(12, 90)
		track.Size = UDim2.new(1, -24, 0, 10)
		plaques[collection.id] = { text = text, progress = W.progress(track) }
	end
	return {
		root = page,
		update = function(snapshot: Types.Snapshot)
			for index, dot in dots do
				dot.BackgroundColor3 = if snapshot.goalProgress >= index
					then Theme.primary
					else Theme.disabled
			end
			progress.Text = snapshot.goalProgress .. " / 3"
			reward.Text = "+" .. State.number(snapshot.goalReward) .. " Coins"
			claim.set(
				if snapshot.goalClaimed
					then "Claimed"
					elseif snapshot.goalProgress >= 3 then "Claim reward"
					else "Keep displaying",
				ctx.canAct() and not snapshot.goalClaimed and snapshot.goalProgress >= 3
			)
			status.Text = if snapshot.dailyReady
				then "Available · Choose one free box"
				else "Claimed · Back at 00:00 UTC"
			for _, choice in choices do
				choice.set(choice.button.Name, ctx.canAct() and snapshot.dailyReady)
			end
			for _, collection in Catalog.collections do
				local found, total = State.completion(snapshot, collection.id)
				local plaque = plaques[collection.id]
				plaque.text.Text = collection.name
					.. "\n"
					.. (
						if found == total
							then "Complete! Showroom plaque earned"
							else found .. " / " .. total .. " · Collect the set for its plaque"
					)
				plaque.progress(found, total)
			end
		end,
	}
end
return Goals

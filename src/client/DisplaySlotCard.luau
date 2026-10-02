--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Style = require(script.Parent.SystemStyle)
local State = require(script.Parent.SystemState)
local UI = require(script.Parent.UIState)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Icons = require(script.Parent.UIIcons)
local Card = {}
function Card.create(parent: Instance, ctx: Context.Context, slot: number, choose: () -> ())
	local root, stroke = Style.panel(parent, "DisplaySlot" .. slot, Style.card)
	stroke.Color = Style.accent
	stroke.Transparency = 1
	stroke.Thickness = 2
	local number = Style.text(root, "SlotNumber", string.format("%02d", slot), 14, true)
	W.inset(number, 8, 24)
	local stage = Style.panel(root, "PortraitWell", Style.inset, 42)
	stage.Position = UDim2.fromOffset(12, 36)
	stage.Size = UDim2.new(1, -24, 0, 144)
	W.gradient(stage, Style.card, Style.inset, 90)
	local base = Style.panel(stage, "OakPlinth", Style.oak, 14)
	base.Position = UDim2.new(0.1, 0, 1, -24)
	base.Size = UDim2.new(0.8, 0, 0, 20)
	local top = Style.panel(base, "PlinthTop", Style.card, 10)
	top.Size = UDim2.new(1, 0, 0, 8)
	local portrait = Preview.create(stage, ctx.scope, true)
	portrait.frame.Position = UDim2.fromOffset(2, 0)
	portrait.frame.Size = UDim2.new(1, -4, 1, -16)
	local empty = Style.text(stage, "EmptyPlinth", "+", 46, true)
	empty.Size = UDim2.new(1, 0, 1, -20)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.TextColor3 = Style.trim
	local lock = Icons.create(stage, "Lock", Style.muted)
	lock.Position = UDim2.new(0.5, -22, 0.5, -28)
	lock.Size = UDim2.fromOffset(44, 44)
	lock.Visible = false
	local name = Style.text(root, "FigureName", "Choose a figure", 17, true)
	W.inset(name, 184, 42)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local rate = Style.text(root, "Income", "Put this plinth to work", 14)
	W.inset(rate, 222, 40)
	rate.TextXAlignment = Enum.TextXAlignment.Center
	local action = Style.action(root, "Choose figure", ctx, choose)
	action.set("Loading...", false)
	W.inset(action.button, 264, 48)
	local remove = Style.action(root, "Remove", ctx, function()
		ctx.send("Remove", nil, slot, nil)
	end, true)
	remove.button:SetAttribute("Quiet", true)
	remove.button.Visible = false
	return {
		root = root,
		update = function(snapshot: Types.Snapshot, selected: string?)
			local state = State.display(snapshot, slot, selected, ctx.canAct())
			root:SetAttribute("Slot", slot)
			root:SetAttribute("FigureId", state.id)
			root:SetAttribute("Locked", state.locked)
			root:SetAttribute("ValidTarget", selected ~= nil and not state.locked and state.enabled)
			root.BackgroundColor3 = if state.locked
				then Style.paper
				elseif selected and state.enabled then Style.selection
				else Style.card
			stroke.Transparency = if selected and state.enabled and not state.locked then 0.1 else 1
			number.Text = string.format(
				"%02d  %s",
				slot,
				if state.locked
					then "EXTRA SLOT"
					elseif selected and state.enabled then "PLACE HERE"
					else "DISPLAY"
			)
			portrait.figure(if state.id ~= "" and not state.locked then state.id else nil, true)
			empty.Visible = state.id == "" and not state.locked
			lock.Visible = state.locked
			name.Text = if state.locked
				then (if state.available then "Room for one more" else "Extra Display slot")
				elseif state.id ~= "" then Catalog.byId[state.id].name
				else "Your next favorite"
			rate.Text = if state.locked
				then (if state.available
					then UI.number(snapshot.expansionCost) .. " Coins"
					else "Unlock the previous slot first")
				elseif state.id ~= "" then string.format(
					"+%.2f/sec\n%s Coins ready",
					state.rate,
					UI.number(math.floor(snapshot.earnings[state.id] or 0))
				)
				else "Choose a figure to earn Coins"
			rate.TextColor3 = if not state.locked and state.id ~= ""
				then Style.success
				else Style.muted
			action.button.Visible = not state.locked or state.available
			action.set(state.action, state.enabled)
			remove.button.Visible = state.remove
			remove.set("Remove", ctx.canAct())
			action.button.Size = if state.remove
				then UDim2.new(0.62, -15, 0, 48)
				else UDim2.new(1, -24, 0, 48)
			remove.button.Position = UDim2.new(0.62, 0, 0, 264)
			remove.button.Size = UDim2.new(0.38, -12, 0, 48)
		end,
	}
end
return Card

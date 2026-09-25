--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Visits = {}
function Visits.create(parent: Instance, ctx: Context.Context): Context.Screen
	local root = W.frame(parent, "Visits", Theme.paper)
	W.corner(root, 16)
	W.outline(root, Theme.card, 0.15)
	local title = W.title(root, "The showroom circle", 38)
	W.inset(title, 10, 38)
	title.TextSize = 23
	local page = W.scroll(root, "ShowroomDirectory", ctx.scope)
	page.Position = UDim2.fromOffset(0, 52)
	page.Size = UDim2.new(1, 0, 1, -52)
	local home = W.action(page, "Return home", ctx.scope, ctx.effects, function()
		ctx.visit(0)
	end, true)
	home.button.LayoutOrder = 1
	home.button:SetAttribute("Quiet", true)
	local heading = W.label(page, "Showrooms in this server", 34, 18)
	heading.LayoutOrder = 2
	local tiles = W.tiles(page, ctx.scope, 218, 3, 226)
	tiles.LayoutOrder = 3
	local cards: {
		{
			root: Frame,
			name: TextLabel,
			status: TextLabel,
			previews: { Preview.Preview },
			action: W.Action,
			target: number?,
		}
	} =
		{}
	for index = 1, 24 do
		local card = W.card(tiles, "Room" .. index, 226)
		card.LayoutOrder = index
		card.Visible = false
		local stage = W.frame(card, "DisplayStage", Theme.soft)
		stage.Position = UDim2.fromOffset(6, 78)
		stage.Size = UDim2.new(1, -12, 0, 88)
		W.corner(stage, 8)
		W.gradient(stage, Theme.paper, Theme.soft, 90)
		local name = W.title(card, "", 42)
		W.inset(name, 8, 42)
		name.TextSize = 21
		local status = W.label(card, "", 24, 14)
		W.inset(status, 52, 24)
		status.TextColor3 = Theme.muted
		local previews: { Preview.Preview } = {}
		for slot = 1, 4 do
			local preview = Preview.create(card, ctx.scope)
			preview.frame.Position = UDim2.new((slot - 1) * 0.25, 0, 0, 82)
			preview.frame.Size = UDim2.new(0.25, 0, 0, 80)
			previews[slot] = preview
		end
		local action = W.action(card, "Visit", ctx.scope, ctx.effects, function()
			local target = cards[index].target
			if target then
				ctx.visit(target)
			end
		end)
		W.inset(action.button, 172, 44)
		cards[index] = {
			root = card,
			name = name,
			status = status,
			previews = previews,
			action = action,
			target = nil,
		}
	end
	return {
		root = root,
		update = function(snapshot: Types.Snapshot)
			for index, card in cards do
				local room = snapshot.rooms[index]
				card.root.Visible = room ~= nil
				card.target = if room then room.userId else nil
				if room then
					card.name.Text = room.name
					local count = 0
					for _, id in room.slots do
						if id ~= "" then
							count += 1
						end
					end
					card.status.Text = if count == 0
						then "Open · A new showroom"
						else string.format(
							"Open · %d figures · %g Coins/sec",
							count,
							room.rate
						)
					card.action.set(
						if room.userId == snapshot.visiting then "You're here" else "Visit showroom",
						room.userId ~= snapshot.visiting and snapshot.ready
					)
				end
				for slot, preview in card.previews do
					local id = if room then room.slots[slot] else nil
					preview.figure(if id == "" then nil else id, true)
				end
			end
		end,
	}
end
return Visits

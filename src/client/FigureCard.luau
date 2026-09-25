--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)
local Preview = require(script.Parent.UIPreview)
local Card = {}
function Card.create(parent: Instance, id: string, ctx: Context.Context)
	local definition = Catalog.byId[id]
	local action = W.action(parent, "", ctx.scope, ctx.effects, function()
		ctx.inspect(id)
	end, true)
	local root = action.button
	root.Name = id
	local tint = W.frame(root, "Rarity", Theme.rarity(definition.rarity))
	tint.Size = UDim2.new(1, -12, 1, -66)
	tint.Position = UDim2.fromOffset(6, 6)
	W.corner(tint, 14)
	local portrait = Preview.create(tint, ctx.scope)
	local quantity = W.label(tint, "", 24, 14)
	quantity.TextXAlignment = Enum.TextXAlignment.Right
	quantity.Position = UDim2.fromOffset(6, 4)
	quantity.Size = UDim2.new(1, -14, 0, 24)
	quantity.ZIndex = 2
	local name = W.label(root, "Mystery figure", 34, 14)
	name.Position = UDim2.new(0, 8, 1, -62)
	name.Size = UDim2.new(1, -16, 0, 34)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local rarity = W.label(root, definition.rarity, 22, 13)
	rarity.TextColor3 = Theme.muted
	rarity.Position = UDim2.new(0, 8, 1, -26)
	rarity.Size = UDim2.new(1, -16, 0, 22)
	rarity.TextXAlignment = Enum.TextXAlignment.Center
	return {
		root = root,
		update = function(snapshot: Types.Snapshot)
			local discovered = snapshot.discovered[id] == true
			portrait.figure(id, discovered)
			quantity.Text = if discovered then "x" .. (snapshot.owned[id] or 0) else "?"
			name.Text = if discovered then definition.name else "Mystery figure"
			root:SetAttribute("Discovered", discovered)
			root:SetAttribute("Owned", snapshot.owned[id] or 0)
		end,
	}
end
return Card

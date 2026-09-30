--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Context = require(script.Parent.UIContext)
local Style = require(script.Parent.SystemStyle)
local Preview = require(script.Parent.UIPreview)
local Card = {}
function Card.create(parent: Instance, ctx: Context.Context, name: string, callback: () -> ())
	local action = Style.action(parent, "", ctx, callback, true)
	action.button.Name = name
	local face, outline = Style.panel(action.button, "FigureWell", Style.card, 12)
	face.Position = UDim2.fromOffset(3, 3)
	face.Size = UDim2.new(1, -6, 1, -6)
	outline.Color = Style.accent
	outline.Transparency = 1
	outline.Thickness = 2
	local plinth = Style.panel(face, "Plinth", Style.oak, 12)
	plinth.Position = UDim2.new(0.12, 0, 1, -38)
	plinth.Size = UDim2.new(0.76, 0, 0, 9)
	local preview = Preview.create(face, ctx.scope, true)
	preview.frame.Position = UDim2.fromOffset(4, 4)
	preview.frame.Size = UDim2.new(1, -8, 1, -34)
	local empty = Style.text(face, "Empty", "+", 30, true)
	empty.Size = UDim2.new(1, 0, 1, -32)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.TextColor3 = Style.trim
	local title = Style.text(face, "FigureName", "Empty", 12)
	title.Position = UDim2.new(0, 4, 1, -30)
	title.Size = UDim2.new(1, -8, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local mark = Style.text(face, "Selected", "", 12, true)
	mark.Position = UDim2.fromOffset(5, 2)
	mark.Size = UDim2.fromOffset(24, 20)
	mark.TextColor3 = Style.accent
	return {
		root = action.button,
		set = function(id: string?, selected: boolean, enabled: boolean)
			action.set("", enabled)
			preview.figure(id, true)
			empty.Visible = id == nil
			title.Text = if id then Catalog.byId[id].name else "Empty"
			face.BackgroundColor3 = if selected then Style.selection else Style.card
			outline.Transparency = if selected then 0 else 1
			mark.Text = if selected then "\u{2713}" else ""
			action.button:SetAttribute("FigureId", id)
			action.button:SetAttribute("Selected", selected)
		end,
	}
end
return Card

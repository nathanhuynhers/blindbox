--!strict
local W = require(script.Parent.Widgets)
local Style = require(script.Parent.ShopStyle)
local Theme = require(script.Parent.ShopTheme)
local Art = require(script.Parent.ShopArtwork)
local Context = require(script.Parent.UIContext)
local Card = {}
export type Card = { button: TextButton, set: (number, number, boolean) -> () }

function Card.create(
	parent: Instance,
	ctx: Context.Context,
	id: string,
	name: string,
	choose: () -> ()
): Card
	local theme = Theme.get(id)
	local action = W.action(parent, "", ctx.scope, ctx.effects, choose, true)
	action.button.Name = "CollectionCard_" .. id
	action.button:SetAttribute("Quiet", true)
	action.button:SetAttribute("Accent", Style.gold)
	local shadow = Style.panel(action.button, "Shadow", Style.woodTrim, 16)
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.Size = UDim2.new(1, 0, 1, -4)
	shadow.BackgroundTransparency = 0.84
	local face = Style.panel(action.button, "CardFace", theme.wash, 16)
	face.Size = UDim2.new(1, 0, 1, -5)
	local outline = W.outline(face, Style.gold, 0.65)
	local pattern = Art.mount(face, "Pattern", Enum.ScaleType.Tile)
	pattern.root.Position = UDim2.fromOffset(3, 3)
	pattern.root.Size = UDim2.new(1, -6, 1, -6)
	pattern.image.TileSize = UDim2.fromOffset(200, 200)
	pattern.image.ImageTransparency = 0.88
	pattern.set(theme.patternKey)
	local emblem = Art.mount(face, "Emblem", Enum.ScaleType.Fit)
	emblem.root.Position = UDim2.fromOffset(14, 14)
	emblem.root.Size = UDim2.fromOffset(46, 46)
	local native = Style.label(emblem.native, "Mark", "\u{2726}", 32, true)
	native.Size = UDim2.fromScale(1, 1)
	native.TextXAlignment = Enum.TextXAlignment.Center
	emblem.set(theme.emblemKey)
	local title = Style.label(face, "CollectionName", name, 19, true)
	title.Position = UDim2.fromOffset(70, 12)
	title.Size = UDim2.new(1, -84, 0, 50)
	local progress = Style.label(face, "Discovery", "", 13)
	progress.Position = UDim2.fromOffset(16, 72)
	progress.Size = UDim2.new(1, -32, 0, 24)
	local track = Style.panel(face, "ProgressTrack", Style.secondary, 6)
	track.Position = UDim2.new(0, 16, 1, -17)
	track.Size = UDim2.new(1, -32, 0, 6)
	local fill = Style.panel(track, "Fill", theme.primary, 6)
	return {
		button = action.button,
		set = function(found: number, total: number, selected: boolean)
			action.set("", true)
			action.button:SetAttribute("Selected", selected)
			outline.Color = if selected then Style.gold else theme.primary
			outline.Thickness = if selected then 2 else 1
			outline.Transparency = if selected then 0.05 else 0.72
			shadow.BackgroundTransparency = if selected then 0.78 else 0.9
			progress.Text = string.format("%d / %d discovered", found, total)
			fill.Size = UDim2.fromScale(if total > 0 then found / total else 0, 1)
			fill.Visible = found > 0
		end,
	}
end
return Card

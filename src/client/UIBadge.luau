--!strict
-- Pills, chips and count badges that size to their text.
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Icons = require(script.Parent.UIIcons)
local Badge = {}

export type Badge = {
	root: Frame,
	label: TextLabel,
	set: (string) -> (),
	paint: (fill: Color3, text: Color3, outline: Color3?) -> (),
}
export type Options = {
	fill: Color3,
	color: Color3,
	height: number,
	size: number,
	outline: Color3?,
	thickness: number?,
	font: Font?,
	pad: number?,
	icon: string?,
	iconColor: Color3?,
}

function Badge.create(parent: Instance, name: string, text: string, options: Options): Badge
	local root = Kit.frame(parent, name, options.fill)
	root.AutomaticSize = Enum.AutomaticSize.X
	root.Size = UDim2.fromOffset(0, options.height)
	Kit.corner(root, math.floor(options.height / 2))
	local stroke =
		Kit.stroke(root, options.outline or options.fill, options.thickness or Style.outlineSmall)
	stroke.Enabled = options.outline ~= nil
	local pad = options.pad or math.floor(options.height * 0.38)
	Kit.padding(root, 0, pad, 0, pad)
	local list = Kit.list(root, Enum.FillDirection.Horizontal, 6, Enum.VerticalAlignment.Center)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	if options.icon then
		local icon = Icons.create(
			root,
			options.icon,
			options.iconColor or options.color,
			math.floor(options.size * 1.15)
		)
		icon.LayoutOrder = 0
	end
	local label = Kit.text(
		root,
		"Text",
		text,
		options.size,
		options.font or Style.body(Enum.FontWeight.Heavy),
		options.color
	)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.TextTruncate = Enum.TextTruncate.None
	label.LayoutOrder = 1
	return {
		root = root,
		label = label,
		set = function(value: string)
			label.Text = value
		end,
		paint = function(fill: Color3, color: Color3, outline: Color3?)
			root.BackgroundColor3 = fill
			label.TextColor3 = color
			stroke.Enabled = outline ~= nil
			if outline then
				stroke.Color = outline
			end
		end,
	}
end

export type RarityBadge = { root: Frame, label: TextLabel, rarity: (string) -> () }
function Badge.rarity(parent: Instance, height: number, size: number, outline: Color3?): RarityBadge
	local badge = Badge.create(parent, "RarityPill", "", {
		fill = Style.track,
		color = Style.ink,
		height = height,
		size = size,
		outline = outline,
	})
	return {
		root = badge.root,
		label = badge.label,
		rarity = function(id: string)
			local tint, onTint = Style.rarity(id)
			badge.paint(tint, onTint, outline)
			badge.set(string.upper(id))
		end,
	}
end

-- Small corner badge (dock counts, ×N, BEST, ON DISPLAY) anchored at a corner of its parent.
function Badge.corner(
	parent: Instance,
	name: string,
	options: Options,
	anchor: Vector2,
	offset: Vector2
): Badge
	local badge = Badge.create(parent, name, "", options)
	badge.root.AnchorPoint = anchor
	badge.root.Position = UDim2.new(anchor.X, offset.X, anchor.Y, offset.Y)
	badge.root.ZIndex = 20
	badge.root.Visible = false
	return badge
end

return Badge

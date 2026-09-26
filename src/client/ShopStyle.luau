--!strict
local W = require(script.Parent.Widgets)
local Style = {
	surface = Color3.fromRGB(247, 238, 220),
	elevated = Color3.fromRGB(255, 249, 238),
	secondary = Color3.fromRGB(239, 225, 197),
	wood = Color3.fromRGB(201, 150, 90),
	woodTrim = Color3.fromRGB(138, 90, 50),
	gold = Color3.fromRGB(216, 173, 90),
	ink = Color3.fromRGB(73, 52, 38),
	muted = Color3.fromRGB(121, 102, 87),
}

function Style.panel(parent: Instance, name: string, color: Color3, radius: number?): Frame
	local frame = W.frame(parent, name, color)
	W.corner(frame, radius or 18)
	return frame
end

function Style.label(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	heading: boolean?
): TextLabel
	local label = W.label(parent, text, size + 12, size)
	label.Name = name
	label.TextColor3 = if heading then Style.ink else Style.muted
	label.Font = if heading then Enum.Font.GothamBold else Enum.Font.Gotham
	return label
end

return Style

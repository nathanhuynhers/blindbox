--!strict
local OpeningConfig = require(script.Parent.OpeningConfig)
local Theme = {
	paper = Color3.fromRGB(249, 247, 243),
	card = Color3.fromRGB(255, 254, 251),
	ink = Color3.fromRGB(48, 44, 60),
	muted = Color3.fromRGB(113, 108, 123),
	primary = Color3.fromRGB(94, 83, 130),
	soft = Color3.fromRGB(236, 231, 243),
	disabled = Color3.fromRGB(227, 225, 230),
	gold = Color3.fromRGB(246, 205, 114),
	error = Color3.fromRGB(159, 65, 71),
	shadow = Color3.fromRGB(37, 33, 49),
	font = Enum.Font.GothamMedium,
	heading = Enum.Font.GothamBold,
	gap = 12,
	padding = 12,
	radius = 12,
	target = 48,
	transition = 0.14,
}
function Theme.rarity(name: string): Color3
	return OpeningConfig.profile(name).tint
end
return Theme

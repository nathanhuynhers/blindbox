--!strict
local OpeningConfig = require(script.Parent.OpeningConfig)
local Theme = {
	paper = Color3.fromRGB(249, 245, 234),
	card = Color3.fromRGB(255, 253, 246),
	ink = Color3.fromRGB(40, 65, 62),
	muted = Color3.fromRGB(89, 111, 104),
	primary = Color3.fromRGB(49, 113, 94),
	soft = Color3.fromRGB(222, 234, 217),
	disabled = Color3.fromRGB(220, 223, 216),
	gold = Color3.fromRGB(246, 205, 114),
	error = Color3.fromRGB(159, 65, 71),
	shadow = Color3.fromRGB(27, 48, 44),
	font = Enum.Font.GothamMedium,
	heading = Enum.Font.FredokaOne,
	gap = 12,
	padding = 12,
	radius = 18,
	target = 48,
	transition = 0.14,
}
function Theme.rarity(name: string): Color3
	return OpeningConfig.profile(name).tint
end
return Theme

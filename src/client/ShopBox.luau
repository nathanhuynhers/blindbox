--!strict
local ShopTheme = require(script.Parent.ShopTheme)
local Artwork = require(script.Parent.ShopArtwork)
local W = require(script.Parent.Widgets)

local ShopBox = {}
export type Box = { root: Frame, set: (ShopTheme.Theme, string) -> () }

local function fallbackPattern(parent: Instance)
	for index = 1, 7 do
		local dot = W.frame(parent, "Motif", Color3.new(1, 1, 1))
		dot.Size = UDim2.fromOffset(10 + index % 3 * 4, 10 + index % 3 * 4)
		dot.Position = UDim2.fromScale((index * 0.27) % 0.9, (index * 0.43) % 0.82)
		dot.BackgroundTransparency = 0.7
		W.corner(dot, 20)
	end
end

function ShopBox.create(parent: Instance): Box
	local root = W.frame(parent, "StandardBox")
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = root
	local shadow = W.frame(root, "BoxShadow", Color3.fromRGB(99, 72, 46))
	shadow.AnchorPoint = Vector2.new(0.5, 1)
	shadow.Position = UDim2.fromScale(0.52, 0.92)
	shadow.Size = UDim2.fromScale(0.84, 0.09)
	shadow.BackgroundTransparency = 0.68
	W.corner(shadow, 100)
	-- Offset rear face and folded top give the same package depth for every theme.
	local side = W.frame(root, "SideFace", Color3.new(1, 1, 1))
	side.Position = UDim2.fromScale(0.70, 0.16)
	side.Size = UDim2.fromScale(0.19, 0.67)
	W.corner(side, 5)
	local sideGradient = W.gradient(side, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0)
	W.outline(side, Color3.fromRGB(119, 97, 67), 0.6)
	local sidePattern = Artwork.mount(side, "Pattern", Enum.ScaleType.Tile)
	sidePattern.image.TileSize = UDim2.fromOffset(180, 180)
	sidePattern.image.ImageTransparency = 0.42
	fallbackPattern(sidePattern.native)
	local seam = W.frame(side, "Fold", Color3.fromRGB(81, 64, 45))
	seam.Position = UDim2.fromScale(0.12, 0.02)
	seam.Size = UDim2.fromScale(0.025, 0.96)
	seam.BackgroundTransparency = 0.65
	local body = W.frame(root, "Body", Color3.new(1, 1, 1))
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.43, 0.55)
	body.Size = UDim2.fromScale(0.68, 0.68)
	W.corner(body, 5)
	local bodyGradient = W.gradient(body, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 35)
	local bodyOutline = W.outline(body, Color3.new(1, 1, 1), 0.12)
	bodyOutline.Thickness = 2
	local bodyPattern = Artwork.mount(body, "Pattern", Enum.ScaleType.Tile)
	bodyPattern.image.TileSize = UDim2.fromOffset(230, 230)
	bodyPattern.image.ImageTransparency = 0.34
	fallbackPattern(bodyPattern.native)
	bodyPattern.root.Position = UDim2.fromScale(0.025, 0.025)
	bodyPattern.root.Size = UDim2.fromScale(0.95, 0.95)
	local inset = W.frame(body, "FoilFrame")
	inset.Position = UDim2.fromScale(0.05, 0.05)
	inset.Size = UDim2.fromScale(0.90, 0.90)
	W.corner(inset, 4)
	W.outline(inset, Color3.fromRGB(255, 247, 211), 0.15)
	local band = W.frame(body, "Band", Color3.new(1, 1, 1))
	band.Position = UDim2.fromScale(0.06, 0.61)
	band.Size = UDim2.fromScale(0.88, 0.30)
	band.BackgroundTransparency = 0.06
	W.corner(band, 5)
	local lid = W.frame(root, "Lid", Color3.new(1, 1, 1))
	lid.AnchorPoint = Vector2.new(0.5, 0.5)
	lid.Position = UDim2.fromScale(0.49, 0.18)
	lid.Size = UDim2.fromScale(0.79, 0.13)
	W.corner(lid, 5)
	local lidGradient = W.gradient(lid, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 25)
	local lidOutline = W.outline(lid, Color3.new(1, 1, 1), 0.12)
	lidOutline.Thickness = 2
	local lidPattern = Artwork.mount(lid, "Pattern", Enum.ScaleType.Tile)
	lidPattern.image.TileSize = UDim2.fromOffset(230, 230)
	lidPattern.image.ImageTransparency = 0.4
	fallbackPattern(lidPattern.native)
	local emblem = Artwork.mount(body, "Emblem", Enum.ScaleType.Fit)
	emblem.root.AnchorPoint = Vector2.new(0.5, 0.5)
	emblem.root.Position = UDim2.fromScale(0.5, 0.34)
	emblem.root.Size = UDim2.fromScale(0.48, 0.48)
	local fallback = W.label(emblem.native, "\u{2726}", 64, 42)
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.TextXAlignment = Enum.TextXAlignment.Center
	fallback.TextScaled = true
	local title = W.label(body, "", 34, 20)
	title.Position = UDim2.fromScale(0.10, 0.64)
	title.Size = UDim2.fromScale(0.80, 0.23)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	local titleLimit = Instance.new("UITextSizeConstraint")
	titleLimit.MinTextSize = 8
	titleLimit.MaxTextSize = 22
	titleLimit.Parent = title
	return {
		root = root,
		set = function(theme: ShopTheme.Theme, name: string)
			bodyGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), theme.wash)
			sideGradient.Color = ColorSequence.new(theme.primary, theme.secondary)
			sidePattern.set(theme.patternKey)
			lidGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), theme.secondary)
			bodyOutline.Color = theme.secondary
			lidOutline.Color = theme.secondary
			band.BackgroundColor3 = theme.primary
			bodyPattern.set(theme.patternKey)
			lidPattern.set(theme.patternKey)
			emblem.set(theme.emblemKey)
			fallback.TextColor3 = theme.primary
			title.Text = name
			title.TextColor3 = Color3.fromRGB(255, 251, 235)
		end,
	}
end

return ShopBox

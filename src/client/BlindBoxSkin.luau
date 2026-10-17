--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Assets = require(Shared.AssetManifest)
local Spec = require(Shared.BlindBoxSpec)
local Box = require(Shared.BlindBoxModel)
local Theme = require(script.Parent.ShopTheme)
local Catalog = require(Shared.Catalog)
local Skin = {}

local function paint(parts: { BasePart }?, color: Color3)
	if not parts then
		return
	end
	for _, part in parts do
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0
	end
end

function Skin.apply(
	model: Model,
	surfaces: Box.Surfaces,
	collectionId: string,
	renderTitle: boolean?
): { Instance }
	local theme = Theme.get(collectionId)
	local right, up, front = Box.axes(surfaces)
	-- The source GLB has no image textures; imported material layers can mask Part.Color.
	for _, child in model:GetDescendants() do
		if child:IsA("SurfaceAppearance") or child:GetAttribute("BlindBoxTheme") == true then
			child:Destroy()
		elseif child:IsA("MeshPart") then
			child.TextureID = ""
		end
	end
	paint(surfaces.BoxBody, theme.wash)
	paint(surfaces.LidCap, Color3.fromRGB(255, 249, 238))
	paint(surfaces.BottomCap, theme.trim)
	paint(surfaces.EmblemBadge, Color3.fromRGB(255, 249, 238))
	paint(surfaces.CollectionNamePlate, theme.primary)
	for _, name in Spec.trimSurfaces do
		paint(surfaces[name], theme.trim)
	end
	paint(surfaces.UpperTrimBand, theme.secondary)
	local normals = { FrontPatternPanel = front, SidePatternPanel = right, TopPatternPanel = up }
	local preload: { Instance } = {}
	local pattern = Assets.resolve(theme.patternKey)
	for _, name in Spec.patternSurfaces do
		paint(surfaces[name], theme.wash)
		for _, part in surfaces[name] do
			if pattern == "" then
				continue
			end
			local texture = Instance.new("Texture")
			texture.Name = "CollectionPattern"
			texture:SetAttribute("BlindBoxTheme", true)
			texture.Face = Box.face(part, normals[name])
			texture.Texture = pattern
			texture.Color3 = Color3.new(1, 1, 1)
			local tile = math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.85
			texture.StudsPerTileU, texture.StudsPerTileV = tile, tile
			texture.Parent = part
			table.insert(preload, texture)
		end
	end
	local emblem = Assets.resolve(theme.emblemKey)
	for _, part in surfaces.EmblemBadge do
		if emblem == "" then
			continue
		end
		local decal = Instance.new("Decal")
		decal.Name = "CollectionEmblem"
		decal:SetAttribute("BlindBoxTheme", true)
		decal.Face = Box.face(part, front)
		decal.Texture = emblem
		decal.Color3 = Color3.new(1, 1, 1)
		decal.Parent = part
		table.insert(preload, decal)
	end
	local title = collectionId
	for _, collection in Catalog.collections do
		if collection.id == collectionId then
			title = collection.name
			break
		end
	end
	for _, part in surfaces.CollectionNamePlate do
		-- World/stage boxes use one native label. Viewport previews own a projected label.
		if renderTitle == false then
			continue
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = "CollectionTitle"
		gui:SetAttribute("BlindBoxTheme", true)
		gui.Face = Box.face(part, front)
		gui.CanvasSize = Vector2.new(768, 192)
		gui.LightInfluence = 0
		gui.Parent = part
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(0.92, 0.88)
		text.Position = UDim2.fromScale(0.04, 0.06)
		text.BackgroundTransparency = 1
		text.Text = title
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.fromRGB(255, 249, 238)
		text.TextScaled = true
		text.TextWrapped = true
		text.Parent = gui
	end
	model:SetAttribute("CollectionId", collectionId)
	return preload
end

return Skin

--!strict
local FigureModel = require(game:GetService("ReplicatedStorage").Shared.FigureModel)
local Figure = {}
export type Figure = { model: Model, pose: (CFrame) -> (), appearance: (number) -> () }
type PartLook = {
	part: BasePart,
	color: Color3,
	material: Enum.Material,
	reflectance: number,
	transparency: number,
	texture: string?,
}
function Figure.create(parent: Instance, id: string): Figure
	-- Same awarded catalog ID and model factory used by Display/Collection; no extra definitions.
	local model = FigureModel.create(id, CFrame.new())
	model.Parent = parent
	local bounds, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * 3.1 / math.max(size.X, size.Y, size.Z))
	bounds, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-bounds.Position + Vector3.new(0, size.Y / 2, 0)) * model:GetPivot())
	local origin = model:GetPivot()
	local parts: { PartLook } = {}
	local images: { [Decal]: number } = {}
	local textures: { [Texture]: number } = {}
	local appearances: { [SurfaceAppearance]: Instance } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			table.insert(parts, {
				part = part,
				color = part.Color,
				material = part.Material,
				reflectance = part.Reflectance,
				transparency = part.Transparency,
				texture = if part:IsA("MeshPart") then part.TextureID else nil,
			})
		elseif part:IsA("Decal") then
			images[part] = part.Transparency
		elseif part:IsA("Texture") then
			textures[part] = part.Transparency
		elseif part:IsA("SurfaceAppearance") and part.Parent then
			appearances[part] = part.Parent
		end
	end
	-- Detached material layers remain owned by the session, never shared templates.
	local hidden = Instance.new("Folder")
	hidden.Name = "HiddenFigureMaterials"
	hidden.Parent = parent
	return {
		model = model,
		pose = function(at)
			model:PivotTo(at * origin)
		end,
		appearance = function(amount)
			for _, entry in parts do
				entry.part.Color = Color3.fromRGB(12, 17, 23):Lerp(entry.color, amount)
				entry.part.Material = if amount < 1
					then Enum.Material.SmoothPlastic
					else entry.material
				entry.part.Reflectance = entry.reflectance * amount
				entry.part.Transparency = entry.transparency
				if entry.part:IsA("MeshPart") and entry.texture then
					entry.part.TextureID = if amount < 1 then "" else entry.texture
				end
			end
			for object, transparency in images do
				object.Transparency = 1 - (1 - transparency) * amount
			end
			for object, transparency in textures do
				object.Transparency = 1 - (1 - transparency) * amount
			end
			for appearance, target in appearances do
				appearance.Parent = if amount < 1 then hidden else target
			end
		end,
	}
end
return Figure

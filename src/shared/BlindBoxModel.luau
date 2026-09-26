--!strict
local Spec = require(script.Parent.BlindBoxSpec)
local Box = {}
export type Surfaces = { [string]: { BasePart } }

-- Imported semantic objects can be Models containing MeshParts, not just named parts.
function Box.surfaces(model: Model): (Surfaces?, string)
	local result: Surfaces = {}
	for _, name in Spec.required do
		local node = model:FindFirstChild(name, true)
		local parts: { BasePart } = {}
		if node then
			if node:IsA("BasePart") then
				table.insert(parts, node)
			end
			for _, descendant in node:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
				end
			end
		end
		if #parts == 0 then
			return nil, "No geometry for " .. name
		end
		result[name] = parts
	end
	for _, name in Spec.trimSurfaces do
		if result[name] then
			continue
		end
		local node = model:FindFirstChild(name, true)
		if node then
			local parts: { BasePart } = {}
			if node:IsA("BasePart") then
				table.insert(parts, node)
			end
			for _, child in node:GetDescendants() do
				if child:IsA("BasePart") then
					table.insert(parts, child)
				end
			end
			result[name] = parts
		end
	end
	return result, ""
end

function Box.center(parts: { BasePart }): Vector3
	local sum = Vector3.zero
	for _, part in parts do
		sum += part.Position
	end
	return sum / #parts
end

function Box.axes(surfaces: Surfaces): (Vector3, Vector3, Vector3)
	local origin = Box.center(surfaces.BoxBody)
	local up = (Box.center(surfaces.TopPatternPanel) - Box.center(surfaces.BottomCap)).Unit
	local towardFront = Box.center(surfaces.FrontPatternPanel) - origin
	local front = (towardFront - up * towardFront:Dot(up)).Unit
	local right = up:Cross(front).Unit
	if right:Dot(Box.center(surfaces.SidePatternPanel) - origin) < 0 then
		right = -right
	end
	return right, up, front
end

function Box.face(part: BasePart, normal: Vector3): Enum.NormalId
	local n = part.CFrame:VectorToObjectSpace(normal)
	local x, y, z = math.abs(n.X), math.abs(n.Y), math.abs(n.Z)
	if x >= y and x >= z then
		return if n.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	end
	if y >= z then
		return if n.Y > 0 then Enum.NormalId.Top else Enum.NormalId.Bottom
	end
	return if n.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front
end

return Box

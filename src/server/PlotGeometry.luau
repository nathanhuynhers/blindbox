--!strict
local Config = require(script.Parent.PlotConfig)
local Shelf = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
-- Entrance looks along +Z, so its left is +X. Shelf fronts look inward along -X.
local Geometry = { displayZ = Config.depth / 2 - 12, shelfX = Config.width / 2 - 10 }
function Geometry.origin(index: number): Vector3
	assert(index >= 1 and index <= Config.maxPlots and index % 1 == 0, "Unknown fixed plot slot")
	local rows = math.ceil(Config.maxPlots / Config.columns)
	return Vector3.new(
		((index - 1) % Config.columns - (Config.columns - 1) / 2) * (Config.width + Config.gap),
		1,
		(math.floor((index - 1) / Config.columns) - (rows - 1) / 2) * (Config.depth + Config.gap)
	)
end
function Geometry.shelfOffset(unit: number, row: number, slot: number): Vector3
	return Vector3.new(
		Geometry.shelfX,
		2 + (Shelf.rowsPerShelfUnit - row) * 5,
		-4
			+ (unit - (Shelf.visibleShelfUnits + 1) / 2) * 24
			+ (slot - (Shelf.slotsPerRow + 1) / 2) * 5
	)
end
function Geometry.shelfAnchor(origin: Vector3, unit: number, row: number, slot: number): CFrame
	local position = origin + Geometry.shelfOffset(unit, row, slot)
	return CFrame.lookAt(position, position + Vector3.new(-1, 0, 0))
end
function Geometry.part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Parent = parent
	return part
end
function Geometry.label(part: BasePart, text: string, distance: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 54)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = distance or 80
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(40, 45, 52)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	label.TextSize = 16
	label.Text = text
	label.Parent = gui
	return label
end
return Geometry

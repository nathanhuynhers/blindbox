--!strict
local Config = require(script.Parent.PlotConfig)
local Shelf = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
-- Entrance is local -Z; Display is local +Z; Collection is local +X.
local Geometry = {
	displayZ = Config.depth / 2 - 12,
	shelfX = Config.width / 2 - 10,
	shelfCenterZ = -4,
	shelfUnitPitch = Shelf.slotsPerRow * 3.6 + 1.2,
	shelfSlotSpacing = 3.6,
	shelfRowSpacing = 4.2,
	shelfBaseY = 1.6,
}
function Geometry.angle(index: number): number
	assert(index >= 1 and index <= Config.maxPlots and index % 1 == 0, "Unknown fixed plot slot")
	return math.rad((index - 1) * 360 / Config.maxPlots)
end
function Geometry.radialPosition(index: number, radius: number, y: number?): Vector3
	local angle = Geometry.angle(index)
	return Vector3.new(math.sin(angle) * radius, y or Config.walkingY, -math.cos(angle) * radius)
end
function Geometry.transform(index: number): CFrame
	local position = Geometry.radialPosition(index, Config.plotRadius)
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end
function Geometry.radialTransform(index: number, radius: number, y: number?): CFrame
	local position = Geometry.radialPosition(index, radius, y)
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end
function Geometry.shelfOffset(unit: number, row: number, slot: number): Vector3
	return Vector3.new(
		Geometry.shelfX,
		Geometry.shelfBaseY + (Shelf.rowsPerShelfUnit - row) * Geometry.shelfRowSpacing,
		Geometry.shelfCenterZ
			+ (unit - (Shelf.visibleShelfUnits + 1) / 2) * Geometry.shelfUnitPitch
			+ (slot - (Shelf.slotsPerRow + 1) / 2) * Geometry.shelfSlotSpacing
	)
end
function Geometry.shelfAnchor(transform: CFrame, unit: number, row: number, slot: number): CFrame
	local offset = Geometry.shelfOffset(unit, row, slot)
	return transform * CFrame.lookAt(offset, offset + Vector3.new(-1, 0, 0))
end
function Geometry.partAt(
	parent: Instance,
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = at
	part.Color = color
	part.Parent = parent
	return part
end
function Geometry.part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3
): Part
	return Geometry.partAt(parent, name, size, CFrame.new(position), color)
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

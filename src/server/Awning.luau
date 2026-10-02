--!strict
-- Striped fabric awning of native parts. `back` is the center of the awning's raised back edge:
-- its X runs along the width and its -Z points toward the lower front overhang.
local Geometry = require(script.Parent.PlotGeometry)

local Awning = {}
Awning.style = table.freeze({
	stripeWidth = 2.4,
	thickness = 0.2,
	valanceHeight = 0.8,
	valanceThickness = 0.12,
	ivory = Color3.fromRGB(252, 249, 243),
})
local style = Awning.style

-- Odd stripe count so both ends are accent-colored.
function Awning.stripes(width: number): number
	local count = math.max(3, math.floor(width / style.stripeWidth + 0.5))
	return if count % 2 == 0 then count + 1 else count
end

-- Two ivory backing parts plus one accent part per accent stripe on the slope and the valance.
function Awning.partCount(width: number): number
	return 2 + 2 * math.ceil(Awning.stripes(width) / 2)
end

local function piece(parent: Instance, name: string, size: Vector3, at: CFrame, color: Color3): Part
	local part = Geometry.partAt(parent, name, size, at, color)
	part.Material = Enum.Material.Fabric
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

function Awning.build(
	parent: Instance,
	name: string,
	back: CFrame,
	width: number,
	depth: number,
	rise: number,
	accent: Color3
): Model
	local awning = Instance.new("Model")
	awning.Name = name
	local length = math.sqrt(depth * depth + rise * rise)
	local slope = back
		* CFrame.new(0, -rise / 2, -depth / 2)
		* CFrame.Angles(-math.atan2(rise, depth), 0, 0)
	local front = back * CFrame.new(0, -rise - style.valanceHeight / 2, -depth)
	piece(awning, "Canopy", Vector3.new(width, style.thickness, length), slope, style.ivory)
	piece(
		awning,
		"Valance",
		Vector3.new(width, style.valanceHeight, style.valanceThickness),
		front,
		style.ivory
	)
	local count = Awning.stripes(width)
	local stripe = width / count
	for index = 1, count, 2 do
		local x = -width / 2 + stripe * (index - 0.5)
		piece(
			awning,
			"Stripe",
			Vector3.new(stripe, style.thickness + 0.02, length + 0.02),
			slope * CFrame.new(x, 0, 0),
			accent
		)
		piece(
			awning,
			"ValanceStripe",
			Vector3.new(stripe, style.valanceHeight + 0.02, style.valanceThickness + 0.02),
			front * CFrame.new(x, 0, 0),
			accent
		)
	end
	awning.Parent = parent
	return awning
end

return Awning

--!strict
-- Original native shapes. Replace this one adapter with licensed image icons later.
local Icons = {}
function Icons.create(parent: Instance, name: string, color: Color3): Frame
	local root = Instance.new("Frame")
	root.Name = name .. "Icon"
	root.Size = UDim2.fromOffset(24, 24)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local function shape(
		x: number,
		y: number,
		w: number,
		h: number,
		round: boolean?,
		rotation: number?
	)
		local frame = Instance.new("Frame")
		frame.Position = UDim2.fromScale(x, y)
		frame.Size = UDim2.fromScale(w, h)
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Rotation = rotation or 0
		frame.Parent = root
		local corner = Instance.new("UICorner")
		corner.CornerRadius = if round then UDim.new(1, 0) else UDim.new(0, 2)
		corner.Parent = frame
	end
	if name == "Collection" then
		shape(0.08, 0.13, 0.37, 0.7)
		shape(0.55, 0.13, 0.37, 0.7)
		shape(0.44, 0.2, 0.12, 0.7)
	elseif name == "Display" then
		shape(0.05, 0.68, 0.9, 0.12)
		shape(0.16, 0.3, 0.25, 0.3, true)
		shape(0.58, 0.3, 0.25, 0.3, true)
	elseif name == "Shop" then
		shape(0.15, 0.4, 0.3, 0.5)
		shape(0.55, 0.4, 0.3, 0.5)
		shape(0.07, 0.21, 0.86, 0.14)
		shape(0.37, 0.02, 0.26, 0.22, true)
	elseif name == "Goals" then
		shape(0.24, 0.24, 0.52, 0.52, false, 45)
	elseif name == "Scrap" then
		shape(0.12, 0.1, 0.65, 0.29, false, -8)
		shape(0.28, 0.49, 0.58, 0.33, false, 12)
	elseif name == "Visits" then
		shape(0.12, 0.1, 0.32, 0.32, true)
		shape(0.57, 0.1, 0.32, 0.32, true)
		shape(0.07, 0.51, 0.41, 0.36, true)
		shape(0.52, 0.51, 0.41, 0.36, true)
	elseif name == "Lock" then
		shape(0.28, 0.06, 0.44, 0.55, true)
		shape(0.14, 0.44, 0.72, 0.48)
	elseif name == "Check" then
		shape(0.13, 0.48, 0.36, 0.15, false, 45)
		shape(0.35, 0.36, 0.6, 0.15, false, -45)
	elseif name == "Close" then
		shape(0.1, 0.43, 0.8, 0.12, false, 45)
		shape(0.1, 0.43, 0.8, 0.12, false, -45)
	else
		shape(0.08, 0.08, 0.84, 0.84, true)
	end
	return root
end
return Icons

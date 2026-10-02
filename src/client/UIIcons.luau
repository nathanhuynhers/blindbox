--!strict
-- Original native shapes drawn with frames (no image uploads). Each icon fills a square frame.
local Style = require(script.Parent.UIStyle)
local Icons = {}

local function part(
	root: Frame,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	rotation: number?,
	round: boolean?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Stroke"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	frame.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if round == false then UDim.new(0, 2) else UDim.new(1, 0)
	corner.Parent = frame
	return frame
end

local function ring(
	root: Frame,
	x: number,
	y: number,
	size: number,
	color: Color3,
	thickness: number
): Frame
	local frame = part(root, x, y, size, size, color)
	frame.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
	return frame
end

function Icons.create(parent: Instance, name: string, color: Color3, size: number): Frame
	local root = Instance.new("Frame")
	root.Name = name .. "Icon"
	root.Size = UDim2.fromOffset(size, size)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local line = math.max(2, size * 0.1)
	local bar = line / size
	if name == "Coin" then
		local coin = part(root, 0.5, 0.5, 0.86, 0.86, Style.gold)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Style.ink
		stroke.Thickness = math.max(1.5, size * 0.085)
		stroke.Parent = coin
		ring(root, 0.5, 0.5, 0.44, Style.coinRing, math.max(1.5, size * 0.075))
	elseif name == "Close" then
		part(root, 0.5, 0.5, 0.82, bar * 1.4, color, 45)
		part(root, 0.5, 0.5, 0.82, bar * 1.4, color, -45)
	elseif name == "Plus" then
		part(root, 0.5, 0.5, 0.74, bar * 1.3, color)
		part(root, 0.5, 0.5, bar * 1.3, 0.74, color)
	elseif name == "Check" then
		part(root, 0.36, 0.62, 0.36, bar * 1.4, color, 45)
		part(root, 0.6, 0.48, 0.6, bar * 1.4, color, -50)
	elseif name == "Left" or name == "Right" then
		local flip = if name == "Left" then 1 else -1
		part(root, 0.5, 0.36, 0.44, bar * 1.3, color, -45 * flip)
		part(root, 0.5, 0.64, 0.44, bar * 1.3, color, 45 * flip)
	elseif name == "Lock" then
		ring(root, 0.5, 0.36, 0.42, color, line)
		local body = part(root, 0.5, 0.66, 0.62, 0.44, color, 0, false)
		body.BackgroundColor3 = color
	elseif name == "Clock" then
		ring(root, 0.5, 0.5, 0.76, color, line)
		part(root, 0.5, 0.38, bar, 0.26, color)
		part(root, 0.58, 0.55, 0.2, bar, color, 30)
	elseif name == "Gear" then
		for index = 0, 7 do
			part(root, 0.5, 0.5, bar * 1.2, 0.92, color, index * 22.5 * 2)
		end
		local hub = part(root, 0.5, 0.5, 0.62, 0.62, Style.white)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = line
		stroke.Parent = hub
		ring(root, 0.5, 0.5, 0.24, color, line)
	elseif name == "Gift" then
		local box = part(root, 0.5, 0.64, 0.7, 0.48, color, 0, false)
		box.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = line
		stroke.Parent = box
		part(root, 0.5, 0.38, 0.86, bar * 1.2, color)
		part(root, 0.5, 0.62, bar * 1.2, 0.5, color)
		ring(root, 0.38, 0.24, 0.2, color, line * 0.8)
		ring(root, 0.62, 0.24, 0.2, color, line * 0.8)
	elseif name == "Star" then
		part(root, 0.5, 0.5, 0.56, 0.56, color, 45, false)
		part(root, 0.5, 0.5, 0.2, 0.86, color)
		part(root, 0.5, 0.5, 0.86, 0.2, color)
	end
	return root
end

return Icons

--!strict
-- Minimal engine boundary shim. Tests execute the actual PlayerPlot geometry and renderer.
-- This does not simulate Roblox physics, rendering, replication, or mouse/touch input.
local Engine = { nodes = {}, players = {}, clock = 0, connections = 0 }
local function signal()
	local callbacks = {}
	return {
		Connect = function(_self, callback)
			local key = {}
			callbacks[key] = callback
			Engine.connections += 1
			return {
				Disconnect = function()
					if callbacks[key] then
						callbacks[key] = nil
						Engine.connections -= 1
					end
				end,
			}
		end,
		fire = function(_self, ...)
			local copy = table.clone(callbacks)
			for key, callback in copy do
				if callbacks[key] then
					callback(...)
				end
			end
		end,
	}
end
local vectorMeta = {}
local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
vectorMeta.__add = function(a, b)
	return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vectorMeta.__sub = function(a, b)
	return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vectorMeta.__mul = function(a, b)
	if type(a) == "number" then
		return vector(a * b.X, a * b.Y, a * b.Z)
	end
	if type(b) == "number" then
		return vector(a.X * b, a.Y * b, a.Z * b)
	end
	return vector(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vectorMeta.__div = function(a, b)
	return vector(a.X / b, a.Y / b, a.Z / b)
end
vectorMeta.__unm = function(a)
	return vector(-a.X, -a.Y, -a.Z)
end
local function dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
local function cross(a, b)
	return vector(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
vectorMeta.__index = function(value, key)
	if key == "Magnitude" then
		return math.sqrt(value.X ^ 2 + value.Y ^ 2 + value.Z ^ 2)
	end
	if key == "Unit" then
		local length = math.sqrt(value.X ^ 2 + value.Y ^ 2 + value.Z ^ 2)
		return vector(value.X / length, value.Y / length, value.Z / length)
	end
	if key == "Dot" then
		return dot
	end
	if key == "Cross" then
		return cross
	end
	return nil
end
Engine.Vector3 = { new = vector, zero = vector(0, 0, 0), yAxis = vector(0, 1, 0) }
Engine.Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
-- Enum items compare as their item names, e.g. Enum.Material.Wood == "Wood".
local enumOverrides = { KeyCode = { E = 1 } }
enumOverrides.UserInputType = {}
for _, name in { "Touch", "MouseButton1", "MouseMovement", "Keyboard", "Gamepad1" } do
	enumOverrides.UserInputType[name] = { Name = name }
end
Engine.Enum = setmetatable({}, {
	__index = function(_, enum)
		return enumOverrides[enum]
			or setmetatable({}, {
				__index = function(_, item)
					return item
				end,
			})
	end,
})
-- Full rigid-transform CFrames: rotation columns are Right, Up and Back (-Look).
local frameMeta = {}
local function frame(position, right, up, back)
	return setmetatable({
		Position = position,
		right = right or vector(1, 0, 0),
		up = up or vector(0, 1, 0),
		back = back or vector(0, 0, 1),
	}, frameMeta)
end
local function rotate(cf, v)
	return cf.right * v.X + cf.up * v.Y + cf.back * v.Z
end
local function unrotate(cf, v)
	return vector(dot(cf.right, v), dot(cf.up, v), dot(cf.back, v))
end
frameMeta.__mul = function(a, b)
	if getmetatable(b) == vectorMeta then
		return a.Position + rotate(a, b)
	end
	return frame(
		a.Position + rotate(a, b.Position),
		rotate(a, b.right),
		rotate(a, b.up),
		rotate(a, b.back)
	)
end
frameMeta.__add = function(a, b)
	return frame(a.Position + b, a.right, a.up, a.back)
end
frameMeta.__index = function(a, key)
	if key == "LookVector" then
		return -a.back
	elseif key == "RightVector" then
		return a.right
	elseif key == "UpVector" then
		return a.up
	elseif key == "X" or key == "Y" or key == "Z" then
		return a.Position[key]
	elseif key == "Rotation" then
		return frame(vector(0, 0, 0), a.right, a.up, a.back)
	elseif key == "Inverse" then
		return function(self)
			local right = vector(self.right.X, self.up.X, self.back.X)
			local up = vector(self.right.Y, self.up.Y, self.back.Y)
			local back = vector(self.right.Z, self.up.Z, self.back.Z)
			local inverse = frame(vector(0, 0, 0), right, up, back)
			return frame(-rotate(inverse, self.Position), right, up, back)
		end
	elseif key == "PointToObjectSpace" then
		return function(self, point)
			return unrotate(self, point - self.Position)
		end
	elseif key == "PointToWorldSpace" then
		return function(self, point)
			return self.Position + rotate(self, point)
		end
	elseif key == "VectorToWorldSpace" then
		return function(self, v)
			return rotate(self, v)
		end
	elseif key == "VectorToObjectSpace" then
		return function(self, v)
			return unrotate(self, v)
		end
	elseif key == "ToObjectSpace" then
		return function(self, other)
			return self:Inverse() * other
		end
	end
	return nil
end
local function axisX(angle)
	local c, s = math.cos(angle), math.sin(angle)
	return frame(vector(0, 0, 0), vector(1, 0, 0), vector(0, c, s), vector(0, -s, c))
end
local function axisY(angle)
	local c, s = math.cos(angle), math.sin(angle)
	return frame(vector(0, 0, 0), vector(c, 0, -s), vector(0, 1, 0), vector(s, 0, c))
end
local function axisZ(angle)
	local c, s = math.cos(angle), math.sin(angle)
	return frame(vector(0, 0, 0), vector(c, s, 0), vector(-s, c, 0), vector(0, 0, 1))
end
Engine.CFrame = {
	new = function(a, b, c)
		return frame(if type(a) == "number" then vector(a, b, c) else a)
	end,
	Angles = function(x, y, z)
		return axisX(x) * axisY(y) * axisZ(z)
	end,
	fromEulerAnglesYXZ = function(x, y, z)
		return axisY(y) * axisX(x) * axisZ(z)
	end,
	lookAt = function(position, target, upHint)
		local look = (target - position).Unit
		local right = cross(look, upHint or vector(0, 1, 0)).Unit
		local up = cross(right, look)
		return frame(position, right, up, -look)
	end,
	fromMatrix = function(position, right, up, back)
		return frame(position, right, up, back or cross(right, up))
	end,
}
local function children(object)
	return rawget(object, "_children")
end
local partClasses = { Part = true, SpawnLocation = true, WedgePart = true }
local function node(class)
	local object = {
		Name = class,
		ClassName = class,
		attrs = {},
		Destroying = signal(),
		MouseClick = signal(),
		Triggered = signal(),
		dead = false,
		CanCollide = true,
		Transparency = 0,
		_children = {},
	}
	setmetatable(object, {
		__index = function(self, key)
			if key == "CFrame" then
				return rawget(self, "_cframe") or frame(self.Position)
			elseif key == "Parent" then
				return rawget(self, "_parent")
			end
			return nil
		end,
		__newindex = function(self, key, value)
			if key == "CFrame" then
				rawset(self, "_cframe", value)
				rawset(self, "Position", value.Position)
			elseif key == "Parent" then
				local old = rawget(self, "_parent")
				if old == value then
					return
				end
				if old then
					local siblings = children(old)
					local index = table.find(siblings, self)
					if index then
						table.remove(siblings, index)
					end
				end
				rawset(self, "_parent", value)
				if value then
					table.insert(children(value), self)
				end
			else
				rawset(self, key, value)
			end
		end,
	})
	function object:GetPivot()
		return self.pivot or frame(self.Position)
	end
	function object:GetScale()
		return self.scale or 1
	end
	function object:ScaleTo(scale)
		self.scale = scale
	end
	function object:GetBoundingBox()
		return self:GetPivot(),
			vector(2 * self:GetScale(), 2 * self:GetScale(), 2 * self:GetScale())
	end
	function object:PivotTo(cf)
		self.pivot = cf
		self.Position = cf.Position
	end
	function object:Clone()
		local copy = node(self.ClassName)
		for key, value in pairs(self) do
			if type(value) ~= "function" and key ~= "_children" and key ~= "_parent" and key ~= "attrs" and key ~= "Destroying" and key ~= "MouseClick" then
				rawset(copy, key, value)
			end
		end
		for key, value in pairs(self.attrs) do
			copy.attrs[key] = value
		end
		for _, child in children(self) do
			child:Clone().Parent = copy
		end
		return copy
	end
	function object:GetChildren()
		return table.clone(children(self))
	end
	function object:GetDescendants()
		local found = {}
		for _, child in children(self) do
			table.insert(found, child)
			for _, nested in child:GetDescendants() do
				table.insert(found, nested)
			end
		end
		return found
	end
	function object:FindFirstChild(name)
		for _, child in children(self) do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function object:FindFirstChildOfClass(kind)
		for _, child in children(self) do
			if child.ClassName == kind then
				return child
			end
		end
		return nil
	end
	function object:IsA(kind)
		return self.ClassName == kind
			or (kind == "BasePart" and partClasses[self.ClassName] == true)
			or (kind == "Light" and (self.ClassName == "PointLight" or self.ClassName == "SurfaceLight"))
	end
	function object:SetAttribute(key, value)
		self.attrs[key] = value
	end
	function object:GetAttribute(key)
		return self.attrs[key]
	end
	function object:Destroy()
		if self.dead then
			return
		end
		self.dead = true
		self.Destroying:fire()
		self:ClearAllChildren()
		self.Parent = nil
	end
	function object:ClearAllChildren()
		for _, child in self:GetChildren() do
			child:Destroy()
		end
	end
	table.insert(Engine.nodes, object)
	return object
end
Engine.Instance = { new = node }
Engine.warnings = {}
function Engine.warn(...)
	table.insert(Engine.warnings, table.concat({ ... }, " "))
end
Engine.workspace = node("Workspace")
local colorMeta = {}
local function color(r, g, b)
	return setmetatable({ r, g, b, R = r / 255, G = g / 255, B = b / 255 }, colorMeta)
end
colorMeta.__index = {
	Lerp = function(a, b, t)
		return color(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)
	end,
}
Engine.Color3 = {
	fromRGB = color,
	new = function(r, g, b)
		return color(r * 255, g * 255, b * 255)
	end,
	fromHex = function(hex)
		local value = tonumber((string.gsub(hex, "#", "")), 16) or 0
		return color(
			bit32.rshift(value, 16),
			bit32.band(bit32.rshift(value, 8), 255),
			bit32.band(value, 255)
		)
	end,
}
Engine.NumberRange = {
	new = function(a, b)
		return { Min = a, Max = b or a }
	end,
}
Engine.NumberSequence = {
	new = function(a)
		return { a }
	end,
}
Engine.UDim = {
	new = function(scale, offset)
		return { Scale = scale, Offset = offset }
	end,
}
Engine.UDim2 = {
	new = function(xs, xo, ys, yo)
		return { xs, xo, ys, yo }
	end,
	fromOffset = function(x, y)
		return { x, y }
	end,
	fromScale = function(x, y)
		return { x, y }
	end,
}
local Template = {}
function Template.part(parent, name, position)
	local part = node("Part")
	part.Parent = parent
	part.Name = name
	part.Position = position
	return part
end
Engine.Template = Template
function Engine.player(id)
	local character = node("Model")
	local root = Template.part(character, "HumanoidRootPart", vector(0, 0, 0))
	local humanoid = node("Humanoid")
	humanoid.Parent = character
	humanoid.Health = 100
	function character:PivotTo(cf)
		root.Position = cf.Position
	end
	local player = { UserId = id, DisplayName = "Player " .. id, Character = character }
	Engine.players[id] = player
	return player
end
Engine.figureCreates = 0
Engine.FigureModel = {
	create = function(id, cf)
		Engine.figureCreates += 1
		local model = node("Model")
		model.Name = id
		-- Deliberately nonzero pivot offset: resizing must preserve anchor-relative model pivots.
		model:PivotTo(cf * frame(vector(0, 1, 0)))
		return model
	end,
	variant = function(id)
		return Engine.figureVariants[id] or "placeholder"
	end,
}
Engine.figureVariants = {}
Engine.services = {
	Players = {},
	UserInputService = { TouchEnabled = false, MouseEnabled = true, LastInputTypeChanged = signal() },
	ProximityPromptService = { PromptShown = signal(), PromptTriggered = signal() },
}
Engine.game = {
	GetService = function(_, name)
		return assert(Engine.services[name], "Unexpected service " .. name)
	end,
}
return Engine

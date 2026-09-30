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
vectorMeta.__index = function(value, key)
	if key == "Magnitude" then
		return math.sqrt(value.X ^ 2 + value.Y ^ 2 + value.Z ^ 2)
	end
	return nil
end
Engine.Vector3 = { new = vector }
Engine.Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
Engine.Enum = {
	Material = { Wood = "Wood", WoodPlanks = "WoodPlanks", SmoothPlastic = "SmoothPlastic" },
	PartType = { Cylinder = "Cylinder" },
	SurfaceType = { Smooth = "Smooth" },
	NormalId = { Bottom = "Bottom", Front = "Front", Left = "Left" },
	SurfaceGuiSizingMode = { FixedSize = "FixedSize" },
	Font = { GothamBlack = "GothamBlack", GothamMedium = "GothamMedium" },
}
-- Planar CFrame operations are sufficient for these upright plot fixtures.
local frameMeta = {}
local function frame(position, yaw)
	return setmetatable({ Position = position, yaw = yaw or 0 }, frameMeta)
end
local function rotate(v, yaw)
	return vector(
		math.cos(yaw) * v.X + math.sin(yaw) * v.Z,
		v.Y,
		-math.sin(yaw) * v.X + math.cos(yaw) * v.Z
	)
end
frameMeta.__mul = function(a, b)
	return frame(a.Position + rotate(b.Position, a.yaw), a.yaw + b.yaw)
end
frameMeta.__add = function(a, b)
	return frame(a.Position + b, a.yaw)
end
frameMeta.__index = function(a, key)
	if key == "LookVector" then
		return rotate(vector(0, 0, -1), a.yaw)
	end
	if key == "RightVector" then
		return rotate(vector(1, 0, 0), a.yaw)
	end
	if key == "Inverse" then
		return function(self)
			return frame(
				rotate(vector(-self.Position.X, -self.Position.Y, -self.Position.Z), -self.yaw),
				-self.yaw
			)
		end
	end
	if key == "PointToObjectSpace" then
		return function(self, point)
			return rotate(point - self.Position, -self.yaw)
		end
	end
	if key == "PointToWorldSpace" then
		return function(self, point)
			return self.Position + rotate(point, self.yaw)
		end
	end
	return nil
end
Engine.CFrame = {
	new = function(a, b, c)
		return frame(if type(a) == "number" then vector(a, b, c) else a)
	end,
	Angles = function(_x, y, _z)
		return frame(vector(0, 0, 0), y)
	end,
	lookAt = function(position, target)
		local direction = target - position
		return frame(position, math.atan2(-direction.X, -direction.Z))
	end,
}
local function node(class)
	local object = {
		Name = class,
		ClassName = class,
		Parent = nil,
		attrs = {},
		Destroying = signal(),
		MouseClick = signal(),
		dead = false,
		CanCollide = true,
		Transparency = 0,
	}
	setmetatable(object, {
		__index = function(self, key)
			if key == "CFrame" then
				return rawget(self, "_cframe") or frame(self.Position)
			end
			return nil
		end,
		__newindex = function(self, key, value)
			if key == "CFrame" then
				rawset(self, "_cframe", value)
				rawset(self, "Position", value.Position)
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
	function object:GetChildren()
		local children = {}
		for _, child in Engine.nodes do
			if child.Parent == self then
				table.insert(children, child)
			end
		end
		return children
	end
	function object:FindFirstChild(name)
		for _, child in self:GetChildren() do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function object:FindFirstChildOfClass(kind)
		for _, child in self:GetChildren() do
			if child.ClassName == kind then
				return child
			end
		end
		return nil
	end
	function object:IsA(kind)
		return self.ClassName == kind or (kind == "BasePart" and self.ClassName == "Part")
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
Engine.workspace = node("Workspace")
Engine.Color3 = {
	fromRGB = function(r, g, b)
		return { r, g, b }
	end,
	new = function(r, g, b)
		return { r, g, b }
	end,
}
Engine.UDim2 = {
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
return Engine

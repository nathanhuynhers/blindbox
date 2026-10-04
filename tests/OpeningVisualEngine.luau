--!strict
-- Instance/math/task boundaries only. Real cinematic, box, skin, VFX and audio run in tests.
-- CFrame rotation/mesh loading and GPU output are NOT simulated.
local E = require("./OpeningEngine")
local vmt = {}
local function v(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt)
end
vmt.__add = function(a, b)
	return v(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vmt.__sub = function(a, b)
	return v(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vmt.__unm = function(a)
	return v(-a.X, -a.Y, -a.Z)
end
vmt.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return if type(b) == "number"
		then v(a.X * b, a.Y * b, a.Z * b)
		else v(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__div = function(a, b)
	return a * (1 / b)
end
vmt.__index = function(a, key)
	if key == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	end
	if key == "Unit" then
		return a / a.Magnitude
	end
	if key == "Lerp" then
		return function(self, b, p)
			return self + (b - self) * p
		end
	end
	if key == "Dot" then
		return function(self, b)
			return self.X * b.X + self.Y * b.Y + self.Z * b.Z
		end
	end
	if key == "Cross" then
		return function(self, b)
			return v(
				self.Y * b.Z - self.Z * b.Y,
				self.Z * b.X - self.X * b.Z,
				self.X * b.Y - self.Y * b.X
			)
		end
	end
	return nil
end
E.Vector3 = { new = v, zero = v(), one = v(1, 1, 1) }
E.Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
local cmt = {}
local function cf(x, y, z)
	local p = if type(x) == "table" then x else v(x, y, z)
	return setmetatable({ Position = p, X = p.X, Y = p.Y, Z = p.Z }, cmt)
end
cmt.__mul = function(a, b)
	return cf(a.Position + b.Position)
end
cmt.__add = function(a, b)
	return cf(a.Position + b)
end
cmt.__index = function(_a, key)
	if key == "Rotation" then
		return cf()
	end
	if key == "Inverse" then
		return function(self)
			return cf(-self.Position)
		end
	end
	if key == "VectorToObjectSpace" then
		return function(_self, b)
			return b
		end
	end
	if key == "Lerp" then
		return function(self, b, p)
			return cf(self.Position:Lerp(b.Position, p))
		end
	end
	return nil
end
E.CFrame = {
	new = cf,
	Angles = function()
		return cf()
	end,
	lookAt = function(position)
		return cf(position)
	end,
}
local colorMt = {
	__index = {
		Lerp = function(a, b, p)
			return setmetatable(
				{ a[1] + (b[1] - a[1]) * p, a[2] + (b[2] - a[2]) * p, a[3] + (b[3] - a[3]) * p },
				getmetatable(a)
			)
		end,
	},
}
E.Color3 = {
	new = function(r, g, b)
		return setmetatable({ r, g, b }, colorMt)
	end,
}
E.Color3.fromRGB = function(r, g, b)
	return E.Color3.new(r / 255, g / 255, b / 255)
end
E.NumberRange = {
	new = function(a, b)
		return { Min = a, Max = b or a }
	end,
}
E.NumberSequence = {
	new = function(a, b)
		return { a, b }
	end,
}
E.ColorSequence = E.NumberSequence
E.NumberSequenceKeypoint = {
	new = function(t, n)
		return { Time = t, Value = n }
	end,
}
E.UDim2 = {
	fromScale = function(x, y)
		return { x, y }
	end,
}
for _, kind in
	{
		"Material",
		"PartType",
		"NormalId",
		"Font",
		"ParticleEmitterShape",
		"ParticleOrientation",
		"ParticleEmitterShapeStyle",
		"ParticleEmitterShapeInOut",
		"AssetFetchStatus",
		"EasingStyle",
		"PlaybackState",
	}
do
	E.Enum[kind] = setmetatable({}, {
		__index = function(_self, key)
			return key
		end,
	})
end
local M = E.methods
local oldIsA = M.IsA
function M:IsA(class)
	return oldIsA(self, class)
		or (class == "BasePart" and (self.ClassName == "Part" or self.ClassName == "MeshPart"))
		or (class == "Light" and (self.ClassName == "PointLight" or self.ClassName == "SurfaceLight" or self.ClassName == "SpotLight"))
		or (
			class == "PostEffect"
			and (self.ClassName == "BloomEffect" or self.ClassName == "ColorCorrectionEffect")
		)
end
function M:GetPivot()
	return self.WorldPivot or cf()
end
function M:PivotTo(at)
	self.WorldPivot = at
end
function M:GetScale()
	return self.scale or 1
end
function M:ScaleTo(scale)
	self.scale = scale
end
function M:GetBoundingBox()
	return self:GetPivot(), v(3, 3, 3)
end
function M:Clear()
	self.liveParticles = 0
	self.clears = (self.clears or 0) + 1
end
function M:Emit(n)
	self.liveParticles = (self.liveParticles or 0) + n
end
function M:Play()
	self.IsPlaying = true
end
function M:Clone()
	local object = E.Instance.new(self.ClassName)
	for key, value in self.props do
		if
			key ~= "Parent"
			and type(value) ~= "function"
			and not (type(value) == "table" and value.Connect)
		then
			object[key] = value
		end
	end
	for key, value in self.attributes do
		object:SetAttribute(key, value)
	end
	for _, child in self:GetChildren() do
		child:Clone().Parent = object
	end
	return object
end
local originalNew = E.Instance.new
E.Instance.new = function(class)
	local object = originalNew(class)
	if class == "Sound" then
		object.IsLoaded, object.IsPlaying = true, false
	end
	if object:IsA("BasePart") then
		object.CFrame, object.Position, object.Size = cf(), v(), v(1, 1, 1)
		object.Color, object.Material = E.Color3.new(1, 1, 1), "SmoothPlastic"
		object.Reflectance, object.Transparency = 0, 0
	end
	return object
end
E.camera.ViewportSize = E.Vector2.new(1280, 720)
E.replication = E.Instance.new("ReplicatedStorage")
E.replication.DescendantAdded = E.signal()
E.services.ReplicatedStorage = E.replication
E.services.SoundService = E.Instance.new("SoundService")
E.TweenInfo = {
	new = function(seconds, style)
		return { Time = seconds, EasingStyle = style }
	end,
}
E.tasks = {}
local function schedule(callback)
	local thread = coroutine.create(callback)
	table.insert(E.tasks, { thread = thread, callback = callback, canceled = false })
	return thread
end
E.task = {
	defer = schedule,
	delay = function(_duration, callback)
		return schedule(callback)
	end,
	cancel = function(thread)
		for _, job in E.tasks do
			if job.thread == thread then
				job.canceled = true
			end
		end
		coroutine.close(thread)
	end,
}
E.services.ContentProvider = {
	PreloadAsync = function()
		if E.failLoad then
			error("Injected asset failure")
		end
	end,
}
function E.flushTasks(evenCanceled)
	local jobs = E.tasks
	E.tasks = {}
	for _, job in jobs do
		if evenCanceled then
			job.callback()
		elseif not job.canceled then
			assert(coroutine.resume(job.thread))
		end
	end
end
function E.template()
	local folder = E.Instance.new("Folder")
	folder.Name, folder.Parent = "ProductionModels", E.replication
	local model = E.Instance.new("Model")
	model.Name, model.Parent = "BlindBoxBase", folder
	local root = E.Instance.new("Model")
	root.Name, root.Parent = "BlindBox_Root", model
	local Spec = require("./BlindBoxSpec")
	local offsets = {
		TopPatternPanel = v(0, 2, 0),
		BottomCap = v(0, -2, 0),
		FrontPatternPanel = v(0, 0, -2),
		SidePatternPanel = v(2, 0, 0),
	}
	for _, name in Spec.required do
		local part = E.Instance.new("MeshPart")
		part.Name, part.Parent = name, root
		part.Position = offsets[name] or v()
		part.CFrame = cf(part.Position)
	end
	model:SetAttribute("ExpectedPartCount", #Spec.required)
	return folder
end
E.FigureModel = {
	create = function(id)
		local model = E.Instance.new("Model")
		model.Name = id
		local mesh = E.Instance.new("MeshPart")
		mesh.Name, mesh.Color, mesh.TextureID, mesh.Parent =
			"FigureBody", E.Color3.fromRGB(100, 170, 120), "original-texture", model
		return model
	end,
}
return E

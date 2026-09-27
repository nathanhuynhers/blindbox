--!strict
-- Minimal engine boundary shim. Tests execute the actual PlayerPlot geometry and renderer.
-- This does not simulate Roblox physics, rendering, replication, or prompt input.
local Engine = { nodes = {}, players = {}, clock = 0, connections = 0 }
local function signal()
	local callbacks = {}
	return {
		Connect = function(_self, callback)
			local key = {}; callbacks[key] = callback; Engine.connections += 1
			return { Disconnect = function()
				if callbacks[key] then callbacks[key] = nil; Engine.connections -= 1 end
			end }
		end,
		fire = function(_self, ...)
			local copy = table.clone(callbacks)
			for key, callback in copy do if callbacks[key] then callback(...) end end
		end,
	}
end
local vectorMeta = {}
local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
vectorMeta.__add = function(a, b) return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vectorMeta.__sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vectorMeta.__index = function(value, key)
	if key == "Magnitude" then return math.sqrt(value.X ^ 2 + value.Y ^ 2 + value.Z ^ 2) end
	return nil
end
Engine.Vector3 = { new = vector }
local function node(class)
	local object = { Name = class, ClassName = class, Parent = nil, attrs = {}, Destroying = signal(), Triggered = signal(), dead = false }
	function object:GetChildren()
		local children = {}; for _, child in Engine.nodes do if child.Parent == self then table.insert(children, child) end end
		return children
	end
	function object:FindFirstChild(name)
		for _, child in self:GetChildren() do if child.Name == name then return child end end
		return nil
	end
	function object:FindFirstChildOfClass(kind)
		for _, child in self:GetChildren() do if child.ClassName == kind then return child end end
		return nil
	end
	function object:IsA(kind) return self.ClassName == kind or (kind == "BasePart" and self.ClassName == "Part") end
	function object:SetAttribute(key, value) self.attrs[key] = value end
	function object:GetAttribute(key) return self.attrs[key] end
	function object:Destroy()
		if self.dead then return end
		self.dead = true; self.Destroying:fire(); self:ClearAllChildren(); self.Parent = nil
	end
	function object:ClearAllChildren() for _, child in self:GetChildren() do child:Destroy() end end
	table.insert(Engine.nodes, object)
	return object
end
Engine.Instance = { new = node }
Engine.workspace = node("Workspace")
Engine.Players = { GetPlayerByUserId = function(_self, id) Engine.figureCreates = 0
Engine.FigureModel = { create = function(id, cf)
 Engine.figureCreates += 1
 local model = node("Model"); model.Name = id; model.Position = cf.Position
 return model
end }
return Engine.players[id] end }
Engine.Color3 = { fromRGB = function(r,g,b) return {r,g,b} end, new = function(r,g,b) return {r,g,b} end }
Engine.UDim2 = { fromOffset = function(x,y) return {x,y} end, fromScale = function(x,y) return {x,y} end }
Engine.CFrame = { new = function(position) return {Position=position} end, lookAt = function(position, _target) return {Position=position} end }
local Template = {}
function Template.part(parent, name, position)
	local part = node("Part"); part.Parent = parent; part.Name = name; part.Position = position
	return part
end
Engine.Template = Template
function Engine.player(id)
	local character = node("Model")
	local root = Template.part(character, "HumanoidRootPart", vector(0,0,0))
	local humanoid = node("Humanoid"); humanoid.Parent = character; humanoid.Health = 100
	function character:PivotTo(cf) root.Position = cf.Position end
	local player = { UserId = id, DisplayName = "Player " .. id, Character = character }
	Engine.players[id] = player
	return player
end
function Engine.trigger(part, player)
	Engine.clock += 1
	player.Character:PivotTo({ Position = part.Position })
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	assert(prompt); prompt.Triggered:fire(player)
end
Engine.figureCreates = 0
Engine.FigureModel = { create = function(id, cf)
 Engine.figureCreates += 1
 local model = node("Model"); model.Name = id; model.Position = cf.Position
 return model
end }
return Engine

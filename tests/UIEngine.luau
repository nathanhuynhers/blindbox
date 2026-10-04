--!nocheck
-- Engine boundary double for the redesigned UI. The real components, screens, Interface and
-- projections run unchanged; only Instances, services, signals and task timers are faked.
-- It checks bindings, routing, sends and lifetime. It does NOT render, measure text or resolve
-- layout, fonts, images or viewport models; those are Studio checks.
local Visual = require("./OpeningVisualEngine")
local Engine = {
	connections = 0,
	created = 0,
	destroyed = 0,
	screen = { X = 1280, Y = 720 },
	now = 1000,
	timers = {},
	previews = {},
}

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			local token = {}
			callbacks[token] = callback
			Engine.connections += 1
			return {
				Disconnect = function()
					if callbacks[token] then
						callbacks[token] = nil
						Engine.connections -= 1
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for token, callback in table.clone(callbacks) do
				if callbacks[token] then
					callback(...)
				end
			end
		end,
	}
end
Engine.signal = signal

local events = {
	Activated = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	InputBegan = true,
	MouseEnter = true,
	MouseLeave = true,
	SelectionGained = true,
	SelectionLost = true,
	Destroying = true,
	AncestryChanged = true,
	AttributeChanged = true,
}
local families = {
	TextButton = { GuiButton = true, GuiObject = true },
	ImageButton = { GuiButton = true, GuiObject = true },
	Frame = { GuiObject = true },
	TextLabel = { GuiObject = true },
	ImageLabel = { GuiObject = true },
	ScrollingFrame = { GuiObject = true },
	ViewportFrame = { GuiObject = true },
	CanvasGroup = { GuiObject = true },
	ScreenGui = { LayerCollector = true },
}

local methods = {}
local mt = {}
local function new(class: string)
	local object = setmetatable({
		__props = {
			ClassName = class,
			Name = class,
			Visible = true,
			Text = "",
			Selectable = true,
			Active = true,
			AbsoluteSize = Engine.screen,
			AbsolutePosition = { X = 0, Y = 0 },
			AbsoluteContentSize = { X = 0, Y = 0 },
			AbsoluteWindowSize = Engine.screen,
			CanvasPosition = { X = 0, Y = 0 },
		},
		__children = {},
		__signals = {},
		__attributes = {},
		__alive = true,
	}, mt)
	Engine.created += 1
	return object
end
mt.__index = function(self, key)
	local method = methods[key]
	if method then
		return method
	end
	local props = rawget(self, "__props")
	local value = props[key]
	if value ~= nil then
		return value
	end
	if events[key] then
		local made = signal()
		props[key] = made
		return made
	end
	return nil
end
mt.__newindex = function(self, key, value)
	local props = rawget(self, "__props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			rawget(old, "__children")[self] = nil
		end
		if value then
			rawget(value, "__children")[self] = true
		end
	end
	props[key] = value
	local changed = rawget(self, "__signals")[key]
	if changed then
		changed:Fire()
	end
end
function methods:IsA(class)
	local own = self.ClassName
	return class == own or class == "Instance" or (families[own] or {})[class] == true
end
function methods:SetAttribute(key, value)
	rawget(self, "__attributes")[key] = value
end
function methods:GetAttribute(key)
	return rawget(self, "__attributes")[key]
end
function methods:GetPropertyChangedSignal(key)
	local signals = rawget(self, "__signals")
	if not signals[key] then
		signals[key] = signal()
	end
	return signals[key]
end
function methods:GetChildren()
	local result = {}
	for child in rawget(self, "__children") do
		table.insert(result, child)
	end
	return result
end
function methods:GetDescendants()
	local result = {}
	local function walk(node)
		for child in rawget(node, "__children") do
			table.insert(result, child)
			walk(child)
		end
	end
	walk(self)
	return result
end
function methods:FindFirstChild(name, recursive)
	for _, child in if recursive then self:GetDescendants() else self:GetChildren() do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _, child in self:GetChildren() do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function methods:WaitForChild(name)
	return assert(self:FindFirstChild(name), "Missing child " .. name)
end
function methods:IsDescendantOf(ancestor)
	local node = self.Parent
	while node do
		if node == ancestor then
			return true
		end
		node = node.Parent
	end
	return false
end
function methods:Destroy()
	if not rawget(self, "__alive") then
		return
	end
	for _, child in self:GetChildren() do
		child:Destroy()
	end
	rawset(self, "__alive", false)
	Engine.destroyed += 1
	self.Parent = nil
end

function Engine.alive(root): number
	local count = 0
	for _ in root:GetDescendants() do
		count += 1
	end
	return count
end
function Engine.find(root, name: string)
	return assert(root:FindFirstChild(name, true), "Missing UI object: " .. name)
end
function Engine.click(button)
	assert(button.Visible, "Clicked a hidden button: " .. button.Name)
	button.Activated:Fire({ UserInputType = { Name = "MouseButton1" } })
end

Engine.Instance = { new = new }
local function udim2(xs, xo, ys, yo)
	return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
Engine.UDim2 = {
	new = udim2,
	fromOffset = function(x, y)
		return udim2(0, x, 0, y)
	end,
	fromScale = function(x, y)
		return udim2(x, 0, y, 0)
	end,
}
Engine.UDim = {
	new = function(scale, offset)
		return { Scale = scale, Offset = offset }
	end,
}
Engine.Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
Engine.Rect = {
	new = function(a, b, c, d)
		return { Min = { X = a, Y = b }, Max = { X = c, Y = d } }
	end,
}
Engine.Color3 = Visual.Color3
Engine.Vector3 = Visual.Vector3
Engine.NumberSequence = Visual.NumberSequence
Engine.NumberSequenceKeypoint = Visual.NumberSequenceKeypoint
Engine.Font = {
	new = function(family, weight)
		return { Family = family, Weight = weight }
	end,
	fromEnum = function(value)
		return { Family = value }
	end,
}
Engine.TweenInfo = {
	new = function()
		return {}
	end,
}
-- Enum.X.Y resolves to one cached item per name, so equality checks behave.
local enumGroups = {}
Engine.Enum = setmetatable({}, {
	__index = function(_, group)
		local cached = enumGroups[group]
		if not cached then
			local items = {}
			cached = setmetatable({}, {
				__index = function(_, item)
					items[item] = items[item] or { Name = item, EnumType = group }
					return items[item]
				end,
			})
			enumGroups[group] = cached
		end
		return cached
	end,
})

-- Timers: task.delay schedules against Engine.now; Engine.advance runs what is due.
local nextTimer = 0
Engine.task = {
	delay = function(seconds, callback)
		nextTimer += 1
		local token = { id = nextTimer }
		Engine.timers[token] = { at = Engine.now + seconds, callback = callback }
		return token
	end,
	cancel = function(token)
		Engine.timers[token] = nil
	end,
	spawn = function(callback, ...)
		callback(...)
	end,
	defer = function(callback, ...)
		callback(...)
	end,
}
function Engine.pending(): number
	local count = 0
	for _ in Engine.timers do
		count += 1
	end
	return count
end
function Engine.advance(seconds: number)
	local target = Engine.now + seconds
	while true do
		local soonest, at = nil, math.huge
		for token, timer in Engine.timers do
			if timer.at <= target and timer.at < at then
				soonest, at = token, timer.at
			end
		end
		if not soonest then
			break
		end
		local timer = Engine.timers[soonest]
		Engine.timers[soonest] = nil
		Engine.now = timer.at
		timer.callback()
	end
	Engine.now = target
end

local playerGui = new("PlayerGui")
local player = new("Player")
playerGui.Parent = player
playerGui.Name = "PlayerGui"
Engine.playerGui = playerGui
local gamepadInput = false
Engine.setGamepad = function(value)
	gamepadInput = value
end
Engine.bound = {}
local services = {
	Players = { LocalPlayer = player },
	GuiService = new("GuiService"),
	UserInputService = {
		TouchEnabled = false,
		InputChanged = signal(),
		InputEnded = signal(),
		GetLastInputType = function()
			return { Name = if gamepadInput then "Gamepad1" else "MouseButton1" }
		end,
	},
	ContextActionService = {
		BindActionAtPriority = function(_, name, callback)
			Engine.bound[name] = callback
		end,
		UnbindAction = function(_, name)
			Engine.bound[name] = nil
		end,
	},
	TweenService = {
		Create = function(_, object, _, goals)
			return {
				Play = function()
					for key, value in goals do
						object[key] = value
					end
				end,
				Cancel = function() end,
			}
		end,
	},
}
services.GuiService.TopbarInset = Engine.Rect.new(104, 0, 1280, 58)
services.GuiService.SelectedObject = nil
Engine.services = services
Engine.game = {
	GetService = function(_, name)
		return assert(services[name], "Unexpected service " .. name)
	end,
}
Engine.workspace = {
	GetServerTimeNow = function()
		return Engine.now
	end,
	FindFirstChild = function()
		return nil
	end,
}

-- Sfx double: records sound names in play order; the real module has its own spec.
Engine.sounds = {}
local soundLevels = { sfx = 1, music = 1 }
Engine.Sfx = {
	play = function(name)
		table.insert(Engine.sounds, name)
	end,
	volume = function(kind)
		return soundLevels[kind]
	end,
	setVolume = function(kind, value)
		soundLevels[kind] = value
	end,
}

-- UIPreview / BlindBoxPreview doubles: record identity, build no models.
Engine.Preview = {
	create = function(parent)
		local frame = new("ViewportFrame")
		frame.Parent = parent
		local preview = {
			frame = frame,
			figure = function(id)
				frame:SetAttribute("FigureId", id)
			end,
			box = function() end,
		}
		table.insert(Engine.previews, preview)
		return preview
	end,
}
Engine.BoxPreview = {
	create = function(parent)
		local root = new("Frame")
		root.Name = "BlindBoxPreview"
		root.Parent = parent
		return {
			root = root,
			set = function(id)
				root:SetAttribute("CollectionId", id)
			end,
		}
	end,
}
return Engine

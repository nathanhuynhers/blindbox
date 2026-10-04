--!strict
-- Engine boundary double for the real controller/camera. Does not simulate 3D rendering.
local Engine = {
	nodes = {},
	connections = 0,
	cues = {},
	warnings = {},
	failConstruct = false,
	failDraw = false,
}
local function signal()
	local callbacks = {}
	return {
		Capture = function()
			return table.clone(callbacks)
		end,
		Connect = function(_self, callback)
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
		Fire = function(_self, ...)
			for token, callback in table.clone(callbacks) do
				if callbacks[token] then
					callback(...)
				end
			end
		end,
	}
end
Engine.signal = signal
local methods = {}
Engine.methods = methods
local mt = {}
function methods:IsA(class)
	return class == self.ClassName or class == "Instance"
end
function methods:GetPropertyChangedSignal(key)
	if not self.signals[key] then
		self.signals[key] = signal()
	end
	return self.signals[key]
end
function methods:GetChildren()
	local result = {}
	for node in self.children do
		table.insert(result, node)
	end
	return result
end
function methods:GetDescendants()
	local result = {}
	for _, child in self:GetChildren() do
		table.insert(result, child)
		for _, descendant in child:GetDescendants() do
			table.insert(result, descendant)
		end
	end
	return result
end
function methods:FindFirstChild(name, recursive)
	for _, node in (if recursive then self:GetDescendants() else self:GetChildren()) do
		if node.Name == name then
			return node
		end
	end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _, node in self:GetChildren() do
		if node:IsA(class) then
			return node
		end
	end
	return nil
end
function methods:IsDescendantOf(parent)
	local current = self.Parent
	while current do
		if current == parent then
			return true
		end
		current = current.Parent
	end
	return false
end
function methods:SetAttribute(key, value)
	self.attributes[key] = value
end
function methods:GetAttribute(key)
	return self.attributes[key]
end
function methods:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.Destroying:Fire()
	for _, child in self:GetChildren() do
		child:Destroy()
	end
	self.Parent = nil
end
function methods:Move(_direction, _relative) end
mt.__index = function(self, key)
	return methods[key] or self.props[key]
end
mt.__newindex = function(self, key, value)
	if key == "destroyed" then
		rawset(self, key, value)
		return
	end
	if key == "Parent" then
		local previous = self.props.Parent
		if previous then
			previous.children[self] = nil
		end
		if value then
			value.children[self] = true
		end
	end
	self.props[key] = value
	if self.signals[key] then
		self.signals[key]:Fire()
	end
	if key == "Parent" then
		self.AncestryChanged:Fire()
	end
end
local function node(class)
	local object = setmetatable({
		ClassName = class,
		props = {
			Name = class,
			Visible = true,
			Selectable = true,
			Enabled = true,
			Destroying = signal(),
			AncestryChanged = signal(),
			Activated = signal(),
		},
		signals = {},
		attributes = {},
		children = {},
	}, mt)
	table.insert(Engine.nodes, object)
	return object
end
Engine.Instance = { new = node }
Engine.typeof = function(value)
	return if type(value) == "table" and value.ClassName then "Instance" else typeof(value)
end
Engine.warn = function(message)
	table.insert(Engine.warnings, message)
end
Engine.Enum = {
	CameraType = { Custom = "Custom", Scriptable = "Scriptable", Attach = "Attach" },
	ZIndexBehavior = { Sibling = 1 },
	ScreenInsets = { DeviceSafeInsets = 1 },
	UserInputState = { Begin = "Begin" },
	ContextActionResult = { Sink = "Sink" },
	KeyCode = { ButtonA = "A", ButtonB = "B", ButtonX = "X", Return = "Return", Space = "Space" },
	PlayerActions = {
		CharacterForward = 1,
		CharacterBackward = 2,
		CharacterLeft = 3,
		CharacterRight = 4,
		CharacterJump = 5,
	},
}
Engine.Vector3 = { zero = {} }
Engine.workspace = node("Workspace")
Engine.camera = node("Camera")
Engine.camera.Parent, Engine.camera.CameraType = Engine.workspace, "Custom"
Engine.camera.CFrame, Engine.camera.Focus, Engine.camera.FieldOfView =
	"original-frame", "original-focus", 73
Engine.workspace.CurrentCamera = Engine.camera
Engine.player = node("Player")
Engine.playerGui = node("PlayerGui")
Engine.playerGui.Parent = Engine.player
Engine.player.CharacterRemoving, Engine.player.CharacterAdded = signal(), signal()
Engine.player.Character = node("Model")
Engine.humanoid = node("Humanoid")
Engine.humanoid.Parent, Engine.humanoid.Died = Engine.player.Character, signal()
Engine.camera.CameraSubject = Engine.humanoid
Engine.render = signal()
Engine.heartbeat = signal()
Engine.input = { LastInputTypeChanged = signal(), last = "MouseButton1" }
function Engine.input:GetLastInputType()
	return { Name = self.last }
end
Engine.guiService = {}
Engine.actions = { bound = {} }
function Engine.actions:BindActionAtPriority(name, callback)
	self.bound[name] = callback
end
function Engine.actions:UnbindAction(name)
	self.bound[name] = nil
end
local services = {
	Players = { LocalPlayer = Engine.player },
	RunService = {
		RenderStepped = Engine.render,
		Heartbeat = Engine.heartbeat,
		IsStudio = function()
			return Engine.studio == true
		end,
	},
	UserInputService = Engine.input,
	ContextActionService = Engine.actions,
	GuiService = Engine.guiService,
}
Engine.services = services
Engine.game = {
	GetService = function(_, name)
		assert(services[name], name)
		return services[name]
	end,
}
function Engine.key(key)
	Engine.actions.bound.BlindboxOpeningInput("", "Begin", { KeyCode = key })
end
function Engine.click(which)
	local input = node("InputObject")
	input.UserInputType = { Name = "MouseButton1" }
	Engine.view[which].Activated:Fire(input)
end
Engine.View = {
	create = function(gui, _scope, result, profile, reveal)
		Engine.profile = profile
		Engine.reveal = reveal
		local primary, hit, skip = node("TextButton"), node("TextButton"), node("TextButton")
		local shield = node("TextButton")
		primary.Parent, hit.Parent, skip.Parent, shield.Parent = gui, gui, gui, gui
		-- Reveal card choices; the real RevealCard is covered by Screens.spec.
		local display, keep = node("TextButton"), node("TextButton")
		display.Parent, keep.Parent = gui, gui
		Engine.view =
			{ primary = primary, hitTarget = hit, skip = skip, display = display, keep = keep, shield = shield }
		Engine.result = result
		local State = require("./OpeningState")
		return {
			primary = primary,
			hitTarget = hit,
			shield = shield,
			skip = skip,
			choices = { display = display, keep = keep },
			firstChoice = function()
				return display
			end,
			refresh = function(model)
				Engine.reveal = model
			end,
			draw = function(state)
				Engine.state = state
				gui:SetAttribute("Phase", state.phase)
				primary.Visible = state.phase == "Await" or state.phase == "Result"
				primary.Selectable = state.phase == "Await"
					or (state.phase == "Result" and state.elapsed >= 0.35)
				skip.Visible = State.canSkip(state)
			end,
		}
	end,
}
Engine.Audio = {
	preload = function(_scope) end,
	create = function(scope)
		local sounds = node("Folder")
		sounds.Name, sounds.Parent = "OpeningSounds", Engine.workspace
		scope.add(function()
			sounds:Destroy()
		end)
		return {
			play = function(key)
				table.insert(Engine.cues, key)
			end,
			stop = function() end,
			stopGroup = function() end,
			mix = function() end,
			modulate = function() end,
			update = function() end,
			destroy = function()
				sounds:Destroy()
			end,
		}
	end,
}
Engine.Cinematic = {
	create = function(scope, _gui, _result, _profile, _collection, _reduced, interrupted)
		local Owner = require("./OpeningCamera")
		local owner = Owner.create(scope, interrupted)
		local stage = node("Model")
		stage.Name, stage.Parent = "BlindboxCinematic", Engine.workspace
		scope.add(function()
			stage:Destroy()
		end)
		if Engine.failConstruct then
			error("Injected construction failure")
		end
		return {
			draw = function(state)
				if Engine.failDraw then
					error("Injected render failure")
				end
				if state.phase ~= "Enter" or state.elapsed >= 0.11 then
					if state.phase == "Closing" and state.elapsed >= 0.11 then
						owner.restore()
					else
						owner.take()
						owner.camera.CFrame = "cinematic-frame"
					end
				end
			end,
			enter = function() end,
			skip = function() end,
			tease = function() end,
			restore = owner.restore,
		}
	end,
}
return Engine

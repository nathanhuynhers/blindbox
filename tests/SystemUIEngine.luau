--!strict
-- Engine/UI primitives only: actual screens, layout and state modules run unchanged.
-- This tests bindings/lifetime, not Roblox rendering or layout resolution.
local Engine = { nodes = {}, previews = {}, actions = {} }
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return {
				Disconnect = function()
					local i = table.find(callbacks, callback)
					if i then
						table.remove(callbacks, i)
					end
				end,
			}
		end,
		fire = function()
			for _, callback in callbacks do
				callback()
			end
		end,
	}
end
local function node(class)
	local attributes, signals = {}, {}
	local object = {
		ClassName = class,
		Name = class,
		Visible = true,
		AbsoluteSize = { X = 1040, Y = 700 },
		Position = {},
		Size = {},
		Text = "",
		Activated = signal(),
	}
	function object:SetAttribute(key, value)
		attributes[key] = value
	end
	function object:GetAttribute(key)
		return attributes[key]
	end
	function object:GetPropertyChangedSignal(key)
		if not signals[key] then
			signals[key] = signal()
		end
		return signals[key]
	end
	table.insert(Engine.nodes, object)
	return object
end
Engine.Instance = { new = node }
Engine.UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
	end,
	fromOffset = function(x, y)
		return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
	end,
	fromScale = function(x, y)
		return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }
	end,
}
Engine.Color3 = {
	fromRGB = function(r, g, b)
		return { r, g, b }
	end,
}
Engine.Enum = {
	Font = { GothamBold = 1, GothamMedium = 2, FredokaOne = 3 },
	ScrollingDirection = { Y = 1 },
	TextXAlignment = { Center = 1 },
	TextTruncate = { AtEnd = 1 },
}
Engine.Theme = { ink = {}, primary = {} }
Engine.TweenInfo = {
	new = function()
		return {}
	end,
}
Engine.TweenService = {
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
}
local W = {}
function W.frame(parent, name, color)
	local result = node("Frame")
	result.Parent = parent
	result.Name = name
	result.BackgroundColor3 = color
	return result
end
function W.label(parent, text, height, size)
	local result = node("TextLabel")
	result.Parent = parent
	result.Text = text
	result.TextSize = size
	result.Size = Engine.UDim2.new(1, 0, 0, height)
	return result
end
function W.corner() end
function W.gradient()
	return {}
end
function W.outline()
	return {}
end
function W.inset(object, y, height)
	object.Position = Engine.UDim2.fromOffset(12, y)
	object.Size = Engine.UDim2.new(1, -24, 0, height)
end
function W.action(parent, text, _, _, callback)
	local button = node("TextButton")
	button.Parent = parent
	button.Text = text
	button.Name = text
	local enabled = true
	local result = {
		button = button,
		set = function(value, allowed, selected)
			button.Text = value
			enabled = allowed
			button:SetAttribute("Enabled", allowed)
			button:SetAttribute("Active", selected)
		end,
		click = function()
			if enabled then
				callback()
			end
		end,
	}
	table.insert(Engine.actions, result)
	return result
end
Engine.Widgets = W
Engine.Preview = {
	create = function(parent)
		local frame = node("ViewportFrame")
		frame.Parent = parent
		local preview = {
			frame = frame,
			figure = function(id)
				frame:SetAttribute("FigureId", id)
			end,
		}
		table.insert(Engine.previews, preview)
		return preview
	end,
}
Engine.Icons = {
	create = function(parent, name)
		return W.frame(parent, name .. "Icon")
	end,
}
function Engine.find(root, name)
	for _, object in Engine.nodes do
		local ancestor = object
		while ancestor do
			if ancestor == root and object.Name == name then
				return object
			end
			ancestor = ancestor.Parent
		end
	end
	error("Missing UI object: " .. name)
end
function Engine.click(root, name)
	local button = Engine.find(root, name)
	for _, action in Engine.actions do
		if action.button == button then
			action.click()
			return
		end
	end
	error("Missing UI action: " .. name)
end
return Engine

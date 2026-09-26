--!strict
local Context = require(script.Parent.UIContext)
local Assets = require(script.Parent.CollectionAssets)
local Style = require(script.Parent.CollectionStyle)
local W = require(script.Parent.Widgets)
local Controls = {}
export type Action = { button: TextButton, set: (string, boolean, boolean?) -> () }
function Controls.action(
	parent: Instance,
	text: string,
	kind: string,
	ctx: Context.Context,
	callback: () -> ()
): Action
	-- Reuse only input/teardown/motion behavior; the book owns the entire visible surface.
	local action = W.action(parent, "", ctx.scope, ctx.effects, callback, true)
	local button = action.button
	button.Name = text
	button:SetAttribute("Quiet", true)
	local slot = Assets.mount(button, "ButtonSkin", ctx.scope)
	local depth = W.frame(slot.native, "Depth", Color3.fromRGB(122, 89, 45))
	depth.Position = UDim2.fromOffset(0, 3)
	W.corner(depth, 22)
	local face = W.frame(slot.native, "Face", Color3.new(1, 1, 1))
	face.Size = UDim2.new(1, 0, 1, -2)
	W.corner(face, 22)
	local shine = W.gradient(face, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 90)
	local rim = W.outline(face, Color3.fromRGB(255, 246, 214), 0.12)
	rim.Thickness = 2
	local label = W.label(button, text, 44, 18)
	label.Name = "Caption"
	label.Size = UDim2.new(1, -12, 1, -2)
	label.Position = UDim2.fromOffset(6, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextXAlignment = Enum.TextXAlignment.Center
	if kind == "filter" then
		slot.root.Position = UDim2.fromOffset(0, 6)
		slot.root.Size = UDim2.new(1, 0, 0, 32)
		label.Position = UDim2.fromOffset(6, 6)
		label.Size = UDim2.new(1, -12, 0, 32)
		label.TextSize = 13
		rim.Thickness = 1
	elseif kind == "secondary" then
		label.TextSize = 12
		rim.Thickness = 1
		depth.Position = UDim2.fromOffset(0, 2)
	end
	local function set(value: string, enabled: boolean, selected: boolean?)
		action.set("", enabled, selected)
		label.Text = value
		local first = if kind == "display"
			then Color3.fromRGB(154, 204, 99)
			elseif kind == "recycle" then Color3.fromRGB(255, 214, 111)
			else Color3.fromRGB(255, 250, 236)
		local last = if kind == "display"
			then Color3.fromRGB(71, 131, 63)
			elseif kind == "recycle" then Color3.fromRGB(235, 155, 60)
			else Color3.fromRGB(232, 208, 172)
		if not enabled then
			first, last = Color3.fromRGB(226, 218, 204), Color3.fromRGB(193, 181, 165)
		end
		shine.Color = ColorSequence.new(first, last)
		depth.BackgroundColor3 = last:Lerp(Color3.fromRGB(60, 43, 30), 0.35)
		label.TextColor3 = if kind == "display" and enabled
			then Color3.fromRGB(255, 255, 237)
			else Color3.fromRGB(84, 57, 34)
		local asset = if kind == "display"
			then Assets.buttons.display
			elseif kind == "recycle" then Assets.buttons.recycle
			else Assets.buttons.paper
		slot.set(if enabled then asset else { id = "" })
	end
	set(text, true)
	return { button = button, set = set }
end
function Controls.badge(parent: Instance, ctx: Context.Context)
	local root = W.frame(parent, "RarityBadge")
	root.Size = UDim2.fromOffset(114, 24)
	local slot = Assets.mount(root, "BadgeSkin", ctx.scope)
	local face = W.frame(slot.native, "Pill", Color3.new(1, 1, 1))
	W.corner(face, 16)
	local gradient = W.gradient(face, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	W.outline(face, Color3.fromRGB(255, 253, 231), 0.2)
	local label = W.label(root, "", 24, 12)
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextColor3 = Color3.fromRGB(255, 255, 250)
	label.Font = Enum.Font.GothamBold
	return {
		root = root,
		set = function(rarity: string)
			local tint = Style.rarity(rarity)
			gradient.Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.16), tint)
			label.Text = string.upper(rarity)
			slot.set(Assets.badges[rarity] or { id = "" })
		end,
	}
end
return Controls

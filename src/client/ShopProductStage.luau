--!strict
local W = require(script.Parent.Widgets)
local Style = require(script.Parent.ShopStyle)
local Preview = require(script.Parent.BlindBoxPreview)
local Context = require(script.Parent.UIContext)
local Stage = {}
export type Stage = { root: Frame, set: (string, string) -> () }

function Stage.create(
	parent: Instance,
	ctx: Context.Context,
	previous: () -> (),
	following: () -> ()
): Stage
	local root = Style.panel(parent, "ProductStage", Style.elevated, 22)
	local arch = Style.panel(root, "StudioArch", Style.secondary, 150)
	arch.Position = UDim2.fromScale(0.07, 0.045)
	arch.Size = UDim2.fromScale(0.86, 0.83)
	arch.BackgroundTransparency = 0.36
	W.gradient(arch, Color3.fromRGB(255, 254, 248), Color3.fromRGB(235, 215, 179), 90)
	local rim = W.outline(arch, Style.gold, 0.76)
	rim.Thickness = 2
	local shadow = Style.panel(root, "PedestalShadow", Style.woodTrim, 100)
	shadow.Position = UDim2.fromScale(0.09, 0.90)
	shadow.Size = UDim2.fromScale(0.82, 0.055)
	shadow.BackgroundTransparency = 0.8
	-- Broad low plinth and a thin raised top, with a continuous gold rim.
	local base = Style.panel(root, "PedestalBase", Style.secondary, 70)
	base.Position = UDim2.fromScale(0.06, 0.82)
	base.Size = UDim2.fromScale(0.88, 0.105)
	W.gradient(base, Style.elevated, Color3.fromRGB(216, 188, 141), 90)
	W.outline(base, Style.gold, 0.32).Thickness = 2
	local top = Style.panel(root, "PedestalTop", Style.elevated, 90)
	top.Position = UDim2.fromScale(0.085, 0.785)
	top.Size = UDim2.fromScale(0.83, 0.085)
	W.gradient(top, Color3.fromRGB(255, 254, 248), Style.secondary, 90)
	W.outline(top, Style.gold, 0.4)
	local box = Preview.create(root, ctx.scope)
	box.root.Position = UDim2.fromScale(0.08, 0.02)
	box.root.Size = UDim2.fromScale(0.84, 0.82)
	local plaque = Style.label(root, "ProductPlaque", "", 15, true)
	plaque.AnchorPoint = Vector2.new(0.5, 0.5)
	plaque.Position = UDim2.fromScale(0.5, 0.89)
	plaque.Size = UDim2.fromScale(0.62, 0.05)
	plaque.TextXAlignment = Enum.TextXAlignment.Center
	for index, callback in { previous, following } do
		local action = W.action(
			root,
			if index == 1 then "\u{2039}" else "\u{203A}",
			ctx.scope,
			ctx.effects,
			callback,
			true
		)
		action.button.Name = if index == 1 then "PreviousCollection" else "NextCollection"
		action.button.AnchorPoint = Vector2.new(if index == 1 then 0 else 1, 0.5)
		action.button.Position = UDim2.fromScale(if index == 1 then 0.02 else 0.98, 0.48)
		action.button.Size = UDim2.fromOffset(44, 44)
		action.button:SetAttribute("Surface", Style.elevated)
		action.button:SetAttribute("Accent", Style.gold)
		action.button.TextSize = 30
		local corner = action.button:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(1, 0)
		end
	end
	return {
		root = root,
		set = function(id: string, name: string)
			box.set(id)
			plaque.Text = name
		end,
	}
end
return Stage

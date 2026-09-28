--!strict
local Assets = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
local NavigationAssetIds = require(game:GetService("ReplicatedStorage").Shared.NavigationAssetIds)
local Button = require(script.Parent.NavigationButton)
local Config = require(script.Parent.NavigationConfig)
local Context = require(script.Parent.UIContext)
local Theme = require(script.Parent.UITheme)
local W = require(script.Parent.Widgets)

local Navigation = {}
Navigation.pages = Config.pages

local function railSurface(parent: Instance, name: string, shadow: boolean): Frame
	local frame = W.frame(parent, name, if shadow then Theme.shadow else Theme.card)
	frame.BackgroundTransparency = if shadow then 0.82 else 0.16
	frame.Position = if shadow then UDim2.fromOffset(0, 5) else UDim2.fromOffset(0, 0)
	frame.ZIndex = if shadow then 5 else 6
	W.corner(frame, 24)
	if not shadow then
		local stroke = W.outline(frame, Color3.fromRGB(205, 193, 220), 0.48)
		stroke.Thickness = 1.25
		W.gradient(frame, Color3.fromRGB(250, 247, 252), Color3.fromRGB(255, 250, 239), 90)
	end
	return frame
end

function Navigation.create(parent: Instance, ctx: Context.Context, choose: (string) -> ())
	local root = W.frame(parent, "Navigation")
	root.ClipsDescendants = false
	root.SelectionGroup = true
	root.ZIndex = 6

	local shadow = railSurface(root, "RailShadow", true)
	local surface = railSurface(root, "RailSurface", false)
	local itemsRoot = W.frame(surface, "Items")
	itemsRoot.Position = UDim2.fromOffset(6, 5)
	itemsRoot.Size = UDim2.new(1, -12, 1, -10)
	itemsRoot.ZIndex = 7
	local list = W.list(itemsRoot, 0)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	local active: string? = nil
	local actions: { [string]: Button.Button } = {}
	for index, item in Config.items do
		local image = NavigationAssetIds.resolve(item.id, Assets.resolve(item.assetKey))
		if image == "" then
			warn(
				string.format(
					"Navigation artwork is not registered: %s. Add its Roblox Image ID to ReplicatedStorage.Shared.NavigationAssetIds.",
					item.id
				)
			)
		end
		local action = Button.create(itemsRoot, item, image, ctx.scope, ctx.effects, choose)
		action.button.LayoutOrder = index
		actions[item.id] = action
	end

	local function paint()
		for id, action in actions do
			action.setSelected(id == active)
		end
	end

	return {
		root = root,
		actions = actions,
		layout = function(size: Vector2, desktop: boolean)
			local geometry = Config.layout(size.X, size.Y, desktop)
			root.AnchorPoint = Vector2.new(0, 0)
			root.Position = UDim2.fromOffset(geometry.x, geometry.y)
			root.Size = UDim2.fromOffset(geometry.width, geometry.height)
			shadow.Size = UDim2.fromScale(1, 1)
			surface.Size = UDim2.fromScale(1, 1)
			list.FillDirection = if desktop
				then Enum.FillDirection.Vertical
				else Enum.FillDirection.Horizontal
			list.Padding = UDim.new(0, geometry.gap)
			for _, item in Config.items do
				actions[item.id].layout(desktop, geometry.itemWidth, geometry.itemHeight)
			end
			paint()
		end,
		set = function(page: string?, daily: boolean)
			active = page
			actions.Goals.setBadge(if daily then "" else nil)
			paint()
		end,
		badge = function(id: string, value: string?)
			local action = actions[id]
			if action then
				action.setBadge(value)
			end
		end,
	}
end

return Navigation

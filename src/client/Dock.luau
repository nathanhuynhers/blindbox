--!strict
-- Bottom dock: five tiles (icon + label), active tile raised on violet wash, live badges.
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Badge = require(script.Parent.UIBadge)
local Layout = require(script.Parent.UILayout)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local Navigation = require(script.Parent.NavigationConfig)
local Dock = {}

type Tile = {
	button: TextButton,
	face: Frame,
	shadow: Frame,
	stroke: UIStroke,
	icon: ImageLabel,
	label: TextLabel,
	badge: Badge.Badge,
	corners: { UICorner },
}
export type Dock = {
	root: Frame,
	tiles: { [string]: TextButton },
	layout: (Layout.Dock, boolean) -> (),
	set: (string?, State.Badges?) -> (),
}

function Dock.create(parent: Instance, ctx: Context.Context, choose: (string) -> ()): Dock
	local root = Kit.frame(parent, "Dock")
	root.SelectionGroup = true
	root.ZIndex = 30
	local tiles: { [string]: Tile } = {}
	local buttons: { [string]: TextButton } = {}
	for index, item in Navigation.items do
		local button = Instance.new("TextButton")
		button.Name = "Dock" .. item.id
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.LayoutOrder = index
		button.Parent = root
		button:SetAttribute("AccessibleName", item.label)
		local shadow = Kit.frame(button, "Shadow", Style.ink)
		shadow.ZIndex = 1
		local face = Kit.frame(button, "Face", Style.white)
		face.ZIndex = 2
		local corners = { Kit.corner(shadow, 22), Kit.corner(face, 22) }
		local stroke = Kit.stroke(face, Style.ink)
		local icon = Kit.image(face, "Icon", Navigation.image(item.id))
		icon.AnchorPoint = Vector2.new(0.5, 0)
		local label = Kit.text(face, "Label", item.label, 15, Style.display())
		label.TextXAlignment = Enum.TextXAlignment.Center
		local badge = Badge.corner(face, "Badge", {
			fill = Style.violet,
			color = Style.white,
			height = 24,
			size = 12,
			outline = Style.ink,
		}, Vector2.new(1, 0), Vector2.new(10, -10))
		ctx.scope.connect(button.Activated, function()
			choose(item.id)
		end)
		tiles[item.id] = {
			button = button,
			face = face,
			shadow = shadow,
			stroke = stroke,
			icon = icon,
			label = label,
			badge = badge,
			corners = corners,
		}
		buttons[item.id] = button
	end
	local phone = false
	local active: string? = nil
	local badges: State.Badges = {}
	local function paint()
		for id, tile in tiles do
			local on = id == active
			local lift = if on then -6 else 0
			tile.face.BackgroundColor3 = if on then Style.violetWash else Style.white
			tile.stroke.Color = if on then Style.violet else Style.ink
			tile.shadow.BackgroundColor3 = if on then Style.violetDark else Style.ink
			tile.label.TextColor3 = if on then Style.violetDark else Style.ink
			tile.face.Position = UDim2.fromOffset(0, lift)
			tile.shadow.Position = UDim2.fromOffset(0, lift + (if phone then 4 else 5))
			tile.button:SetAttribute("Active", on)
			local text = badges[id]
			tile.badge.root.Visible = text ~= nil
			if text then
				-- Phone tiles are narrow: the Display badge shows its count only.
				tile.badge.set(
					if phone and id == "Display" then string.match(text, "^%d+") or text else text
				)
				tile.badge.paint(
					if id == "Shop"
						then Style.gold
						elseif id == "Goals" then Style.alert
						else Style.violet,
					if id == "Shop" then Style.ink else Style.white,
					Style.ink
				)
				tile.badge.root.Size = UDim2.fromOffset(0, if phone then 22 else 24)
			end
		end
	end
	return {
		root = root,
		tiles = buttons,
		layout = function(geometry: Layout.Dock, nextPhone: boolean)
			phone = nextPhone
			Kit.rect(root, geometry.x, geometry.y, geometry.width, geometry.height)
			for index, item in Navigation.items do
				local tile = tiles[item.id]
				Kit.rect(
					tile.button,
					(index - 1) * (geometry.item + geometry.gap),
					0,
					geometry.item,
					geometry.itemHeight
				)
				tile.face.Size = UDim2.fromScale(1, 1)
				tile.shadow.Size = UDim2.fromScale(1, 1)
				for _, corner in tile.corners do
					corner.CornerRadius = UDim.new(0, if phone then 18 else 22)
				end
				local iconSize = geometry.icon
				tile.icon.Visible = tile.icon.Image ~= ""
				local top = math.floor((geometry.itemHeight - iconSize - geometry.label - 4) / 2)
				tile.icon.Position = UDim2.new(0.5, 0, 0, top)
				tile.icon.Size = UDim2.fromOffset(iconSize, iconSize)
				tile.label.TextSize = geometry.label
				Kit.rect(
					tile.label,
					2,
					if tile.icon.Visible then top + iconSize else 0,
					geometry.item - 4,
					if tile.icon.Visible then geometry.label + 4 else geometry.itemHeight
				)
				tile.badge.root.Position =
					UDim2.new(1, if phone then 8 else 10, 0, if phone then -8 else -10)
			end
			paint()
		end,
		set = function(page: string?, nextBadges: State.Badges?)
			active = page
			badges = nextBadges or {}
			paint()
		end,
	}
end

return Dock

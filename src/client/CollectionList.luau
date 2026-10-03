--!strict
-- Collection list used by Shop and Collection: emblem (or monogram) on accent wash, name, thin
-- progress bar, found/total. Phone landscape collapses it to an icon-only rail.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Progress = require(script.Parent.UIProgress)
local State = require(script.Parent.UIState)
local Context = require(script.Parent.UIContext)
local List = {}

export type List = {
	root: Frame,
	items: { [string]: TextButton },
	layout: (width: number, height: number, rail: boolean) -> (),
	update: (Types.Snapshot, string) -> (),
}

type Item = {
	button: TextButton,
	stroke: UIStroke,
	icon: Frame,
	emblem: ImageLabel,
	mono: TextLabel,
	name: TextLabel,
	bar: Progress.Bar,
	count: TextLabel,
}

-- Emblem or monogram on the collection's wash; shared by the list, Goals and chips.
function List.icon(
	parent: Instance,
	id: string,
	name: string,
	size: number
): (Frame, ImageLabel, TextLabel)
	local accent = Style.collection(id)
	local icon = Kit.frame(parent, "CollectionIcon", accent.wash)
	icon.Size = UDim2.fromOffset(size, size)
	icon.ClipsDescendants = true
	Kit.corner(icon, math.floor(size * 0.28))
	local emblem = Kit.image(icon, "Emblem", Style.emblem(id))
	emblem.ScaleType = Enum.ScaleType.Crop
	local mono = Kit.text(
		icon,
		"Monogram",
		Style.mono(id, name),
		math.floor(size * 0.38),
		Style.display(),
		accent.color
	)
	mono.Size = UDim2.fromScale(1, 1)
	mono.TextXAlignment = Enum.TextXAlignment.Center
	-- Exactly one representation shows: uploaded emblem art, otherwise the monogram.
	emblem.Visible = emblem.Image ~= ""
	mono.Visible = not emblem.Visible
	return icon, emblem, mono
end

function List.create(parent: Instance, ctx: Context.Context, choose: (string) -> ()): List
	local root = Kit.column(parent, "CollectionList", Style.surface2, "left", 28)
	local heading =
		Kit.text(root, "Heading", "COLLECTIONS", 12, Style.body(Enum.FontWeight.Heavy), Style.muted)
	local layout = Kit.list(root, Enum.FillDirection.Vertical, 6)
	local scroll = Kit.scroll(root, "Collections", ctx.scope, layout, 4, ctx.scale)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local items: { [string]: Item } = {}
	local buttons: { [string]: TextButton } = {}
	for index, collection in Catalog.collections do
		local button = Instance.new("TextButton")
		button.Name = "Collection_" .. collection.id
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Style.white
		button.BackgroundTransparency = 1
		button.LayoutOrder = index
		button.Parent = scroll
		Kit.corner(button, 16)
		local stroke = Kit.stroke(button, Style.violet)
		local icon, emblem, mono = List.icon(button, collection.id, collection.name, 42)
		local name = Kit.text(button, "Name", collection.name, 15)
		local bar = Progress.bar(button, "Progress", 6, Style.collection(collection.id).color)
		local count = Kit.text(button, "Count", "", 13, nil, Style.muted)
		count.TextXAlignment = Enum.TextXAlignment.Right
		ctx.scope.connect(button.Activated, function()
			choose(collection.id)
		end)
		items[collection.id] = {
			button = button,
			stroke = stroke,
			icon = icon,
			emblem = emblem,
			mono = mono,
			name = name,
			bar = bar,
			count = count,
		}
		buttons[collection.id] = button
	end
	local rail = false
	return {
		root = root,
		items = buttons,
		layout = function(width: number, height: number, nextRail: boolean)
			rail = nextRail
			heading.Visible = not rail
			Kit.rect(heading, 18, 14, width - 24, 16)
			local top = if rail then 4 else 34
			Kit.rect(scroll, 0, top, width, height - top)
			for _, item in items do
				if rail then
					item.button.Size = UDim2.fromOffset(52, 52)
					item.icon.Size = UDim2.fromOffset(46, 46)
					item.icon.Position = UDim2.fromOffset(3, 3)
				else
					item.button.Size = UDim2.fromOffset(width - 24, 62)
					item.icon.Size = UDim2.fromOffset(42, 42)
					item.icon.Position = UDim2.fromOffset(10, 10)
					local textX = 64
					local countWidth = 44
					Kit.rect(item.name, textX, 12, width - 24 - textX - countWidth - 10, 20)
					Kit.rect(item.bar.root, textX, 37, width - 24 - textX - countWidth - 10, 6)
					Kit.rect(item.count, width - 24 - countWidth - 10, 12, countWidth, 34)
				end
				item.name.Visible = not rail
				item.bar.root.Visible = not rail
				item.count.Visible = not rail
			end
		end,
		update = function(snapshot: Types.Snapshot, selected: string)
			for id, item in items do
				local found, total = State.completion(snapshot, id)
				local on = id == selected
				item.count.Text = found .. "/" .. total
				item.bar.set(found, total)
				item.stroke.Transparency = if on then 0 else 1
				item.button.BackgroundTransparency = if on and not rail then 0 else 1
				item.button:SetAttribute("Selected", on)
				item.button:SetAttribute(
					"AccessibleName",
					State.collectionName(id) .. ", " .. found .. " of " .. total
				)
			end
		end,
	}
end

return List

--!strict
-- Figure tile/card: accent-wash well with the 3D portrait, rarity-coloured bottom bar, owned
-- count "×N", "ON DISPLAY" and "BEST" tags. Undiscovered figures show "?" and "???".
-- Kinds: "card" (Collection grid), "tile" (Shop contents), "shelf" (Shelves picker),
-- "pick" (Display picker row). One instance is rebound across snapshots; never rebuilt.
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Badge = require(script.Parent.UIBadge)
local Preview = require(script.Parent.UIPreview)
local Context = require(script.Parent.UIContext)
local Sfx = require(script.Parent.Sfx)
local Tile = {}

export type Kind = "card" | "tile" | "shelf" | "pick"
export type View = {
	discovered: boolean,
	selected: boolean?,
	sub: string?,
	subColor: Color3?,
	count: number?,
	onDisplay: boolean?,
	best: boolean?,
	enabled: boolean?,
	-- Undiscovered figures show a grey silhouette instead of "?" (collection progress).
	silhouette: boolean?,
}
export type Tile = {
	button: TextButton,
	id: () -> string?,
	set: (string?, View) -> (),
	size: (width: number, height: number) -> (),
}

function Tile.create(
	parent: Instance,
	ctx: Context.Context,
	kind: Kind,
	choose: (string) -> ()
): Tile
	local button = Instance.new("TextButton")
	button.Name = "Figure"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Parent = parent
	local outline = if kind == "card" or kind == "pick" then Style.outline else Style.outlineSmall
	local radius = if kind == "tile" then 12 elseif kind == "pick" then 14 else 16
	local shadow = Kit.frame(button, "Shadow", Style.ink)
	shadow.Position = UDim2.fromOffset(0, 3)
	shadow.ZIndex = 1
	shadow.Visible = kind == "card"
	Kit.corner(shadow, radius)
	local face = Kit.frame(button, "Face", Style.white)
	face.ZIndex = 2
	Kit.corner(face, radius)
	local stroke = Kit.stroke(face, Style.ink, outline)
	stroke.Enabled = kind ~= "tile"
	-- The rarity colour sits behind the wash and shows as the well's rounded bottom edge.
	local edged = kind == "card" or kind == "tile"
	local bar = Kit.frame(face, "RarityBar", Style.track)
	Kit.corner(bar, radius - 2)
	local well = Kit.frame(bar, "Well", Style.disabledFill)
	well.ClipsDescendants = true
	well.Size = UDim2.new(1, 0, 1, if edged then -5 else 0)
	Kit.corner(well, radius - 2)
	local preview = Preview.create(well, ctx.scope, true)
	local unknown = Kit.text(well, "Unknown", "?", 34, Style.display(), Style.unknownInk)
	unknown.Size = UDim2.fromScale(1, 1)
	unknown.TextXAlignment = Enum.TextXAlignment.Center
	local name = Kit.text(face, "Name", "", 14)
	local sub = Kit.text(face, "Sub", "", 12, nil, Style.muted)
	if kind == "pick" then
		sub.FontFace = Style.display()
		sub.TextSize = 16
	end
	local count = Badge.corner(button, "Owned", {
		fill = Style.ink,
		color = Style.white,
		height = 22,
		size = 12,
	}, Vector2.new(1, 0), Vector2.new(-6, 6))
	local onDisplay = Badge.corner(button, "OnDisplay", {
		fill = Style.mint,
		color = Style.mintInk,
		height = 22,
		size = 11,
		outline = Style.mintFill,
	}, Vector2.new(0, 0), Vector2.new(6, 6))
	onDisplay.set("ON DISPLAY")
	local best = Badge.corner(button, "Best", {
		fill = Style.gold,
		color = Style.ink,
		height = 20,
		size = 11,
		outline = Style.ink,
	}, Vector2.new(1, 0), Vector2.new(-6, -10))
	best.set("BEST")
	local current: string? = nil
	local enabled = true
	ctx.scope.connect(button.Activated, function()
		if current and enabled then
			choose(current)
			Sfx.play("select")
		end
	end)
	local width, height = 100, 100
	local function place()
		local inset = outline
		if kind == "pick" then
			local image = height - 18
			Kit.rect(bar, 6, 6, image, image)
			Kit.rect(name, image + 14, 10, width - image - 22, 20)
			Kit.rect(sub, image + 14, 32, width - image - 22, 22)
			name.TextWrapped = false
		elseif kind == "tile" then
			Kit.rect(bar, 0, 0, width, height)
			name.Visible, sub.Visible = false, false
		elseif kind == "shelf" then
			Kit.rect(bar, inset + 2, inset + 2, width - inset * 2 - 4, height - 38)
			Kit.rect(name, 4, height - 32, width - 8, 28)
			name.TextSize = 12
			name.TextWrapped = true
			name.TextXAlignment = Enum.TextXAlignment.Center
			sub.Visible = false
		else
			local compact = height < 130
			local wellHeight = height - (if compact then 38 else 50)
			Kit.rect(bar, inset, inset, width - inset * 2, wellHeight - inset + 5)
			name.TextSize = if compact then 12 else 14
			sub.TextSize = if compact then 11 else 12
			Kit.rect(
				name,
				8,
				wellHeight + (if compact then 6 else 9),
				width - 16,
				if compact then 15 else 18
			)
			Kit.rect(
				sub,
				8,
				wellHeight + (if compact then 21 else 27),
				width - 16,
				if compact then 13 else 16
			)
		end
		unknown.TextSize = math.floor(math.min(bar.Size.Y.Offset, bar.Size.X.Offset) * 0.36)
	end
	return {
		button = button,
		id = function()
			return current
		end,
		size = function(nextWidth: number, nextHeight: number)
			width, height = nextWidth, nextHeight
			button.Size = UDim2.fromOffset(width, height)
			place()
		end,
		set = function(id: string?, view: View)
			current = id
			button.Visible = id ~= nil
			if not id then
				-- Pooled tiles drop their identity when unbound so lookups never hit a hidden one.
				button.Name = "Figure"
				button:SetAttribute("FigureId", nil)
				preview.figure(nil, true)
				return
			end
			local figure = Catalog.byId[id]
			local accent = Style.collection(figure.collection)
			local tint = Style.rarity(figure.rarity)
			button.Name = id
			button:SetAttribute("FigureId", id)
			button:SetAttribute("Discovered", view.discovered)
			button:SetAttribute(
				"AccessibleName",
				if view.discovered then figure.name .. ", " .. figure.rarity else "Not found yet"
			)
			well.BackgroundColor3 = if view.discovered then accent.wash else Style.disabledFill
			if kind == "pick" or kind == "shelf" then
				well.BackgroundColor3 = accent.wash
			end
			bar.BackgroundColor3 = if edged then tint else well.BackgroundColor3
			local shape = view.discovered or view.silhouette == true
			preview.figure(if shape then id else nil, view.discovered)
			unknown.Visible = not shape
			name.Text = if view.discovered then figure.name else "???"
			sub.Text = view.sub or ""
			sub.TextColor3 = view.subColor or Style.muted
			local selected = view.selected == true
			stroke.Color = if selected then Style.violet else Style.ink
			shadow.BackgroundColor3 = if selected then Style.violet else Style.ink
			face.BackgroundColor3 = if selected and kind == "shelf"
				then Style.violetWash
				else Style.white
			button:SetAttribute("Selected", selected)
			local owned = view.count or 0
			count.root.Visible = owned > 1
			count.set("×" .. owned)
			onDisplay.root.Visible = view.onDisplay == true
			best.root.Visible = view.best == true
			enabled = view.enabled ~= false
			button.Selectable = enabled
		end,
	}
end

return Tile

--!strict
-- Instance primitives shared by every component. No state, no connections except Scroll.bind.
local Style = require(script.Parent.UIStyle)
local Scope = require(script.Parent.UIScope)
local Scroll = require(script.Parent.Scroll)
local Kit = {}

function Kit.frame(parent: Instance, name: string, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color or Style.surface
	frame.BackgroundTransparency = if color then 0 else 1
	frame.Parent = parent
	return frame
end

function Kit.rect(object: GuiObject, x: number, y: number, width: number, height: number)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(width, height)
end

function Kit.corner(object: GuiObject, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
	return corner
end

function Kit.round(object: GuiObject): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = object
	return corner
end

function Kit.stroke(object: GuiObject, color: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness or Style.outline
	stroke.Parent = object
	return stroke
end

function Kit.padding(object: GuiObject, top: number, right: number, bottom: number, left: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.PaddingLeft = UDim.new(0, left)
	padding.Parent = object
end

function Kit.text(
	parent: Instance,
	name: string,
	text: string,
	size: number,
	font: Font?,
	color: Color3?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, math.ceil(size * 1.25))
	label.FontFace = font or Style.body()
	label.TextSize = size
	label.TextColor3 = color or Style.ink
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
	return label
end

-- Compatibility signature used by the kept BlindBoxPreview.
function Kit.label(parent: Instance, text: string, height: number, size: number?): TextLabel
	local label = Kit.text(parent, "Label", text, size or 16)
	label.Size = UDim2.new(1, 0, 0, height)
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
	return label
end

function Kit.image(parent: Instance, name: string, image: string): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.ScaleType = Enum.ScaleType.Fit
	label.Image = image
	label.Parent = parent
	return label
end

function Kit.list(
	parent: Instance,
	direction: Enum.FillDirection,
	gap: number,
	align: Enum.VerticalAlignment?
): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.VerticalAlignment = align or Enum.VerticalAlignment.Top
	layout.Parent = parent
	return layout
end

function Kit.grid(parent: Instance, gap: number): UIGridLayout
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(gap, gap)
	layout.Parent = parent
	return layout
end

-- Measured vertical scroller: the canvas follows the layout's real content size (Scroll.bind).
function Kit.scroll(
	parent: Instance,
	name: string,
	scope: Scope.Scope,
	layout: UIGridStyleLayout,
	padding: number,
	scale: () -> number
): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Style.violet
	frame.CanvasSize = UDim2.fromOffset(0, 0)
	frame.SelectionGroup = true
	frame.Parent = parent
	Kit.padding(frame, padding, padding, padding, padding)
	layout.Parent = frame
	scope.add(Scroll.bind(frame, layout, padding, scale))
	return frame
end

-- A scroller whose canvas height the owner computes (manually placed content).
function Kit.canvas(parent: Instance, name: string): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Style.violet
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
	frame.CanvasSize = UDim2.fromOffset(0, 0)
	frame.SelectionGroup = true
	frame.Parent = parent
	return frame
end

export type Card = {
	root: Frame,
	face: Frame,
	shadow: Frame,
	stroke: UIStroke,
	radius: (number) -> (),
}
-- White face with an ink outline and a hard drop shadow (shadow is a sibling under the face).
function Kit.card(
	parent: Instance,
	name: string,
	color: Color3,
	radius: number,
	drop: number,
	outline: number?
): Card
	local root = Kit.frame(parent, name)
	local shadow = Kit.frame(root, "Shadow", Style.ink)
	shadow.Position = UDim2.fromOffset(0, drop)
	shadow.Visible = drop > 0
	shadow.ZIndex = 1
	local shadowCorner = Kit.corner(shadow, radius)
	local face = Kit.frame(root, "Face", color)
	face.ZIndex = 2
	local faceCorner = Kit.corner(face, radius)
	local stroke = Kit.stroke(face, Style.ink, outline or Style.outline)
	return {
		root = root,
		face = face,
		shadow = shadow,
		stroke = stroke,
		radius = function(value: number)
			shadowCorner.CornerRadius = UDim.new(0, value)
			faceCorner.CornerRadius = UDim.new(0, value)
		end,
	}
end

return Kit

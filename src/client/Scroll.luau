--!strict
-- Explicit content height avoids AutomaticCanvasSize cutting off nested viewport cards.
-- Under a UIScale, AbsoluteContentSize is in screen pixels while CanvasSize is in design units;
-- `scale` (optional) returns that ratio so the canvas is neither short nor inflated.
local Scroll = {}
function Scroll.bind(
	frame: ScrollingFrame,
	layout: UIGridStyleLayout,
	padding: number,
	scale: (() -> number)?
): () -> ()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	frame.ClipsDescendants = true
	local function resize()
		local ratio = if scale then math.max(0.01, scale()) else 1
		frame.CanvasSize =
			UDim2.fromOffset(0, math.ceil(layout.AbsoluteContentSize.Y / ratio + padding * 2))
	end
	local content = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
	local size = frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	return function()
		content:Disconnect()
		size:Disconnect()
	end
end
return Scroll

--!strict
-- Explicit content height avoids AutomaticCanvasSize cutting off nested viewport cards.
local Scroll = {}
function Scroll.bind(frame: ScrollingFrame, layout: UIGridStyleLayout, padding: number): () -> ()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	frame.ClipsDescendants = true
	local function resize()
		frame.CanvasSize =
			UDim2.fromOffset(0, math.ceil(layout.AbsoluteContentSize.Y + padding * 2))
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

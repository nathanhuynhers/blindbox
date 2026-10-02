--!strict
-- Thin progress bar and segmented progress (daily goal) on the shared track color.
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Progress = {}

export type Bar = { root: Frame, set: (number, number) -> (), color: (Color3) -> () }
function Progress.bar(parent: Instance, name: string, height: number, color: Color3): Bar
	local root = Kit.frame(parent, name, Style.track)
	root.Size = UDim2.new(1, 0, 0, height)
	root.ClipsDescendants = true
	Kit.corner(root, math.floor(height / 2))
	local fill = Kit.frame(root, "Fill", color)
	fill.Size = UDim2.fromScale(0, 1)
	Kit.corner(fill, math.floor(height / 2))
	return {
		root = root,
		set = function(count: number, total: number)
			local ratio = if total > 0 then math.clamp(count / total, 0, 1) else 0
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.Visible = ratio > 0
		end,
		color = function(value: Color3)
			fill.BackgroundColor3 = value
		end,
	}
end

export type Segments = { root: Frame, set: (number) -> () }
function Progress.segments(
	parent: Instance,
	name: string,
	count: number,
	height: number,
	gap: number
): Segments
	local root = Kit.frame(parent, name)
	root.Size = UDim2.new(1, 0, 0, height)
	local parts: { Frame } = {}
	for index = 1, count do
		local part = Kit.frame(root, "Segment" .. index, Style.track)
		part.Position = UDim2.new((index - 1) / count, if index == 1 then 0 else gap / 2, 0, 0)
		part.Size =
			UDim2.new(1 / count, -gap / 2 * (if index == 1 or index == count then 1 else 2), 1, 0)
		Kit.corner(part, math.floor(height / 2))
		parts[index] = part
	end
	return {
		root = root,
		set = function(done: number)
			for index, part in parts do
				part.BackgroundColor3 = if index <= done then Style.mintFill else Style.track
			end
		end,
	}
end

return Progress

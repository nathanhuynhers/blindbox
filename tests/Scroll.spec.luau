--!strict
local Scroll = require("./Scroll")
local function signal()
	local callbacks: { () -> () } = {}
	return {
		Connect = function(_self: unknown, callback: () -> ())
			table.insert(callbacks, callback)
			return { Disconnect = function() local index = table.find(callbacks, callback); if index then table.remove(callbacks, index) end end }
		end,
		fire = function() for _, callback in callbacks do callback() end end,
		count = function() return #callbacks end,
	}
end
local content = signal()
local size = signal()
local frame = { CanvasSize = { Y = { Offset = 0 } }, GetPropertyChangedSignal = function() return size end }
local layout = { AbsoluteContentSize = { Y = 1480 }, GetPropertyChangedSignal = function() return content end }
local stop = Scroll.bind(frame, layout, 8)
assert(frame.CanvasSize.Y.Offset == 1496, "last card plus bottom padding is scrollable")
layout.AbsoluteContentSize.Y = 2360
content.fire()
assert(frame.CanvasSize.Y.Offset == 2376, "content growth extends canvas")
layout.AbsoluteContentSize.Y = 500
size.fire()
assert(frame.CanvasSize.Y.Offset == 516, "resize/filter recalculates height")
stop()
assert(content.count() == 0 and size.count() == 0, "connections cleaned up")
print("PASS: 4 scrolling sizing/lifecycle checks (engine properties/signals stubbed)")

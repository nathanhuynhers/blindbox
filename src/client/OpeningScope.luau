--!strict
-- A failing cleanup must not prevent camera, input or UI restoration.
local Scope = {}
export type Scope = {
	add: (() -> ()) -> (),
	destroy: () -> (),
	isAlive: () -> boolean,
	guard: (() -> ()) -> () -> (),
}
function Scope.create(): Scope
	local callbacks: { () -> () } = {}
	local destroyed = false
	local function safely(callback: () -> ())
		local ok, reason = pcall(function()
			callback()
			return true
		end)
		if not ok then
			warn("Opening cleanup: " .. tostring(reason))
		end
	end
	return {
		isAlive = function()
			return not destroyed
		end,
		guard = function(callback)
			return function()
				if not destroyed then
					callback()
				end
			end
		end,
		add = function(callback)
			if destroyed then
				safely(callback)
			else
				table.insert(callbacks, callback)
			end
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for index = #callbacks, 1, -1 do
				safely(callbacks[index])
			end
			table.clear(callbacks)
		end,
	}
end
return Scope

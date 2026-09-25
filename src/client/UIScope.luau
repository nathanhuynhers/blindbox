--!strict
local Scope = {}
export type Scope = {
	add: (() -> ()) -> (),
	connect: (RBXScriptSignal, (...unknown) -> ()) -> (),
	destroy: () -> (),
}
-- Connections/temporary components share the lifetime of their screen, never a snapshot refresh.
function Scope.create(): Scope
	local cleanups: { () -> () } = {}
	local destroyed = false
	return {
		add = function(cleanup: () -> ())
			if destroyed then
				cleanup()
			else
				table.insert(cleanups, cleanup)
			end
		end,
		connect = function(signal: RBXScriptSignal, callback: (...unknown) -> ())
			local connection = signal:Connect(callback)
			if destroyed then
				connection:Disconnect()
			else
				table.insert(cleanups, function()
					connection:Disconnect()
				end)
			end
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			for index = #cleanups, 1, -1 do
				cleanups[index]()
			end
			table.clear(cleanups)
		end,
	}
end
return Scope

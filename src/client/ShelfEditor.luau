--!strict
-- Wait for an authoritative snapshot after the server holds the showcase pause.
-- Closing a screen retains that hold until the pending Shelf request is acknowledged.
local ShelfEditor = {}
export type Controller = {
	shown: (boolean) -> (),
	pending: (boolean) -> (),
	receive: (number?) -> (),
	ready: () -> boolean,
	destroy: () -> (),
}
function ShelfEditor.create(signal: (boolean, number) -> ()): Controller
	local shown, pending, held, destroyed = false, false, false, false
	local token = 0
	local acknowledged: number? = nil
	local function reconcile()
		if shown and not held and not destroyed then
			token += 1
			held = true
			acknowledged = nil
			signal(true, token)
		elseif held and not shown and not pending then
			held = false
			acknowledged = nil
			signal(false, token)
		end
	end
	return {
		shown = function(value)
			shown = value and not destroyed
			reconcile()
		end,
		pending = function(value)
			pending = value
			reconcile()
		end,
		receive = function(value)
			acknowledged = value
		end,
		ready = function()
			return not destroyed and shown and held and acknowledged == token
		end,
		destroy = function()
			-- Script/UI teardown must also preserve an in-flight edit's hold. Disconnect
			-- removes the plot; a surviving client may still recover its pending receipt.
			shown = false
			reconcile()
			destroyed = true
		end,
	}
end
return ShelfEditor

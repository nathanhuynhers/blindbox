--!strict
-- Presentation only. Outstanding confirmed collections trail the latest wallet by their
-- unlanded portions. Tokens never contain a final wallet, so old callbacks cannot restore one.
local Counter = {}
export type Counter = {
	snapshot: (wallet: number, collected: number?, impacts: number?, count: number?) -> number?,
	impact: (token: number, impacts: number) -> (),
	finish: (token: number) -> (),
	reconcile: () -> (),
}
type Pending = { amount: number, count: number, impacts: number }

function Counter.create(display: (number) -> ()): Counter
	local wallet = 0
	local serial = 0
	local pending: { [number]: Pending } = {}
	local function publish()
		local remaining = 0
		for _, entry in pending do
			remaining += entry.amount - math.floor(entry.amount * entry.impacts / entry.count)
		end
		display(math.max(0, wallet - remaining))
	end
	local function reconcile()
		table.clear(pending)
		publish()
	end
	return {
		snapshot = function(value, collected, impacts, count)
			local delta = value - wallet
			wallet = value
			-- Only a known, successful collection delta may be assigned to impacts.
			if collected and collected > 0 and collected == delta and count and count > 0 then
				serial += 1
				pending[serial] = { amount = collected, count = count, impacts = impacts or 0 }
				publish()
				return serial
			end
			if delta ~= 0 then
				table.clear(pending)
			end
			publish()
			return nil
		end,
		impact = function(token, impacts)
			local entry = pending[token]
			if entry then
				entry.impacts = math.clamp(impacts, entry.impacts, entry.count)
				publish()
			end
		end,
		finish = function(token)
			if pending[token] then
				pending[token] = nil
				publish()
			end
		end,
		reconcile = reconcile,
	}
end
return Counter

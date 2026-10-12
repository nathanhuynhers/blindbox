--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Tutorial = require(game:GetService("ReplicatedStorage").Shared.Tutorial)
local AutoCollect = {}
export type Dependencies = {
	now: () -> number,
	ready: () -> boolean,
	ownership: () -> (boolean, boolean),
	enabled: () -> boolean,
	state: () -> Types.State,
	-- Shared owner exports this helper; same non-yielding transfer used by manual/swap.
	-- No revision, quest advancement, settlement or multiplier in this callback.
	transferBank: (Types.State, string) -> number,
}
export type Controller = {
	step: () -> number,
	reason: () -> string,
	pause: () -> (),
	resume: () -> (),
	destroy: () -> (),
}
function AutoCollect.create(deps: Dependencies): Controller
	local active, paused, stepping = true, false, false
	local last = -math.huge
	local reason = "Off"
	return {
		step = function()
			if not active or paused or stepping then
				return 0
			end
			local now = deps.now()
			if now - last < 1 then
				return 0
			end
			last = now -- no catch-up bursts or owned timer; run after normal settlement.
			if not deps.enabled() then
				reason = "Off"
				return 0
			end
			if not deps.ready() then
				reason = "Storage unavailable"
				return 0
			end
			local owned, fresh = deps.ownership()
			if not owned or not fresh then
				reason = "Ownership unconfirmed"
				return 0
			end
			local state = deps.state()
			if state.step <= Tutorial.collect then
				reason = "Collect once from your Display to finish the lesson"
				return 0
			end
			stepping = true
			local total = 0
			local seen: { [string]: boolean } = {}
			for slot = 1, state.display.unlocked do
				local id = state.display.slots[slot]
				if id and id ~= "" and state.owned[id] and not seen[id] then
					seen[id] = true
					total += deps.transferBank(state, id)
				end
			end
			if total > 0 then
				state.revision += 1
			end
			stepping = false
			reason = if total > 0 then "Collecting" else "Waiting for whole Coins or wallet space"
			return total
		end,
		reason = function()
			return reason
		end,
		pause = function()
			paused = true
			reason = "AFK handoff"
		end,
		resume = function()
			paused = false
			last = deps.now()
		end,
		destroy = function()
			active = false
			reason = "Disconnected"
		end,
	}
end
return AutoCollect

--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
export type Entry = { ownership: Types.Ownership, fresh: boolean, busy: boolean }
export type State = { [string]: Entry }
local Entitlements = {}
function Entitlements.refresh(
	state: State,
	key: string,
	userId: number,
	passId: number,
	owns: (number, number) -> boolean
): boolean
	local entry = state[key]
	if not entry then
		entry = { ownership = "Unknown", fresh = false, busy = false }
		state[key] = entry
	end
	if entry.busy then
		return false
	end
	entry.busy, entry.fresh = true, false
	local ok, owned = pcall(owns, userId, passId)
	entry.busy = false
	if ok and typeof(owned) == "boolean" then
		entry.ownership = if owned then "Owned" else "NotOwned"
		entry.fresh = true
	end
	-- Failure preserves previously verified ownership, never invents ownership.
	return entry.fresh
end
function Entitlements.view(state: State, key: string): (Types.Ownership, boolean)
	local entry = state[key]
	if entry then
		return entry.ownership, entry.fresh
	end
	local unknown: Types.Ownership = "Unknown"
	return unknown, false
end
return Entitlements

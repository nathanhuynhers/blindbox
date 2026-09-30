--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local UI = require(script.Parent.UIState)
local State = {}
export type Slot = {
	id: string,
	locked: boolean,
	available: boolean,
	action: string,
	enabled: boolean,
	remove: boolean,
	rate: number,
}
function State.display(
	snapshot: Types.Snapshot,
	slot: number,
	selected: string?,
	canAct: boolean
): Slot
	local id = snapshot.slots[slot] or ""
	local locked = slot > snapshot.unlocked
	local purchase = locked and slot == 4 and DisplayConfig.unlockMethods[slot] == "LegacyCoins"
	local action, enabled = if id == "" then "Choose figure" else "Change figure", canAct
	if locked then
		action = if purchase then "Unlock slot" else "Coming later"
		enabled = canAct and purchase and snapshot.coins >= snapshot.expansionCost
	elseif selected then
		local _, free = UI.copies(snapshot, selected)
		action = if selected == id
			then "Displayed here"
			elseif free == 0 then "No spare copies"
			else "Place here"
		enabled = canAct and free > 0 and selected ~= id
	end
	return {
		id = id,
		locked = locked,
		available = purchase,
		action = action,
		enabled = enabled,
		remove = not locked and id ~= "",
		rate = snapshot.rates[id] or 0,
	}
end
function State.shelf(snapshot: Types.Snapshot, selectedId: string): Types.VisibleShelf?
	for _, unit in snapshot.shelves.visible do
		if unit.id == selectedId then
			return unit
		end
	end
	return snapshot.shelves.visible[1]
end
-- A fixed pool of picker previews is rebound by page, independent of catalog size.
function State.discovered(snapshot: Types.Snapshot): { string }
	local ids: { string } = {}
	for _, figure in Catalog.figures do
		if snapshot.discovered[figure.id] then
			table.insert(ids, figure.id)
		end
	end
	return ids
end
function State.picker(
	ids: { string },
	requested: number,
	capacity: number
): ({ string }, number, number)
	local pages = math.max(1, math.ceil(#ids / capacity))
	local page = math.clamp(requested, 1, pages)
	local result: { string } = {}
	for index = (page - 1) * capacity + 1, math.min(#ids, page * capacity) do
		table.insert(result, ids[index])
	end
	return result, page, pages
end
function State.goal(snapshot: Types.Snapshot): string
	return if snapshot.goalClaimed
		then "claimed"
		elseif snapshot.goalProgress >= 3 then "ready"
		else "progress"
end
return State

--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local State = {}
-- Read-only presentation projections. The server still validates every action and all values.
function State.copies(snapshot: Types.Snapshot, id: string): (number, number)
	local owned, displayed = snapshot.owned[id] or 0, 0
	for _, placed in snapshot.slots do
		if placed == id then
			displayed += 1
		end
	end
	return owned, math.max(0, owned - displayed)
end
function State.completion(snapshot: Types.Snapshot, collection: string): (number, number)
	local found, total = 0, 0
	for _, figure in Catalog.figures do
		if figure.collection == collection then
			total += 1
			if snapshot.discovered[figure.id] then
				found += 1
			end
		end
	end
	return found, total
end
function State.matches(
	snapshot: Types.Snapshot,
	id: string,
	collection: string,
	ownedOnly: boolean
): boolean
	return Catalog.byId[id].collection == collection
		and (not ownedOnly or (snapshot.owned[id] or 0) > 0)
end
function State.recycle(snapshot: Types.Snapshot, id: string): boolean
	local owned, free = State.copies(snapshot, id)
	return snapshot.ready and owned > 1 and free > 0
end
function State.grid(width: number, minimum: number, maximum: number): (number, number)
	local available = math.max(1, width - 32) -- padding and scroll bar gutter
	local columns = math.clamp(math.floor((available + 12) / (minimum + 12)), 1, maximum)
	return columns, math.max(1, math.floor((available - (columns - 1) * 12) / columns))
end
function State.number(value: number): string
	local integer = tostring(math.floor(value))
	local reversed = string.gsub(string.reverse(integer), "(%d%d%d)", "%1,")
	local result = string.reverse(reversed)
	return string.gsub(result, "^,", "")
end
function State.bonusProgress(snapshot: Types.Snapshot): number
	local seen: { [string]: boolean } = {}
	local counts: { [string]: number } = {}
	local best = 0
	for _, id in snapshot.slots do
		local figure = Catalog.byId[id]
		if figure and not seen[id] then
			seen[id] = true
			counts[figure.collection] = (counts[figure.collection] or 0) + 1
			best = math.max(best, counts[figure.collection])
		end
	end
	return math.min(3, best)
end
function State.compact(value: number): string
	if value < 10000 then
		return State.number(value)
	end
	local unit = if value >= 1000000000
		then 1000000000
		elseif value >= 1000000 then 1000000
		else 1000
	local suffix = if unit == 1000000000 then "B" elseif unit == 1000000 then "M" else "K"
	return string.format("%g%s", math.floor(value / unit * 10) / 10, suffix)
end
function State.ownedCollection(snapshot: Types.Snapshot, preferred: number): number
	local populated: { [string]: boolean } = {}
	for _, figure in Catalog.figures do
		if (snapshot.owned[figure.id] or 0) > 0 then
			populated[figure.collection] = true
		end
	end
	if populated[Catalog.collections[preferred].id] then
		return preferred
	end
	for index, collection in Catalog.collections do
		if populated[collection.id] then
			return index
		end
	end
	return preferred
end
return State

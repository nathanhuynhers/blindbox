--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Selection = {}
export type State = { collection: string, figure: string, inspected: boolean, acquired: boolean }
function Selection.first(collection: string, snapshot: Types.Snapshot?, ownedOnly: boolean): string
	local first: string? = nil
	for _, figure in Catalog.figures do
		if figure.collection == collection then
			first = first or figure.id
			if
				snapshot
				and (
					if ownedOnly
						then (snapshot.owned[figure.id] or 0) > 0
						else snapshot.discovered[figure.id]
				)
			then
				return figure.id
			end
		end
	end
	return first or Catalog.figures[1].id
end
function Selection.create(): State
	local collection = Catalog.collections[1].id
	return {
		collection = collection,
		figure = Selection.first(collection, nil, false),
		inspected = false,
		acquired = false,
	}
end
function Selection.choose(state: State, id: string, acquired: boolean?)
	local figure = Catalog.byId[id]
	if not figure then
		return
	end
	state.collection, state.figure = figure.collection, id
	state.inspected, state.acquired = true, acquired == true
end
function Selection.open(state: State, picker: boolean)
	-- Opening rewards survive the next navigation into Collection, including narrow layouts.
	state.inspected = state.acquired and not picker
	state.acquired = false
end
function Selection.step(state: State, direction: number)
	local ids: { string } = {}
	for _, figure in Catalog.figures do
		if figure.collection == state.collection then
			table.insert(ids, figure.id)
		end
	end
	local index = table.find(ids, state.figure) or 1
	Selection.choose(state, ids[(index - 1 + direction) % #ids + 1])
end
return Selection

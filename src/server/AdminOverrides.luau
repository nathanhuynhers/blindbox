--!strict
local AdminTypes = require(game:GetService("ReplicatedStorage").Shared.AdminTypes)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local CollectionEconomy = require(script.Parent.CollectionEconomy)
local Overrides = {}
export type Store = { [number]: AdminTypes.Override }
function Overrides.peek(store: Store, userId: number, now: number): AdminTypes.Override?
	local value = store[userId]
	if value and now >= value.expires then
		store[userId] = nil
		return nil
	end
	return value
end
-- Called ONLY within open(), after the complete opening preflight. No yields.
function Overrides.consume(
	store: Store,
	userId: number,
	collection: string,
	roll: number,
	now: number
): string?
	local value = Overrides.peek(store, userId, now)
	if not value or value.collection ~= collection then
		return nil
	end
	local figure = value.figure
	if figure and Catalog.byId[figure] and Catalog.byId[figure].collection == collection then
		store[userId] = nil
		return figure
	end
	if value.rarity then
		local id = CollectionEconomy.roll(roll, collection, {}, nil, value.rarity)
		store[userId] = nil
		return id
	end
	return nil
end
return Overrides

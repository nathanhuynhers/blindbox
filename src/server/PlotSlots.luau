--!strict
export type Allocator = { limit: number, owners: { [number]: number }, slots: { [number]: number } }
local Slots = {}
function Slots.new(limit: number): Allocator
	assert(limit > 0 and limit % 1 == 0, "Invalid plot limit")
	return { limit = limit, owners = {}, slots = {} }
end
function Slots.claim(allocator: Allocator, userId: number): number?
	if allocator.owners[userId] then
		return nil
	end
	for index = 1, allocator.limit do
		if not allocator.slots[index] then
			allocator.slots[index] = userId
			allocator.owners[userId] = index
			return index
		end
	end
	return nil
end
function Slots.release(allocator: Allocator, userId: number)
	local index = allocator.owners[userId]
	if index then
		allocator.slots[index] = nil
		allocator.owners[userId] = nil
	end
end
return Slots

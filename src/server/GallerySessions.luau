--!strict
-- Pure runtime membership. IDs are session generations, never persisted coordinates.
export type Runtime = {
	ownerId: number,
	id: string,
	index: number,
	participants: { [number]: boolean },
}
export type Visit = { ownerId: number, runtimeId: string, roomId: string? }
export type Registry =
	{ owners: { [number]: Runtime }, visits: { [number]: Visit }, serial: number }
local Sessions = {}
function Sessions.new(): Registry
	return { owners = {}, visits = {}, serial = 0 }
end
function Sessions.leave(registry: Registry, actorId: number): number?
	local visit = registry.visits[actorId]
	if not visit then
		return nil
	end
	registry.visits[actorId] = nil
	local runtime = registry.owners[visit.ownerId]
	if runtime then
		runtime.participants[actorId] = nil
		if not next(runtime.participants) then
			registry.owners[visit.ownerId] = nil
			return visit.ownerId
		end
	end
	return nil
end
function Sessions.enter(registry: Registry, actorId: number, ownerId: number): Runtime
	assert(not registry.visits[actorId], "Leave previous runtime before entering")
	local runtime = registry.owners[ownerId]
	if not runtime then
		local used: { [number]: boolean } = {}
		for _, other in registry.owners do
			used[other.index] = true
		end
		local index = 1
		while used[index] do
			index += 1
		end
		registry.serial += 1
		runtime =
			{ ownerId = ownerId, id = tostring(registry.serial), index = index, participants = {} }
		registry.owners[ownerId] = runtime
	end
	runtime.participants[actorId] = true
	registry.visits[actorId] = { ownerId = ownerId, runtimeId = runtime.id, roomId = nil }
	return runtime
end
function Sessions.valid(registry: Registry, actorId: number, runtimeId: string): boolean
	local visit = registry.visits[actorId]
	local runtime = if visit then registry.owners[visit.ownerId] else nil
	return visit ~= nil
		and runtime ~= nil
		and runtime.id == runtimeId
		and visit.runtimeId == runtimeId
		and runtime.participants[actorId] == true
end
function Sessions.closeOwner(registry: Registry, ownerId: number): { number }
	local actors: { number } = {}
	local runtime = registry.owners[ownerId]
	if runtime then
		for id in runtime.participants do
			table.insert(actors, id)
			registry.visits[id] = nil
		end
		registry.owners[ownerId] = nil
	end
	return actors
end
return Sessions

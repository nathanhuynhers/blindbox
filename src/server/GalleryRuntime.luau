--!strict
local Players = game:GetService("Players")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Config = require(game:GetService("ReplicatedStorage").Shared.ShowroomConfig)
local Sessions = require(script.Parent.GallerySessions)
local Showrooms = require(script.Parent.Showrooms)
local Template = require(script.Parent.SpaceTemplate)
type RoomRuntime = {
	id: string,
	space: Template.Space,
	connections: { RBXScriptConnection },
	index: number,
}
type Runtime = {
	id: string,
	hall: Template.Space,
	rooms: { [string]: RoomRuntime },
	doors: Folder,
	connections: { RBXScriptConnection },
	doorConnections: { RBXScriptConnection },
	page: number,
	doorSignature: string,
}
export type Controller = {
	register: (Player, BasePart) -> (),
	remove: (Player) -> (),
	leave: (Player) -> (),
	view: (Player) -> Types.GalleryView?,
	access: (Player) -> Showrooms.Access?,
	refresh: (Player) -> (),
	destroy: () -> (),
}
local Gallery = {}
local function disconnect(connections: { RBXScriptConnection })
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end
local function near(player: Player, position: Vector3, distance: number): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and (root.Position - position).Magnitude <= distance
end
function Gallery.create(getState: (number) -> Types.State?, returnHome: (Player) -> ()): Controller
	local registry = Sessions.new()
	local runtimes: { [number]: Runtime } = {}
	local entrances: { [Player]: RBXScriptConnection } = {}
	local lastAction: { [Player]: number } = {}
	local roomSerial = 0
	local root = Instance.new("Folder")
	root.Name = "GalleryRuntimes"
	root.Parent = workspace
	local function allowed(player: Player): boolean
		local now = os.clock()
		if now - (lastAction[player] or -math.huge) < 0.5 or not getState(player.UserId) then
			return false
		end
		lastAction[player] = now
		return true
	end
	local function destroyRuntime(ownerId: number)
		local runtime = runtimes[ownerId]
		if not runtime then
			return
		end
		runtimes[ownerId] = nil
		disconnect(runtime.connections)
		disconnect(runtime.doorConnections)
		for _, room in runtime.rooms do
			disconnect(room.connections)
			room.space.model:Destroy()
		end
		runtime.hall.model:Destroy()
	end
	local function prune(ownerId: number)
		local runtime = runtimes[ownerId]
		if not runtime then
			return
		end
		local occupied: { [string]: boolean } = {}
		for _, visit in registry.visits do
			if visit.ownerId == ownerId and visit.roomId then
				occupied[visit.roomId] = true
			end
		end
		for id, room in runtime.rooms do
			if not occupied[id] then
				disconnect(room.connections)
				room.space.model:Destroy()
				runtime.rooms[id] = nil
			end
		end
	end
	local function leave(player: Player)
		local old = registry.visits[player.UserId]
		local empty = Sessions.leave(registry, player.UserId)
		if empty then
			destroyRuntime(empty)
		elseif old then
			prune(old.ownerId)
		end
	end
	local function current(player: Player, runtime: Runtime): boolean
		return runtime.hall.model.Parent ~= nil
			and Sessions.valid(registry, player.UserId, runtime.id)
	end
	local function pivot(player: Player, cf: CFrame)
		if player.Character then
			player.Character:PivotTo(cf)
		end
	end
	local function hallway(player: Player, ownerId: number, runtime: Runtime)
		if not current(player, runtime) then
			return
		end
		registry.visits[player.UserId].roomId = nil
		pivot(player, runtime.hall.spawn)
		prune(ownerId)
	end
	local function enterRoom(player: Player, ownerId: number, runtime: Runtime, roomId: string)
		local state = getState(ownerId)
		local data = if state then state.showrooms.rooms[roomId] else nil
		if
			not data
			or not current(player, runtime)
			or registry.visits[player.UserId].roomId ~= nil
		then
			return
		end
		local room: RoomRuntime? = runtime.rooms[roomId]
		if not room then
			local used: { [number]: boolean } = {}
			for _, other in runtime.rooms do
				used[other.index] = true
			end
			local index = 1
			while used[index] do
				index += 1
			end
			local origin = runtime.hall.origin
				+ Vector3.new(((index - 1) % 6 - 2) * 64, 0, 110 + math.floor((index - 1) / 6) * 64)
			local space = Template.create(
				root,
				"Showroom_" .. ownerId .. "_" .. roomId,
				origin,
				ownerId,
				data
			)
			roomSerial += 1
			local roomRuntimeId = runtime.id .. ":room:" .. roomSerial
			space.model:SetAttribute("RuntimeId", roomRuntimeId)
			local created: RoomRuntime =
				{ id = roomRuntimeId, space = space, connections = {}, index = index }
			runtime.rooms[roomId] = created
			table.insert(
				created.connections,
				space.model.Destroying:Connect(function()
					if runtime.rooms[roomId] ~= created then
						return
					end
					disconnect(created.connections)
					runtime.rooms[roomId] = nil
					for actorId, visit in registry.visits do
						if visit.ownerId == ownerId and visit.roomId == roomId then
							visit.roomId = nil
							local actor = Players:GetPlayerByUserId(actorId)
							if actor then
								pivot(actor, runtime.hall.spawn)
							end
						end
					end
				end)
			)
			local exit, prompt = Template.portal(
				space.model,
				"GalleryExit",
				origin + Vector3.new(0, 3, -18),
				"Return to Gallery"
			)
			table.insert(
				created.connections,
				prompt.Triggered:Connect(function(actor: Player)
					local visit = registry.visits[actor.UserId]
					if
						allowed(actor)
						and exit.Parent ~= nil
						and runtime.rooms[roomId] == created
						and current(actor, runtime)
						and visit
						and visit.roomId == roomId
						and near(actor, exit.Position, 12)
					then
						hallway(actor, ownerId, runtime)
					end
				end)
			)
			Template.render(space, data)
			room = created
		end
		assert(room, "Showroom allocation failed")
		registry.visits[player.UserId].roomId = roomId
		pivot(player, room.space.spawn)
	end
	local renderDoors: (number, Runtime) -> ()
	renderDoors = function(ownerId, runtime)
		local state = getState(ownerId)
		if not state then
			return
		end
		local ids: { string } = {}
		for id in state.showrooms.rooms do
			table.insert(ids, id)
		end
		table.sort(ids)
		local pages = math.max(1, math.ceil(#ids / Config.roomsPerHall))
		runtime.page = math.clamp(runtime.page, 1, pages)
		local signature = tostring(runtime.page) .. "|" .. table.concat(ids, "|")
		if signature == runtime.doorSignature then
			return
		end
		runtime.doorSignature = signature
		disconnect(runtime.doorConnections)
		runtime.doors:ClearAllChildren()
		for offset = 1, Config.roomsPerHall do
			local id = ids[(runtime.page - 1) * Config.roomsPerHall + offset]
			if id then
				local position = runtime.hall.origin
					+ Vector3.new(
						if offset % 2 == 1 then -16 else 16,
						3,
						-12 + math.floor((offset - 1) / 2) * 14
					)
				local door, prompt = Template.portal(
					runtime.doors,
					"RoomEntrance",
					position,
					Showrooms.name(state.showrooms.rooms[id])
				)
				door:SetAttribute("RoomId", id)
				table.insert(
					runtime.doorConnections,
					prompt.Triggered:Connect(function(actor: Player)
						if door.Parent and allowed(actor) and near(actor, door.Position, 12) then
							enterRoom(actor, ownerId, runtime, id)
						end
					end)
				)
			end
		end
		local sign = Template.part(
			runtime.doors,
			"HallLabel",
			runtime.hall.origin + Vector3.new(0, 4, 29),
			Vector3.new(8, 2, 1),
			Color3.fromRGB(60, 70, 80)
		)
		Template.label(
			sign,
			if #ids == 0
				then "Complete a collection to unlock its Showroom"
				else string.format("Gallery hall %d / %d", runtime.page, pages)
		)
		if pages > 1 then
			for _, direction in { -1, 1 } do
				local door, prompt = Template.portal(
					runtime.doors,
					"HallPage",
					runtime.hall.origin + Vector3.new(direction * 9, 3, 27),
					if direction == 1 then "Next hall" else "Previous hall"
				)
				table.insert(
					runtime.doorConnections,
					prompt.Triggered:Connect(function(actor: Player)
						local visit = registry.visits[actor.UserId]
						if
							door.Parent
							and allowed(actor)
							and current(actor, runtime)
							and visit
							and not visit.roomId
							and near(actor, door.Position, 12)
						then
							runtime.page = (runtime.page - 1 + direction) % pages + 1
							renderDoors(ownerId, runtime)
						end
					end)
				)
			end
		end
	end
	local function enter(player: Player, ownerId: number)
		if not getState(ownerId) then
			return
		end
		leave(player)
		local session = Sessions.enter(registry, player.UserId, ownerId)
		local runtime: Runtime? = runtimes[ownerId]
		if not runtime then
			local hall = Template.create(
				root,
				"Gallery_" .. ownerId,
				Vector3.new(session.index * 640, 200, 1000),
				ownerId,
				nil
			)
			hall.model:SetAttribute("RuntimeId", session.id)
			local doors = Instance.new("Folder")
			doors.Name = "Entrances"
			doors.Parent = hall.model
			local created: Runtime = {
				id = session.id,
				hall = hall,
				rooms = {},
				doors = doors,
				connections = {},
				doorConnections = {},
				page = 1,
				doorSignature = "",
			}
			runtimes[ownerId] = created
			table.insert(
				created.connections,
				hall.model.Destroying:Connect(function()
					local guests = Sessions.closeOwner(registry, ownerId)
					destroyRuntime(ownerId)
					for _, actorId in guests do
						local actor = Players:GetPlayerByUserId(actorId)
						if actor then
							returnHome(actor)
						end
					end
				end)
			)
			local captured = created
			local exit, prompt = Template.portal(
				hall.model,
				"MainPlotExit",
				hall.origin + Vector3.new(0, 3, -29),
				"Return to your plot"
			)
			table.insert(
				created.connections,
				prompt.Triggered:Connect(function(actor: Player)
					local visit = registry.visits[actor.UserId]
					if
						allowed(actor)
						and current(actor, captured)
						and visit
						and not visit.roomId
						and near(actor, exit.Position, 12)
					then
						leave(actor)
						returnHome(actor)
					end
				end)
			)
			renderDoors(ownerId, created)
			runtime = created
		end
		assert(runtime, "Gallery allocation failed")
		pivot(player, runtime.hall.spawn)
	end
	return {
		register = function(owner, entrance)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Enter Gallery"
			prompt.ObjectText = owner.DisplayName .. "'s Gallery"
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = entrance
			entrances[owner] = prompt.Triggered:Connect(function(actor: Player)
				if
					entrance.Parent
					and allowed(actor)
					and not registry.visits[actor.UserId]
					and near(actor, entrance.Position, 12)
				then
					enter(actor, owner.UserId)
				end
			end)
		end,
		leave = leave,
		remove = function(player)
			leave(player)
			local guests = Sessions.closeOwner(registry, player.UserId)
			destroyRuntime(player.UserId)
			for _, id in guests do
				local actor = Players:GetPlayerByUserId(id)
				if actor then
					returnHome(actor)
				end
			end
			if entrances[player] then
				entrances[player]:Disconnect()
				entrances[player] = nil
			end
			lastAction[player] = nil
		end,
		view = function(player)
			local visit = registry.visits[player.UserId]
			local runtime = if visit then runtimes[visit.ownerId] else nil
			if not visit or not runtime or not current(player, runtime) then
				return nil
			end
			local state = getState(visit.ownerId)
			local owner = Players:GetPlayerByUserId(visit.ownerId)
			if not state or not owner then
				return nil
			end
			local rooms: { { roomId: string, name: string } } = {}
			-- Only the bounded visible hall is projected; room ownership itself has no four-room cap.
			for _, door in runtime.doors:GetChildren() do
				local id = door:GetAttribute("RoomId")
				if typeof(id) == "string" and state.showrooms.rooms[id] then
					table.insert(
						rooms,
						{ roomId = id, name = Showrooms.name(state.showrooms.rooms[id]) }
					)
				end
			end
			table.sort(rooms, function(a, b)
				return a.roomId < b.roomId
			end)
			local room = if visit.roomId then state.showrooms.rooms[visit.roomId] else nil
			local activeRoom = if visit.roomId then runtime.rooms[visit.roomId] else nil
			return {
				ownerId = visit.ownerId,
				ownerName = owner.DisplayName,
				runtimeId = if activeRoom then activeRoom.id else visit.runtimeId,
				roomId = visit.roomId,
				room = if room then Showrooms.copyRoom(room) else nil,
				canEdit = player.UserId == visit.ownerId,
				rooms = rooms,
			}
		end,
		access = function(player)
			local visit = registry.visits[player.UserId]
			local runtime = if visit then runtimes[visit.ownerId] else nil
			local room = if runtime
					and visit
					and visit.roomId
				then runtime.rooms[visit.roomId]
				else nil
			if
				not visit
				or not runtime
				or not room
				or not room.space.model.Parent
				or not current(player, runtime)
				or not near(player, room.space.origin, 34)
				or not getState(visit.ownerId)
			then
				return nil
			end
			return {
				actorId = player.UserId,
				ownerId = visit.ownerId,
				runtimeId = room.id,
				roomId = visit.roomId,
			}
		end,
		refresh = function(owner)
			local runtime = runtimes[owner.UserId]
			local state = getState(owner.UserId)
			if runtime and state then
				renderDoors(owner.UserId, runtime)
				for id, room in runtime.rooms do
					Template.render(room.space, state.showrooms.rooms[id])
				end
			end
		end,
		destroy = function()
			for _, connection in entrances do
				connection:Disconnect()
			end
			for id in runtimes do
				destroyRuntime(id)
			end
			table.clear(entrances)
			table.clear(lastAction)
			table.clear(registry.owners)
			table.clear(registry.visits)
			root:Destroy()
		end,
	}
end
return Gallery

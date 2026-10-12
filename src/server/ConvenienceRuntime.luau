--!strict
-- Integration adapter owns remotes/connections, never an income or purchase loop.
local Players = game:GetService("Players")
local Service = require(script.Parent.ConvenienceService)
local Wire = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local Runtime = {}
export type Controller = {
	add: (Player, Service.Owner) -> boolean,
	remove: (number) -> (),
	step: () -> (),
	refresh: (number) -> (),
	deliver: (Player, Wire.OpeningDelivery) -> (),
	beforeHandoff: (number) -> boolean,
	recover: (number) -> (),
	busy: (number) -> boolean,
	destroy: () -> (),
}
function Runtime.start(folder: Folder): Controller
	local request = Instance.new("RemoteEvent")
	request.Name, request.Parent = "ConvenienceRequest", folder
	local state = Instance.new("RemoteEvent")
	state.Name, state.Parent = "ConvenienceState", folder
	local result = Instance.new("RemoteEvent")
	result.Name, result.Parent = "ConvenienceResult", folder
	local owners: { [number]: Player } = {}
	local service = Service.create({
		now = os.clock,
		notify = function(userId: number, snapshot: Wire.Snapshot)
			local player = owners[userId]
			if player and Players:GetPlayerByUserId(userId) == player then
				state:FireClient(player, snapshot)
			end
		end,
	})
	local connection = request.OnServerEvent:Connect(function(player: Player, raw: unknown)
		if owners[player.UserId] == player then
			service.receive(player.UserId, raw)
		end
	end)
	local function remove(userId: number)
		owners[userId] = nil
		service.remove(userId)
	end
	local removing = Players.PlayerRemoving:Connect(function(player: Player)
		if owners[player.UserId] == player then
			remove(player.UserId)
		end
	end)
	local active = true
	return {
		add = function(player, owner)
			if not active or Players:GetPlayerByUserId(player.UserId) ~= player then
				return false
			end
			if not service.add(player.UserId, owner) then
				return false
			end
			owners[player.UserId] = player
			service.refresh(player.UserId)
			return true
		end,
		remove = remove,
		deliver = function(player, delivery)
			if
				active
				and owners[player.UserId] == player
				and Players:GetPlayerByUserId(player.UserId) == player
			then
				result:FireClient(player, delivery)
			end
		end,
		step = service.step,
		refresh = service.refresh,
		beforeHandoff = service.beforeHandoff,
		recover = service.recover,
		busy = service.busy,
		destroy = function()
			if not active then
				return
			end
			active = false
			connection:Disconnect()
			removing:Disconnect()
			service.destroy()
			table.clear(owners)
			request:Destroy()
			state:Destroy()
			result:Destroy()
		end,
	}
end
return Runtime

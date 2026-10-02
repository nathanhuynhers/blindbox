--!strict
-- Moves each new character of a bound player to a server-chosen CFrame (their plot's spawn pad).
-- Until a player is bound, Roblox spawns them on the plaza SpawnLocation. No client position is used.
local PlayerSpawn = {}

export type Binding = {
	player: Player,
	target: CFrame,
	connection: RBXScriptConnection?,
	pending: thread?,
	active: boolean,
}

local function cancelPending(binding: Binding)
	local pending = binding.pending
	binding.pending = nil
	if pending and coroutine.status(pending) ~= "dead" then
		task.cancel(pending)
	end
end

local function place(binding: Binding, character: Model)
	cancelPending(binding)
	binding.pending = task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if
			root
			and binding.active
			and binding.player.Character == character
			and character.Parent
		then
			character:PivotTo(binding.target)
		end
		if binding.pending == coroutine.running() then
			binding.pending = nil
		end
	end)
end

function PlayerSpawn.bind(player: Player, target: CFrame): Binding
	local binding: Binding = {
		player = player,
		target = target,
		connection = nil,
		pending = nil,
		active = true,
	}
	binding.connection = player.CharacterAdded:Connect(function(character: Model)
		place(binding, character)
	end)
	-- The first character usually spawned on the plaza while the profile was loading.
	if player.Character then
		place(binding, player.Character)
	end
	return binding
end

function PlayerSpawn.unbind(binding: Binding)
	binding.active = false
	if binding.connection then
		binding.connection:Disconnect()
		binding.connection = nil
	end
	cancelPending(binding)
end

return PlayerSpawn

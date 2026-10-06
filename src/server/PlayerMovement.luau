--!strict
local Config = require(script.Parent.MovementConfig)
local PlayerMovement = {}

export type Binding = {
	player: Player,
	active: boolean,
	character: Model?,
	humanoidAdded: RBXScriptConnection?,
	added: RBXScriptConnection?,
	removing: RBXScriptConnection?,
}

local function clearCharacter(binding: Binding)
	binding.character = nil
	if binding.humanoidAdded then
		binding.humanoidAdded:Disconnect()
		binding.humanoidAdded = nil
	end
end

local function observe(binding: Binding, character: Model)
	if not binding.active or binding.player.Character ~= character then
		return
	end
	clearCharacter(binding)
	binding.character = character
	local function apply(child: Instance)
		if
			binding.active
			and binding.humanoidAdded ~= nil
			and binding.character == character
			and binding.player.Character == character
			and child:IsA("Humanoid")
			and child.Parent == character
		then
			-- One authoritative assignment per character; future server-owned speed
			-- resolution belongs here, rather than in camera or teleport lifecycle code.
			child.WalkSpeed = Config.baselineWalkSpeed
			if binding.humanoidAdded then
				binding.humanoidAdded:Disconnect()
				binding.humanoidAdded = nil
			end
		end
	end
	-- Listen before inspecting so a late Humanoid cannot be missed. No yielding or
	-- polling; the watcher ends on success, character removal/replacement or unbind.
	binding.humanoidAdded = character.ChildAdded:Connect(apply)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		apply(humanoid)
	end
end

function PlayerMovement.bind(player: Player): Binding
	local binding: Binding = {
		player = player,
		active = true,
		character = nil,
		humanoidAdded = nil,
		added = nil,
		removing = nil,
	}
	binding.added = player.CharacterAdded:Connect(function(character: Model)
		observe(binding, character)
	end)
	binding.removing = player.CharacterRemoving:Connect(function(character: Model)
		if binding.character == character then
			clearCharacter(binding)
		end
	end)
	if player.Character then
		observe(binding, player.Character)
	end
	return binding
end

function PlayerMovement.unbind(binding: Binding)
	binding.active = false
	clearCharacter(binding)
	if binding.added then
		binding.added:Disconnect()
		binding.added = nil
	end
	if binding.removing then
		binding.removing:Disconnect()
		binding.removing = nil
	end
end

return PlayerMovement

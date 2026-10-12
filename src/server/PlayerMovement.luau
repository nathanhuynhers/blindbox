--!strict
local Config = require(script.Parent.MovementConfig)
local PlayerMovement = {}
export type Selection = { ready: boolean, owned: boolean, fresh: boolean, enabled: boolean }

export type Binding = {
	player: Player,
	active: boolean,
	character: Model?,
	humanoid: Humanoid?,
	speed: number,
	humanoidAdded: RBXScriptConnection?,
	added: RBXScriptConnection?,
	removing: RBXScriptConnection?,
}
local bindings: { [Player]: Binding } = {}

function PlayerMovement.resolve(selection: Selection): number
	return if selection.ready
			and selection.owned
			and selection.fresh
			and selection.enabled
		then Config.upgradedWalkSpeed
		else Config.baselineWalkSpeed
end

local function clearCharacter(binding: Binding)
	binding.character = nil
	binding.humanoid = nil
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
			-- Character application and entitlement refresh share this boundary;
			-- camera and teleport lifecycle code never restore an old speed.
			binding.humanoid = child
			child.WalkSpeed = binding.speed
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
	local existing = bindings[player]
	if existing then
		return existing
	end
	local binding: Binding = {
		player = player,
		active = true,
		character = nil,
		humanoid = nil,
		speed = Config.baselineWalkSpeed,
		humanoidAdded = nil,
		added = nil,
		removing = nil,
	}
	bindings[player] = binding
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

-- Called on loaded preferences, entitlement refresh and readiness/handoff changes.
function PlayerMovement.update(binding: Binding, selection: Selection)
	if not binding.active then
		return
	end
	local speed = PlayerMovement.resolve(selection)
	local changed = binding.speed ~= speed
	binding.speed = speed
	local humanoid, character = binding.humanoid, binding.character
	if
		changed
		and humanoid
		and character
		and binding.player.Character == character
		and humanoid.Parent == character
	then
		humanoid.WalkSpeed = speed
	end
end

function PlayerMovement.unbind(binding: Binding)
	if bindings[binding.player] == binding then
		bindings[binding.player] = nil
	end
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

--!strict
-- Actual server module on engine doubles; no Studio runtime is simulated.
local E = require("./OpeningEngine")
local Movement = require("./PlayerMovement")
local Config = require("./MovementConfig")
local checks = 0
local function check(value: boolean, message: string)
	checks += 1
	assert(value, message)
end
local function character()
	local model = E.Instance.new("Model")
	model.ChildAdded = E.signal()
	return model
end
local function humanoid(model)
	local value = E.Instance.new("Humanoid")
	value.WalkSpeed = 16
	value.Parent = model
	model.ChildAdded:Fire(value)
	return value
end
local player = E.player
local baseline = E.connections
player.Character = character()
local first = humanoid(player.Character)
local binding = Movement.bind(player)
check(Config.baselineWalkSpeed == 20 and table.isfrozen(Config), "single frozen playtest config")
check(first.WalkSpeed == Config.baselineWalkSpeed, "existing initial character configured immediately")
check(binding.humanoidAdded == nil and E.connections == baseline + 2, "ready character releases watcher")
first.WalkSpeed = 23
local extra = humanoid(player.Character)
check(first.WalkSpeed == 23 and extra.WalkSpeed == 16, "one assignment without continuous overwrite")

local old = player.Character
player.CharacterRemoving:Fire(old)
player.Character = character()
player.CharacterAdded:Fire(player.Character)
check(binding.humanoidAdded ~= nil, "respawn awaits late Humanoid without yielding")
local part = E.Instance.new("Part")
part.Parent = player.Character
player.Character.ChildAdded:Fire(part)
check(binding.humanoidAdded ~= nil, "unrelated child does not consume watcher")
local completed = player.Character.ChildAdded:Capture()
local second = humanoid(player.Character)
check(second.WalkSpeed == Config.baselineWalkSpeed, "respawn gets configured baseline")
second.WalkSpeed = 23
for _, callback in completed do callback(second) end
check(second.WalkSpeed == 23, "queued callback after success cannot reset a later speed")
check(E.connections == baseline + 2, "late success releases watcher")

-- Captured queued callbacks from old characters cannot affect a successor.
player.CharacterRemoving:Fire(player.Character)
player.Character = character()
player.CharacterAdded:Fire(player.Character)
local pending = player.Character
local queued = pending.ChildAdded:Capture()
player.Character = character()
player.CharacterAdded:Fire(player.Character)
local successor = player.Character
local abandoned = humanoid(pending)
for _, callback in queued do callback(abandoned) end
check(abandoned.WalkSpeed == 16, "replaced character and queued callback ignored")
player.CharacterRemoving:Fire(pending)
check(binding.character == successor, "stale removal does not clear successor")
check(E.connections == baseline + 3, "only successor watcher remains")
player.CharacterRemoving:Fire(successor)
check(binding.character == nil and E.connections == baseline + 2, "removal cleans missing-Humanoid watcher")

player.Character = nil
Movement.unbind(binding)
Movement.unbind(binding)
check(E.connections == baseline, "unbind releases player listeners idempotently")
binding = Movement.bind(player)
check(binding.character == nil, "bind before initial spawn")
player.Character = character()
player.CharacterAdded:Fire(player.Character)
local initial = humanoid(player.Character)
check(initial.WalkSpeed == Config.baselineWalkSpeed, "first CharacterAdded configured")
player.CharacterRemoving:Fire(player.Character)
player.Character = character()
player.CharacterAdded:Fire(player.Character)
queued = player.Character.ChildAdded:Capture()
local added = player.CharacterAdded:Capture()
Movement.unbind(binding)
local after = humanoid(player.Character)
for _, callback in queued do callback(after) end
for _, callback in added do callback(player.Character) end
player.CharacterAdded:Fire(player.Character)
check(after.WalkSpeed == 16, "unbind prevents late Humanoid and queued spawn mutations")
check(E.connections == baseline, "pending unbind leaves no connections")
print(string.format("PASS: %d player movement spawn/respawn/cleanup checks (engine doubles)", checks))

--!strict
-- LOGIC-03 playtest baseline, in studs/second. Tune here; no player modifiers yet.
local MovementConfig: { baselineWalkSpeed: number } = {
	baselineWalkSpeed = 20,
}

return table.freeze(MovementConfig)

--!strict
-- Baseline walk speed in studs/second (Roblox default 16). Raised from the LOGIC-03 playtest
-- value of 20 so crossing town is quick: plot to plaza ~140 studs (~4 s), plot to the opposite
-- plot ~340 studs (~9 s). Tune here; no player modifiers yet.
local MovementConfig: { baselineWalkSpeed: number } = {
	baselineWalkSpeed = 36,
}

return table.freeze(MovementConfig)

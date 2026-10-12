--!strict
-- Baseline walk speed in studs/second (Roblox default 16). Raised from the LOGIC-03 playtest
-- value of 20 so crossing town is quick: plot to plaza ~140 studs (~4 s), plot to the opposite
-- plot ~340 studs (~9 s). Approved movement pass selects 48; no additive modifiers.
local MovementConfig: { baselineWalkSpeed: number, upgradedWalkSpeed: number } = {
	baselineWalkSpeed = 36,
	upgradedWalkSpeed = 48,
}

return table.freeze(MovementConfig)

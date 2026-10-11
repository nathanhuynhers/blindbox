--!strict
-- Client clock: Idled's duration already includes the initial idle-detection delay.
local Config = require(script.Parent.AfkConfig)
export type Clock = { since: number?, eventAt: number, activeAt: number }
local Idle = {}
function Idle.threshold(): number
	return math.min(Config.idleSeconds, Config.idleLimitSeconds - Config.safetyMarginSeconds)
end
function Idle.new(now: number): Clock
	return { since = nil, eventAt = -math.huge, activeAt = now }
end
function Idle.active(clock: Clock, now: number)
	clock.since, clock.eventAt, clock.activeAt = nil, -math.huge, now
end
function Idle.report(clock: Clock, duration: number, now: number)
	if duration ~= duration or duration < 0 or duration >= math.huge then
		return
	end
	clock.since = math.max(clock.activeAt, now - duration)
	clock.eventAt = now
end
function Idle.duration(clock: Clock, now: number): number?
	local since = clock.since
	if not since or now - clock.eventAt > Config.idleFreshSeconds then
		return nil
	end
	return math.max(0, now - since)
end
return Idle

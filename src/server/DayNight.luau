--!strict
-- Server-driven ~20-minute day/night cycle through Lighting.ClockTime. Real time is spread
-- unevenly over the 24 clock hours so most of a session is daylight. An interval loop (not
-- per frame) applies interpolated looks and flips NightLights only when dusk/dawn is crossed.
local NightLights = require(script.Parent.NightLights)

export type Segment = { from: number, to: number, seconds: number }
export type Look = {
	clock: number,
	ambient: Color3,
	outdoor: Color3,
	brightness: number,
	shift: Color3,
	atmosphere: Color3,
	decay: Color3,
	density: number,
	haze: number,
}
export type Handle = { thread: thread, atmosphere: Atmosphere?, owned: boolean }

local DayNight = {}

local segments: { Segment } = {
	{ from = 6, to = 17, seconds = 600 }, -- day
	{ from = 17, to = 19.5, seconds = 180 }, -- golden hour into dusk
	{ from = 19.5, to = 29, seconds = 300 }, -- night (clock wraps past midnight)
	{ from = 29, to = 30, seconds = 120 }, -- dawn
}
local cycle = 0
for _, segment in segments do
	cycle += segment.seconds
end

DayNight.config = table.freeze({
	cycleSeconds = cycle,
	tickSeconds = 1,
	startClock = 10,
	lightsOn = 18.6,
	lightsOff = 5.6,
})

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function look(clock: number, values: Look): Look
	local copy = table.clone(values)
	copy.clock = clock
	return copy
end
local night: Look = {
	clock = 0,
	ambient = rgb(38, 42, 70),
	outdoor = rgb(84, 94, 140),
	brightness = 0.9,
	shift = rgb(120, 140, 200),
	atmosphere = rgb(70, 80, 120),
	decay = rgb(40, 46, 84),
	density = 0.36,
	haze = 0.4,
}
local dawn: Look = {
	clock = 0,
	ambient = rgb(90, 78, 92),
	outdoor = rgb(160, 135, 150),
	brightness = 1.8,
	shift = rgb(255, 196, 170),
	atmosphere = rgb(240, 206, 196),
	decay = rgb(190, 150, 165),
	density = 0.32,
	haze = 1.2,
}
local day: Look = {
	clock = 0,
	ambient = rgb(78, 78, 90),
	outdoor = rgb(150, 152, 165),
	brightness = 2.6,
	shift = rgb(255, 248, 236),
	atmosphere = rgb(200, 222, 238),
	decay = rgb(126, 166, 206),
	density = 0.27,
	haze = 0.6,
}
local golden: Look = {
	clock = 0,
	ambient = rgb(120, 88, 72),
	outdoor = rgb(178, 136, 112),
	brightness = 2.8,
	shift = rgb(255, 178, 106),
	atmosphere = rgb(255, 204, 156),
	decay = rgb(236, 148, 112),
	density = 0.32,
	haze = 1.8,
}
local dusk: Look = {
	clock = 0,
	ambient = rgb(78, 60, 88),
	outdoor = rgb(128, 100, 130),
	brightness = 1.6,
	shift = rgb(236, 138, 128),
	atmosphere = rgb(214, 152, 166),
	decay = rgb(124, 82, 124),
	density = 0.35,
	haze = 1.3,
}
-- Sorted by clock hour; sampling wraps from the last keyframe back to the first.
DayNight.looks = {
	look(0, night),
	look(5.2, night),
	look(6.3, dawn),
	look(8.5, day),
	look(16.3, day),
	look(17.6, golden),
	look(18.6, dusk),
	look(19.8, night),
}

function DayNight.clockAt(elapsed: number): number
	local t = elapsed % cycle
	for _, segment in segments do
		if t < segment.seconds then
			return (segment.from + (segment.to - segment.from) * t / segment.seconds) % 24
		end
		t -= segment.seconds
	end
	return segments[1].from
end

function DayNight.elapsedFor(clock: number): number
	local hour = clock % 24
	if hour < segments[1].from then
		hour += 24
	end
	local elapsed = 0
	for _, segment in segments do
		if hour < segment.to then
			return elapsed + (hour - segment.from) / (segment.to - segment.from) * segment.seconds
		end
		elapsed += segment.seconds
	end
	return 0
end

function DayNight.isNight(clock: number): boolean
	return clock >= DayNight.config.lightsOn or clock < DayNight.config.lightsOff
end

function DayNight.sample(clock: number): Look
	local looks = DayNight.looks
	local previous, following = looks[#looks], looks[1]
	for index, keyframe in looks do
		if keyframe.clock > clock then
			following = keyframe
			previous = looks[index - 1] or looks[#looks]
			break
		end
		previous = keyframe
		following = looks[index + 1] or looks[1]
	end
	local span = (following.clock - previous.clock) % 24
	local alpha = if span == 0 then 0 else ((clock - previous.clock) % 24) / span
	return {
		clock = clock,
		ambient = previous.ambient:Lerp(following.ambient, alpha),
		outdoor = previous.outdoor:Lerp(following.outdoor, alpha),
		brightness = previous.brightness + (following.brightness - previous.brightness) * alpha,
		shift = previous.shift:Lerp(following.shift, alpha),
		atmosphere = previous.atmosphere:Lerp(following.atmosphere, alpha),
		decay = previous.decay:Lerp(following.decay, alpha),
		density = previous.density + (following.density - previous.density) * alpha,
		haze = previous.haze + (following.haze - previous.haze) * alpha,
	}
end

local function apply(lighting: Lighting, atmosphere: Atmosphere?, clock: number)
	local current = DayNight.sample(clock)
	lighting.ClockTime = clock
	lighting.Ambient = current.ambient
	lighting.OutdoorAmbient = current.outdoor
	lighting.Brightness = current.brightness
	lighting.ColorShift_Top = current.shift
	if atmosphere then
		atmosphere.Color = current.atmosphere
		atmosphere.Decay = current.decay
		atmosphere.Density = current.density
		atmosphere.Haze = current.haze
	end
	NightLights.set(DayNight.isNight(clock))
end

function DayNight.start(lighting: Lighting): Handle
	local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
	local owned = atmosphere == nil
	if not atmosphere then
		local created = Instance.new("Atmosphere")
		created.Name = "TownAtmosphere"
		created.Offset = 0.1
		created.Glare = 0
		created.Parent = lighting
		atmosphere = created
	end
	local origin = os.clock() - DayNight.elapsedFor(DayNight.config.startClock)
	local thread = task.spawn(function()
		while true do
			apply(lighting, atmosphere, DayNight.clockAt(os.clock() - origin))
			task.wait(DayNight.config.tickSeconds)
		end
	end)
	return { thread = thread, atmosphere = atmosphere, owned = owned }
end

function DayNight.stop(handle: Handle)
	if coroutine.status(handle.thread) ~= "dead" then
		task.cancel(handle.thread)
	end
	if handle.owned and handle.atmosphere then
		handle.atmosphere:Destroy()
	end
end

return DayNight

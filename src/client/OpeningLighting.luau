--!strict
-- While the opening camera owns the view, the local Lighting shows the town's daytime look so
-- the toy has a stable ambient base across time of day and device quality. Stage lights and
-- an unobstructed model area are also required: the compact scrim previously tinted the toy.
-- The server's day/night writes that replicate meanwhile are
-- remembered and put back on release, so the world never keeps the studio look.
local Lighting = game:GetService("Lighting")
local OpeningLighting = {}
type Look = {
	ambient: Color3,
	outdoor: Color3,
	brightness: number,
	shift: Color3,
	clock: number,
}
-- Mirrors the server's DayNight daytime keyframe.
OpeningLighting.look = table.freeze({
	ambient = Color3.fromRGB(78, 78, 90),
	outdoor = Color3.fromRGB(150, 152, 165),
	brightness = 2.6,
	shift = Color3.fromRGB(255, 248, 236),
	clock = 13,
}) :: Look

local function read(): Look
	return {
		ambient = Lighting.Ambient,
		outdoor = Lighting.OutdoorAmbient,
		brightness = Lighting.Brightness,
		shift = Lighting.ColorShift_Top,
		clock = Lighting.ClockTime,
	}
end
local function write(look: Look)
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoor
	Lighting.Brightness = look.brightness
	Lighting.ColorShift_Top = look.shift
	Lighting.ClockTime = look.clock
end

-- Returns the release function; calling it more than once is harmless.
function OpeningLighting.hold(): () -> ()
	local studio = OpeningLighting.look
	local saved = read()
	write(studio)
	-- Anything that differs from the studio look was written by someone else (the server's
	-- day/night clock): keep it as the value to restore, then reassert the studio look.
	local changed = Lighting.Changed:Connect(function()
		local now = read()
		saved = {
			ambient = if now.ambient ~= studio.ambient then now.ambient else saved.ambient,
			outdoor = if now.outdoor ~= studio.outdoor then now.outdoor else saved.outdoor,
			brightness = if now.brightness ~= studio.brightness
				then now.brightness
				else saved.brightness,
			shift = if now.shift ~= studio.shift then now.shift else saved.shift,
			clock = if now.clock ~= studio.clock then now.clock else saved.clock,
		}
		write(studio)
	end)
	local released = false
	return function()
		if released then
			return
		end
		released = true
		changed:Disconnect()
		write(saved)
	end
end

return OpeningLighting

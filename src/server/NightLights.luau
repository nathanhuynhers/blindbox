--!strict
-- Bounded registry of dusk-to-dawn lights. Fixtures register a light and/or a glowing lens;
-- DayNight switches all of them only when the day/night state changes (never per frame).
local Layout = require(script.Parent.TownLayout)

export type Entry = {
	light: Light?,
	lens: BasePart?,
	change: ((boolean) -> ())?,
	dayColor: Color3,
	nightColor: Color3,
	dayMaterial: Enum.Material,
}

local NightLights = {}
NightLights.budget = Layout.budgets.nightLights

local entries: { [Entry]: true } = {}
local lights = 0
local controllers = 0
local on = false

local function apply(entry: Entry)
	if entry.change then
		entry.change(on)
	end
	if entry.light then
		entry.light.Enabled = on
	end
	local lens = entry.lens
	if lens then
		lens.Material = if on then Enum.Material.Neon else entry.dayMaterial
		lens.Color = if on then entry.nightColor else entry.dayColor
	end
end

-- Lights beyond the budget are destroyed and only the lens glow is kept, so the scene stays bounded.
function NightLights.add(light: Light?, lens: BasePart?, nightColor: Color3?): Entry
	local kept = light
	if kept then
		if lights >= NightLights.budget then
			warn("NightLights budget reached; dropping light", kept.Name)
			kept:Destroy()
			kept = nil
		else
			lights += 1
			kept.Shadows = false
		end
	end
	local entry: Entry = {
		light = kept,
		lens = lens,
		change = nil,
		dayColor = if lens then lens.Color else Color3.new(1, 1, 1),
		nightColor = nightColor or (if lens then lens.Color else Color3.new(1, 1, 1)),
		dayMaterial = if lens then lens.Material else Enum.Material.SmoothPlastic,
	}
	entries[entry] = true
	apply(entry)
	return entry
end

-- Registers fixture-level night tuning without consuming the bounded actual-light budget.
function NightLights.watch(change: (boolean) -> ()): Entry
	local entry: Entry = {
		light = nil,
		lens = nil,
		change = change,
		dayColor = Color3.new(1, 1, 1),
		nightColor = Color3.new(1, 1, 1),
		dayMaterial = Enum.Material.SmoothPlastic,
	}
	entries[entry] = true
	controllers += 1
	apply(entry)
	return entry
end

-- Idempotent; owners call this when their fixture is destroyed.
function NightLights.release(entry: Entry)
	if entries[entry] then
		entries[entry] = nil
		if entry.light then
			lights -= 1
		end
		if entry.change then
			controllers -= 1
		end
	end
end

function NightLights.set(enabled: boolean)
	if on == enabled then
		return
	end
	on = enabled
	for entry in entries do
		apply(entry)
	end
end

function NightLights.isOn(): boolean
	return on
end

function NightLights.lightCount(): number
	return lights
end

function NightLights.controllerCount(): number
	return controllers
end

return NightLights

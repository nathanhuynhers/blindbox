--!strict
-- Pure presentation samples shared by camera, comet, tail, atmosphere and audio.
local Config = require(script.Parent.OpeningConfig)
local State = require(script.Parent.OpeningState)
local Flight = {}
local settings = Config.flight
export type Sample = {
	position: Vector3,
	age: number,
	launch: number,
	dive: number,
	apex: number,
	energy: number,
	pulse: number,
	scale: number,
	color: Color3,
	accent: Color3,
	trailColor: Color3,
	sparkColor: Color3,
	atmosphereColor: Color3,
	highlight: Color3,
	waves: { number },
	hushed: boolean,
	transition: number,
}
local function smooth(p: number): number
	p = math.clamp(p, 0, 1)
	return p * p * (3 - 2 * p)
end
local function curve(a: Vector3, b: Vector3, c: Vector3, d: Vector3, p: number): Vector3
	local q = 1 - p
	return a * q ^ 3 + b * 3 * q ^ 2 * p + c * 3 * q * p ^ 2 + d * p ^ 3
end
function Flight.durations(profile: Config.Profile, reduced: boolean): (number, number, number)
	return if reduced then math.min(0.2, profile.timing.opening) else profile.timing.opening,
		if reduced then math.min(0.18, profile.timing.flight) else profile.timing.flight,
		if reduced
			then profile.timing.rarityReduced or profile.timing.rarityTease
			else profile.timing.rarityTease
end
function Flight.motion(
	profile: Config.Profile,
	reduced: boolean,
	p: number
): (number, number, number)
	local _, _, duration = Flight.durations(profile, reduced)
	local apexDuration = if reduced then settings.reducedApex else profile.flight.apex
	local diveDuration = if reduced then settings.reducedDive else profile.flight.dive
	-- Frozen future-profile beats pause path progress, including at a gold-shell interruption.
	local holdFraction =
		math.clamp(profile.teaseHold * profile.timing.rarityTease / duration, 0, 0.999)
	local activeProgress = Config.teaseMotion(profile, p, 0)
	local q = math.clamp((activeProgress - holdFraction) / (1 - holdFraction), 0, 1)
	local apexFraction = apexDuration / (apexDuration + diveDuration)
	return if holdFraction > 0 then math.clamp(activeProgress / holdFraction, 0, 1) else 1,
		math.clamp(q / apexFraction, 0, 1),
		math.clamp((q - apexFraction) / (1 - apexFraction), 0, 1)
end
function Flight.position(profile: Config.Profile, reduced: boolean, age: number): Vector3
	local opening, ascent, tease = Flight.durations(profile, reduced)
	local launchAt = settings.launchAt * opening / profile.timing.opening
	local start = Vector3.new(0, Config.stage.boxY + 1.2, 0)
	if age <= opening then
		local p = math.clamp((age - launchAt) / (opening - launchAt), 0, 1)
			^ settings.launchAcceleration
		return start:Lerp(if reduced then settings.reducedLaunch else settings.launchEnd, p)
	elseif age <= opening + ascent then
		local t = math.clamp((age - opening) / ascent, 0, 1)
		local p = t * 0.85 + t ^ settings.riseAcceleration * 0.15
		return if reduced
			then settings.reducedLaunch:Lerp(settings.reducedCrest, p)
			else curve(
				settings.launchEnd,
				settings.riseControl0,
				settings.riseControl1,
				settings.crest,
				p
			)
	end
	local hold, apex, dive =
		Flight.motion(profile, reduced, math.clamp((age - opening - ascent) / tease, 0, 1))
	local continuation = profile.flight.continuation or settings
	if reduced then
		return (settings.reducedCrest + Vector3.new(0, hold * settings.reducedHoldRise, 0)):Lerp(
			settings.landing,
			smooth(dive)
		)
	elseif apex == 0 then
		return settings.crest:Lerp(settings.holdEnd, smooth(hold))
	elseif dive == 0 then
		return curve(
			settings.holdEnd,
			continuation.apexControl0,
			continuation.apexControl1,
			continuation.diveStart,
			smooth(apex)
		)
	end
	return curve(
		continuation.diveStart,
		continuation.diveControl0,
		continuation.diveControl1,
		settings.landing,
		dive ^ settings.diveAcceleration
	)
end
function Flight.sample(state: State.State, profile: Config.Profile): Sample
	local opening, ascent, tease = Flight.durations(profile, state.reduced)
	local phase, p = state.phase, State.progress(state)
	local age = if phase == "Break"
		then p * opening
		elseif phase == "Flight" then opening + p * ascent
		elseif phase == "RarityTease" then opening + ascent + p * tease
		else opening + ascent + tease
	local launchAt = settings.launchAt * opening / profile.timing.opening
	local launch = math.clamp((age - launchAt) / (opening - launchAt), 0, 1)
	local color, accent = Config.neutral, Config.neutral
	local trailColor, sparkColor, atmosphereColor = color, color, color
	local pulse, compression, apex, dive = 0, 0, 0, 0
	local waves: { number } = {}
	local highlight, hushed, transition = Config.neutral, false, 0
	local destabilization = 0
	local energy = if phase == "Break" then launch else 0.4 + p * 0.6
	if phase == "Break" then
		local compressionAt = settings.compressionAt * opening / profile.timing.opening
		local compressed = math.clamp((age - compressionAt) / (launchAt - compressionAt), 0, 1)
		compression = compressed * (1 - smooth(launch))
	end
	if phase == "RarityTease" then
		local beat, index = Config.teaseBeat(profile, p)
		local previous = profile.tease[index - 1]
		local from = if previous then previous.color else Config.neutral
		local fromAccent = if previous then previous.secondary else Config.neutral
		local nextBeat = profile.tease[index + 1]
		local duration = math.min(
			profile.flight.transition,
			((if nextBeat then nextBeat.at else 1) - beat.at) * tease
		)
		local t = math.clamp((p - beat.at) * tease / math.max(0.001, duration), 0, 1)
		transition = t
		compression = math.sin(math.clamp(t / 0.35, 0, 1) * math.pi)
		for i, wave in profile.signature.pulses do
			waves[i] = math.sin(math.clamp((t - wave.at) / wave.span, 0, 1) * math.pi)
				* wave.strength
			pulse = math.max(pulse, waves[i])
		end
		hushed = beat.quiet == true or t < profile.signature.quietUntil
		color = from:Lerp(beat.color, smooth((t - 0.22) / 0.5))
		accent = fromAccent:Lerp(
			beat.secondary,
			smooth((t - profile.signature.accentDelay) / (1 - profile.signature.accentDelay))
		)
		highlight = fromAccent:Lerp(profile.highlight, smooth((t - 0.55) / 0.45))
		trailColor = from:Lerp(beat.color, smooth((t - 0.36) / 0.52))
		sparkColor = from:Lerp(beat.color, smooth((t - 0.48) / 0.48))
		atmosphereColor = from:Lerp(beat.color, smooth((t - 0.55) / 0.45))
		local _hold
		_hold, apex, dive = Flight.motion(profile, state.reduced, p)
		energy = if hushed then 0.03 else 0.22 + dive * 0.78
		if beat.quiet then
			pulse = 0
			table.clear(waves)
		end
		if beat.destabilize then
			destabilization = math.sin((p - beat.at) * tease * 35) * 0.06
		end
	end
	return {
		highlight = highlight,
		waves = waves,
		hushed = hushed,
		transition = transition,
		position = Flight.position(profile, state.reduced, age),
		age = age,
		launch = launch,
		apex = apex,
		dive = dive,
		energy = energy,
		pulse = pulse,
		scale = 1
			- compression * profile.signature.compression
			+ pulse * profile.flight.pulse * (if state.reduced
				then settings.reducedPulseScale
				else 1)
			+ destabilization,
		color = color,
		accent = accent,
		trailColor = trailColor,
		sparkColor = sparkColor,
		atmosphereColor = atmosphereColor,
	}
end
return Flight

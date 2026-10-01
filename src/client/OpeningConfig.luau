--!strict
local State = require(script.Parent.OpeningState)
local ShopTheme = require(script.Parent.ShopTheme)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Config = {}
-- Shared deterministic path and choreography. All positions are local to the stage.
Config.flight = {
	launchDuration = 0.4,
	flightDuration = 0.85,
	apexDuration = 0.24,
	diveDuration = 0.62,
	impactDuration = 0.38,
	launchAt = 0.18,
	acquireDelay = 0.035,
	acquireDuration = 0.1,
	gatherAt = 0.06,
	compressionAt = 0.1,
	cameraSettleAt = 0.62,
	impactKickAt = 0.02,
	launchAcceleration = 2.4,
	launchEnd = Vector3.new(0.4, 7, 0.5),
	riseControl0 = Vector3.new(1, 15, 1.5),
	riseControl1 = Vector3.new(1, 20, 5),
	crest = Vector3.new(4, 22, 7),
	holdEnd = Vector3.new(5.5, 23, 8),
	apexControl0 = Vector3.new(7, 24, 9),
	apexControl1 = Vector3.new(9, 24, 7),
	diveStart = Vector3.new(8, 21, 5),
	diveControl0 = Vector3.new(7, 18, 3),
	diveControl1 = Vector3.new(1.5, 8, 0),
	landing = Vector3.new(0, 1.2, 0),
	riseAcceleration = 1.6,
	diveAcceleration = 1.7,
	fovStart = 46,
	fovDiveExtra = 3,
	pursuitStrength = 18,
	riseOffset = Vector3.new(-1.8, -2.2, -8.5),
	holdOffset = Vector3.new(-1.4, 0.2, -8),
	diveOffset = Vector3.new(-1.2, 3, -8.5),
	aimOffset = Vector3.new(-0.45, -0.35, 0),
	roll = 0.018,
	coreSize = 0.34,
	auraSize = 2.4,
	tailSegments = 7,
	tailSeconds = 0.3,
	trailLifetime = 0.4,
	streakDensity = 5,
	impactPulseAt = 0.03,
	impactRingAt = 0.05,
	impactBurstAt = 0.06,
	impactPeakAt = 0.08,
	impactCalmAt = 0.22,
	impactShakeDuration = 0.16,
	impactLight = 0.65,
	impactBloom = 0.9,
	impactFov = 2,
	reducedApex = 0.12,
	reducedDive = 0.24,
	reducedLaunch = Vector3.new(0, 4.6, 0),
	reducedCrest = Vector3.new(0.2, 4.9, 0),
	reducedHoldRise = 0.1,
	reducedAuraScale = 0.75,
	reducedPulseScale = 0.2,
}
export type TeaseBeat = {
	at: number,
	color: Color3,
	secondary: Color3,
	cue: string,
	freeze: boolean?,
	quiet: boolean?,
	shatter: boolean?,
	destabilize: boolean?,
}
export type Profile = {
	rarity: Rarity.Id,
	tint: Color3,
	accent: Color3,
	highlight: Color3,
	resultText: Color3,
	glow: Color3,
	cues: { transformation: string, impact: string, reveal: string },
	signature: {
		pulses: { { at: number, span: number, strength: number } },
		quietUntil: number,
		compression: number,
		accentDelay: number,
		trailLayers: number,
		spectral: boolean,
		spectralTiming: {
			pearlAt: number,
			bloomAt: number,
			bloomEnd: number,
			sweepAt: number,
			sweepDuration: number,
			ringDuration: number,
			innerDelay: number,
			calmAt: number,
		}?,
		transformRings: number,
		lightScale: number,
		cameraPull: number,
		holdFovDrop: number,
		ringColors: { Color3 },
	},
	timing: State.Timing,
	shake: number,
	shakeFrequency: number,
	cameraShake: number,
	fovPeak: number,
	particles: number,
	particleMultiplier: number,
	rings: number,
	trailWidth: number,
	bloom: number,
	tease: { TeaseBeat },
	teaseHold: number,
	flight: {
		transition: number,
		hold: number,
		apex: number,
		dive: number,
		auraScale: number,
		trailLength: number,
		sparkRate: number,
		pulse: number,
		continuation: {
			apexControl0: Vector3,
			apexControl1: Vector3,
			diveStart: Vector3,
			diveControl0: Vector3,
			diveControl1: Vector3,
		}?,
	},
}
export type Collection = {
	name: string,
	base: Color3,
	lid: Color3,
	ribbon: Color3,
	ink: Color3,
	accent: Color3,
	emblem: string,
	pattern: string,
	motif: string,
	ambience: string,
}
export type Packaging = Collection

local function profile(
	id: Rarity.Id,
	pacing: {
		anticipation: number,
		charge: number,
		shake: number,
		silhouette: number,
		reveal: number,
	},
	intensity: number,
	transition: number,
	hold: number
): Profile
	local settings = Config.flight
	local identity = Rarity.get(id)
	local tint, accent = identity.tint, identity.accent
	local apex, dive = settings.apexDuration, settings.diveDuration
	local timing: State.Timing = {
		anticipation = pacing.anticipation,
		charge = pacing.charge,
		shake = pacing.shake,
		silhouette = pacing.silhouette,
		reveal = pacing.reveal,
		flight = settings.flightDuration,
		opening = settings.launchDuration,
		rarityTease = transition + hold + apex + dive,
		rarityReduced = transition + hold + settings.reducedApex + settings.reducedDive,
		impact = settings.impactDuration,
	}
	return {
		rarity = id,
		tint = tint,
		accent = accent,
		highlight = identity.highlight,
		resultText = tint,
		glow = accent,
		cues = { transformation = "rarityTransformation", impact = "impact", reveal = "reveal" },
		signature = {
			pulses = { { at = 0.12, span = 0.62, strength = 1 } },
			quietUntil = 0,
			compression = 0.22,
			accentDelay = 0.16,
			trailLayers = 1,
			spectral = false,
			transformRings = if intensity >= 3 then 1 else 0,
			lightScale = 1,
			cameraPull = 0,
			holdFovDrop = 0,
			ringColors = { tint:Lerp(accent, 0.3) },
		},
		timing = timing,
		shake = 0.024 + intensity * 0.012,
		shakeFrequency = 17 + intensity * 2,
		cameraShake = 0.025 + intensity * 0.012,
		fovPeak = 58 + intensity * 3,
		particles = 8 + intensity * 4,
		particleMultiplier = 0.65 + intensity * 0.25,
		rings = intensity,
		trailWidth = 0.62 + intensity * 0.12,
		bloom = 0.16 + intensity * 0.07,
		tease = { { at = 0, color = tint, secondary = accent, cue = "rarity" .. id } },
		teaseHold = (transition + hold) / timing.rarityTease,
		flight = {
			transition = transition,
			hold = hold,
			apex = apex,
			dive = dive,
			auraScale = 1 + intensity * 0.12,
			trailLength = 6 + intensity * 0.8,
			sparkRate = 10 + intensity * 2,
			pulse = 0.2 + intensity * 0.1,
		},
	}
end
-- Presentation profiles only. No catalog probabilities or economic values.
Config.rarities = {
	Common = profile("Common", {
		anticipation = 0.22,
		charge = 0.42,
		shake = 0.38,
		silhouette = 0.35,
		reveal = 0.45,
	}, 1, 0.19, 0.25),
	Uncommon = profile("Uncommon", {
		anticipation = 0.25,
		charge = 0.5,
		shake = 0.44,
		silhouette = 0.48,
		reveal = 0.52,
	}, 2, 0.22, 0.35),
	Rare = profile("Rare", {
		anticipation = 0.28,
		charge = 0.58,
		shake = 0.5,
		silhouette = 0.65,
		reveal = 0.58,
	}, 3, 0.25, 0.55),
	Legendary = profile("Legendary", {
		anticipation = 0.28,
		charge = 0.58,
		shake = 0.5,
		silhouette = 0.8,
		reveal = 0.58,
	}, 3, 0.30, 0.70),
	Mythical = profile("Mythical", {
		anticipation = 0.28,
		charge = 0.58,
		shake = 0.5,
		silhouette = 0.95,
		reveal = 0.58,
	}, 3, 0.38, 0.90),
} :: { [string]: Profile }
-- Higher tiers change composition and rhythm while retaining Rare's particle/Bloom budgets.
local legendary, mythical = Config.rarities.Legendary, Config.rarities.Mythical
legendary.flight.auraScale, legendary.trailWidth = 1.48, 1.08
legendary.flight.trailLength, legendary.flight.pulse = 9, 0.54
legendary.rings, legendary.cameraShake = 2, 0.065
legendary.resultText = legendary.tint:Lerp(legendary.accent, 0.45)
legendary.signature = {
	pulses = { { at = 0.14, span = 0.4, strength = 1 }, { at = 0.65, span = 0.3, strength = 0.65 } },
	quietUntil = 0,
	compression = 0.28,
	accentDelay = 0.46,
	trailLayers = 2,
	spectral = false,
	transformRings = 2,
	lightScale = 1.12,
	cameraPull = 0.3,
	holdFovDrop = 2,
	ringColors = { legendary.tint, legendary.accent },
}
mythical.flight.auraScale, mythical.trailWidth = 1.52, 1.1
mythical.flight.trailLength, mythical.flight.pulse = 9.2, 0.56
mythical.rings, mythical.cameraShake, mythical.fovPeak = 2, 0.061, 68
mythical.resultText = mythical.tint:Lerp(mythical.accent, 0.4)
mythical.signature = {
	-- One bloom after a pearl suspension; the rings have their own outward cadence.
	pulses = { { at = 0.145 / 0.38, span = 1 - 0.145 / 0.38, strength = 0.75 } },
	quietUntil = 0.145 / 0.38,
	compression = 0.5,
	accentDelay = 0.38,
	trailLayers = 3,
	spectral = true,
	spectralTiming = {
		pearlAt = 0.08,
		bloomAt = 0.145,
		bloomEnd = 0.32,
		sweepAt = 0.24,
		sweepDuration = 0.42,
		ringDuration = 0.36,
		innerDelay = 0.12,
		calmAt = 0.17,
	},
	transformRings = 2,
	lightScale = 1.12,
	cameraPull = 0.5,
	holdFovDrop = 3,
	ringColors = { mythical.tint, mythical.highlight },
}
for _, data in { legendary, mythical } do
	data.cues = {
		transformation = "transform" .. data.rarity,
		impact = "impact" .. data.rarity,
		reveal = "reveal" .. data.rarity,
	}
end
for _, id in Rarity.order do
	assert(Config.rarities[id], "Missing opening rarity profile")
end

-- Packaging stays consistent with the Shop. Only ambient motion belongs to the cinematic.
Config.collectionEffects = {
	grove = { motif = "leaf", ambience = "ambienceGrove" },
	tide = { motif = "bubble", ambience = "ambienceTide" },
} :: { [string]: { motif: string, ambience: string } }
function Config.collection(id: string): Collection
	local theme = ShopTheme.get(id)
	local name = id
	for _, entry in Catalog.collections do
		if entry.id == id then
			name = entry.name
		end
	end
	local effect = Config.collectionEffects[id]
	return {
		name = name,
		base = theme.wash,
		lid = theme.primary,
		ribbon = theme.trim,
		ink = theme.ink,
		accent = theme.secondary,
		emblem = theme.emblemKey,
		pattern = theme.patternKey,
		motif = if effect then effect.motif else "mote",
		ambience = if effect then effect.ambience else "ambience",
	}
end
Config.packaging = {
	grove = Config.collection("grove"),
	tide = Config.collection("tide"),
	concept = Config.collection("concept"),
	echo = Config.collection("echo"),
}
Config.neutral = Color3.fromRGB(255, 238, 208)
Config.stage = {
	origin = Vector3.new(0, 10000, 0),
	boxHeight = 3.4,
	boxY = 2.8,
	background = Color3.fromRGB(26, 29, 35),
	floor = Color3.fromRGB(39, 42, 47),
	fov = 44,
	chargeFov = 40,
	resultFov = 36,
	reducedFov = 44,
	cameraDistance = 12.5,
	resultDistance = 10,
	revealPush = 0.45,
	portraitFit = 0.72,
}
Config.effects = {
	texture = "rbxasset://textures/particles/sparkles_main.dds",
	softTexture = "rbxasset://textures/particles/flare_main.dds",
	maxBurst = 32,
	maxRings = 4,
	orbitCount = 5,
	mobileDensity = 0.55,
	reducedDensity = 0.25,
}
-- One shared direct-light budget. Box/comet accents replace some studio illumination;
-- they no longer stack on top of three full-strength, range-32 point lights.
Config.lighting = { baseline = 1.4, peak = 1.8, range = 18 }
function Config.impactCalmAt(presentation: Profile?): number
	local spectral = if presentation then presentation.signature.spectralTiming else nil
	return if spectral then spectral.calmAt else Config.flight.impactCalmAt
end
export type LightState = { studio: number, seam: number, comet: number, bloom: number }
function Config.lightState(
	phase: State.Phase,
	progress: number,
	elapsed: number?,
	presentation: Profile?
): LightState
	local p = math.clamp(progress, 0, 1)
	local calmAt = Config.impactCalmAt(presentation)
	local spectral = if presentation then presentation.signature.spectralTiming else nil
	local seam, comet, bloom = 0, 0, 0.5
	if phase == "Enter" or phase == "Done" then
		return { studio = 0, seam = 0, comet = 0, bloom = 0 }
	elseif phase == "Charge" then
		seam = p * 0.6
	elseif phase == "Shake" or phase == "Await" then
		seam = 0.6
	elseif phase == "Break" then
		seam = (1 - p) * 0.6 + math.sin(p * math.pi) * 0.2
		comet = if p >= 0.625 then 0.5 else 0
	elseif phase == "Flight" or phase == "RarityTease" then
		comet = 0.5
		if phase == "RarityTease" and spectral then
			local age = elapsed or 0
			local bloomProgress =
				math.clamp((age - spectral.bloomAt) / (spectral.bloomEnd - spectral.bloomAt), 0, 1)
			comet = 0.12 + 0.38 * bloomProgress
			bloom = 0.2 + 0.3 * bloomProgress
		end
	elseif phase == "Impact" then
		local age = elapsed or p * Config.flight.impactDuration
		local pulse = math.clamp(
			if age < Config.flight.impactPeakAt
				then (age - Config.flight.impactPulseAt)
					/ (Config.flight.impactPeakAt - Config.flight.impactPulseAt)
				else 1 - (age - Config.flight.impactPeakAt) / (calmAt - Config.flight.impactPeakAt),
			0,
			1
		)
		comet = Config.flight.impactLight * pulse
		bloom = 0.15 + Config.flight.impactBloom * pulse
	elseif phase == "Silhouette" or phase == "Result" or phase == "Closing" then
		bloom = 0.15
	elseif phase == "Reveal" then
		bloom = 0.15 + math.sin(p * math.pi) * 0.35
	end
	if presentation and (phase == "RarityTease" or phase == "Impact") then
		comet *= presentation.signature.lightScale
	end
	return {
		studio = if phase == "Silhouette"
				or (phase == "Impact" and (elapsed or p * Config.flight.impactDuration) >= calmAt)
			then 0.35
			else math.min(Config.lighting.baseline, Config.lighting.peak - seam - comet),
		seam = seam,
		comet = comet,
		bloom = bloom,
	}
end
-- Original/licensed sound IDs only; empty slots are silent and sequencing never waits on them.
Config.sounds = {
	entrance = "",
	ambience = "",
	ambienceGrove = "",
	ambienceTide = "",
	charge = "",
	shake = "",
	click = "",
	crack = "",
	lid = "",
	launch = "",
	flight = "",
	acceleration = "",
	rarityTransformation = "",
	dive = "",
	postImpactShimmer = "",
	rarityCommon = "",
	rarityUncommon = "",
	rarityRare = "",
	rarityLegendary = "",
	rarityMythical = "",
	transformLegendary = "",
	impactLegendary = "",
	revealLegendary = "",
	transformMythical = "",
	impactMythical = "",
	revealMythical = "",
	impact = "",
	silhouette = "",
	reveal = "",
	discovery = "",
	close = "",
} :: { [string]: string }
Config.volume = 0.45
Config.audioLimit = 8
Config.audioLifetime = 8
Config.breakCues = {
	{ at = 0.0, cue = "crack" },
	{ at = 0.08, cue = "lid" },
	{ at = Config.flight.launchAt, cue = "launch" },
}
function Config.profile(rarity: string): Profile
	return Config.rarities[rarity] or Config.rarities.Common
end
function Config.teaseBeat(profileData: Profile, progress: number): (TeaseBeat, number)
	local index = 1
	for i, beat in profileData.tease do
		if progress >= beat.at then
			index = i
		end
	end
	return profileData.tease[index], index
end
-- Integrate only moving sections: freeze beats hold position without jumping backward.
function Config.teaseMotion(profileData: Profile, progress: number, holdOverride: number?): number
	local elapsed, total = 0, 0
	for i, beat in profileData.tease do
		local finish = if profileData.tease[i + 1] then profileData.tease[i + 1].at else 1
		if not beat.freeze then
			total += finish - beat.at
			elapsed += math.clamp(progress - beat.at, 0, finish - beat.at)
		end
	end
	local activeProgress = if total > 0 then elapsed / total else 0
	local hold = holdOverride or profileData.teaseHold
	return math.clamp((activeProgress - hold) / (1 - hold), 0, 1)
end
return Config

--!strict
local State = require(script.Parent.OpeningState)
local ShopTheme = require(script.Parent.ShopTheme)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = {}
export type TeaseBeat = {
	at: number,
	color: Color3,
	secondary: Color3,
	cue: string,
	freeze: boolean?,
	quiet: boolean?,
	shatter: boolean?,
}
export type Profile = {
	tint: Color3,
	accent: Color3,
	glow: Color3,
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
	tint: Color3,
	accent: Color3,
	timing: State.Timing,
	intensity: number,
	cue: string
): Profile
	return {
		tint = tint,
		accent = accent,
		glow = accent,
		timing = timing,
		shake = 0.024 + intensity * 0.012,
		shakeFrequency = 17 + intensity * 2,
		cameraShake = 0.025 + intensity * 0.012,
		fovPeak = 58 + intensity * 3,
		particles = 8 + intensity * 4,
		particleMultiplier = 0.65 + intensity * 0.25,
		rings = intensity,
		trailWidth = 0.2 + intensity * 0.065,
		bloom = 0.16 + intensity * 0.07,
		tease = { { at = 0, color = tint, secondary = accent, cue = cue } },
		teaseHold = 0.22,
	}
end
-- Presentation profiles only. No catalog probabilities or economic values.
Config.rarities = {
	Common = profile(Color3.fromRGB(185, 222, 204), Color3.fromRGB(251, 239, 207), {
		anticipation = 0.22,
		charge = 0.42,
		shake = 0.38,
		opening = 0.32,
		flight = 0.55,
		rarityTease = 0.42,
		impact = 0.16,
		silhouette = 0.35,
		reveal = 0.45,
	}, 1, "rarityCommon"),
	Uncommon = profile(Color3.fromRGB(184, 164, 214), Color3.fromRGB(239, 220, 244), {
		anticipation = 0.25,
		charge = 0.5,
		shake = 0.44,
		opening = 0.34,
		flight = 0.6,
		rarityTease = 0.54,
		impact = 0.18,
		silhouette = 0.48,
		reveal = 0.52,
	}, 2, "rarityUncommon"),
	Rare = profile(Color3.fromRGB(231, 182, 86), Color3.fromRGB(255, 232, 180), {
		anticipation = 0.28,
		charge = 0.58,
		shake = 0.5,
		opening = 0.36,
		flight = 0.66,
		rarityTease = 0.68,
		impact = 0.2,
		silhouette = 0.65,
		reveal = 0.58,
	}, 3, "rarityRare"),
} :: { [string]: Profile }

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
Config.packaging = { grove = Config.collection("grove"), tide = Config.collection("tide") }
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
	flightHeight = 14,
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
export type LightState = { studio: number, seam: number, comet: number, bloom: number }
function Config.lightState(phase: State.Phase, progress: number): LightState
	local p = math.clamp(progress, 0, 1)
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
	elseif phase == "Impact" then
		bloom = 0.5 + 0.8 * (1 - p) ^ 2
	elseif phase == "Silhouette" or phase == "Result" or phase == "Closing" then
		bloom = 0.15
	elseif phase == "Reveal" then
		bloom = 0.15 + math.sin(p * math.pi) * 0.35
	end
	return {
		studio = math.min(Config.lighting.baseline, Config.lighting.peak - seam - comet),
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
	rarityCommon = "",
	rarityUncommon = "",
	rarityRare = "",
	impact = "",
	silhouette = "",
	reveal = "",
	discovery = "",
	close = "",
} :: { [string]: string }
Config.volume = 0.45
Config.audioLimit = 8
Config.audioLifetime = 8
Config.breakCues =
	{ { at = 0.08, cue = "crack" }, { at = 0.16, cue = "lid" }, { at = 0.2, cue = "launch" } }
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
function Config.teaseMotion(profileData: Profile, progress: number): number
	local elapsed, total = 0, 0
	for i, beat in profileData.tease do
		local finish = if profileData.tease[i + 1] then profileData.tease[i + 1].at else 1
		if not beat.freeze then
			total += finish - beat.at
			elapsed += math.clamp(progress - beat.at, 0, finish - beat.at)
		end
	end
	local activeProgress = if total > 0 then elapsed / total else 0
	return math.clamp((activeProgress - profileData.teaseHold) / (1 - profileData.teaseHold), 0, 1)
end
return Config

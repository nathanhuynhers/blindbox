--!strict
local E = require("./OpeningVisualEngine")
local Flight = require("./OpeningFlight")
local Config = require("./OpeningConfig")
local State = require("./OpeningState")
local Scope = require("./OpeningScope")
local Effects = require("./OpeningEffects")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function colorNear(a, b)
	return math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) + math.abs(a[3] - b[3]) < 0.00001
end
for _, reduced in { false, true } do
	for rarity, profile in Config.rarities do
		local state = State.create(profile.timing, reduced, false)
		local opening, ascent, tease = Flight.durations(profile, reduced)
		check(
			tease >= profile.flight.transition + profile.flight.hold,
			"rarity recognition time preserved"
		)
		for _, boundary in { opening, opening + ascent, opening + ascent + tease } do
			local before = Flight.position(profile, reduced, boundary - 0.00001)
			local after = Flight.position(profile, reduced, boundary + 0.00001)
			check((after - before).Magnitude < 0.005, "continuous path at phase boundary")
		end
		for _, phase in { "Break", "Flight", "RarityTease", "Impact", "Silhouette" } do
			state.phase, state.elapsed = phase, 0
			local duration = State.duration(state)
			for i = 0, 100 do
				state.elapsed = duration * i / 100
				local sample = Flight.sample(state, profile)
				check(sample.position.Magnitude < 40, "finite bounded stage path")
				if phase == "Break" or phase == "Flight" then
					check(colorNear(sample.color, Config.neutral), "no early rarity core")
					check(
						colorNear(sample.trailColor, Config.neutral)
							and colorNear(sample.atmosphereColor, Config.neutral),
						"no early rarity surroundings"
					)
				elseif
					phase == "RarityTease"
					and state.elapsed >= profile.flight.transition
					and state.elapsed <= profile.flight.transition + profile.flight.hold
				then
					check(
						colorNear(sample.color, profile.tint)
							and colorNear(sample.trailColor, profile.tint),
						rarity .. " recognizable complete tint"
					)
					check(sample.apex == 0 and sample.dive == 0, "hold precedes apex and dive")
				end
			end
		end
		state.phase, state.elapsed = "RarityTease", 0
		check(
			colorNear(Flight.sample(state, profile).color, Config.neutral),
			"transformation begins neutral"
		)
		state.elapsed = profile.flight.transition * 0.55
		local middle = Flight.sample(state, profile)
		check(
			not colorNear(middle.color, Config.neutral)
				and not colorNear(middle.color, profile.tint),
			"color interpolates"
		)
		check(
			not colorNear(middle.color, middle.trailColor),
			"core transforms before trailing layers"
		)
		state.elapsed = tease
		check(
			(Flight.sample(state, profile).position - Config.flight.landing).Magnitude < 0.00001,
			"comet contacts destination"
		)
		check(State.advance(state, 0) and state.phase == "Impact", "landing enters impact")
		State.advance(state, State.duration(state))
		check(
			state.phase == "Silhouette" and state.elapsed == 0,
			"impact hands off to full silhouette hold"
		)
		State.advance(state, State.duration(state) - 0.001)
		check(state.phase == "Silhouette", "identity cannot reveal during silhouette hold")
		local launchAt = Config.flight.launchAt * opening / profile.timing.opening
		local step = (opening - launchAt) / 4
		local a = Flight.position(profile, reduced, launchAt)
		local b = Flight.position(profile, reduced, launchAt + step)
		local c = Flight.position(profile, reduced, launchAt + step * 2)
		check((c - b).Magnitude > (b - a).Magnitude * 1.5, "launch accelerates")
		if not reduced then
			local diveAt = opening
				+ ascent
				+ profile.flight.transition
				+ profile.flight.hold
				+ profile.flight.apex
			local early = (Flight.position(profile, false, diveAt + 0.1) - Flight.position(
				profile,
				false,
				diveAt
			)).Magnitude
			local later = (Flight.position(profile, false, diveAt + 0.4) - Flight.position(
				profile,
				false,
				diveAt + 0.3
			)).Magnitude
			check(later > early * 2, "dive accelerates visibly")
		end
	end
end
local future = table.clone(Config.rarities.Rare)
future.tease = {
	{ at = 0, color = future.tint, secondary = future.accent, cue = "rarityRare" },
	{
		at = 0.3,
		color = future.tint,
		secondary = future.accent,
		cue = "",
		freeze = true,
		quiet = true,
	},
	{
		at = 0.5,
		color = Config.rarities.Uncommon.tint,
		secondary = future.accent,
		cue = "",
		shatter = true,
	},
}
local o, a, t = Flight.durations(future, false)
check(
	(Flight.position(future, false, o + a + t * 0.31) - Flight.position(
		future,
		false,
		o + a + t * 0.49
	)).Magnitude < 0.00001,
	"future gold interruption freezes actual path"
)
local futureState = State.create(future.timing, false, false)
futureState.phase, futureState.elapsed = "RarityTease", t * 0.4
check(
	Flight.sample(futureState, future).energy < 0.1
		and Flight.sample(futureState, future).pulse == 0,
	"quiet beat suppresses speed and pulse"
)
check(Config.rarities.Secret == nil, "no live secret rarity")

-- Exercise actual VFX allocation/retirement; no GPU output is simulated here.
for _, reduced in { false, true } do
	local scope = Scope.create()
	local parent = E.Instance.new("Model")
	local profile = Config.rarities.Rare
	local effects =
		Effects.create(parent, E.camera, scope, profile, Config.collection("tide"), reduced, false)
	local state = State.create(profile.timing, reduced, false)
	E.camera.CFrame = E.CFrame.new()
	local function draw(phase, elapsed)
		state.phase, state.elapsed = phase, elapsed
		effects.enter(phase)
		effects.update(
			state,
			E.CFrame.new(),
			Config.stage.origin + Flight.sample(state, profile).position,
			elapsed
		)
	end
	draw("Flight", 0.08)
	local core = parent:FindFirstChild("CometCore", true)
	check(core and core.Size.X >= 0.3, "readable core")
	local tail = parent:FindFirstChild("CurvedTail", true)
	check(
		tail and #tail:GetChildren() == Config.flight.tailSegments * 2 + 1,
		"bounded sampled taper"
	)
	local count = #E.nodes
	for i = 1, 60 do
		draw("Flight", i / 100)
	end
	check(#E.nodes == count, "no Instances created during frame updates")
	local streaks = 0
	for _, node in parent:GetDescendants() do
		if node.Name == "SpeedStreaks" and node.Enabled then
			streaks += 1
		end
	end
	check(
		streaks == (if reduced then 0 else 4),
		"restrained streak layers and reduced-motion suppression"
	)
	draw("RarityTease", profile.flight.transition + 0.05)
	check(colorNear(core.Color, profile.accent), "real comet transforms")
	draw("Impact", 0.08)
	check(
		not parent:FindFirstChild("FlightEffects", true) and core.destroyed and tail.destroyed,
		"all flight effects retire at contact"
	)
	check(parent:FindFirstChild("OpeningImpactLight", true).Brightness > 0, "brief contact light")
	draw("Impact", Config.flight.impactCalmAt + 0.01)
	check(
		not parent:FindFirstChild("OpeningImpactLight", true).Enabled,
		"impact light collapses before silhouette"
	)
	check(
		E.camera:FindFirstChild("OpeningBloom").Intensity <= profile.bloom * 0.15 + 0.00001,
		"bloom returns to silhouette baseline"
	)
	draw("Silhouette", 0)
	check(not parent:FindFirstChild("ImpactEffects", true), "impact family retires at silhouette")
	check(parent:FindFirstChild("SoftHalo", true).Enabled, "quiet rarity backlight remains")
	scope.destroy()
	parent:Destroy()
	check(#E.camera:GetChildren() == 0, "post effects cleaned")
end
-- Mythical's distinction is ordered contrast, including in reduced motion.
for _, reduced in { false, true } do
	local profile = Config.rarities.Mythical
	local state = State.create(profile.timing, reduced, false)
	state.phase = "RarityTease"
	local function at(elapsed)
		state.elapsed = elapsed
		return Flight.sample(state, profile)
	end
	local pearl = at(0.11)
	check(
		pearl.hushed and pearl.pulse == 0 and pearl.scale <= 0.51,
		"compressed suspension precedes the bloom"
	)
	check(
		colorNear(pearl.accent, profile.accent) and colorNear(pearl.color, Config.neutral),
		"pearl core arrives before pink body"
	)
	local bloom = at(0.24)
	check(
		not bloom.hushed and bloom.pulse > 0.6 and not colorNear(bloom.color, Config.neutral),
		"one colored bloom releases suspension"
	)
	check(
		bloom.spectralRings[1] > 0 and bloom.spectralRings[2] == 0,
		"outer response precedes inner wave"
	)
	local follow = at(0.38)
	check(
		follow.spectralRings[1] > follow.spectralRings[2] and follow.spectralRings[2] > 0,
		"staggered rings expand independently of core pulse"
	)
	check(
		follow.pulse < 0.001 and follow.spectralSweep > 0 and follow.spectralSweep < 1,
		"cyan travels into recognition after core settles"
	)
	local held = at(0.8)
	check(
		held.spectralSweep == 1 and held.recognition == 1 and held.apex == 0 and held.dive == 0,
		"stable recognition after one completed sweep"
	)
	check(
		held.spectralRings[1] == 1 and held.spectralRings[2] == 1,
		"both transformation rings finish within recognition"
	)
	local calm = Config.lightState("Impact", 0.18 / profile.timing.impact, 0.18, profile)
	local legendary =
		Config.lightState("Impact", 0.18 / profile.timing.impact, 0.18, Config.rarities.Legendary)
	check(
		calm.comet == 0 and calm.studio == 0.35 and legendary.comet > 0,
		"Mythical retires aggression sooner without changing Legendary"
	)

	local scope = Scope.create()
	local parent = E.Instance.new("Model")
	local effects =
		Effects.create(parent, E.camera, scope, profile, Config.collection("grove"), reduced, false)
	local function draw(phase, elapsed)
		state.phase, state.elapsed = phase, elapsed
		effects.enter(phase)
		effects.update(
			state,
			E.CFrame.new(),
			Config.stage.origin + Flight.sample(state, profile).position,
			elapsed
		)
	end
	draw("Flight", 0.5)
	local sparks = parent:FindFirstChild("FlightSparks", true)
	check(sparks.liveParticles > 0, "neutral launch has particles to retire")
	draw("RarityTease", 0.11)
	check(
		sparks.liveParticles == 0 and not sparks.Enabled,
		"suspense clears existing flight particles"
	)
	for _, object in parent:GetDescendants() do
		if object.Name == "SpeedStreaks" or object.Name == "DistantMotes" then
			check(
				not object.Enabled and object.liveParticles == 0,
				"surroundings are quiet during pearl beat"
			)
		end
	end
	local cyan = {}
	for _, object in parent:GetDescendants() do
		if object.Name == "IridescentEdgeTrail" then
			table.insert(cyan, object)
		end
	end
	draw("RarityTease", 0.33)
	-- Descendant enumeration has no order; the taper identifies head-to-tail segments.
	table.sort(cyan, function(left, right)
		return left.Width0 > right.Width0
	end)
	check(
		cyan[1].Enabled and cyan[1].Transparency[1] < cyan[#cyan].Transparency[1],
		"cyan starts at the comet end in both motion modes"
	)
	draw("RarityTease", 0.56)
	check(
		cyan[#cyan].Enabled and cyan[#cyan].Transparency[1] < cyan[1].Transparency[1],
		"cyan pass travels toward the tail instead of cycling all layers"
	)
	check(
		colorNear(parent:FindFirstChild("InnerGlow", true).Color, profile.tint)
			and colorNear(parent:FindFirstChild("CometCore", true).Color, profile.accent),
		"pearl core separates from pink body"
	)
	local count = #E.nodes
	for step = 1, 30 do
		draw("RarityTease", 0.56 + step * 0.02)
	end
	check(#E.nodes == count, "spectral sweep and recognition allocate no per-frame Instances")
	draw("Impact", 0.08)
	check(
		not parent:FindFirstChild("FlightEffects", true),
		"spectral trails and transform rings retire at contact"
	)
	local impact = parent:FindFirstChild("ImpactSparks", true)
	check(impact.liveParticles > 0 and impact.liveParticles <= 17, "bounded sparse impact")
	check(
		not parent:FindFirstChild("SoftHalo", true).Enabled,
		"halo waits for impact aggression to retire"
	)
	draw("Impact", 0.18)
	check(
		impact.liveParticles == 0 and not parent:FindFirstChild("OpeningImpactLight", true).Enabled,
		"spectral calm clears actual transient resources"
	)
	for _, object in parent:FindFirstChild("ImpactEffects", true):GetDescendants() do
		if object:IsA("Beam") then
			check(not object.Enabled, "impact rings absent throughout calm")
		end
	end
	draw("Silhouette", 0.2)
	check(not parent:FindFirstChild("ImpactEffects", true), "no impact family survives silhouette")
	local halo = parent:FindFirstChild("SoftHalo", true)
	check(
		halo.Enabled and colorNear(halo.Color[1], profile.accent),
		"quiet pearl backlight keeps spectral silhouette readable"
	)
	check(parent:FindFirstChild("QuietDust", true).Rate <= 2, "prestige halo uses fewer motes")
	scope.destroy()
	effects.update(state, E.CFrame.new(), E.Vector3.zero, 0)
	effects.clear()
	parent:Destroy()
	check(#E.camera:GetChildren() == 0, "spectral cleanup is idempotent and stale draws are inert")
end
print(
	"PASS: " .. checks .. " flight timing, curve, palette, reduced-motion and VFX ownership checks"
)

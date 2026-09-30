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
print(
	"PASS: " .. checks .. " flight timing, curve, palette, reduced-motion and VFX ownership checks"
)

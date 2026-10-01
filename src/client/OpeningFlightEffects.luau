--!strict
-- All objects are descendants of the existing FlightEffects retirement family.
local Config = require(script.Parent.OpeningConfig)
local State = require(script.Parent.OpeningState)
local Flight = require(script.Parent.OpeningFlight)
local FlightEffects = {}
export type Visual = { update: (State.State, Flight.Sample, Camera) -> (), shatter: () -> () }
local function part(parent: Instance, name: string, size: Vector3): Part
	local object = Instance.new("Part")
	object.Name, object.Size = name, size
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
	object.Transparency, object.CastShadow, object.Parent = 1, false, parent
	return object
end
local function particles(parent: Instance, name: string, size: number): ParticleEmitter
	local object = Instance.new("ParticleEmitter")
	object.Name, object.Texture = name, Config.effects.texture
	object.Enabled, object.Rate, object.LightEmission, object.LightInfluence = false, 0, 0.6, 0
	object.Size = NumberSequence.new(size, 0)
	object.Transparency = NumberSequence.new(0.25, 1)
	object.Lifetime, object.Speed = NumberRange.new(0.25, 0.45), NumberRange.new(2, 4)
	object.EmissionDirection, object.SpreadAngle = Enum.NormalId.Back, Vector2.new(12, 12)
	object.Parent = parent
	return object
end
function FlightEffects.create(
	parent: Folder,
	profile: Config.Profile,
	reduced: boolean,
	density: number
): Visual
	local settings = Config.flight
	local spectralTiming = profile.signature.spectralTiming
	local core = part(parent, "CometCore", Vector3.one * settings.coreSize)
	core.Material, core.Shape = Enum.Material.Neon, Enum.PartType.Ball
	local glow = part(parent, "InnerGlow", Vector3.one * settings.coreSize * 2)
	glow.Material, glow.Shape = Enum.Material.Neon, Enum.PartType.Ball
	local aura = Instance.new("BillboardGui")
	aura.Name, aura.Adornee, aura.AlwaysOnTop, aura.LightInfluence = "OuterAura", core, false, 0
	aura.Enabled, aura.Parent = false, core
	local soft = Instance.new("ImageLabel")
	soft.Name, soft.BackgroundTransparency, soft.Size = "SoftGlow", 1, UDim2.fromScale(1, 1)
	soft.Image, soft.Parent = Config.effects.softTexture, aura
	local star = Instance.new("ImageLabel")
	star.Name, star.BackgroundTransparency, star.Size = "Star", 1, UDim2.fromScale(0.62, 0.62)
	star.Position, star.Image, star.Parent =
		UDim2.fromScale(0.19, 0.19), Config.effects.texture, aura
	local spectral: ImageLabel? = nil
	if profile.signature.spectral then
		local rim = Instance.new("ImageLabel")
		rim.Name, rim.BackgroundTransparency = "SpectralRim", 1
		rim.Image, rim.Size = Config.effects.softTexture, UDim2.fromScale(1.12, 0.8)
		rim.ImageTransparency, rim.Visible, rim.Parent = 0.68, false, aura
		spectral = rim
	end
	local sparks = particles(core, "FlightSparks", 0.085)
	local secondary = particles(core, "TrailingGlints", 0.045)
	secondary.Lifetime = NumberRange.new(0.4, 0.6)
	local light = Instance.new("PointLight")
	light.Name, light.Range, light.Brightness, light.Enabled, light.Parent =
		"OpeningCometLight", 12, 0, false, core
	local left, right = Instance.new("Attachment"), Instance.new("Attachment")
	left.Parent, right.Parent = core, core
	local trail = Instance.new("Trail")
	trail.Name, trail.Attachment0, trail.Attachment1 = "CometRibbon", left, right
	trail.Lifetime, trail.MinLength, trail.FaceCamera = settings.trailLifetime, 0.03, true
	trail.Transparency, trail.WidthScale, trail.LightEmission =
		NumberSequence.new(0.6, 1), NumberSequence.new(1, 0), 0.6
	trail.Enabled, trail.Parent = false, core
	-- A sampled tapered tail remains substantial during the slow rarity hold and apex.
	-- Native Trail alone shortens to almost nothing there and clears at phase boundaries.
	local tailRoot = part(parent, "CurvedTail", Vector3.one)
	tailRoot.CFrame = CFrame.new(Config.stage.origin)
	local points: { Attachment } = {}
	local beams: { Beam } = {}
	local innerTrails: { { beam: Beam, start: Attachment, finish: Attachment, segment: number, layer: number } } =
		{}
	for i = 1, settings.tailSegments + 1 do
		local point = Instance.new("Attachment")
		point.Parent = tailRoot
		points[i] = point
		if i > 1 then
			local beam = Instance.new("Beam")
			beam.Name, beam.Attachment0, beam.Attachment1 = "TaperedTail", points[i - 1], point
			beam.FaceCamera, beam.Segments, beam.LightEmission = true, 1, 0.65
			-- A continuous ribbon avoids repeating flare sprites along the tail.
			beam.Transparency = NumberSequence.new(0.2 + (i - 2) / settings.tailSegments * 0.75)
			beam.Enabled, beam.Parent = false, tailRoot
			beams[i - 1] = beam
			for layer = 2, profile.signature.trailLayers do
				local start, finish = Instance.new("Attachment"), Instance.new("Attachment")
				start.Parent, finish.Parent = tailRoot, tailRoot
				local inner = Instance.new("Beam")
				inner.Name = if layer == 2 then "RadiantInnerTrail" else "IridescentEdgeTrail"
				inner.Attachment0, inner.Attachment1 = start, finish
				inner.FaceCamera, inner.Segments, inner.LightEmission = true, 1, 0.6
				inner.Transparency =
					NumberSequence.new(0.3 + (i - 2) / settings.tailSegments * 0.65)
				inner.Enabled, inner.Parent = false, tailRoot
				table.insert(
					innerTrails,
					{ beam = inner, start = start, finish = finish, segment = i - 1, layer = layer }
				)
			end
		end
	end
	local layers: { { mount: Part, emitter: ParticleEmitter, depth: number, side: number, speed: number } } =
		{}
	for level, depth in { 24, 13, 5 } do
		for _, side in { -1, 1 } do
			local mount = part(parent, "DepthLayer" .. level, Vector3.new(2, 8, 3))
			local emitter = particles(
				mount,
				if level == 1 then "DistantMotes" else "SpeedStreaks",
				if level == 1 then 0.08 else 0.11
			)
			emitter.Texture = Config.effects.softTexture
			emitter.EmissionDirection = Enum.NormalId.Front
			emitter.Lifetime = NumberRange.new(0.4, 0.8)
			if level > 1 then
				emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
				emitter.Squash = NumberSequence.new(5.5)
			end
			table.insert(layers, {
				mount = mount,
				emitter = emitter,
				depth = depth,
				side = side,
				speed = level * level * 3,
			})
		end
	end
	local launched = false
	local wasHushed = false
	return {
		shatter = function()
			if parent.Parent then
				sparks:Emit(
					math.min(Config.effects.maxBurst, math.floor(profile.particles * density))
				)
			end
		end,
		update = function(state, sample, camera)
			if not parent.Parent then
				return
			end
			local active = state.phase == "Flight"
				or state.phase == "RarityTease"
				or (state.phase == "Break" and sample.launch > 0)
			local gathering = state.phase == "Break" and state.elapsed >= settings.gatherAt
			local visible = active or gathering
			if sample.hushed and not wasHushed then
				-- Silence the particles already in flight as well as future emission.
				sparks:Clear()
				secondary:Clear()
				trail:Clear()
				for _, layer in layers do
					layer.emitter:Clear()
				end
			end
			wasHushed = sample.hushed
			local position = Config.stage.origin + sample.position
			local earlier = Flight.position(profile, reduced, sample.age - 0.025)
			local direction = sample.position - earlier
			if direction.Magnitude < 0.001 then
				direction = Vector3.new(0.1, 1, 0.1)
			end
			direction = direction.Unit
			core.CFrame = CFrame.lookAt(position, position + direction)
			glow.CFrame = core.CFrame
			local scale = sample.scale * (if active then 1 else 0.65)
			core.Size, glow.Size =
				Vector3.one * settings.coreSize * scale, Vector3.one * settings.coreSize * 2 * scale
			core.Color, glow.Color, light.Color = sample.accent, sample.color, sample.color
			core.Transparency, glow.Transparency =
				if visible then 0 else 1, if visible then 0.78 else 1
			local rarity = if state.phase == "RarityTease"
				then math.clamp(state.elapsed / profile.flight.transition, 0, 1)
				else 0
			local auraScale = settings.auraSize
				* (1 + (profile.flight.auraScale - 1) * rarity)
				* scale
				* (if reduced then settings.reducedAuraScale else 1)
			aura.Size, aura.Enabled = UDim2.fromScale(auraScale, auraScale), visible
			soft.ImageColor3, star.ImageColor3 = sample.color, sample.accent
			soft.ImageTransparency, star.ImageTransparency = 0.25, 0.12
			if spectralTiming then
				soft.ImageTransparency = 0.25 + sample.suspense * 0.5
			end
			if spectral then
				spectral.Visible = active and sample.spectralSweep > 0
				spectral.ImageColor3 = sample.highlight
				-- One iridescent pass, then a faint stable edge throughout recognition.
				spectral.Position = UDim2.fromScale(-0.18 + sample.spectralSweep * 0.24, 0.1)
				spectral.ImageTransparency = 0.88 - math.sin(sample.spectralSweep * math.pi) * 0.2
			end
			if profile.signature.trailLayers > 1 and not spectralTiming then
				glow.Color = sample.accent
			end
			light.Enabled, light.Brightness =
				active,
				if active
					then Config.lightState(
						state.phase,
						State.progress(state),
						state.elapsed,
						profile
					).comet
					else 0
			local width = (0.72 + (profile.trailWidth - 0.72) * rarity) * (1 + sample.dive * 0.18)
			if spectralTiming then
				width *= (1 - sample.suspense * 0.55) * (if reduced then 0.65 else 1)
			end
			left.Position, right.Position =
				Vector3.new(-width / 2, 0, 0), Vector3.new(width / 2, 0, 0)
			trail.Enabled, trail.Color =
				active and not reduced and not sample.hushed, ColorSequence.new(sample.trailColor)
			sparks.Enabled, secondary.Enabled =
				active and not sample.hushed,
				active and rarity > 0.8 and profile.rings > 1 and not reduced and not sample.hushed
			sparks.Rate, secondary.Rate =
				profile.flight.sparkRate * density * (0.4 + sample.energy * 0.6), 4 * density
			sparks.Color, secondary.Color =
				ColorSequence.new(sample.sparkColor),
				ColorSequence.new(sample.sparkColor, sample.accent)
			if active and not launched and not sample.hushed then
				launched = true
				sparks:Emit(math.max(1, math.floor(10 * density)))
			end
			local length = (6.5 + (profile.flight.trailLength - 6.5) * rarity)
				* (1 + sample.dive * 0.2)
			if spectralTiming then
				length *= (1 - sample.suspense * 0.6) * (if reduced then 0.22 else 1)
			end
			local tailVisible = active and (not reduced or (spectralTiming ~= nil and rarity > 0))
			for i, point in points do
				local q = (i - 1) / settings.tailSegments
				local past =
					Flight.position(profile, reduced, sample.age - q * settings.tailSeconds)
				local offset = past - sample.position
				-- Preserve a long taper through the hold; sampled curvature still follows the arc.
				local tail = if offset.Magnitude > 0.001 then offset.Unit else -direction
				local distance =
					math.min(length * q, math.max(offset.Magnitude, length * q * sample.launch))
				point.Position = sample.position + tail * distance
				if i > 1 then
					local beam = beams[i - 1]
					beam.Width0, beam.Width1 =
						width * (1 - (i - 2) / settings.tailSegments), width * (1 - q)
					beam.Color, beam.Enabled = ColorSequence.new(sample.trailColor), tailVisible
				end
			end
			for _, inner in innerTrails do
				local beam, index = inner.beam, inner.segment
				local side = if inner.layer == 3 then width * 0.2 else 0
				local offset = Vector3.new(side, 0, -0.02 * inner.layer)
				inner.start.Position, inner.finish.Position =
					points[index].Position + offset, points[index + 1].Position + offset
				local widthScale = if inner.layer == 2 then 0.32 else 0.13
				beam.Width0, beam.Width1 =
					beams[index].Width0 * widthScale, beams[index].Width1 * widthScale
				beam.Color =
					ColorSequence.new(if inner.layer == 2 then sample.accent else sample.highlight)
				beam.Enabled = tailVisible
					and sample.transition > (if spectralTiming then 0.18 else 0.45)
				if spectralTiming and inner.layer == 3 then
					local q = (index - 0.5) / settings.tailSegments
					local pass =
						math.max(0, 1 - math.abs(sample.spectralSweep * 1.4 - 0.2 - q) / 0.24)
					beam.Transparency = NumberSequence.new(0.9 - pass * 0.6)
					beam.Enabled = tailVisible and sample.spectralSweep > 0
				end
			end
			for _, layer in layers do
				local mountPosition = (camera.CFrame * CFrame.new(
					layer.side * layer.depth * 0.48,
					0,
					-layer.depth
				)).Position
				layer.mount.CFrame = CFrame.lookAt(mountPosition, mountPosition - direction)
				layer.emitter.Color = ColorSequence.new(sample.atmosphereColor)
				layer.emitter.Rate = settings.streakDensity
					* density
					* (0.18 + sample.energy)
					* (if layer.depth == 5 then 0.45 else 1)
				layer.emitter.Speed = NumberRange.new(
					layer.speed * (0.3 + sample.energy),
					layer.speed * (0.5 + sample.energy)
				)
				layer.emitter.Enabled = active
					and not sample.hushed
					and (not reduced or layer.depth == 24)
			end
		end,
	}
end
return FlightEffects

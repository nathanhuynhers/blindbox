--!strict
local Config = require(script.Parent.OpeningConfig)
local State = require(script.Parent.OpeningState)
local Scope = require(script.Parent.OpeningScope)
local Flight = require(script.Parent.OpeningFlight)
local FlightEffects = require(script.Parent.OpeningFlightEffects)
local Effects = {}
export type Effects = {
	update: (State.State, CFrame, Vector3, number) -> (),
	enter: (State.Phase) -> (),
	tease: (Config.TeaseBeat) -> (),
	clear: () -> (),
	suspend: () -> (),
}
type Orbit = { part: Part, beam: Beam }
type Ring = { show: (CFrame, number, Color3, number) -> () }
local function part(parent: Instance, name: string, at: CFrame, size: Vector3): Part
	local object = Instance.new("Part")
	object.Name, object.CFrame, object.Size = name, at, size
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
	object.Transparency, object.CastShadow = 1, false
	object.Parent = parent
	return object
end
local function emitter(
	parent: Instance,
	name: string,
	texture: string,
	size: number
): ParticleEmitter
	local object = Instance.new("ParticleEmitter")
	object.Name, object.Texture = name, texture
	object.Enabled, object.Rate = false, 0
	object.LightEmission, object.LightInfluence = 0.55, 0
	object.Lifetime = NumberRange.new(0.35, 0.7)
	object.Speed = NumberRange.new(0.3, 1)
	object.SpreadAngle = Vector2.new(180, 180)
	object.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.18, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	object.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	object.Color = ColorSequence.new(Config.neutral)
	object.Parent = parent
	return object
end
local function ring(parent: Instance, segments: number): Ring
	local anchor = part(parent, "LightRing", CFrame.new(), Vector3.one)
	local attachments: { Attachment } = {}
	local beams: { Beam } = {}
	for i = 1, segments do
		local attachment = Instance.new("Attachment")
		attachment.Parent = anchor
		attachments[i] = attachment
	end
	for i = 1, segments do
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = attachments[i], attachments[i % segments + 1]
		beam.Width0, beam.Width1 = 0.035, 0.035
		beam.FaceCamera, beam.LightEmission, beam.Segments = true, 0.7, 1
		beam.Enabled = false
		beam.Parent = anchor
		beams[i] = beam
	end
	local hidden = true
	return {
		show = function(at, radius, color, transparency)
			if transparency >= 1 and hidden then
				return
			end
			hidden = transparency >= 1
			anchor.CFrame = at
			for i, attachment in attachments do
				local angle = (i - 1) * math.pi * 2 / segments
				attachment.Position = Vector3.new(math.cos(angle), math.sin(angle), 0) * radius
				beams[i].Enabled = not hidden
				beams[i].Color = ColorSequence.new(color)
				beams[i].Transparency = NumberSequence.new(transparency)
			end
		end,
	}
end
function Effects.create(
	parent: Instance,
	camera: Camera,
	scope: Scope.Scope,
	profile: Config.Profile,
	collection: Config.Collection,
	reduced: boolean,
	mobile: boolean
): Effects
	local spectral = profile.signature.spectralTiming
	local calmAt = Config.impactCalmAt(profile)
	local density = (if mobile then Config.effects.mobileDensity else 1)
		* (if reduced then Config.effects.reducedDensity else 1)
	local origin = Config.stage.origin
	local root = Instance.new("Folder")
	root.Name, root.Parent = "OpeningEffects", parent
	scope.add(function()
		root:Destroy()
	end)
	local function group(name: string): Folder
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = name, root
		return folder
	end
	local boxGroup, flightGroup = group("BoxEffects"), group("FlightEffects")
	local impactGroup, revealGroup = group("ImpactEffects"), group("RevealEffects")
	local resultGroup = group("ResultEffects")
	local currentPhase: State.Phase? = nil
	local cracked = false
	local suspended = false
	local function make(
		parentObject: Instance,
		name: string,
		texture: string,
		size: number
	): ParticleEmitter
		local object = emitter(parentObject, name, texture, size)
		return object
	end
	local atmosphereAnchor = part(
		resultGroup,
		"Atmosphere",
		CFrame.new(origin + Vector3.new(0, 5, 0)),
		Vector3.new(15, 12, 10)
	)
	local dust = make(atmosphereAnchor, "QuietDust", Config.effects.softTexture, 0.055)
	dust.Lifetime, dust.Speed = NumberRange.new(2, 3), NumberRange.new(0.12, 0.3)
	dust.Color = ColorSequence.new(collection.accent)
	dust.Rate = 4 * density
	local motifAnchor =
		part(boxGroup, "CollectionAtmosphere", atmosphereAnchor.CFrame, atmosphereAnchor.Size)
	local motif = make(motifAnchor, "CollectionMotif", Config.effects.softTexture, 0.11)
	motif.Rate, motif.Lifetime = 1.8 * density, NumberRange.new(1.8, 2.5)
	motif.Color = ColorSequence.new(collection.accent)
	motif.RotSpeed = NumberRange.new(-18, 18)
	if collection.motif == "leaf" then
		motif.Texture = Config.effects.texture
		motif.Squash = NumberSequence.new(1.2)
		motif.Acceleration = Vector3.new(0.1, -0.1, 0)
	elseif collection.motif == "bubble" then
		motif.Acceleration = Vector3.new(0, 0.22, 0)
	end
	local seamAnchor = part(boxGroup, "LidSeam", CFrame.new(), Vector3.new(2.5, 0.08, 2.5))
	local seam = make(seamAnchor, "SeamMotes", Config.effects.softTexture, 0.18)
	seam.Rate, seam.Speed = 9 * density, NumberRange.new(0.2, 0.7)
	seam.EmissionDirection, seam.SpreadAngle = Enum.NormalId.Top, Vector2.new(18, 18)
	local seamLight = Instance.new("PointLight")
	seamLight.Color, seamLight.Range, seamLight.Brightness = Config.neutral, 10, 0
	seamLight.Name, seamLight.Enabled, seamLight.Parent = "OpeningSeamLight", false, seamAnchor
	local chargeAnchor = part(boxGroup, "ConvergenceShell", CFrame.new(), Vector3.new(8, 8, 8))
	local charge = make(chargeAnchor, "InwardEnergy", Config.effects.softTexture, 0.085)
	charge.Shape, charge.ShapeStyle, charge.ShapeInOut =
		Enum.ParticleEmitterShape.Sphere,
		Enum.ParticleEmitterShapeStyle.Surface,
		Enum.ParticleEmitterShapeInOut.Inward
	charge.Speed, charge.Lifetime = NumberRange.new(5, 6), NumberRange.new(0.45, 0.65)
	charge.Rate = 20 * density
	local target = Instance.new("Attachment")
	target.Parent = seamAnchor
	local orbits: { Orbit } = {}
	for _ = 1, (if reduced then 0 else Config.effects.orbitCount) do
		local mote = part(boxGroup, "GatheringMote", CFrame.new(), Vector3.one * 0.055)
		mote.Material, mote.Shape, mote.Color =
			Enum.Material.Neon, Enum.PartType.Ball, Config.neutral
		local attachment = Instance.new("Attachment")
		attachment.Parent = mote
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = attachment, target
		beam.Width0, beam.Width1 = 0.018, 0.006
		beam.FaceCamera, beam.LightEmission = true, 0.8
		beam.Color = ColorSequence.new(collection.accent, Config.neutral)
		beam.Transparency = NumberSequence.new(0.82)
		beam.CurveSize0, beam.Segments, beam.Enabled = 1.4, 12, false
		beam.Parent = mote
		table.insert(orbits, { part = mote, beam = beam })
	end
	local flight = FlightEffects.create(flightGroup, profile, reduced, density)
	local launchRing, destination = ring(flightGroup, 24), ring(flightGroup, 24)
	local transformRings: { Ring } = {}
	for _ = 1, profile.signature.transformRings do
		table.insert(transformRings, ring(flightGroup, if mobile then 16 else 24))
	end
	local impactAnchor =
		part(impactGroup, "RevealLight", CFrame.new(origin + Vector3.new(0, 1.1, 0)), Vector3.one)
	local impact = make(impactAnchor, "ImpactSparks", Config.effects.texture, 0.13)
	impact.Speed, impact.Drag, impact.Lifetime =
		NumberRange.new(4, 8), 6, NumberRange.new(0.2, 0.42)
	impact.SpreadAngle, impact.EmissionDirection = Vector2.new(85, 85), Enum.NormalId.Top
	local impactCore = make(impactAnchor, "ContactPulse", Config.effects.softTexture, 2.4)
	impactCore.Lifetime, impactCore.Speed = NumberRange.new(0.14), NumberRange.new(0)
	if spectral then
		impact.Speed, impact.Lifetime = NumberRange.new(1.5, 3.5), NumberRange.new(0.12, 0.2)
		impactCore.Size = NumberSequence.new(1.8, 0)
	end
	local impactLight = Instance.new("PointLight")
	impactLight.Name, impactLight.Range, impactLight.Enabled, impactLight.Brightness, impactLight.Parent =
		"OpeningImpactLight", 12, false, 0, impactAnchor
	local impactBurst, contactBurst = false, false
	local revealAnchor = part(revealGroup, "RevealSparkleMount", impactAnchor.CFrame, Vector3.one)
	local reveal = make(revealAnchor, "RevealSparkles", Config.effects.texture, 0.11)
	reveal.Speed, reveal.Lifetime, reveal.Acceleration =
		NumberRange.new(1, 2.6), NumberRange.new(0.45, 0.9), Vector3.new(0, -0.7, 0)
	local haloAnchor =
		part(resultGroup, "HaloGlow", CFrame.new(origin + Vector3.new(0, 2.4, 1.4)), Vector3.one)
	local halo = make(haloAnchor, "SoftHalo", Config.effects.softTexture, 6.4)
	halo.Rate, halo.Lifetime, halo.Speed, halo.LockedToPart =
		6, NumberRange.new(0.3), NumberRange.new(0), true
	halo.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	local haloRing = ring(resultGroup, if mobile then 20 else 28)
	local edgeHalo = if profile.signature.spectral or profile.signature.trailLayers > 1
		then ring(resultGroup, if mobile then 20 else 28)
		else nil
	local impactRings: { Ring } = {}
	for _ = 1, math.min(profile.rings, if reduced and not spectral then 1 else Config.effects.maxRings) do
		table.insert(impactRings, ring(impactGroup, if mobile then 16 else 24))
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Name, bloom.Threshold, bloom.Size, bloom.Intensity, bloom.Enabled =
		"OpeningBloom", 1.4, 20, 0, false
	bloom.Parent = camera
	scope.add(function()
		bloom:Destroy()
	end)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name, grade.Saturation, grade.Enabled = "OpeningGrade", -0.06, false
	grade.Parent = camera
	scope.add(function()
		grade:Destroy()
	end)
	local color = Config.neutral
	local function tint(main: Color3, accent: Color3)
		color = main
		for _, object in { impact, reveal, halo } do
			if object.Parent then
				object.Color = ColorSequence.new(main, accent)
			end
		end
		if impactCore.Parent then
			impactCore.Color = ColorSequence.new(accent)
		end
	end
	local function burst(object: ParticleEmitter, count: number)
		object:Emit(
			math.min(
				Config.effects.maxBurst,
				math.max(1, math.floor(count * density * profile.particleMultiplier))
			)
		)
	end
	-- Disable alone leaves live particles/trail segments until their lifetimes expire.
	local function clear()
		if not scope.isAlive() then
			return
		end
		for _, object in root:GetDescendants() do
			if object:IsA("ParticleEmitter") then
				object.Enabled = false
				object:Clear()
			end
			if object:IsA("Trail") then
				object.Enabled = false
				object:Clear()
			elseif object:IsA("Beam") then
				object.Enabled = false
			elseif object:IsA("Light") then
				object.Enabled, object.Brightness = false, 0
			elseif object:IsA("BasePart") then
				object.Transparency = 1
			end
			if object:IsA("BillboardGui") then
				object.Enabled = false
			end
		end
		haloRing.show(CFrame.new(), 1, color, 1)
		bloom.Intensity, bloom.Enabled, grade.Enabled = 0, false, false
		grade.Brightness, grade.Contrast = 0, 0
	end
	local function retire(folder: Folder)
		if folder.Parent then
			folder:Destroy()
		end
	end
	return {
		clear = clear,
		suspend = function()
			if suspended or not scope.isAlive() then
				return
			end
			suspended = true
			clear()
			bloom.Enabled, grade.Enabled = false, false
			haloRing.show(CFrame.new(), 1, color, 1)
		end,
		tease = function(beat)
			if not scope.isAlive() or suspended or currentPhase ~= "RarityTease" then
				return
			end
			if beat.shatter then
				flight.shatter()
			end
		end,
		enter = function(phase)
			if not scope.isAlive() or suspended or not State.isForward(currentPhase, phase) then
				return
			end
			currentPhase = phase
			clear()
			-- Families span only the beats that intentionally share their resources.
			if
				phase == "Flight"
				or phase == "RarityTease"
				or phase == "Impact"
				or phase == "Silhouette"
				or phase == "Reveal"
				or phase == "Result"
				or phase == "Closing"
				or phase == "Done"
			then
				retire(boxGroup)
			end
			if
				phase == "Impact"
				or phase == "Silhouette"
				or phase == "Reveal"
				or phase == "Result"
				or phase == "Closing"
				or phase == "Done"
			then
				retire(flightGroup)
			end
			if
				phase == "Silhouette"
				or phase == "Reveal"
				or phase == "Result"
				or phase == "Closing"
				or phase == "Done"
			then
				retire(impactGroup)
			end
			if phase == "Result" or phase == "Closing" or phase == "Done" then
				retire(revealGroup)
			end
			if phase == "Arrival" then
				burst(seam, 6)
			elseif phase == "Impact" then
				tint(profile.tint, profile.accent)
			elseif phase == "Silhouette" or phase == "Result" then
				-- Contrast: no flight/impact debris survives into the silhouette beat.
				clear()
				tint(profile.tint, profile.accent)
			elseif phase == "Reveal" then
				burst(reveal, profile.particles * (if spectral then 0.35 else 0.55))
			end
		end,
		update = function(state, boxAt, cometPosition, time)
			if not scope.isAlive() or suspended or state.phase ~= currentPhase then
				return
			end
			local phase: State.Phase = state.phase
			local p = State.progress(state)
			local lighting = Config.lightState(phase, p, state.elapsed, profile)
			local boxPhase = phase == "Arrival"
				or phase == "Anticipation"
				or phase == "Charge"
				or phase == "Shake"
				or phase == "Await"
				or phase == "Break"
			local charging = phase == "Charge" or phase == "Shake" or phase == "Await"
			local showing = phase == "Silhouette"
				or phase == "Reveal"
				or phase == "Result"
				or phase == "Closing"
			local sample = Flight.sample(state, profile)
			if phase == "RarityTease" then
				tint(sample.color, sample.accent)
			end

			bloom.Enabled, grade.Enabled = phase ~= "Enter", phase ~= "Enter"
			bloom.Intensity = (if reduced then 0.08 else profile.bloom) * lighting.bloom
			grade.Contrast = if phase == "Impact" and (not spectral or state.elapsed < calmAt)
				then (1 - p) * 0.06
				else 0
			grade.TintColor = Color3.new(1, 1, 1):Lerp(
				if showing
						or phase == "Impact"
						or phase == "RarityTease"
					then color
					else Config.neutral,
				0.035
			)
			dust.Enabled = boxPhase or showing
			if boxGroup.Parent then
				if
					phase == "Break"
					and not cracked
					and state.elapsed
						>= Config.breakTiming.crackAt * State.duration(state) / profile.timing.opening
				then
					cracked = true
					burst(seam, 8)
				end
				motif.Enabled = boxPhase and phase ~= "Break"
				seamAnchor.CFrame = boxAt * CFrame.new(0, 1.65, 0)
				chargeAnchor.CFrame = boxAt
				charge.Enabled, seam.Enabled = phase == "Charge", charging or phase == "Break"
				seamLight.Brightness, seamLight.Enabled = lighting.seam, lighting.seam > 0
				for i, orbit in orbits do
					local visible = phase == "Charge"
					orbit.part.Transparency, orbit.beam.Enabled =
						if visible then 0.15 else 1, visible
					if visible then
						local angle = time * 2.8 + i * math.pi * 2 / #orbits
						local radius = 3.5 * (1 - p) + 0.3
						orbit.part.CFrame = boxAt
							* CFrame.new(
								math.cos(angle) * radius,
								0.7 + math.sin(angle * 0.7) * radius * 0.5,
								math.sin(angle) * radius
							)
					end
				end
			end
			if flightGroup.Parent then
				flight.update(state, sample, camera)
				launchRing.show(
					CFrame.new(origin + Vector3.new(0, Config.stage.boxY + 1.2, 0))
						* CFrame.Angles(math.pi / 2, 0, 0),
					0.3 + sample.launch * 1.7,
					Config.neutral,
					if phase == "Break" and sample.launch > 0 then 0.5 + sample.launch * 0.5 else 1
				)
				for i, wave in transformRings do
					local strength = sample.waves[i] or 0
					local response = sample.spectralRings[i]
					if response then
						-- Radius only grows: a thin outer response, then a smaller cyan wave.
						wave.show(
							CFrame.lookAt(cometPosition, camera.CFrame.Position)
								* CFrame.Angles(0, if i == 2 then 0.35 else 0, 0),
							(0.5 + response * 2.1)
								* (if i == 1 then 1 else 0.7)
								* (if reduced then 0.7 else 1),
							if i == 1 then profile.tint else profile.highlight,
							if phase == "RarityTease"
								then 1 - math.sin(response * math.pi) * (if reduced
									then 0.25
									else 0.45)
								else 1
						)
						continue
					end
					wave.show(
						CFrame.new(cometPosition),
						(0.7 + (1 - strength) * 1.8) * (if i == 1 then 1 else 0.72),
						if i == 1
							then sample.color
							elseif profile.signature.spectral then sample.highlight
							else sample.accent,
						if phase == "RarityTease"
							then 1 - strength * (if reduced then 0.2 else 0.45)
							else 1
					)
				end
				destination.show(
					CFrame.new(origin + Vector3.new(0, 0.83, 0)) * CFrame.Angles(math.pi / 2, 0, 0),
					2.35,
					color,
					if sample.dive > 0.45 and phase == "RarityTease"
						then 0.8 - sample.dive * 0.16
						else 1
				)
			end
			local haloVisible = showing
				or (phase == "Impact" and (not spectral or state.elapsed >= calmAt))
			halo.Enabled = haloVisible
			local haloAlpha = if showing then 0.65 elseif haloVisible then 0.4 + p * 0.25 else 1
			if spectral and phase == "Impact" and haloVisible then
				haloAlpha = 1
					- math.clamp(
							(state.elapsed - calmAt) / (profile.timing.impact - calmAt),
							0,
							1
						)
						* 0.35
			end
			haloRing.show(
				CFrame.new(origin + Vector3.new(0, 2.45, 1.35)),
				if spectral then 2.3 else 2.05,
				color,
				haloAlpha
			)
			if edgeHalo then
				edgeHalo.show(
					CFrame.new(origin + Vector3.new(0, 2.45, 1.32))
						* CFrame.Angles(0, if spectral then 0.4 else 0, 0),
					if spectral then 1.85 else 2.17,
					if profile.signature.spectral then profile.highlight else profile.accent,
					if haloVisible
						then (if spectral then 1 - (1 - haloAlpha) * 0.5 else 0.78)
						else 1
				)
			end
			if spectral and haloVisible then
				halo.Color = ColorSequence.new(profile.accent)
				halo.Rate = 4
				dust.Rate = 2 * density
				dust.Color = ColorSequence.new(profile.accent, profile.highlight)
			end
			if impactGroup.Parent then
				local elapsed = state.elapsed
				if phase == "Impact" then
					if not contactBurst and elapsed >= Config.flight.impactPulseAt then
						contactBurst = true
						burst(impactCore, 1)
					end
					if not impactBurst and elapsed >= Config.flight.impactBurstAt then
						impactBurst = true
						burst(impact, profile.particles * (if spectral then 0.6 else 1))
					end
					impactLight.Color, impactLight.Brightness, impactLight.Enabled =
						if spectral then profile.accent else color,
						lighting.comet,
						lighting.comet > 0
					if elapsed >= calmAt then
						impact:Clear()
						impactCore:Clear()
						impactLight.Enabled, impactLight.Brightness = false, 0
					end
				end
				for i, value in impactRings do
					local start = Config.flight.impactRingAt
						+ (i - 1) * (if spectral then 0.045 else 0.025)
					local age = elapsed - start
					local progress = math.clamp(
						age / (calmAt - (if spectral then start else Config.flight.impactRingAt)),
						0,
						1
					)
					value.show(
						CFrame.new(origin + Vector3.new(0, 0.82 + i * 0.015, 0))
							* CFrame.Angles(math.pi / 2, 0, 0),
						0.35
							+ progress
								* (if spectral
									then (if i == 1 then 2.8 else 1.85)
									else 2.7 + i * 0.4),
						profile.signature.ringColors[(i - 1) % #profile.signature.ringColors + 1],
						if phase == "Impact"
								and age >= 0
								and elapsed < calmAt
							then (if spectral
								then 0.45 + progress * 0.55
								else 0.25 + progress * 0.75)
							else 1
					)
				end
			end
		end,
	}
end
return Effects

--!strict
-- Audio follows the existing presentation clock. No tasks, waits, remotes or visual ownership.
local Audio = require(script.Parent.OpeningAudio)
local Mix = require(script.Parent.OpeningAudioConfig)
local Config = require(script.Parent.OpeningConfig)
local State = require(script.Parent.OpeningState)
local Flight = require(script.Parent.OpeningFlight)
local Sequence = {}
export type Sequence = { enter: (State.State) -> (), update: (State.State) -> () }
function Sequence.create(
	audio: Audio.Audio,
	profile: Config.Profile,
	collection: Config.Collection,
	isNew: boolean
): Sequence
	local current: State.Phase? = nil
	local fired: { [string]: boolean } = {}
	local revealed, discovered = false, false
	local beatIndex, shakeIndex, lastShake = 0, 0, -math.huge
	local flightKey = if profile.signature.spectral then "flightMythical" else "flight"
	local spectral = profile.signature.spectralTiming
	local function once(
		key: string,
		at: number,
		elapsed: number,
		callback: () -> (),
		timely: boolean?
	)
		if not fired[key] and elapsed >= at then
			fired[key] = true
			-- A stalled frame may pass multiple beats; never machine-gun overdue transients.
			if not timely or elapsed - at <= Mix.lateTolerance then
				callback()
			end
		end
	end
	local function stopLayer(key: string)
		local cue = Mix.cues[key]
		audio.stop(key, if cue then cue.fadeOut else Mix.mixFade)
	end
	local function reveal()
		if not revealed then
			revealed = true
			audio.play(profile.cues.reveal)
		end
	end
	local function discovery()
		if isNew and not discovered then
			discovered = true
			audio.play("discovery")
		end
	end
	return {
		enter = function(state: State.State)
			local phase: State.Phase = state.phase
			if not State.isForward(current, phase) then
				return
			end
			current = phase
			table.clear(fired)
			if phase == "Enter" then
				audio.mix(Mix.mixes.box, 0)
				audio.play(collection.ambience)
			elseif phase == "Arrival" then
				if not state.reduced then
					audio.play("entrance")
				end
			elseif phase == "Anticipation" then
				stopLayer("entrance")
				audio.play("tension")
			elseif phase == "Charge" then
				stopLayer("tension")
				audio.play("charge")
			elseif phase == "Shake" then
				audio.modulate("charge", 1)
			elseif phase == "Await" then
				stopLayer("charge")
				audio.stop("shake")
				audio.play("await")
			elseif phase == "Break" then
				audio.stopGroup("Energy", 0)
				audio.mix(Mix.mixes.breakOpen, 0.025)
				audio.play("click")
			elseif phase == "Flight" then
				audio.stopGroup("Box", Mix.mixFade)
				stopLayer("launch")
				audio.mix(Mix.mixes.flight)
				audio.play("flight")
				audio.play("flightAir")
				if not state.reduced then
					audio.play("acceleration")
				end
			elseif phase == "RarityTease" then
				audio.stop("launch")
				audio.stop("acceleration")
				audio.mix(Mix.mixes.transform)
				if spectral then
					audio.stop()
					audio.play("mythicalInward")
				end
			elseif phase == "Impact" then
				-- Contact owns the whole mix. Flight, dive and transformation tails end here.
				audio.stop()
				audio.play(profile.cues.impact)
			elseif phase == "Silhouette" then
				audio.stopGroup("Impact")
				audio.play(if spectral then "silhouetteMythical" else "silhouette")
			elseif phase == "Reveal" then
				audio.stopGroup("Ambience", Mix.mixFade)
				audio.stop("postImpactShimmer", Mix.mixFade)
				audio.mix(Mix.mixes.reveal)
				reveal()
			elseif phase == "Result" then
				if state.skipped then
					audio.stop()
				else
					audio.stopGroup("Energy")
					audio.stopGroup("Rarity")
					audio.stopGroup("Impact")
				end
				audio.mix(Mix.mixes.result)
				audio.play("result")
				reveal()
				-- Skip lands directly on the already-visible NEW badge; no delayed callback.
				discovery()
			elseif phase == "Closing" then
				audio.stop(nil, Mix.exitFade)
				audio.play("close")
			elseif phase == "Done" then
				audio.stop()
			end
		end,
		update = function(state)
			if state.phase ~= current then
				return
			end
			local phase, elapsed, p = state.phase, state.elapsed, State.progress(state)
			if phase == "Arrival" then
				once("settle", State.duration(state) * Mix.arrivalSettleAt, elapsed, function()
					audio.play("settle", if state.reduced then 0.65 else 1)
				end, true)
			elseif phase == "Charge" then
				audio.modulate("charge", p)
			elseif phase == "Shake" and not state.reduced then
				-- Sample the actual visual sine's extrema; coalesce missed ticks to one.
				local index =
					math.floor((elapsed * profile.shakeFrequency * 2 - math.pi / 2) / math.pi)
				if
					index > shakeIndex
					and p >= Mix.shake.minProgress
					and elapsed - lastShake >= Mix.shake.spacing
				then
					shakeIndex, lastShake = index, elapsed
					audio.play(
						"shake",
						0.25 + p * p * 0.5,
						Mix.shake.speeds[index % #Mix.shake.speeds + 1]
					)
				end
			elseif phase == "Break" then
				for _, cue in Config.breakCues do
					once(
						cue.cue,
						cue.at * State.duration(state) / profile.timing.opening,
						elapsed,
						function()
							audio.play(cue.cue)
						end,
						true
					)
				end
			elseif phase == "Flight" then
				local energy = Flight.sample(state, profile).energy
				audio.modulate("flight", energy)
				audio.modulate("flightAir", energy)
			elseif phase == "RarityTease" then
				local beat, index = Config.teaseBeat(profile, p)
				local age = elapsed - beat.at * State.duration(state)
				local sample = Flight.sample(state, profile)
				if index ~= beatIndex then
					beatIndex = index
					table.clear(fired)
					if beat.quiet then
						audio.stop()
					end
				end
				if beat.quiet then
					return
				end
				local firstAt = if spectral
					then spectral.bloomAt
					elseif profile.rarity == "Legendary" then profile.signature.pulses[1].at
						* profile.flight.transition
					else 0
				if spectral then
					once("pearl", spectral.pearlAt, age, function()
						audio.play("mythicalPearl")
					end, true)
				end
				once("transform", firstAt, age, function()
					audio.play(profile.cues.transformation)
					audio.play(beat.cue)
				end, true)
				if profile.rarity == "Legendary" then
					once(
						"secondPulse",
						profile.signature.pulses[2].at * profile.flight.transition,
						age,
						function()
							audio.play("legendaryPulse")
						end,
						true
					)
				end
				once(
					"resume",
					profile.flight.transition * profile.signature.quietUntil,
					age,
					function()
						audio.play(collection.ambience)
						if flightKey ~= "flight" then
							audio.stop("flight")
						end
						audio.play(flightKey)
						audio.play("flightAir")
					end
				)
				if sample.dive > 0 then
					audio.mix(Mix.mixes.dive)
					once("dive", 0, age, function()
						audio.stopGroup("Rarity", Mix.mixFade)
						audio.play("dive")
					end)
					audio.modulate("dive", sample.dive)
				elseif sample.apex > 0 then
					audio.mix(Mix.mixes.apex)
				elseif age >= profile.flight.transition then
					audio.mix(Mix.mixes.hold)
				end
				audio.modulate(flightKey, sample.energy)
				audio.modulate("flightAir", sample.energy)
			elseif phase == "Impact" then
				once("cut", Mix.impactCutAt, elapsed, function()
					audio.stopGroup("Impact", Mix.impactFade)
				end)
				once("shimmer", Config.impactCalmAt(profile), elapsed, function()
					audio.play("postImpactShimmer")
				end, true)
			elseif phase == "Reveal" then
				once("discovery", State.duration(state) * Mix.discoveryAt, elapsed, discovery, true)
			end
		end,
	}
end
return Sequence

--!strict
-- Actual audio/sequence/controller with simulated Sound instances; no IDs leave this process.
local E = require("./OpeningVisualEngine")
local Audio = require("./OpeningAudio")
local Sequence = require("./OpeningAudioSequence")
local Mix = require("./OpeningAudioConfig")
local Config = require("./OpeningConfig")
local State = require("./OpeningState")
local Scope = require("./OpeningScope")
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local baseline = E.connections
-- Slots come only from SoundManifest.opening; the rejected synthesized pack stays disconnected.
local Manifest = require("./SoundManifest")
local AssetIds = require("./AssetIds")
local rejected = {}
for key, id in AssetIds do
	if string.sub(key, 1, 14) == "Audio.Opening." then
		rejected["rbxassetid://" .. id] = true
	end
end
local configured, filled = 0, 0
for key in Mix.cues do
	local source = Manifest.opening[key]
	local expected = if source then "rbxassetid://" .. source.id else ""
	check(Mix.sounds[key] == expected, "slot comes from the manifest: " .. key)
	check(not rejected[Mix.sounds[key]], "rejected pack stays disconnected: " .. key)
	configured += 1
	filled += if source then 1 else 0
end
for key in Manifest.opening do
	check(Mix.cues[key] ~= nil, "manifest names a real opening slot: " .. key)
end
check(configured == 48 and filled == 15, "15 of 48 opening slots are filled")
local scope = Scope.create()
local audio = Audio.create(scope)
local function folder()
	return E.services.SoundService:FindFirstChild("OpeningSounds")
end
local function sound(key)
	return folder():FindFirstChild(key)
end
for _, id in
	{ "", "123", "rbxassetid://0", "rbxassetid://-1", "rbxassetid://1x", "https://example.invalid" }
do
	Mix.sounds.crack = id
	audio.play("crack")
	check(#folder():GetChildren() == 0, "invalid/missing IDs are silent")
end
audio.play("unknown")
check(#folder():GetChildren() == 0, "unknown cue is silent")
-- Syntactically valid dummy IDs are used ONLY by the standalone engine double.
for key in Mix.sounds do
	Mix.sounds[key] = "rbxassetid://1"
end
-- Early warmup deduplicates IDs, does not play anything, and obeys controller teardown.
local preloads = 0
local originalPreload = E.services.ContentProvider.PreloadAsync
E.services.ContentProvider.PreloadAsync = function(_self, ids)
	preloads += 1
	check(#ids == 1, "warmup deduplicates configured IDs")
end
local cache = Scope.create()
Audio.preload(cache)
check(preloads == 0 and #folder():GetChildren() == 0, "warmup is deferred and silent")
E.flushTasks()
check(preloads == 1, "warmup begins before presentation")
cache.destroy()
local canceledCache = Scope.create()
Audio.preload(canceledCache)
canceledCache.destroy()
E.flushTasks(true)
check(preloads == 1, "stale warmup never starts after owner teardown")
E.services.ContentProvider.PreloadAsync = originalPreload
audio.play("charge")
check(sound("charge").SoundGroup.Name == "Reveal", "opening sounds join the Reveal group")
audio.update(0.12)
local startVolume, startPitch = sound("charge").Volume, sound("charge").PlaybackSpeed
audio.modulate("charge", 0.5)
local midpoint = sound("charge").Volume
audio.modulate("charge", 1)
check(sound("charge").Volume > midpoint and midpoint > startVolume, "charge volume evolves")
check(sound("charge").PlaybackSpeed > startPitch, "charge pitch evolves")
check(midpoint < (sound("charge").Volume + startVolume) / 2, "charge builds nonlinearly")
audio.stop()
audio.play("await")
local sustained = sound("await")
audio.play("await")
audio.update(60)
check(sound("await") == sustained, "loop is reused and survives the old eight-second limit")
audio.stop("await", 0.1)
audio.update(0.05)
check(sound("await") and sound("await").Volume < Mix.master * Mix.cues.await.volume, "loop fades")
audio.update(0.06)
check(not sound("await"), "fade finishes")
audio.play("crack")
audio.update(1)
check(not sound("crack"), "one-shot lifetime enforced")
audio.play("revealRare")
sound("revealRare").IsPlaying = false
audio.update(0.01)
check(not sound("revealRare"), "finished one-shot retired")
-- A cache miss is muted, bounded, and never allowed to become an obsolete cue.
local originalNew = E.Instance.new
E.Instance.new = function(class)
	local node = originalNew(class)
	if class == "Sound" then
		node.IsLoaded = false
	end
	return node
end
audio.play("crack")
check(sound("crack").Volume == 0, "unloaded cue starts silent")
audio.update(Mix.lateTolerance + 0.01)
check(not sound("crack"), "late one-shot discarded")
audio.play("await")
audio.update(Mix.loadTimeout + 0.01)
check(not sound("await"), "failed loop load bounded")
E.Instance.new = originalNew
for _, key in
	{
		"rarityCommon",
		"rarityUncommon",
		"rarityRare",
		"rarityLegendary",
		"rarityMythical",
		"crack",
		"impact",
		"reveal",
	}
do
	audio.play(key)
end
check(#folder():GetChildren() == Mix.limit, "voice limit reached")
audio.play("ambience")
check(not sound("ambience"), "low-priority layer cannot evict a transient")
audio.play("impactMythical")
check(
	sound("impactMythical") and #folder():GetChildren() == Mix.limit,
	"high-priority transient admitted at cap"
)
local volume = 0
for _, child in folder():GetChildren() do
	volume += child.Volume
end
check(volume <= Mix.gainBudget + 0.00001, "combined linear gain bounded")
audio.stop()
Mix.sounds.flightMythical = ""
check(
	Audio.asset("flightMythical") == Mix.sounds.flight,
	"optional transformed bed falls back explicitly"
)
scope.destroy()
audio.play("crack")
check(
	not folder() and E.connections == baseline,
	"destroy clears sounds and heartbeat; cannot restart"
)

-- Drive exact visual markers, in both choreography modes, with a recording mixer.
for _, reduced in { false, true } do
	for _, rarity in { "Common", "Uncommon", "Rare", "Legendary", "Mythical" } do
		local owner = Scope.create()
		local mixer = Audio.create(owner)
		local profile = Config.profile(rarity)
		local state = State.create(profile.timing, reduced, false)
		local log = {}
		local play = mixer.play
		mixer.play = function(key, level, speed)
			table.insert(log, { key = key, phase = state.phase, at = state.elapsed })
			play(key, level, speed)
		end
		local sequence = Sequence.create(mixer, profile, Config.collection("grove"), true)
		local function count(key)
			local n = 0
			for _, event in log do
				if event.key == key then
					n += 1
				end
			end
			return n
		end
		local function enter(phase)
			state.phase, state.elapsed = phase, 0
			sequence.enter(state)
			sequence.update(state)
		end
		local function at(age)
			local dt = age - state.elapsed
			mixer.update(dt)
			state.elapsed = age
			sequence.update(state)
		end
		enter("Enter")
		enter("Arrival")
		at(State.duration(state) * Mix.arrivalSettleAt)
		check(count("settle") == 1, "arrival grounded")
		enter("Anticipation")
		enter("Charge")
		at(State.duration(state) * 0.8)
		enter("Shake")
		for i = 1, 10 do
			at(State.duration(state) * i / 11)
		end
		check(
			count("shake") <= 3 and (not reduced or count("shake") == 0),
			"bounded tactile rhythm; no removed-motion rattles"
		)
		enter("Await")
		mixer.update(60)
		check(
			not sound("charge") and sound("await"),
			"Await stops riser and sustains quiet pressure"
		)
		enter("Break")
		check(count("click") == 1 and count("crack") == 0, "input is immediate; crack follows")
		for _, cue in Config.breakCues do
			at(cue.at * State.duration(state) / profile.timing.opening)
		end
		check(
			count("compression") == 1
				and count("crack") == 1
				and count("lid") == 1
				and count("launch") == 1,
			"break markers fire exactly once"
		)
		enter("Flight")
		enter("RarityTease")
		if rarity == "Mythical" then
			check(
				not sound("flight") and not sound("flightAir") and not sound("ambienceGrove"),
				"Mythical hush removes competing beds"
			)
			check(count("transformMythical") == 0, "no premature spectral sting")
			at(0.08)
			check(
				count("mythicalPearl") == 1 and not sound("flightMythical"),
				"pearl suspended before bloom"
			)
			at(0.145)
			check(
				count("transformMythical") == 1 and sound("flightMythical"),
				"bloom and transformed return synchronize"
			)
		elseif rarity == "Legendary" then
			at(profile.signature.pulses[1].at * profile.flight.transition)
			check(
				count("transformLegendary") == 1 and count("legendaryPulse") == 0,
				"Legendary first pulse"
			)
			at(profile.signature.pulses[2].at * profile.flight.transition)
			check(count("legendaryPulse") == 1, "Legendary visual second pulse")
		end
		check(count("rarity" .. rarity) == 1, "unique rarity identity selected")
		at(profile.flight.transition + profile.flight.hold - 0.01)
		check(count("dive") == 0, "recognition gets breathing room")
		at(State.duration(state) - 0.05)
		check(count("dive") == 1, "dive accompanies descent")
		enter("Impact")
		check(
			sound(profile.cues.impact) and not sound("dive") and not sound("flightAir"),
			"contact retires motion"
		)
		at(Mix.impactCutAt)
		at(Mix.impactCutAt + Mix.impactFade + 0.001)
		check(#folder():GetChildren() == 0, "true brief silence before shimmer")
		at(Config.impactCalmAt(profile))
		check(count("postImpactShimmer") == 1, "shimmer at visual calm boundary")
		enter("Silhouette")
		enter("Reveal")
		at(State.duration(state) * Mix.discoveryAt)
		enter("Result")
		sequence.enter(state)
		mixer.update(60)
		check(
			count(profile.cues.reveal) == 1 and count("discovery") == 1,
			"reveal and NEW exactly once"
		)
		check(
			#folder():GetChildren() == 1 and sound("result"),
			"long result contains only calm ambience"
		)
		enter("Closing")
		mixer.update(0.11)
		check(#folder():GetChildren() == 0, "exit completes inside existing curtain")
		owner.destroy()
		check(E.connections == baseline, "repeated sequence returns to baseline")
	end
end

-- Real controller integration with all cues enabled: skips, reduced render sleep, interruptions.
E.Audio = Audio
E.Cinematic = require("./OpeningCinematic")
local template = E.template()
local played = {}
local nativePlay = E.methods.Play
E.methods.Play = function(self)
	if self:IsA("Sound") then
		played[self.Name] = (played[self.Name] or 0) + 1
	end
	nativePlay(self)
end
local Controller = require("./OpeningController")
local controller = Controller.create(function() end, function(message)
	error(message)
end)
local request = 0
local function tick(dt)
	E.heartbeat:Fire(dt)
	E.render:Fire(dt)
end
local function start(reduced, fresh, rarity)
	table.clear(played)
	request += 1
	check(
		controller.present({
			requestId = "audio-" .. request,
			figureId = "grove.pebble",
			quantity = 1,
			isNew = fresh,
			direct = false,
		}, reduced, rarity),
		"controller starts"
	)
end
local function reach(phase)
	for _ = 1, 500 do
		if E.state.phase == phase then
			return
		end
		if E.state.phase == "Await" then
			E.key("A")
		else
			tick(0.025)
		end
	end
	error("Failed to reach " .. phase)
end
E.studio = true
for _, reduced in { false, true } do
	for _, phase in
		{
			"Anticipation",
			"Charge",
			"Shake",
			"Await",
			"Break",
			"Flight",
			"RarityTease",
			"Impact",
			"Silhouette",
			"Reveal",
		}
	do
		start(reduced, false, "Mythical")
		reach(phase)
		if phase == "RarityTease" then
			tick(0.1)
		end
		local stale = E.render:Capture()
		controller.skip()
		check(not played.discovery, "duplicate Skip never emits NEW")
		-- Outlast the longest reveal sting's ceiling.
		for _ = 1, math.ceil((Mix.cues.revealMythical.lifetime + 0.2) / 0.05) do
			tick(0.05)
		end
		for _, child in folder():GetChildren() do
			check(child.Name == "result", "Skip leaves only result ambience")
		end
		check(not sound("discovery"), "duplicates have no NEW layer")
		controller.cancel()
		check(not folder(), "cancel removes folder")
		start(reduced, true, "Legendary")
		for _, callback in stale do
			callback(1)
		end
		check(E.state.phase == "Enter", "old draw cannot fire cues into successor")
		controller.cancel()
	end
	start(reduced, true, "Mythical")
	reach("Await")
	for _ = 1, 600 do
		tick(0.05)
	end
	check(sound("await") and not sound("charge"), "30s Await remains safe with sleeping render")
	E.key("A")
	reach("Result")
	for _ = 1, 600 do
		tick(0.05)
	end
	check(
		sound("result") and #folder():GetChildren() == 1,
		"30s Result cleans transients with sleeping render"
	)
	E.key("A")
	tick(0.12)
	tick(0.12)
	check(not folder(), "Continue fully cleans audio")
end
for _, reduced in { false, true } do
	start(reduced, false, "Common")
	reach("Await")
	E.key("A")
	local seam = E.workspace:FindFirstChild("BlindboxCinematic"):FindFirstChild("SeamMotes", true)
	local at = Config.breakTiming.crackAt
		* State.duration(E.state)
		/ Config.profile("Common").timing.opening
	tick(at - 0.001)
	check(
		seam.liveParticles == 0 and not sound("crack"),
		"no visual or audible crack before marker"
	)
	tick(0.002)
	check(
		seam.liveParticles > 0 and sound("crack"),
		"visual seam burst and crack share scaled marker"
	)
	controller.cancel()
end
for _, interrupt in
	{
		function()
			E.humanoid.Died:Fire()
		end,
		function()
			E.player.CharacterRemoving:Fire()
		end,
		function()
			E.player.CharacterAdded:Fire()
		end,
		function()
			E.playerGui:FindFirstChild("BlindboxOpening"):Destroy()
		end,
		function()
			E.camera.CameraType = "Custom"
		end,
		function()
			controller.cancel()
		end,
	}
do
	start(false, true, "Mythical")
	reach("RarityTease")
	interrupt()
	check(not folder(), "interruption clears actual sounds")
end
-- Real stage teardown, plus ten complete audible simulations of each rarity.
start(false, true, "Mythical")
reach("Flight")
check(sound("flight") ~= nil, "actual mixer is active before stage destruction")
E.workspace:FindFirstChild("BlindboxCinematic"):Destroy()
check(not controller.isActive() and not folder(), "stage destruction clears actual audio")
for _, rarity in { "Common", "Uncommon", "Rare", "Legendary", "Mythical" } do
	for index = 1, 10 do
		start(index % 2 == 0, index % 3 == 0, rarity)
		reach("Result")
		-- Outlast the longest reveal sting's ceiling.
		for _ = 1, math.ceil((Mix.cues.revealMythical.lifetime + 0.2) / 0.025) do
			tick(0.025)
		end
		check(
			(played.discovery or 0) == (if index % 3 == 0 then 1 else 0),
			"NEW uses confirmed discovery only"
		)
		check(
			played[Config.profile(rarity).cues.reveal] == 1,
			"complete sequence reveals exactly once"
		)
		check(
			#folder():GetChildren() == 1 and sound("result"),
			"repeated openings have constant idle sound count"
		)
		E.key("A")
		tick(0.12)
		tick(0.12)
		check(
			not folder() and E.connections == baseline + 2,
			"each complete opening returns to baseline"
		)
	end
end
start(true, true, "Mythical")
reach("RarityTease")
local queuedHeartbeat = E.heartbeat:Capture()
controller.destroy()
for _, callback in queuedHeartbeat do
	callback(1)
end
check(
	not folder() and E.connections == baseline,
	"active controller destroy and stale heartbeat release all audio"
)
template:Destroy()
print(
	"PASS: "
		.. checks
		.. " opening audio behavior checks (simulated assets, not listening acceptance)"
)

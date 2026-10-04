--!strict
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Config = require(script.Parent.OpeningAudioConfig)
local Scope = require(script.Parent.OpeningScope)
local Sfx = require(script.Parent.Sfx)
local Audio = {}
type Gain = { value: number, target: number, from: number, age: number, duration: number }
type Playing = {
	sound: Sound,
	key: string,
	cue: Config.Cue,
	age: number,
	ready: boolean,
	gain: number,
	speed: number,
	progress: number,
	envelope: Gain,
	retiring: boolean,
}
export type Audio = {
	play: (string, number?, number?) -> (),
	stop: (string?, number?) -> (),
	stopGroup: (Config.Group, number?) -> (),
	mix: ({ [Config.Group]: number }, number?) -> (),
	modulate: (string, number) -> (),
	update: (number) -> (),
	destroy: () -> (),
}
local function valid(id: string?): boolean
	return id ~= nil and string.match(id, "^rbxassetid://[1-9]%d*$") ~= nil
end
-- Bounded fallback traversal; a missing/invalid entry never becomes an invented ID.
function Audio.asset(key: string): string?
	for _ = 1, 4 do
		local cue = Config.cues[key]
		if not cue then
			return nil
		end
		local id = Config.sounds[key]
		if valid(id) then
			return id
		end
		if not cue.fallback then
			return nil
		end
		key = cue.fallback
	end
	return nil
end
-- Start at controller creation so the first box has time to cache its short transients.
function Audio.preload(scope: Scope.Scope)
	-- Warm only explicitly configured, valid IDs; loading never gates the presentation clock.
	local ids: { string } = {}
	local unique: { [string]: boolean } = {}
	for key in Config.cues do
		local id = Audio.asset(key)
		if id and not unique[id] then
			unique[id] = true
			table.insert(ids, id)
		end
	end
	if #ids > 0 then
		-- One resident Sound per ID for the owner's lifetime: a live Sound keeps its asset loaded,
		-- so short cues start inside lateTolerance. ID strings do not preload audio.
		local cache = Instance.new("Folder")
		cache.Name = "OpeningSoundCache"
		cache.Parent = SoundService
		local sounds: { Sound } = {}
		for _, id in ids do
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Parent = cache
			table.insert(sounds, sound)
		end
		scope.add(function()
			cache:Destroy()
		end)
		local preload = task.defer(function()
			if not scope.isAlive() then
				return
			end
			pcall(function()
				ContentProvider:PreloadAsync(sounds)
			end)
		end)
		scope.add(function()
			if coroutine.status(preload) ~= "dead" then
				task.cancel(preload)
			end
		end)
	end
end
local function gain(value: number): Gain
	return { value = value, from = value, target = value, age = 0, duration = 0 }
end
local function target(value: Gain, nextValue: number, duration: number)
	if value.target == nextValue then
		return
	end
	value.from, value.target, value.age, value.duration = value.value, nextValue, 0, duration
	if duration <= 0 then
		value.value = nextValue
	end
end
local function step(value: Gain, delta: number)
	value.age += delta
	local p = if value.duration > 0 then math.min(1, value.age / value.duration) else 1
	value.value = value.from + (value.target - value.from) * p * p * (3 - 2 * p)
end
function Audio.create(scope: Scope.Scope): Audio
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "OpeningSounds", SoundService
	local playing: { Playing } = {}
	local groups: { [string]: Gain } = {}
	for _, group in Config.groups do
		groups[group] = gain(1)
	end
	local destroyed = false
	local heartbeat: RBXScriptConnection? = nil
	local function disconnect()
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end
	local function remove(index: number)
		playing[index].sound:Destroy()
		table.remove(playing, index)
	end
	local function retire(index: number, duration: number?)
		local entry = playing[index]
		local fade = duration or 0
		if fade <= 0 then
			remove(index)
		elseif not entry.retiring then
			entry.retiring = true
			target(entry.envelope, 0, fade)
		end
	end
	local function stop(key: string?, fade: number?)
		for i = #playing, 1, -1 do
			if not key or key == playing[i].key then
				retire(i, fade)
			end
		end
		if #playing == 0 then
			disconnect()
		end
	end
	local function update(delta: number)
		if destroyed or delta ~= delta or delta < 0 or delta == math.huge then
			return
		end
		for _, level in groups do
			step(level, delta)
		end
		local total = 0
		for i = #playing, 1, -1 do
			local entry = playing[i]
			entry.age += delta
			step(entry.envelope, delta)
			local cue, sound = entry.cue, entry.sound
			local expired = (not cue.looped and entry.age >= cue.lifetime)
				or (not entry.ready and entry.age > (if cue.looped
					then Config.loadTimeout
					else Config.lateTolerance))
				or (entry.retiring and entry.envelope.value <= 0)
				or sound.Parent ~= folder
			if expired or (entry.ready and not sound.IsPlaying) then
				remove(i)
			else
				entry.ready = entry.ready or sound.IsLoaded
				local volume, speed = 1, 1
				local curve = cue.curve
				if curve then
					volume = curve.volume[1]
						+ (curve.volume[2] - curve.volume[1])
							* entry.progress ^ curve.volumePower
					speed = curve.speed[1]
						+ (curve.speed[2] - curve.speed[1]) * entry.progress ^ curve.speedPower
				end
				sound.PlaybackSpeed = cue.speed * entry.speed * speed
				sound.Volume = if entry.ready
					then Config.master
						* cue.volume
						* entry.gain
						* volume
						* entry.envelope.value
						* groups[cue.group].value
					else 0
				total += sound.Volume
			end
		end
		if total > Config.gainBudget then
			for _, entry in playing do
				entry.sound.Volume *= Config.gainBudget / total
			end
		end
		if #playing == 0 then
			disconnect()
		end
	end
	local function destroy()
		if destroyed then
			return
		end
		destroyed = true
		stop()
		folder:Destroy()
	end
	scope.add(destroy)
	return {
		destroy = destroy,
		stop = stop,
		update = update,
		stopGroup = function(group, fade)
			for i = #playing, 1, -1 do
				if playing[i].cue.group == group then
					retire(i, fade)
				end
			end
			if #playing == 0 then
				disconnect()
			end
		end,
		mix = function(levels, fade)
			for group, level in levels do
				target(groups[group], math.clamp(level, 0, 1), fade or Config.mixFade)
			end
			update(0)
		end,
		modulate = function(key, progress)
			if progress ~= progress then
				return
			end
			for _, entry in playing do
				if entry.key == key then
					entry.progress = math.clamp(progress, 0, 1)
				end
			end
			update(0)
		end,
		play = function(key, level, speed)
			if destroyed then
				return
			end
			local cue, id = Config.cues[key], Audio.asset(key)
			if not cue or not id then
				return
			end
			for _, entry in playing do
				if entry.key == key and cue.looped and not entry.retiring then
					return -- phase-owned layers are idempotent
				end
			end
			stop(key)
			if #playing >= Config.limit then
				local victim = 1
				for i, entry in playing do
					if entry.cue.priority < playing[victim].cue.priority then
						victim = i
					end
				end
				if playing[victim].cue.priority > cue.priority then
					return
				end
				remove(victim)
			end
			local sound = Instance.new("Sound")
			sound.Name, sound.SoundId, sound.Looped, sound.Volume = key, id, cue.looped, 0
			sound:SetAttribute("AudioGroup", cue.group)
			sound.SoundGroup = Sfx.group("Reveal") -- Shares the game mix and the Sound setting.
			sound.Parent = folder -- Non-positional: consistent across camera/device layouts.
			local envelope = gain(if cue.fadeIn > 0 then 0 else 1)
			target(envelope, 1, cue.fadeIn)
			table.insert(playing, {
				sound = sound,
				key = key,
				cue = cue,
				age = 0,
				ready = sound.IsLoaded,
				gain = level or 1,
				speed = speed or 1,
				progress = 0,
				envelope = envelope,
				retiring = false,
			})
			sound:Play()
			update(0)
			if not heartbeat and #playing > 0 then
				-- Independent of the sleeping reduced-motion render clock; no delayed cues.
				heartbeat = RunService.Heartbeat:Connect(update)
			end
		end,
	}
end
return Audio

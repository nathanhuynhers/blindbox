--!strict
-- Client sound effects from SoundManifest. Presentation only: nothing waits on, reads or is
-- gated by a sound. A placeholder, unknown name or failed asset is a silent no-op: Roblox plays
-- nothing for a Sound that cannot load, so preload status is only logged.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Manifest = require(script.Parent.SoundManifest)
local Sfx = {}

local master: SoundGroup? = nil
local groups: { [string]: SoundGroup } = {}
local pools: { [string]: { Sound } } = {}
local lastPlayed: { [string]: number } = {}
local lastGroup: { [string]: number } = {}
local cursor: { [string]: number } = {}
local muted, preloaded = false, false

function Sfx.asset(id: string): string?
	return if string.match(id, "^[1-9]%d*$") then "rbxassetid://" .. id else nil
end

local function root(): SoundGroup
	local current = master
	if current and current.Parent then
		return current
	end
	local created = Instance.new("SoundGroup")
	created.Name = "Master"
	created.Volume = if muted then 0 else Manifest.master
	created.Parent = SoundService
	master = created
	table.clear(groups)
	table.clear(pools)
	return created
end

-- Master > UI / SFX / Reveal, built on first use. The opening cinematic's cues join Reveal.
function Sfx.group(name: Manifest.Group): SoundGroup
	local parent = root()
	local existing = groups[name]
	if existing then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Volume = Manifest.groups[name] or 1
	created.Parent = parent -- Nested groups multiply, so Master mutes everything.
	groups[name] = created
	return created
end

-- One pooled voice. A live Sound keeps its asset loaded, so later voices start instantly.
local function voice(name: string, entry: Manifest.Entry, id: string, pool: { Sound }): Sound
	local group = Sfx.group(entry.group)
	local created = Instance.new("Sound")
	created.Name = name
	created.SoundId = id
	created.SoundGroup = group
	created.Parent = group
	table.insert(pool, created)
	return created
end

local function poolOf(name: string): { Sound }
	local pool = pools[name]
	if not pool then
		pool = {}
		pools[name] = pool
	end
	return pool :: { Sound }
end

function Sfx.play(name: string)
	local entry = Manifest.sounds[name]
	local id = if entry then Sfx.asset(entry.id) else nil
	if muted or not entry or not id then
		return
	end
	local now = os.clock()
	if
		now - (lastPlayed[name] or -math.huge) < (entry.cooldown or 0.05)
		or now - (lastGroup[entry.group] or -math.huge) < (Manifest.gap[entry.group] or 0)
	then
		return
	end
	Sfx.group(entry.group) -- Rebuilds the groups (and drops stale pools) after a teardown.
	local pool = poolOf(name)
	local sound: Sound? = nil
	for _, candidate in pool do
		if not candidate.IsPlaying then
			sound = candidate
			break
		end
	end
	if not sound and #pool >= (entry.voices or 1) then
		-- Every voice is busy: retrigger the next one in turn instead of stacking more.
		cursor[name] = (cursor[name] or 0) % #pool + 1
		sound = pool[cursor[name]]
	end
	local playing = sound or voice(name, entry, id, pool)
	lastPlayed[name], lastGroup[entry.group] = now, now
	playing.Volume = entry.volume
	playing.PlaybackSpeed = (entry.speed or 1) * (1 + (math.random() * 2 - 1) * (entry.pitch or 0))
	playing.TimePosition = 0
	playing:Play()
end

function Sfx.muted(): boolean
	return muted
end

function Sfx.setMuted(value: boolean)
	muted = value
	root().Volume = if value then 0 else Manifest.master
end

-- Create each sound's first voice now and warm it in the background. Sound instances, not ID
-- strings: ContentProvider reports audio ID strings as failed. Failures are logged once.
function Sfx.preload()
	if preloaded then
		return
	end
	preloaded = true
	local voices: { Sound } = {}
	for name, entry in Manifest.sounds do
		local id = Sfx.asset(entry.id)
		if id then
			Sfx.group(entry.group) -- Build groups before taking a pool (a rebuild clears pools).
			local pool = poolOf(name)
			if #pool == 0 then
				table.insert(voices, voice(name, entry, id, pool))
			end
		end
	end
	if #voices == 0 then
		return
	end
	task.defer(function()
		local ok, problem = pcall(function()
			ContentProvider:PreloadAsync(
				voices,
				function(contentId: string, status: Enum.AssetFetchStatus)
					if status ~= Enum.AssetFetchStatus.Success then
						warn(`Sfx: {contentId} did not load ({tostring(status)}); it plays nothing`)
					end
				end
			)
		end)
		if not ok then
			warn("Sfx: preload failed: " .. tostring(problem))
		end
	end)
end

function Sfx.destroy()
	if master then
		master:Destroy()
		master = nil
	end
	table.clear(groups)
	table.clear(pools)
	table.clear(lastPlayed)
	table.clear(lastGroup)
	table.clear(cursor)
end

return Sfx

--!strict
-- Client sound effects from SoundManifest. Presentation only: nothing waits on, reads or is
-- gated by a sound. A placeholder, unknown name or failed asset is a silent no-op.
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
local failed: { [string]: boolean } = {}
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

function Sfx.play(name: string)
	local entry = Manifest.sounds[name]
	local id = if entry then Sfx.asset(entry.id) else nil
	if muted or not entry or not id or failed[id] then
		return
	end
	local now = os.clock()
	if
		now - (lastPlayed[name] or -math.huge) < (entry.cooldown or 0.05)
		or now - (lastGroup[entry.group] or -math.huge) < (Manifest.gap[entry.group] or 0)
	then
		return
	end
	local group = Sfx.group(entry.group)
	local pool: { Sound } = pools[name] or {}
	pools[name] = pool
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
	if not sound then
		local created = Instance.new("Sound")
		created.Name = name
		created.SoundId = id
		created.SoundGroup = group
		created.Parent = group
		table.insert(pool, created)
		sound = created
	end
	local playing = sound :: Sound
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

-- Warm the manifest once in the background. A failed asset is logged once and stays silent.
function Sfx.preload()
	if preloaded then
		return
	end
	preloaded = true
	local ids: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, entry in Manifest.sounds do
		local id = Sfx.asset(entry.id)
		if id and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		return
	end
	task.defer(function()
		local ok, problem = pcall(function()
			ContentProvider:PreloadAsync(
				ids,
				function(contentId: string, status: Enum.AssetFetchStatus)
					if status ~= Enum.AssetFetchStatus.Success and not failed[contentId] then
						failed[contentId] = true
						warn(
							`Sfx: {contentId} did not load ({tostring(status)}); it will stay silent`
						)
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

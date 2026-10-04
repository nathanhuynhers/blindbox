--!strict
-- Background music from SoundManifest.music. One looping Sound in the Music SoundGroup under the
-- Sfx Master group, so the Settings Sound switch mutes it too. Presentation only: nothing waits
-- on it, and a placeholder, unknown name or failed asset plays nothing.
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Manifest = require(script.Parent.SoundManifest)
local Sfx = require(script.Parent.Sfx)
local Music = {}

type Playing = { name: string, sound: Sound, tween: Tween? }
local current: Playing? = nil
local fading: { [Sound]: Playing } = {} -- Stopped tracks still fading out.

local function fade(entry: Playing, volume: number, seconds: number, done: (() -> ())?)
	if entry.tween then
		entry.tween:Cancel()
		entry.tween = nil
	end
	if seconds <= 0 then
		entry.sound.Volume = volume
		if done then
			done()
		end
		return
	end
	local tween = TweenService:Create(
		entry.sound,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine),
		{ Volume = volume }
	)
	entry.tween = tween
	if done then
		tween.Completed:Connect(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				done()
			end
		end)
	end
	tween:Play()
end

-- Fade the playing track out and remove it. Safe to call when nothing plays.
function Music.stop(seconds: number?)
	local entry = current
	if not entry then
		return
	end
	current = nil
	local track = Manifest.music[entry.name]
	fading[entry.sound] = entry
	fade(entry, 0, seconds or (if track then track.fadeOut else nil) or 0, function()
		fading[entry.sound] = nil
		entry.sound:Destroy()
	end)
end

-- Play a manifest entry (an area or context name). Asking for the track already playing does
-- nothing, so repeated calls never restart or stack it; another name replaces it.
function Music.play(name: string)
	if current and current.name == name and current.sound.Parent then
		return
	end
	Music.stop()
	local track = Manifest.music[name]
	local id = if track then Sfx.asset(track.id) else nil
	if not track or not id then
		return
	end
	local group = Sfx.group("Music")
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. name
	sound.SoundId = id
	sound.Looped = track.looped ~= false
	local loopEnd = track.loopEnd
	if loopEnd then
		sound.PlaybackRegionsEnabled = true
		sound.LoopRegion = NumberRange.new(0, loopEnd)
	end
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = group
	local entry: Playing = { name = name, sound = sound, tween = nil }
	current = entry
	sound:Play()
	fade(entry, track.volume, track.fadeIn or 0)
	task.defer(function()
		local ok, problem = pcall(function()
			-- A Sound instance, not the ID string: ContentProvider fails audio ID strings.
			ContentProvider:PreloadAsync({ sound }, function(contentId: string, status)
				if status ~= Enum.AssetFetchStatus.Success then
					warn(`Music: {contentId} did not load ({tostring(status)}); it plays nothing`)
				end
			end)
		end)
		if not ok then
			warn("Music: preload failed: " .. tostring(problem))
		end
	end)
end

function Music.playing(): string?
	return if current then current.name else nil
end

function Music.destroy()
	local entries = { current }
	for _, entry in fading do
		table.insert(entries, entry)
	end
	current = nil
	table.clear(fading)
	for _, entry in entries do
		if entry then
			if entry.tween then
				entry.tween:Cancel()
			end
			entry.sound:Destroy()
		end
	end
end

return Music

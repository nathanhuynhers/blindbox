--!strict
-- The real Music module on the engine double: start once, no stacking, fades, track switch,
-- placeholders, mute through Master, mix level, preload failure and teardown.
local E = require("./OpeningVisualEngine")
local tweens = {}
E.services.TweenService = {
	Create = function(_self, object, info, goal)
		local tween =
			{ object = object, info = info, goal = goal, played = false, canceled = false }
		tween.Completed = E.signal()
		function tween:Play()
			self.played = true
		end
		function tween:Cancel()
			self.canceled = true
		end
		table.insert(tweens, tween)
		return tween
	end,
}
local Manifest = require("./SoundManifest")
local Sfx = require("./Sfx")
local Music = require("./Music")
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function finish(tween)
	for key, value in tween.goal do
		tween.object[key] = value
	end
	tween.Completed:Fire(E.Enum.PlaybackState.Completed)
end
local function tracks()
	local master = E.services.SoundService:FindFirstChild("Master")
	local group = master and master:FindFirstChild("Music")
	return if group then group:GetChildren() else {}
end
-- Manifest data: every entry is a numeric ID or a placeholder, with a sane level and fades.
for name, track in Manifest.music do
	check(track.id == "" or Sfx.asset(track.id) ~= nil, "valid ID or placeholder: " .. name)
	check(track.volume > 0 and track.volume <= 1, "track volume in (0, 1]: " .. name)
	check((track.fadeIn or 0) >= 0 and (track.fadeOut or 0) >= 0, "non-negative fades: " .. name)
end
check(Manifest.music.world ~= nil, "a world track exists")
-- Mix: music sits under the effects, inside the requested 0.15-0.3 effective range.
local effective = Manifest.music.world.volume * Manifest.groups.Music * Manifest.master
check(Manifest.groups.Music < Manifest.groups.SFX, "Music group below SFX")
check(effective >= 0.15 and effective <= 0.3, "world music effective level is 0.15-0.3")
-- Unknown names and placeholders are silent no-ops.
Music.play("nowhere")
check(#tracks() == 0 and Music.playing() == nil, "unknown name plays nothing")
Manifest.music.placeholder = { id = "", source = "PLACEHOLDER", volume = 0.5 }
Music.play("placeholder")
check(#tracks() == 0 and Music.playing() == nil, "placeholder plays nothing")
Music.stop()
check(true, "stop with nothing playing is safe")
-- Start: one looping Sound in the Music group that fades in from silence.
Music.play("world")
local sound = tracks()[1]
check(#tracks() == 1 and Music.playing() == "world", "world starts")
check(sound.Looped and sound.IsPlaying and sound.Volume == 0, "looping, playing, starts silent")
check(sound.SoundGroup.Name == "Music" and sound.SoundGroup.Parent.Name == "Master", "Music group")
local fadeIn = tweens[#tweens]
check(fadeIn.goal.Volume == Manifest.music.world.volume, "fades to the track level")
check(fadeIn.info.Time == Manifest.music.world.fadeIn and fadeIn.played, "uses the fade-in time")
-- Repeated starts (respawns, repeated ready snapshots) never restart or stack it.
local made = #tweens
for _ = 1, 5 do
	Music.play("world")
end
check(#tracks() == 1 and tracks()[1] == sound and #tweens == made, "no restart, no duplicate")
-- The Sound switch mutes music through Master.
Sfx.setMuted(true)
check(sound.SoundGroup.Parent.Volume == 0, "muting Master silences music")
Sfx.setMuted(false)
-- Another context replaces it: the old track fades out and is removed, only one stays current.
Manifest.music.plaza = { id = "2", source = "test", volume = 0.6, fadeIn = 1, fadeOut = 0.5 }
Music.play("plaza")
local fadeOut = tweens[#tweens - 1]
check(fadeOut.object == sound and fadeOut.goal.Volume == 0, "old track fades out")
check(fadeOut.info.Time == Manifest.music.world.fadeOut, "uses the old track's fade-out")
check(Music.playing() == "plaza" and #tracks() == 2, "new track starts while the old fades")
finish(fadeOut)
check(sound.Parent == nil and #tracks() == 1, "faded track is removed")
-- Explicit stop with a custom fade, and a canceled fade never leaks the Sound.
Music.stop(0)
check(#tracks() == 0 and Music.playing() == nil, "stop(0) removes at once")
Music.play("world")
Music.play("plaza")
check(#tracks() == 2, "one playing, one fading")
Music.destroy()
check(#tracks() == 0 and Music.playing() == nil, "destroy removes playing and fading tracks")
-- A failed load is logged, never thrown, and the track simply plays nothing.
E.flushTasks() -- Earlier plays' preloads, under the normal stub.
local warnings = #E.warnings
E.services.ContentProvider.PreloadAsync = function(_self, list, callback)
	callback(list[1].SoundId, E.Enum.AssetFetchStatus.Failure)
end
Music.play("world")
E.flushTasks()
check(#E.warnings == warnings + 1 and Music.playing() == "world", "failed load only logs")
Music.destroy()
print(`PASS: {checks} Music manifest, start-once, fade, switch, mute, mix and teardown checks`)

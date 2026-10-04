--!strict
-- The real Sfx module on the engine double: placeholders, caps, cooldowns, groups, mute, teardown.
local E = require("./OpeningVisualEngine")
local Manifest = require("./SoundManifest")
local Sfx = require("./Sfx")
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function master()
	return E.services.SoundService:FindFirstChild("Master")
end
local function sounds(name)
	local found = {}
	for _, group in master():GetChildren() do
		for _, child in group:GetChildren() do
			if child.Name == name then
				table.insert(found, child)
			end
		end
	end
	return found
end
-- Every manifest entry is valid data: a numeric ID or a placeholder, sane levels, known group.
for name, entry in Manifest.sounds do
	check(entry.id == "" or Sfx.asset(entry.id) ~= nil, "valid ID or placeholder: " .. name)
	check(Manifest.groups[entry.group] ~= nil, "known group: " .. name)
	check(entry.volume > 0 and entry.volume <= 1, "volume in (0, 1]: " .. name)
	check((entry.pitch or 0) >= 0 and (entry.pitch or 0) < 0.5, "small pitch range: " .. name)
	check((entry.voices or 1) >= 1 and (entry.voices or 1) <= 4, "bounded voices: " .. name)
end
for key, cue in Manifest.opening do
	check(cue.id == "" or Sfx.asset(cue.id) ~= nil, "valid opening ID: " .. key)
end
-- Unknown names and placeholders are silent no-ops that build nothing.
Sfx.play("doesNotExist")
check(master() == nil, "unknown name builds nothing")
Manifest.sounds.testPlaceholder = { id = "", source = "PLACEHOLDER", group = "UI", volume = 0.5 }
Sfx.play("testPlaceholder")
check(master() == nil, "placeholder builds nothing")
for _, bad in { "0", "-1", "12a", "rbxassetid://5" } do
	check(Sfx.asset(bad) == nil, "rejects malformed ID " .. bad)
end
-- Groups nest under Master with manifest levels.
Manifest.sounds.testA = { id = "1", source = "test", group = "SFX", volume = 0.5, voices = 2 }
Sfx.play("testA")
check(master().Volume == Manifest.master, "master level")
check(master():FindFirstChild("SFX").Volume == Manifest.groups.SFX, "group level")
local first = sounds("testA")[1]
check(first.SoundGroup == master():FindFirstChild("SFX") and first.IsPlaying, "plays in its group")
-- Cooldown: a second play inside the cooldown is dropped.
Sfx.play("testA")
check(#sounds("testA") == 1, "cooldown drops a rapid repeat")
-- Voice cap: two overlapping voices, then further plays are dropped instead of stacking.
local function wait(seconds)
	local started = os.clock()
	repeat
	until os.clock() - started >= seconds
end
Manifest.sounds.testA.cooldown = 0
for _ = 1, 10 do
	Sfx.play("testA")
end
check(#sounds("testA") == 2, "voices are capped and reused")
for _, sound in sounds("testA") do
	sound.IsPlaying, sound.TimePosition = true, 5
end
Sfx.play("testA")
local restarted = 0
for _, sound in sounds("testA") do
	restarted += if sound.TimePosition == 0 then 1 else 0
end
check(#sounds("testA") == 2 and restarted == 1, "a busy pool retriggers one voice, never stacks")
-- Finished sounds are reused rather than recreated.
for _, sound in sounds("testA") do
	sound.IsPlaying = false
end
Sfx.play("testA")
check(#sounds("testA") == 2, "a finished voice is reused")
-- UI gap: one UI sound per gesture.
Manifest.sounds.testUI1 = { id = "2", source = "test", group = "UI", volume = 0.5 }
Manifest.sounds.testUI2 = { id = "3", source = "test", group = "UI", volume = 0.5 }
Sfx.play("testUI1")
Sfx.play("testUI2")
check(#sounds("testUI1") == 1 and #sounds("testUI2") == 0, "second UI sound in the gap is dropped")
wait(Manifest.gap.UI + 0.01)
Sfx.play("testUI2")
check(#sounds("testUI2") == 1, "UI sound after the gap plays")
-- Player volumes: "sfx" scales UI, SFX and Reveal (the opening); "music" only the Music group.
Sfx.group("Reveal")
Sfx.group("Music")
Sfx.setVolume("sfx", 0.5)
check(Sfx.volume("sfx") == 0.5, "sfx volume is kept")
for _, name in { "UI", "SFX", "Reveal" } do
	check(
		master():FindFirstChild(name).Volume == Manifest.groups[name] * 0.5,
		"sfx scales " .. name
	)
end
check(master():FindFirstChild("Music").Volume == Manifest.groups.Music, "sfx leaves Music alone")
check(master().Volume == Manifest.master, "Master stays at its mix level")
Sfx.setVolume("sfx", 0)
wait(0.06)
sounds("testUI1")[1].IsPlaying = false
Sfx.play("testUI1")
check(not sounds("testUI1")[1].IsPlaying, "sfx volume 0 skips plays")
Sfx.setVolume("sfx", 0 / 0)
check(Sfx.volume("sfx") == 1, "a NaN volume falls back to full")
Sfx.setVolume("sfx", 7)
check(Sfx.volume("sfx") == 1, "volumes clamp to 0..1")
-- Preload runs once, warms one resident voice per real sound, and only logs failures.
local preloaded = nil
local original = E.services.ContentProvider.PreloadAsync
E.services.ContentProvider.PreloadAsync = function(_self, list, callback)
	preloaded = list
	callback("rbxassetid://1", E.Enum.AssetFetchStatus.Failure)
end
local warnings = #E.warnings
Sfx.preload()
Sfx.preload()
check(preloaded == nil, "preload is deferred")
E.flushTasks()
local real = 0
for name, entry in Manifest.sounds do
	if entry.id ~= "" then
		real += 1
		check(#sounds(name) >= 1, "resident voice exists: " .. name)
	end
end
check(preloaded and #preloaded == real - 3, "preload warms each new sound's first voice once")
check(preloaded[1].ClassName == "Sound", "preload passes Sound instances, not ID strings")
check(#E.warnings == warnings + 1, "a failed load is logged")
for _, sound in sounds("testA") do
	sound.IsPlaying = false
end
Sfx.play("testA")
check(#sounds("testA") == 2, "a logged failure never blocks or stacks playback")
E.services.ContentProvider.PreloadAsync = original
-- Teardown removes every Sound; the next play rebuilds lazily.
Sfx.destroy()
check(master() == nil, "destroy removes Master and its sounds")
print(`PASS: {checks} Sfx manifest, cap, cooldown, group, mute and teardown checks (engine double)`)

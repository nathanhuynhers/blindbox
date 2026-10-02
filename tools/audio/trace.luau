--!strict
-- Offline mix trace: production state, sequence and mixer inside existing engine doubles.
-- First run tests/run.py to refresh build/tests. Dummy IDs never reach Roblox.
local E = require("../../build/tests/OpeningVisualEngine")
local Audio = require("../../build/tests/OpeningAudio")
local Mix = require("../../build/tests/OpeningAudioConfig")
local Config = require("../../build/tests/OpeningConfig")
local State = require("../../build/tests/OpeningState")
local Scope = require("../../build/tests/OpeningScope")
for key in Mix.sounds do
	Mix.sounds[key] = "rbxassetid://1"
end
local Sequence = require("../../build/tests/OpeningAudioSequence")
for _, reduced in { false, true } do
	for _, rarity in { "Common", "Uncommon", "Rare", "Legendary", "Mythical" } do
		local scope = Scope.create()
		local mixer = Audio.create(scope)
		local profile = Config.profile(rarity)
		local state = State.create(profile.timing, reduced, false)
		local sequence = Sequence.create(mixer, profile, Config.collection("grove"), true)
		local ids, nextId = {}, 0
		local name = string.lower(rarity) .. (if reduced then "_reduced" else "")
		sequence.enter(state)
		sequence.update(state)
		for frame = 0, 7200 do
			local folder = E.services.SoundService:FindFirstChild("OpeningSounds")
			print(string.format("FRAME,%s,%d,%s", name, frame, state.phase))
			for _, sound in folder:GetChildren() do
				if not ids[sound] then
					nextId += 1
					ids[sound] = nextId
				end
				print(
					string.format(
						"VOICE,%d,%s,%.8f,%.8f",
						ids[sound],
						sound.Name,
						sound.Volume,
						sound.PlaybackSpeed
					)
				)
			end
			if state.phase == "Done" then
				break
			end
			mixer.update(1 / 240)
			local changed = State.advance(state, 1 / 240)
			if
				(state.phase == "Await" and state.elapsed >= 0.7)
				or (state.phase == "Result" and state.elapsed >= 1.2)
			then
				changed = State.activate(state)
			end
			if changed then
				sequence.enter(state)
			end
			sequence.update(state)
		end
		scope.destroy()
	end
end

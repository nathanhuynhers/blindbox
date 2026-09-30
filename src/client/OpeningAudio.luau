--!strict
local SoundService = game:GetService("SoundService")
local Config = require(script.Parent.OpeningConfig)
local Scope = require(script.Parent.OpeningScope)
local Audio = {}
type Playing = { sound: Sound, age: number, key: string }
export type Audio = {
	play: (string, boolean?) -> (),
	stop: (string?) -> (),
	update: (number, number) -> (),
	destroy: () -> (),
}
function Audio.create(scope: Scope.Scope): Audio
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "OpeningSounds", SoundService
	local playing: { Playing } = {}
	local destroyed = false
	local function stop(key: string?)
		for i = #playing, 1, -1 do
			local entry = playing[i]
			if not key or key == entry.key then
				entry.sound:Destroy()
				table.remove(playing, i)
			end
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
		play = function(key, looped)
			if destroyed then
				return
			end
			local id = Config.sounds[key] or ""
			if not string.match(id, "^rbxassetid://[1-9]%d*$") then
				return
			end
			stop(key)
			if #playing >= Config.audioLimit then
				playing[1].sound:Destroy()
				table.remove(playing, 1)
			end
			local sound = Instance.new("Sound")
			sound.Name, sound.SoundId, sound.Volume = key, id, Config.volume
			sound.Looped = looped == true
			sound.Parent = folder
			table.insert(playing, { sound = sound, age = 0, key = key })
			sound:Play()
		end,
		update = function(delta, energy)
			for i = #playing, 1, -1 do
				local entry = playing[i]
				entry.age += delta
				-- Failed loads and configured loops have a hard lifetime as well as session ownership.
				if
					entry.age > Config.audioLifetime
					or (entry.age > 0.2 and entry.sound.IsLoaded and not entry.sound.IsPlaying)
				then
					entry.sound:Destroy()
					table.remove(playing, i)
				elseif entry.key == "charge" then
					entry.sound.PlaybackSpeed = 0.92 + energy * 0.22
					entry.sound.Volume = Config.volume * (0.55 + energy * 0.45)
				elseif entry.key == "flight" then
					entry.sound.PlaybackSpeed = 0.9 + energy * 0.2
					entry.sound.Volume = Config.volume * (0.25 + energy * 0.5)
				end
			end
		end,
	}
end
return Audio

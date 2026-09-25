--!strict
local SoundService = game:GetService("SoundService")
local Config = require(script.Parent.OpeningConfig)
local Audio = {}
export type Audio = { play: (string) -> (), destroy: () -> () }

function Audio.create(): Audio
	local folder = Instance.new("Folder")
	folder.Name = "OpeningSounds"
	folder.Parent = SoundService
	local sounds: { Sound } = {}
	local connections: { RBXScriptConnection } = {}
	return {
		play = function(id: string)
			if id == "" then
				return
			end
			-- At most eight short one-shot cues per opening. Failed loads need no blocking preload.
			if #sounds >= 8 then
				return
			end
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = Config.volume
			sound.Parent = folder
			table.insert(sounds, sound)
			table.insert(
				connections,
				sound.Ended:Connect(function()
					sound:Destroy()
				end)
			)
			sound:Play()
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			folder:Destroy()
		end,
	}
end

return Audio

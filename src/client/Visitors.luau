--!strict
local Players = game:GetService("Players")
local Visitors = {}
function Visitors.create()
	local models: { Part } = {}
	local currentRoom: Instance? = nil
	local function clear()
		for _, model in models do
			model:Destroy()
		end
		table.clear(models)
	end
	return {
		update = function(now: number, rate: number, target: number?)
			local rooms = workspace:FindFirstChild("Showrooms")
			local room = if rooms
				then rooms:FindFirstChild(tostring(target or Players.LocalPlayer.UserId))
				else nil
			if room ~= currentRoom then
				clear()
				currentRoom = room
			end
			if not room or rate <= 0 then
				clear()
				return
			end
			local origin = room:GetAttribute("VisitorOrigin")
			if typeof(origin) ~= "Vector3" then
				return
			end
			if #models == 0 then
				for index = 1, 2 do
					local part = Instance.new("Part")
					part.Name = "DecorativeVisitor"
					part.Shape = Enum.PartType.Ball
					part.Size = Vector3.new(1.6, 3, 1.6)
					part.Color = if index == 1
						then Color3.fromRGB(145, 184, 230)
						else Color3.fromRGB(233, 179, 192)
					part.Anchored = true
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Parent = workspace
					table.insert(models, part)
				end
			end
			for index, part in models do
				local phase = (now + index * 8) % 20
				local progress = if phase < 6
					then phase / 6
					elseif phase < 12 then 1
					else 1 - (phase - 12) / 8
				part.Position = origin
					+ Vector3.new(
						if index == 1 then -5 else 5,
						2.5 + (if phase >= 6 and phase < 12 then math.sin(now * 3) * 0.1 else 0),
						-12 + progress * 17
					)
			end
		end,
		destroy = clear,
	}
end
return Visitors

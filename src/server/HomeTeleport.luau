--!strict
-- Handles the non-persistent Home and Plaza actions. The caller supplies no destination or
-- identity; init.server resolves both from OnServerEvent. Both share one cooldown per session.
local PlayerPlot = require(script.Parent.PlayerPlot)

local HomeTeleport = {}

HomeTeleport.cooldown = 1

-- Moves a live character to a server-chosen CFrame after the shared cooldown.
function HomeTeleport.travel(
	player: Player,
	target: CFrame,
	lastRequest: number,
	now: number
): (boolean, number)
	if now - lastRequest < HomeTeleport.cooldown then
		return false, lastRequest
	end

	-- Consume the cooldown even for an invalid character so malformed/spam requests stay bounded.
	lastRequest = now
	local character = player.Character
	if not character or not character.Parent then
		return false, lastRequest
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false, lastRequest
	end

	character:PivotTo(target)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true, lastRequest
end

function HomeTeleport.request(
	player: Player,
	plot: PlayerPlot.Plot,
	lastRequest: number,
	now: number
): (boolean, number)
	if now - lastRequest < HomeTeleport.cooldown then
		return false, lastRequest
	end
	if not plot.active or not plot.model.Parent or plot.ownerId ~= player.UserId then
		return false, now -- Consumes the cooldown so invalid requests stay bounded.
	end
	-- Reuse the same server-computed CFrame used by PlayerSpawn, including its inward facing.
	return HomeTeleport.travel(player, plot.spawn, lastRequest, now)
end

-- The plaza spawn pad, raised to the plot spawn's standing height and facing the landmark.
function HomeTeleport.plazaTarget(pad: BasePart): CFrame
	return pad.CFrame * CFrame.new(0, 4, 0)
end

return HomeTeleport

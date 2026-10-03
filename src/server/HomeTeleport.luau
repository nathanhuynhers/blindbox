--!strict
-- Handles the non-persistent Home action against a server-owned plot session.
-- The caller supplies no destination or identity; init.server resolves both from OnServerEvent.
local PlayerPlot = require(script.Parent.PlayerPlot)

local HomeTeleport = {}

HomeTeleport.cooldown = 1

function HomeTeleport.request(
	player: Player,
	plot: PlayerPlot.Plot,
	lastRequest: number,
	now: number
): (boolean, number)
	if now - lastRequest < HomeTeleport.cooldown then
		return false, lastRequest
	end

	-- Consume the cooldown even for an invalid character so malformed/spam requests stay bounded.
	lastRequest = now
	if not plot.active or not plot.model.Parent or plot.ownerId ~= player.UserId then
		return false, lastRequest
	end

	local character = player.Character
	if not character or not character.Parent then
		return false, lastRequest
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false, lastRequest
	end

	-- Reuse the same server-computed CFrame used by PlayerSpawn, including its inward facing.
	character:PivotTo(plot.spawn)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true, lastRequest
end

return HomeTeleport

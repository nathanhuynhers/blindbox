--!strict
local Players = game:GetService("Players")
local Scope = require(script.Parent.OpeningScope)
local CameraOwner = {}
export type Owner = { camera: Camera, take: () -> (), restore: () -> (), isOwned: () -> boolean }
function CameraOwner.create(scope: Scope.Scope, interrupted: () -> ()): Owner
	local camera = workspace.CurrentCamera
	assert(camera, "No local camera")
	local savedType, savedSubject = camera.CameraType, camera.CameraSubject
	local savedFrame, savedFocus, savedFov = camera.CFrame, camera.Focus, camera.FieldOfView
	local owned, restored = false, false
	local function restore()
		if restored then
			return
		end
		restored = true
		if not owned then
			return
		end
		owned = false
		-- Restore the captured camera even if another local system replaced CurrentCamera.
		if camera.Parent then
			camera.CFrame, camera.Focus, camera.FieldOfView = savedFrame, savedFocus, savedFov
			local character = Players.LocalPlayer.Character
			local subject = if savedSubject and savedSubject.Parent
				then savedSubject
				elseif character then character:FindFirstChildOfClass("Humanoid")
				else nil
			if subject then
				camera.CameraSubject = subject
			end
			camera.CameraType = savedType
		end
		local replacement = workspace.CurrentCamera
		if
			not camera.Parent
			and replacement
			and replacement.CameraType == Enum.CameraType.Scriptable
		then
			local character = Players.LocalPlayer.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then
				replacement.CameraSubject = humanoid
			end
			replacement.FieldOfView = savedFov
			replacement.CameraType = Enum.CameraType.Custom
		end
	end
	scope.add(restore)
	local changed = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if owned and workspace.CurrentCamera ~= camera then
			interrupted()
		end
	end)
	scope.add(function()
		changed:Disconnect()
	end)
	local destroying = camera.Destroying:Connect(function()
		if owned then
			interrupted()
		end
	end)
	scope.add(function()
		destroying:Disconnect()
	end)
	local typeChanged = camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if owned and camera.CameraType ~= Enum.CameraType.Scriptable then
			interrupted()
		end
	end)
	scope.add(function()
		typeChanged:Disconnect()
	end)
	return {
		camera = camera,
		restore = restore,
		isOwned = function()
			return owned
		end,
		take = function()
			if owned or restored then
				return
			end
			assert(
				workspace.CurrentCamera == camera and camera.Parent,
				"Camera changed before cinematic"
			)
			owned = true
			camera.CameraType = Enum.CameraType.Scriptable
		end,
	}
end
return CameraOwner

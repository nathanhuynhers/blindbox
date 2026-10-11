--!strict
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Config = require(game:GetService("ReplicatedStorage").Shared.AfkConfig)
local Idle = require(game:GetService("ReplicatedStorage").Shared.AfkIdle)
local Notice = require(script.Parent.AfkNotice)
local Scope = require(script.Parent.UIScope)
export type Controller = { blocked: () -> boolean, ready: () -> (), destroy: () -> () }
local Client = {}
function Client.create(
	remote: RemoteEvent,
	busy: () -> boolean,
	message: (string, string?) -> ()
): Controller
	local scope = Scope.create()
	local function own(connection: RBXScriptConnection)
		scope.add(function()
			connection:Disconnect()
		end)
	end
	local player = Players.LocalPlayer
	local clock = Idle.new(os.clock())
	local reportAt, activeAt = -math.huge, -math.huge
	local blocked = false
	local exhausted = false
	local notice: Notice.View? = nil
	local function clear()
		blocked = false
		if notice then
			notice.destroy()
			notice = nil
		end
	end
	local function activity()
		local now = os.clock()
		Idle.active(clock, now)
		exhausted = false
		local wasBlocked = blocked
		clear()
		if now - activeAt >= 1 or wasBlocked then
			activeAt = now
			remote:FireServer({ action = "Active" })
		end
	end
	-- Processed input also counts: typing in chat and tapping menus are real activity.
	scope.connect(Input.InputBegan, activity)
	scope.connect(Input.InputEnded, activity)
	own(Input.InputChanged:Connect(function(input: InputObject)
		if
			(input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2)
			and input.Position.Magnitude < 0.15
		then
			return
		end
		activity()
	end))
	scope.connect(Input.WindowFocused, activity)
	scope.connect(player.CharacterAdded, activity)
	scope.connect(player.CharacterRemoving, activity)
	own(player.Idled:Connect(function(duration: number)
		Idle.report(clock, duration, os.clock())
	end))
	own(remote.OnClientEvent:Connect(function(phase: string, token: string)
		if phase == "Check" then
			local duration = Idle.duration(clock, os.clock())
			if not duration or duration < Idle.threshold() or exhausted then
				remote:FireServer({ action = "Active" })
				return
			end
			if busy() then
				remote:FireServer({ action = "Busy", token = token })
				return
			end
			-- Guard new actions before acknowledging; input immediately cancels this guard.
			blocked = true
			remote:FireServer({ action = "Confirm", token = token, idle = duration })
		elseif phase == "Begin" or phase == "Depart" then
			-- Input may have arrived while this server notification was in transit.
			if not blocked or not Idle.duration(clock, os.clock()) then
				remote:FireServer({ action = "Active" })
				return
			end
			if not notice then
				notice = Notice.create()
			end
			local view = notice
			if view then
				view.show(phase == "Depart")
			end
		elseif phase == "Failed" then
			exhausted = true
			clear()
			message(
				"Couldn't move servers. Your collection is protected. Roblox may still disconnect you while idle.",
				"info"
			)
		elseif phase == "Cancelled" then
			clear()
		end
	end))
	local elapsed = 0
	own(RunService.Heartbeat:Connect(function(delta: number)
		elapsed += delta
		if elapsed < 1 then
			return
		end
		elapsed = 0
		local now = os.clock()
		local duration = Idle.duration(clock, now)
		if not duration then
			if blocked then
				activity()
			end
			return
		end
		if not exhausted and now - reportAt >= Config.reportSeconds then
			reportAt = now
			remote:FireServer({
				action = "Idle",
				idle = math.min(duration, Config.idleLimitSeconds),
			})
		end
	end))
	local welcomed = false
	return {
		blocked = function()
			return blocked
		end,
		ready = function()
			if welcomed then
				return
			end
			welcomed = true
			local ok, data = pcall(function(): unknown
				local arriving = TeleportService:GetArrivingTeleportGui()
				if arriving and arriving.Name == "AfkReconnectLoading" then
					arriving:Destroy()
				end
				return TeleportService:GetLocalPlayerTeleportData()
			end)
			-- Presentation only. Teleport data never grants currency or changes a profile.
			if
				ok
				and typeof(data) == "table"
				and (data :: { [string]: unknown }).afkReconnect == true
			then
				message("Welcome back! Your collection is ready.", "success")
			end
		end,
		destroy = function()
			scope.destroy()
			clear()
		end,
	}
end
return Client

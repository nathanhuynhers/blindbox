--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Types = require(ReplicatedStorage.Shared.Types)
local Interface = require(script.Interface)
local Visitors = require(script.Visitors)
local OpeningController = require(script.OpeningController)
local OpeningResult = require(script.OpeningResult)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local intentRemote = remotes:WaitForChild("Intent") :: RemoteEvent
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local syncRemote = remotes:WaitForChild("RequestState") :: RemoteEvent
local visitRemote = remotes:WaitForChild("Visit") :: RemoteEvent
local noticeRemote = remotes:WaitForChild("Notice") :: RemoteEvent
local current: Types.Snapshot? = nil
local pending: Types.Intent? = nil
local beforeRequest: Types.Snapshot? = nil
local opening: OpeningController.Controller? = nil
local sentAt = 0
local sequence = -1
local ui: Interface.Interface
ui = Interface.create(function(action: string, figure: string?, slot: number?, choice: string?)
	local state = current
	if not state or not state.ready or pending or (opening and opening.isActive()) then
		return
	end
	local intent: Types.Intent = {
		action = action,
		choice = choice,
		figure = figure,
		slot = slot,
		id = HttpService:GenerateGUID(false),
		revision = state.revision,
	}
	pending = intent
	beforeRequest = state
	ui.pending(true)
	sentAt = os.clock()
	intentRemote:FireServer(intent)
end, function(target: number)
	if opening and opening.isActive() then
		return
	end
	visitRemote:FireServer(target)
end)
opening = OpeningController.create(ui.openingFocus, ui.message)
local visitors = Visitors.create()
local connections: { RBXScriptConnection } = {}
table.insert(
	connections,
	noticeRemote.OnClientEvent:Connect(function(message: string)
		ui.message(message)
	end)
)
table.insert(
	connections,
	stateRemote.OnClientEvent:Connect(function(state: Types.Snapshot, reply: Types.Reply?)
		if state.sequence > sequence then
			sequence = state.sequence
			current = state
			ui.update(state)
		end
		local request = pending
		if reply and request and reply.id == request.id then
			local before = beforeRequest
			pending = nil
			beforeRequest = nil
			ui.pending(false)
			local feedback = {
				Place = "Figure displayed",
				Remove = "Figure removed",
				Recycle = "+1 Scrap",
				Expand = "Display slot unlocked",
				Theme = "Palette updated",
				Goal = "Daily reward claimed",
			}
			ui.message(
				if reply.ok then feedback[request.action] or reply.message else reply.message,
				if reply.ok then "success" else "error"
			)
			if before then
				local result = OpeningResult.fromReply(request, before, state, reply)
				if result and opening then
					ui.selectAcquired(result.figureId)
					opening.present(result, not ui.effects())
				end
			end
		end
	end)
)
local animationElapsed = 0
local syncAt = 0
table.insert(
	connections,
	RunService.Heartbeat:Connect(function(delta: number)
		local now = os.clock()
		if pending and now - sentAt > 3 then
			sentAt = now
			ui.message("Waiting for server… recovering the same request.")
			intentRemote:FireServer(pending)
		end
		if not current and now - syncAt > 2 then
			syncAt = now
			syncRemote:FireServer()
		end
		animationElapsed += delta
		if animationElapsed >= 0.05 then
			animationElapsed = 0
			local state = current
			local rate = if state then state.rate else 0
			if state then
				for _, room in state.rooms do
					if room.userId == state.visiting then
						rate = room.rate
					end
				end
			end
			visitors.update(
				now,
				if ui.effects() then rate else 0,
				if state then state.visiting else nil
			)
		end
	end)
)
syncRemote:FireServer()
script.Destroying:Connect(function()
	for _, connection in connections do
		connection:Disconnect()
	end
	visitors.destroy()
	if opening then
		opening.destroy()
	end
	ui.destroy()
end)

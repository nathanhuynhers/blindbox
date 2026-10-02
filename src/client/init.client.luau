--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Types = require(ReplicatedStorage.Shared.Types)
local ShelfConfig = require(ReplicatedStorage.Shared.ShelfConfig)
local Interface = require(script.Interface)
local OpeningController = require(script.OpeningController)
local OpeningResult = require(script.OpeningResult)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local intentRemote = remotes:WaitForChild("Intent") :: RemoteEvent
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local syncRemote = remotes:WaitForChild("RequestState") :: RemoteEvent
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
	if string.sub(action, 1, 5) == "Shelf" then
		intent.shelfId = choice
		intent.choice = nil
		intent.carouselRevision = state.shelves.carouselRevision
		intent.shelfSlotId = if slot then ShelfConfig.slots()[slot] else nil
		intent.slot = nil
	end
	pending = intent
	beforeRequest = state
	ui.pending(true)
	sentAt = os.clock()
	intentRemote:FireServer(intent)
end)
opening = OpeningController.create(ui.openingFocus, ui.message)
local connections: { RBXScriptConnection } = {}
table.insert(
	connections,
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		local owner = prompt:GetAttribute("CollectorOwnerId")
		if typeof(owner) == "number" and owner ~= Players.LocalPlayer.UserId then
			prompt.Enabled = false -- Presentation only; the server independently checks ownership.
		end
	end)
)
local function updateCollectors(state: Types.Snapshot)
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = if plots then plots:FindFirstChild(tostring(Players.LocalPlayer.UserId)) else nil
	local targets = if plot then plot:FindFirstChild("FigureCollectors") else nil
	if not targets then
		return
	end
	for slot, id in state.slots do
		local target = targets:FindFirstChild(tostring(slot))
		local prompt = if target then target:FindFirstChildOfClass("ProximityPrompt") else nil
		if prompt then
			prompt.ActionText =
				string.format("Collect %d Coins", math.floor(state.earnings[id] or 0))
		end
	end
end
table.insert(
	connections,
	stateRemote.OnClientEvent:Connect(function(state: Types.Snapshot, reply: Types.Reply?)
		if state.sequence > sequence then
			sequence = state.sequence
			current = state
			ui.update(state)
			updateCollectors(state)
		end
		local request = pending
		if reply and string.sub(reply.id, 1, 8) == "collect:" then
			ui.message(reply.message, if reply.ok then "success" else "error")
		end
		if reply and request and reply.id == request.id then
			local before = beforeRequest
			pending = nil
			beforeRequest = nil
			ui.pending(false)
			local feedback = {
				Place = "Figure displayed",
				Remove = "Figure removed",
				Expand = "Display slot unlocked",
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
local syncAt = 0
table.insert(
	connections,
	RunService.Heartbeat:Connect(function()
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
	end)
)
syncRemote:FireServer()
script.Destroying:Connect(function()
	for _, connection in connections do
		connection:Disconnect()
	end
	if opening then
		opening.destroy()
	end
	ui.destroy()
end)

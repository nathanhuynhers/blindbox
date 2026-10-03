--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Types = require(ReplicatedStorage.Shared.Types)
local ShelfConfig = require(ReplicatedStorage.Shared.ShelfConfig)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Interface = require(script.Interface)
local DisplayInteraction = require(script.DisplayInteraction)
local DisplayEarnings = require(script.DisplayEarnings)
local OpeningController = require(script.OpeningController)
local OpeningResult = require(script.OpeningResult)
local UIState = require(script.UIState)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local intentRemote = remotes:WaitForChild("Intent") :: RemoteEvent
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local syncRemote = remotes:WaitForChild("RequestState") :: RemoteEvent
local homeRemote = remotes:WaitForChild("Home") :: RemoteEvent
local current: Types.Snapshot? = nil
local pending: Types.Intent? = nil
local beforeRequest: Types.Snapshot? = nil
local opening: OpeningController.Controller? = nil
local reveal: OpeningResult.Result? = nil
local sentAt = 0
local sequence = -1
local ui: Interface.Interface
-- The only way the client asks for a change. One request at a time; the server decides.
local function request(action: string, figure: string?, slot: number?, choice: string?)
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
end
ui = Interface.create(request, function()
	homeRemote:FireServer()
end)
-- Reveal choices run after the opening has fully closed and released UI focus.
local function choose(choice: string, result: OpeningResult.Result)
	local state = current
	if not state then
		return
	end
	if choice == "display" then
		local placement = UIState.placement(state, result.figureId)
		if placement then
			request("Place", result.figureId, placement.slot, nil)
		end
	elseif choice == "another" then
		local figure = Catalog.byId[result.figureId]
		if figure then
			request("Buy", nil, nil, figure.collection)
		end
	end
end
opening = OpeningController.create(ui.openingFocus, ui.message, choose)
local function revealModel(state: Types.Snapshot, result: OpeningResult.Result): UIState.Reveal
	return UIState.reveal(state, result.figureId, result.isNew, result.quantity)
end
local connections: { RBXScriptConnection } = {}
local displayInteraction = DisplayInteraction.create(ui.openDisplay, ui.openShelves)
local displayEarnings = DisplayEarnings.create(ui.effects, ui.coinLanded)
table.insert(
	connections,
	stateRemote.OnClientEvent:Connect(function(state: Types.Snapshot, reply: Types.Reply?)
		local previous = current
		if state.sequence > sequence then
			sequence = state.sequence
			current = state
			ui.update(state)
			displayInteraction.update(displayEarnings.update(state))
			if opening and opening.isActive() and reveal then
				-- Live affordability and slots while the Reveal card is up.
				opening.refresh(revealModel(state, reveal))
			end
		end
		local intent = pending
		-- Server-initiated collections (world click or tap) reply with a "collect:" id.
		if reply and string.sub(reply.id, 1, 8) == "collect:" then
			ui.message(reply.message, if reply.ok then "success" else "error")
			if previous and current then
				displayEarnings.collected(previous, current, reply)
			end
		end
		if reply and intent and reply.id == intent.id then
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
				if reply.ok then feedback[intent.action] or reply.message else reply.message,
				if reply.ok then "success" else "error"
			)
			if before then
				local result = OpeningResult.fromReply(intent, before, state, reply)
				if result and opening then
					reveal = result
					opening.present(result, not ui.effects(), nil, revealModel(state, result))
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
	displayInteraction.destroy()
	displayEarnings.destroy()
	ui.destroy()
end)

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Types = require(ReplicatedStorage.Shared.Types)
local ShelfConfig = require(ReplicatedStorage.Shared.ShelfConfig)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local Interface = require(script.Interface)
local DisplayInteraction = require(script.DisplayInteraction)
local ShopKeeper = require(script.ShopKeeper)
local DisplayEarnings = require(script.DisplayEarnings)
local OpeningController = require(script.OpeningController)
local OpeningResult = require(script.OpeningResult)
local PullSummary = require(script.PullSummary)
local OfflineEarnings = require(script.OfflineEarnings)
local WelcomeReward = require(script.WelcomeReward)
local DealPopup = require(script.DealPopup)
local DealStalls = require(script.DealStalls)
local UIState = require(script.UIState)
local Sfx = require(script.Sfx)
local Music = require(script.Music)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local intentRemote = remotes:WaitForChild("Intent") :: RemoteEvent
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local syncRemote = remotes:WaitForChild("RequestState") :: RemoteEvent
local homeRemote = remotes:WaitForChild("Home") :: RemoteEvent
local current: Types.Snapshot? = nil
local pending: Types.Intent? = nil
local beforeRequest: Types.Snapshot? = nil
local opening: OpeningController.Controller? = nil
local summary: PullSummary.Summary
local reveal: OpeningResult.Result? = nil
-- Ownership before the opening's request, so a duplicate can name its rate gain.
local revealBefore: Types.Snapshot? = nil
-- Open 10: the remaining box/reveal steps, then the results grid once they are done.
local batch: { OpeningResult.Result } = {}
local results: { PullSummary.Item }? = nil
local resultsHeading: string? = nil
-- The Welcome Quest finale pops up once per session; the Shop keeps the x10 afterwards.
local welcomeShown = false
-- Shown once the opening closes so it never spoils the reveal.
local shelfNotice: string? = nil
local musicStarted = false
local sentAt = 0
local sequence = -1
local ui: Interface.Interface
local deal: DealPopup.Controller
-- Sounds for confirmed replies. Box results sound through the opening; failures play "error".
local feedback: { [string]: string } = {
	Place = "Figure displayed",
	Remove = "Figure removed",
	Expand = "Display slot unlocked",
	Goal = "Daily reward claimed",
}
local replySounds: { [string]: string } = {
	Place = "place",
	EquipBest = "place",
	ShelfPlace = "place",
	Remove = "remove",
	ShelfRemove = "remove",
	Expand = "unlock",
	BuyShelf = "unlock",
	Goal = "claim",
	Login = "claim",
	ClaimOffline = "claim",
}
Sfx.preload()
-- The only way the client asks for a change. One request at a time; the server decides.
local function request(
	action: string,
	figure: string?,
	slot: number?,
	choice: string?,
	volume: number?,
	window: number?
)
	local state = current
	if not state or not state.ready or pending or (opening and opening.isActive()) then
		return
	end
	local intent: Types.Intent = {
		action = action,
		choice = choice,
		volume = volume,
		figure = figure,
		slot = slot,
		id = HttpService:GenerateGUID(false),
		revision = state.revision,
		window = window,
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
	deal.pending(true)
	sentAt = os.clock()
	intentRemote:FireServer(intent)
end
ui = Interface.create(request, function()
	homeRemote:FireServer()
end)
summary = PullSummary.create(ui.openingFocus, ui.effects)
-- Closing the popup any way claims; a dropped claim re-opens it on the next snapshot.
local offline = OfflineEarnings.create(ui.effects, function()
	request("ClaimOffline")
end)
local welcome = WelcomeReward.create(ui.effects, function()
	request("WelcomeTen")
end)
-- E at a plaza stall; Buy names only the stall and the deal window on screen.
deal = DealPopup.create(ui.effects, function(stall, window)
	request("Deal", nil, stall, nil, nil, window)
end)
local dealStalls = DealStalls.create(ui.effects)
local function revealModel(state: Types.Snapshot, result: OpeningResult.Result): UIState.Reveal
	local model =
		UIState.reveal(state, result.figureId, result.isNew, result.quantity, revealBefore)
	if result.sequence == "last" then
		model.next = "See all results"
	elseif result.sequence then
		model.next = string.format("Next figure (%d left)", #batch)
		model.skip = "View all results"
	end
	-- During the Welcome Quest (and while its x10 waits), the card steers to the next step.
	model.guided = not state.tutorialHidden and state.step <= Tutorial.reward
	return model
end
local function presentNext(state: Types.Snapshot)
	local result = table.remove(batch, 1)
	if result and opening then
		reveal = result
		opening.present(result, not ui.effects(), nil, revealModel(state, result))
	end
end
-- Reveal choices run after the opening has fully closed and released UI focus.
local function choose(choice: string, result: OpeningResult.Result)
	local state = current
	if not state then
		return
	end
	if result.sequence and choice == "skip" then
		table.clear(batch)
	end
	if choice == "display" then
		local placement = UIState.placement(state, result.figureId)
		if placement then
			request("Place", result.figureId, placement.slot, nil)
		end
	elseif choice == "another" and not result.sequence then
		local figure = Catalog.byId[result.figureId]
		if figure then
			request("Buy", nil, nil, figure.collection)
		end
	end
	-- Same frame as the close, so the next step or the grid takes over under the curtain.
	if result.sequence and #batch > 0 then
		presentNext(state)
	elseif result.sequence and results then
		summary.show(results, current, resultsHeading)
		results = nil
	end
end
opening = OpeningController.create(ui.openingFocus, ui.message, choose)
local connections: { RBXScriptConnection } = {}
local displayInteraction = DisplayInteraction.create(
	ui.openDisplay,
	ui.openShelves,
	ui.openShop,
	function(stall)
		local state = current
		if
			state
			and state.ready
			and not (opening and opening.isActive())
			and not summary.isOpen()
			and not offline.isOpen()
			and not welcome.isOpen()
		then
			ui.closeScreen()
			deal.show(stall)
		end
	end
)
local shopKeeper = ShopKeeper.create(ui.effects)
local displayEarnings = DisplayEarnings.create(ui.effects, ui.coinLanded, ui.displayCoins)
ui.onCoinInterrupted(displayEarnings.interrupt, displayEarnings.destroy)
table.insert(
	connections,
	stateRemote.OnClientEvent:Connect(function(state: Types.Snapshot, reply: Types.Reply?)
		local previous = current
		if state.sequence > sequence then
			sequence = state.sequence
			current = state
			if
				previous
				and state.shelves.ownedCount > previous.shelves.ownedCount
				and not (pending and pending.action == "BuyShelf")
			then
				shelfNotice = "Collection complete! New Shelf unlocked"
			end
			displayEarnings.receive(previous, state, reply)
			ui.update(state)
			deal.update(state)
			dealStalls.update(state)
			if state.ready and not musicStarted then
				-- Once the profile and plot are ready. Areas or events may switch it later.
				musicStarted = true
				Music.play("world")
			end
			local offlineCoins, away = UIState.offline(state)
			if offlineCoins and state.ready and not pending and not offline.isOpen() then
				offline.show(offlineCoins, away)
				Sfx.play("open")
			end
			displayInteraction.update(displayEarnings.update(state))
			if
				previous
				and UIState.goal(previous) ~= "ready"
				and UIState.goal(state) == "ready"
			then
				Sfx.play("goalReady")
			end
			if opening and opening.isActive() and reveal then
				-- Live affordability and slots while the Reveal card is up.
				opening.refresh(revealModel(state, reveal))
			end
		end
		local intent = pending
		-- Server-initiated collections (world click or tap) reply with a "collect:" id.
		if reply and string.sub(reply.id, 1, 8) == "collect:" then
			ui.message(reply.message, if reply.ok then "success" else "error")
			if not reply.ok then
				displayEarnings.interrupt()
				Sfx.play("error")
			end
		end
		if reply and intent and reply.id == intent.id then
			local before = beforeRequest
			pending = nil
			beforeRequest = nil
			ui.pending(false)
			deal.pending(false)
			-- A bought deal opens like a Shop box; the popup gives way to the opening.
			if reply.ok and intent.action == "Deal" then
				deal.close()
			end
			local sound: string? = if reply.ok then replySounds[intent.action] else "error"
			local text = if reply.ok
				then feedback[intent.action] or reply.message
				else reply.message
			local kind = if reply.ok then "success" else "error"
			if reply.ok and intent.action == "EquipBest" and before then
				local changed
				text, changed = UIState.equipSummary(before, state)
				if #changed == 0 then
					-- Already optimal is a calm notice, not a failure or a placement.
					sound, kind = nil, "info"
				end
			end
			-- A Login day that grants boxes sounds through its opening instead.
			if intent.action == "Login" and (reply.figure or reply.figures) then
				sound = nil
			end
			if sound then
				Sfx.play(sound)
			end
			-- A saved volume needs no toast; the slider already shows it.
			if not (reply.ok and intent.action == "SetVolume") then
				ui.message(text, kind)
			end
			if
				reply.ok
				and intent.action == "Place"
				and before
				and before.step == Tutorial.display
				and state.step == Tutorial.collect
				and intent.slot
			then
				-- The Welcome Quest's first placement: show where the earning happens, unobstructed.
				ui.closeScreen()
				displayEarnings.celebrate(intent.slot)
			end
			revealBefore = before
			-- Several figures: Open 10, the Welcome x10 or a multi-box Login reward day.
			if before and reply.figures then
				batch = OpeningResult.fromBatch(intent, before, state, reply)
				local items = OpeningResult.summary(batch)
				results = if #items > 0 then items else nil
				resultsHeading = if intent.action == "WelcomeTen" then "Your Welcome ×10!" else nil
				presentNext(state)
			elseif before then
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
		-- Open 10 recovery after a cancelled step (reset or death mid-sequence).
		if results and current and opening and not opening.isActive() then
			if #batch > 0 then
				presentNext(current)
			else
				summary.show(results, current, resultsHeading)
				results = nil
			end
		end
		-- Also after the Open 10 grid closes, so the toast and its sting aren't buried under it.
		if
			shelfNotice
			and not (opening and opening.isActive())
			and #batch == 0
			and not summary.isOpen()
		then
			ui.message(shelfNotice, "success")
			Sfx.play("complete")
			shelfNotice = nil
		end
		local state = current
		if
			state
			and state.ready
			and state.step == Tutorial.reward
			and not welcomeShown
			and not pending
			and not (opening and opening.isActive())
			and #batch == 0
			and not summary.isOpen()
			and not offline.isOpen()
		then
			welcomeShown = true
			welcome.show()
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
	summary.destroy()
	offline.destroy()
	welcome.destroy()
	deal.destroy()
	dealStalls.destroy()
	displayInteraction.destroy()
	shopKeeper.destroy()
	displayEarnings.destroy()
	ui.destroy()
	Music.destroy()
	Sfx.destroy()
end)

--!strict
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local AfkReconnect = require(script.AfkReconnect)
local AfkConfig = require(ReplicatedStorage.Shared.AfkConfig)
local Types = require(ReplicatedStorage.Shared.Types)
local Rules = require(script.Rules)
local Economy = require(script.Economy)
local CollectionEconomy = require(script.CollectionEconomy)
local Transactions = require(script.Transactions)
local Deals = require(script.Deals)
local PlayerPlot = require(script.PlayerPlot)
local Shelves = require(script.Shelves)
local ShelfShowcase = require(script.ShelfShowcase)
local PlotSlots = require(script.PlotSlots)
local PlotConfig = require(script.PlotConfig)
local Storage = require(script.Storage)
local PurchaseRuntime = require(script.PurchaseRuntime)
local PurchaseConfig = require(script.PurchaseConfig)
local CoinModifiers = require(script.CoinModifiers)
local CoinModifierRuntime = require(script.CoinModifierRuntime)
local BoostRuntime = require(script.BoostRuntime)
local OfflineRuntime = require(script.OfflineRuntime)
local OfflineAwards = require(script.OfflineAwards)
local Protocol = require(script.Protocol)
local World = require(script.World)
local ModelAssets = require(script.ModelAssets)
local PlayerSpawn = require(script.PlayerSpawn)
local PlayerMovement = require(script.PlayerMovement)
local HomeTeleport = require(script.HomeTeleport)
local Leaderboard = require(script.Leaderboard)
local DayNight = require(script.DayNight)
local TownModels = require(script.TownModels)
local TownPlacements = require(script.TownPlacements)
local AdminService = require(script.AdminService)
local AdminTypes = require(ReplicatedStorage.Shared.AdminTypes)
local world = World.create()
local productionModels = ModelAssets.publish()
local dayNight = DayNight.start(Lighting)
Leaderboard.start(world.board)
-- Uploaded trees and statues replace their part placeholders as each model loads.
local townModels = TownModels.start(function(kind: string, template: Model)
	if world.root.Parent then
		TownPlacements.swap(kind, template)
	end
end)
type Session = {
	transaction: Transactions.Session,
	plot: PlayerPlot.Plot,
	storage: Storage.Session,
	sequence: number,
	syncTime: number,
	homeTime: number,
	boostRequestTime: number,
	spawn: PlayerSpawn.Binding?,
	afkPosition: Vector3?,
	afkCharacter: Model?,
}
local plots = PlotSlots.new(PlotConfig.maxPlots)
local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local movement: { [Player]: PlayerMovement.Binding } = {}
local closing = 0
local shuttingDown = false
local random = Random.new()
-- Ten per request covers BuyTen; single-box actions use the first.
local function rolls(): { number }
	local values = table.create(10)
	for index = 1, 10 do
		values[index] = math.min(random:NextNumber(), 0.9999999999999999)
	end
	return values
end
local folder = Instance.new("Folder")
folder.Name = "Remotes"
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end
local intentRemote = remote("Intent")
local stateRemote = remote("State")
local syncRemote = remote("RequestState")
local homeRemote = remote("Home")
local plazaRemote = remote("Plaza")
local shelfEditorRemote = remote("ShelfEditor")
local afkRemote = remote("AfkReconnect")
local boostRequest = remote("BoostActivate")
local boostResult = remote("BoostResult")
local adminRemote = Instance.new("RemoteFunction")
adminRemote.Name = "Admin"
adminRemote.Parent = folder
folder.Parent = ReplicatedStorage
local ownershipChanged: ((number) -> ())? = nil
local purchaseChanged: ((Player) -> ())? = nil
local function purchaseSession(player: Player): Storage.Session?
	local session = sessions[player]
	return if session and not shuttingDown then session.storage else nil
end
local offlineIntegration = OfflineRuntime.create(purchaseSession, function(player)
	if purchaseChanged then
		purchaseChanged(player)
	end
end)
local purchases = PurchaseRuntime.start(folder, function(player: Player): Storage.Session?
	return purchaseSession(player)
end, function(userId)
	if ownershipChanged then
		ownershipChanged(userId)
	end
end, {
	eligible = offlineIntegration.eligible,
	prepare = offlineIntegration.prepare,
	fulfill = offlineIntegration.fulfill,
	deliverReserved = function(userId, key, entry)
		-- Only token-only immutable grants belong to P04. Mixed Starter is separate.
		if entry.grant.coins ~= 0 or next(entry.grant.tokens) == nil then
			return nil
		end
		local player = Players:GetPlayerByUserId(userId)
		local owner = if player then purchaseSession(player) else nil
		if not owner or not player then
			return false
		end
		local saved = BoostRuntime.fulfill(owner, key, entry, os.clock())
		if purchaseSession(player) == owner and purchaseChanged then
			purchaseChanged(player)
		end
		return saved
	end,
})
-- Current plaza deal window and its length. Studio playtests may shorten it with the
-- StudioDealWindowSeconds attribute on ServerStorage; live servers always use the config.
local function dealClock(): (number, number)
	local seconds = Economy.deals.windowSeconds
	local override = if RunService:IsStudio()
		then ServerStorage:GetAttribute("StudioDealWindowSeconds")
		else nil
	if typeof(override) == "number" and override >= 10 and override % 1 == 0 then
		seconds = override
	end
	return Deals.window(os.time(), seconds), seconds
end
local function send(player: Player, session: Session, reply: Types.Reply?)
	session.sequence += 1
	local state = session.transaction.state
	local day = math.floor(os.time() / 86400)
	if not session.storage.transferring then
		Rules.refreshDay(state, day)
	end
	local snapshot: Types.Snapshot = {
		offlineAward = OfflineAwards.view(
			state,
			session.storage.ready
				and not session.storage.busy
				and session.storage.pendingSave == nil
		),
		coinModifiers = table.clone(state.coinModifiers),
		earningFactors = Rules.earningFactors(state),
		luckModifiers = table.clone(state.luckModifiers),
		boosts = Rules.boostView(state),
		rarityOdds = CollectionEconomy.rarityOdds(state.pityByGroup, Rules.luck(state)),
		freePityOdds = CollectionEconomy.odds(state.pityByGroup),
		shelfEditorToken = session.plot.showcase.editorToken,
		shelves = Shelves.publicView(state.shelves, session.plot.view),
		shelfAvailable = Shelves.availability(state.shelves, state.owned),
		coins = state.coins,
		earnings = table.clone(state.earnings),
		owned = table.clone(state.owned),
		discovered = table.clone(state.discovered),
		slots = table.clone(state.display.slots),
		revision = state.revision,
		sequence = session.sequence,
		rate = Rules.rate(state),
		step = state.step,
		tutorialHidden = state.tutorialHidden,
		rates = CollectionEconomy.effectiveRates(state.owned),
		baseRates = Rules.rates,
		nextRates = CollectionEconomy.effectiveRates(state.owned, true),
		odds = CollectionEconomy.odds(state.pityByGroup, Rules.luck(state)),
		pityProgress = CollectionEconomy.pityProgress(state.pityByGroup),
		baseOdds = Rules.odds,
		prices = Rules.prices,
		dailyCollection = Economy.dailyCollection,
		unlocked = state.display.unlocked,
		expansionCost = Rules.expansionCost(state),
		shelfPrice = Rules.shelfPrice(state),
		dailyReady = state.lastDailyDay < day,
		loginReady = state.lastLoginDay < day,
		loginStreak = Rules.loginStreak(state, day),
		goalProgress = state.goalProgress,
		goalClaimed = state.goalClaimed,
		goalReward = Economy.goalReward,
		nextDay = (day + 1) * 86400,
		saveStatus = session.storage.status,
		ready = session.storage.ready and not session.storage.transferring,
		bonus = Rules.bonus(state),
		offlinePending = state.offlinePending,
		offlineSeconds = state.offlineSeconds,
		sfxVolume = state.sfxVolume,
		musicVolume = state.musicVolume,
		deals = Deals.view(state, dealClock()),
	}
	stateRemote:FireClient(player, snapshot, reply)
end
-- P02 invokes this immediately after verified ownership changes. A paused/frozen profile
-- defers the change until the ordinary loop resumes; it must not alter a handoff checkpoint.
purchaseChanged = function(player)
	local session = sessions[player]
	if session then
		send(player, session, nil)
	end
end
local function refreshCoinModifiers(player: Player, session: Session, now: number)
	local storage = session.storage
	if shuttingDown then
		return
	end
	local changed = CoinModifierRuntime.sync(storage, PurchaseConfig.products, function(key)
		return purchases.ownership(player.UserId, key)
	end, CoinModifiers.effectsValidated, now)
	local boostsChanged = BoostRuntime.sync(storage, PurchaseConfig.products, function(key)
		return purchases.ownership(player.UserId, key)
	end, { policy = "Unknown", lineageValidated = false, disclosureReady = false }, os.time(), now)
	if changed or boostsChanged then
		if storage.handle then
			storage.status = "Autosave pending"
		end
		PlayerPlot.render(session.plot, session.transaction.state)
	end
end
ownershipChanged = function(userId)
	local player = Players:GetPlayerByUserId(userId)
	local session = if player then sessions[player] else nil
	if player and session then
		refreshCoinModifiers(player, session, os.clock())
		send(player, session, nil)
	end
end
local afk = AfkReconnect.create({
	now = os.clock,
	token = function()
		return HttpService:GenerateGUID(false)
	end,
	spawn = function(work)
		task.spawn(work)
	end,
	available = function(player)
		local session = sessions[player]
		return not RunService:IsStudio()
			and game.PlaceId > 0
			and game.PrivateServerId == ""
			and not shuttingDown
			and player.Parent == Players
			and session ~= nil
			and session.storage.handle ~= nil
			and session.storage.ready
			and not session.storage.transferring
			and not purchases.busy(player.UserId)
			and os.clock() < session.storage.safeUntil
	end,
	prepare = function(player)
		local session = sessions[player]
		if not session or shuttingDown or player.Parent ~= Players then
			return false
		end
		return Storage.prepareTeleport(session.storage)
	end,
	recover = function(player)
		local session = sessions[player]
		if not session or shuttingDown or player.Parent ~= Players then
			return false
		end
		local resumed = Storage.recoverTeleport(session.storage)
		if sessions[player] == session and player.Parent == Players then
			send(player, session, nil)
		end
		return resumed
	end,
	teleport = function(player, token, call)
		local session = sessions[player]
		assert(
			session
				and not shuttingDown
				and player.Parent == Players
				and session.storage.transferring
				and session.storage.released,
			"Profile handoff is not ready"
		)
		local options = Instance.new("TeleportOptions")
		-- Unspecified instance + no reservation uses public matchmaking for this place.
		options.ShouldReserveServer = false
		options:SetTeleportData({ afkReconnect = true, token = token, call = call })
		local ok, message = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		options:Destroy()
		if not ok then
			error(message)
		end
	end,
	notify = function(player, phase, token)
		if player.Parent == Players then
			afkRemote:FireClient(player, phase, token)
		end
	end,
	log = function(player, message)
		warn("AFK reconnect", player.UserId, message)
	end,
})
-- Admin callbacks below are non-yielding; target lookup, mutation and receipt commit
-- share the ordinary session state. Storage remains the only persistence writer.
local function adminTarget(userId: number): AdminService.Target?
	local player = Players:GetPlayerByUserId(userId)
	local session = if player then sessions[player] else nil
	if not session then
		return nil
	end
	local storage = session.storage
	return {
		state = session.transaction.state,
		plot = session.plot.index,
		ready = not shuttingDown
			and not storage.closed
			and storage.ready
			and not storage.transferring
			and os.clock() < storage.safeUntil,
		saveStatus = storage.status,
		persistent = storage.handle ~= nil,
		transferring = storage.transferring,
	}
end
local adminRandom = Random.new() -- dry runs do not consume the ordinary opening RNG stream
local admin = AdminService.create({
	now = os.clock,
	wall = os.time,
	token = function()
		return HttpService:GenerateGUID(false)
	end,
	random = function()
		return math.min(adminRandom:NextNumber(), 0.9999999999999999)
	end,
	target = adminTarget,
	players = function()
		local result: { AdminTypes.PlayerRow } = {}
		for _, player in Players:GetPlayers() do
			local session = sessions[player]
			local target = adminTarget(player.UserId)
			table.insert(result, {
				userId = player.UserId,
				username = player.Name,
				displayName = player.DisplayName,
				plot = if session then session.plot.index else nil,
				ready = target ~= nil and target.ready,
			})
		end
		table.sort(result, function(a, b)
			return a.username < b.username
		end)
		return result
	end,
	changed = function(userId)
		local player = Players:GetPlayerByUserId(userId)
		local session = if player then sessions[player] else nil
		if not player or not session then
			return
		end
		if session.storage.handle and not session.storage.busy then
			session.storage.status = "Autosave pending"
		end
		send(player, session, nil)
		PlayerPlot.render(session.plot, session.transaction.state)
	end,
	teleport = function(actorId, targetId)
		local actor, target =
			Players:GetPlayerByUserId(actorId), Players:GetPlayerByUserId(targetId)
		local session = if actor then sessions[actor] else nil
		local actorData = adminTarget(actorId)
		local character = if target then target.Character else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			not actor
			or not actorData
			or not actorData.ready
			or not session
			or not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
		then
			return false, "Both players need a ready session and a living character."
		end
		local ok, nextTime = HomeTeleport.travel(
			actor,
			root.CFrame * CFrame.new(3, 0, 3),
			session.homeTime,
			os.clock()
		)
		session.homeTime = nextTime
		return ok, if ok then "Teleported to player." else "Teleport unavailable; wait or respawn."
	end,
	kick = function(userId, reason)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return false, "Player has left."
		end
		player:Kick(reason)
		return true, "Player kicked. Normal departure saves their profile."
	end,
	log = function(row)
		print("BlindBox Admin", HttpService:JSONEncode(row))
	end,
})
adminRemote.OnServerInvoke = function(player: Player, raw: unknown): AdminTypes.Reply
	local ok, result = pcall(admin.receive, player.UserId, raw)
	if not ok then
		warn("Admin request failed; refresh before continuing.")
		return {
			ok = false,
			message = "Internal error. Refresh authoritative state before continuing.",
		}
	end
	return result
end
local function closeStorage(storage: Storage.Session)
	closing += 1
	local ok = Storage.close(storage)
	if not ok then
		warn("Profile final save was not confirmed; retained data and lease for recovery.")
	end
	closing -= 1
end
local function remove(player: Player)
	purchases.remove(player.UserId)
	admin.remove(player.UserId)
	afk.remove(player)
	local binding = movement[player]
	if binding then
		movement[player] = nil
		PlayerMovement.unbind(binding)
	end
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if session.spawn then
		PlayerSpawn.unbind(session.spawn)
	end
	-- Queued before the final save yields; the leaderboard flushes it in the background.
	Leaderboard.final(player.UserId, session.transaction.state)
	PlayerPlot.destroy(session.plot)
	PlotSlots.release(plots, player.UserId)
	closeStorage(session.storage)
end
local function added(player: Player)
	if sessions[player] or loading[player] or shuttingDown then
		return
	end
	-- Bind before profile loading yields: the initial plaza character also gets
	-- the baseline, independent of plot assignment or storage readiness.
	if not movement[player] then
		movement[player] = PlayerMovement.bind(player)
	end
	local plotIndex = PlotSlots.claim(plots, player.UserId)
	if not plotIndex then
		player:Kick("No plot is available. Please join another server.")
		return
	end
	loading[player] = true
	local storage, reason = Storage.open(player.UserId)
	loading[player] = nil
	if not storage then
		PlotSlots.release(plots, player.UserId)
		if player.Parent == Players then
			player:Kick(reason)
		end
		return
	end
	if shuttingDown or player.Parent ~= Players then
		PlotSlots.release(plots, player.UserId)
		closeStorage(storage)
		return
	end
	local transaction = Transactions.new(os.clock())
	transaction.state = storage.state
	-- Drop a previous window's stall purchases on load; every snapshot keeps it current.
	Deals.refresh(transaction.state, (dealClock()))
	local session: Session = {
		transaction = transaction,
		plot = PlayerPlot.create(player, plotIndex),
		storage = storage,
		sequence = 0,
		syncTime = -math.huge,
		homeTime = -math.huge,
		boostRequestTime = -math.huge,
		spawn = nil,
		afkPosition = nil,
		afkCharacter = nil,
	}
	sessions[player] = session
	task.spawn(purchases.add, player.UserId)
	afk.add(player)
	PlayerPlot.bind(session.plot, function(actor, direction)
		afk.activity(actor)
		if
			sessions[player] ~= session
			or not sessions[actor]
			or shuttingDown
			or not session.storage.ready
			or session.storage.transferring
			or os.clock() >= session.storage.safeUntil
		then
			return
		end
		if
			PlayerPlot.turn(session.plot, actor, session.transaction.state, direction, os.clock())
		then
			send(player, session, nil)
		end
	end)
	PlayerPlot.bindCollectors(session.plot, function(actor, slot, figure)
		if actor == player then
			afk.activity(player)
		end
		local now = os.clock()
		if
			actor ~= player
			or sessions[player] ~= session
			or shuttingDown
			or not storage.ready
			or storage.transferring
			or now >= storage.safeUntil
		then
			return
		end
		local reply, changed = Transactions.process(transaction, {
			action = "Collect",
			id = "collect:" .. HttpService:GenerateGUID(false),
			revision = transaction.state.revision,
			slot = slot,
			figure = figure,
		}, now, true, 0, math.floor(os.time() / 86400), nil, true)
		if changed and storage.handle and not storage.busy then
			storage.status = "Autosave pending"
		end
		if reply then
			send(player, session, reply)
		end
	end, function()
		return if sessions[player] == session
				and player.Parent == Players
				and not shuttingDown
				and storage.ready
				and not storage.transferring
				and os.clock() < storage.safeUntil
			then transaction.state
			else nil
	end)
	PlayerPlot.render(session.plot, storage.state)
	-- Respawns and character reloads land on this player's own spawn pad until they leave.
	session.spawn = PlayerSpawn.bind(player, session.plot.spawn)
	send(player, session, nil)
end
local connections: { RBXScriptConnection } = {}
table.insert(
	connections,
	afkRemote.OnServerEvent:Connect(function(player: Player, raw: unknown)
		afk.receive(player, raw)
	end)
)
table.insert(
	connections,
	TeleportService.TeleportInitFailed:Connect(
		function(
			player: Instance,
			result: Enum.TeleportResult,
			message: string,
			placeId: number,
			options: Instance
		)
			if
				not player:IsA("Player")
				or placeId ~= game.PlaceId
				or not options
				or not options:IsA("TeleportOptions")
			then
				return
			end
			local ok, data = pcall(function(): unknown
				return options:GetTeleportData()
			end)
			if ok and typeof(data) == "table" then
				local value = data :: { [string]: unknown }
				if
					value.afkReconnect == true
					and typeof(value.token) == "string"
					and typeof(value.call) == "number"
				then
					if AfkConfig.debug then
						print("AFK teleport failure", player.UserId, result.Name, message)
					end
					afk.failed(player, value.token, value.call)
				end
			end
		end
	)
)
table.insert(connections, Players.PlayerAdded:Connect(added))
table.insert(connections, Players.PlayerRemoving:Connect(remove))
-- Production figure templates load asynchronously; swap placeholders as each becomes ready.
table.insert(
	connections,
	productionModels:GetAttributeChangedSignal("FigureRevision"):Connect(function()
		for _, session in sessions do
			PlayerPlot.render(session.plot, session.transaction.state)
		end
	end)
)
for _, player in Players:GetPlayers() do
	task.spawn(added, player)
end
table.insert(
	connections,
	boostRequest.OnServerEvent:Connect(function(player: Player, raw: unknown)
		local session = sessions[player]
		local now = os.clock()
		if shuttingDown or not session or now - session.boostRequestTime < 1 then
			return
		end
		session.boostRequestTime = now
		-- Policy integration supplies current server eligibility here before paid effects can run.
		local result = BoostRuntime.activate(
			session.storage,
			raw,
			{ policy = "Unknown", lineageValidated = false, disclosureReady = false },
			os.time(),
			now
		)
		if sessions[player] == session and not shuttingDown and result then
			boostResult:FireClient(player, result)
			send(player, session, nil)
		end
	end)
)
table.insert(
	connections,
	syncRemote.OnServerEvent:Connect(function(player: Player)
		local session = sessions[player]
		local now = os.clock()
		if not session or now - session.syncTime < 1 then
			return
		end
		session.syncTime = now
		if
			session.storage.ready
			and not session.storage.transferring
			and now < session.storage.safeUntil
		then
			Rules.settle(session.transaction.state, now)
		end
		send(player, session, nil)
	end)
)
table.insert(
	connections,
	homeRemote.OnServerEvent:Connect(function(player: Player)
		afk.activity(player)
		local session = sessions[player]
		if not session or shuttingDown or session.storage.transferring then
			return
		end
		local _, nextRequest =
			HomeTeleport.request(player, session.plot, session.homeTime, os.clock())
		session.homeTime = nextRequest
	end)
)
local plazaTarget = HomeTeleport.plazaTarget(world.spawn)
table.insert(
	connections,
	plazaRemote.OnServerEvent:Connect(function(player: Player)
		afk.activity(player)
		local session = sessions[player]
		if not session or shuttingDown or session.storage.transferring then
			return
		end
		local _, nextRequest =
			HomeTeleport.travel(player, plazaTarget, session.homeTime, os.clock())
		session.homeTime = nextRequest
	end)
)
table.insert(
	connections,
	shelfEditorRemote.OnServerEvent:Connect(
		function(player: Player, rawOpen: unknown, rawToken: unknown)
			afk.activity(player)
			local session = sessions[player]
			if not session or shuttingDown or not session.plot.active then
				return
			end
			-- Resolve only the callback player's plot. Allow a close while storage is
			-- unavailable; no gameplay authority is granted by this presentation signal.
			ShelfShowcase.editor(session.plot.showcase, rawOpen, rawToken, os.clock())
			-- The regular bounded owner snapshot acknowledges the token AND latest view.
		end
	)
)
table.insert(
	connections,
	intentRemote.OnServerEvent:Connect(function(player: Player, raw: unknown)
		afk.activity(player)
		local session = sessions[player]
		if
			not session
			or shuttingDown
			or not session.storage.ready
			or session.storage.transferring
			or os.clock() >= session.storage.safeUntil
		then
			return
		end
		if purchases.busy(player.UserId) then
			local intent = Protocol.parse(raw)
			if intent and intent.action == "ClaimOffline" then
				send(player, session, {
					id = intent.id,
					ok = false,
					message = "Finish or cancel the purchase before claiming.",
				})
				return
			end
		end
		local beforeRevision = session.transaction.state.revision
		local reply, changed = Transactions.process(
			session.transaction,
			raw,
			os.clock(),
			PlayerPlot.canManage(session.plot, player),
			rolls(),
			math.floor(os.time() / 86400),
			PlayerPlot.access(session.plot, player),
			nil,
			(dealClock()),
			function(collection, value)
				return admin.consume(player.UserId, collection, value)
			end
		)
		if not reply then
			return
		end
		if changed then
			if typeof(raw) == "table" then
				local action = (raw :: { [string]: unknown }).action
				if action == "ShelfNext" or action == "ShelfPrevious" then
					ShelfShowcase.browse(session.plot.showcase, os.clock())
				end
			end
			PlayerPlot.render(session.plot, session.transaction.state)
			if
				session.storage.handle
				and not session.storage.busy
				and session.transaction.state.revision ~= beforeRevision
			then
				session.storage.status = "Autosave pending"
			end
		end
		send(player, session, reply)
	end)
)
local elapsed = 0
table.insert(
	connections,
	RunService.Heartbeat:Connect(function(delta: number)
		elapsed += delta
		if elapsed < 1 then
			return
		end
		elapsed = 0
		local now = os.clock()
		for player, session in sessions do
			refreshCoinModifiers(player, session, now)
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				if
					session.afkCharacter ~= character
					or (session.afkPosition and (root.Position - session.afkPosition).Magnitude > 1)
				then
					afk.activity(player)
				end
				session.afkPosition, session.afkCharacter = root.Position, character
			end
			Storage.step(session.storage, now)
			if session.storage.ready and not session.storage.transferring then
				Rules.settle(session.transaction.state, now)
				Leaderboard.observe(player.UserId, session.transaction.state, now)
				if now < session.storage.safeUntil then
					PlayerPlot.stepShowcase(session.plot, session.transaction.state, now)
				end
			end
		end
		admin.step()
		afk.step()
		for player, session in sessions do
			send(player, session, nil)
		end
	end)
)
game:BindToClose(function()
	shuttingDown = true
	purchases.destroy()
	afk.destroy()
	for player, binding in movement do
		PlayerMovement.unbind(binding)
		movement[player] = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	DayNight.stop(dayNight)
	for player in sessions do
		task.spawn(remove, player)
	end
	local deadline = os.clock() + 25
	local flushing = true
	task.spawn(function()
		Leaderboard.stop(os.clock() + 20)
		flushing = false
	end)
	while (next(sessions) or next(loading) or closing > 0 or flushing) and os.clock() < deadline do
		task.wait(0.1)
	end
	folder:Destroy()
	productionModels:Destroy()
	townModels:Destroy()
	world.root:Destroy()
end)

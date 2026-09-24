--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Types = require(ReplicatedStorage.Shared.Types)
local Rules = require(script.Rules)
local Economy = require(script.Economy)
local Transactions = require(script.Transactions)
local Rooms = require(script.Rooms)
local Storage = require(script.Storage)
local Settings = require(script.Settings)
local World = require(script.World)
local gardens = World.create()
type Session = {
	transaction: Transactions.Session,
	room: Rooms.Room,
	storage: Storage.Session,
	sequence: number,
	syncTime: number,
	visitTime: number,
	visiting: number,
	characterConnection: RBXScriptConnection?,
	spawnTask: thread?,
}
local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local closing = 0
local shuttingDown = false
local directory: { Types.PublicRoom } = {}
local random = Random.new()
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
local visitRemote = remote("Visit")
local noticeRemote = remote("Notice")
folder.Parent = ReplicatedStorage
local function send(player: Player, session: Session, reply: Types.Reply?)
	session.sequence += 1
	local state = session.transaction.state
	local day = math.floor(os.time() / 86400)
	Rules.refreshDay(state, day)
	local snapshot: Types.Snapshot = {
		coins = state.coins,
		scrap = state.scrap,
		owned = table.clone(state.owned),
		discovered = table.clone(state.discovered),
		slots = table.clone(state.slots),
		revision = state.revision,
		sequence = session.sequence,
		rate = Rules.rate(state),
		step = state.step,
		rates = Rules.rates,
		odds = Rules.odds,
		price = Economy.price,
		redeemCost = Economy.redeemCost,
		unlocked = state.unlocked,
		theme = state.theme,
		themes = table.clone(state.themes),
		expansionCost = Economy.expansionCost,
		themeCost = Economy.themeCost,
		dailyReady = state.lastDailyDay < day,
		goalProgress = state.goalProgress,
		goalClaimed = state.goalClaimed,
		goalReward = Economy.goalReward,
		nextDay = (day + 1) * 86400,
		saveStatus = session.storage.status,
		ready = session.storage.ready,
		rooms = directory,
		visiting = session.visiting,
		bonus = Rules.bonus(state),
	}
	stateRemote:FireClient(player, snapshot, reply)
end
local function home(player: Player, session: Session)
	session.visiting = player.UserId
	if player.Character then
		player.Character:PivotTo(session.room.spawn)
	end
end
local function closeStorage(storage: Storage.Session)
	closing += 1
	local ok = Storage.close(storage)
	if not ok then
		warn("Showroom final save was not confirmed; retained data and lease for recovery.")
	end
	closing -= 1
end
local function remove(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if session.characterConnection then
		session.characterConnection:Disconnect()
	end
	if session.spawnTask and coroutine.status(session.spawnTask) ~= "dead" then
		task.cancel(session.spawnTask)
	end
	for guest, other in sessions do
		if other.visiting == player.UserId then
			home(guest, other)
		end
	end
	Rooms.destroy(session.room)
	closeStorage(session.storage)
end
local function added(player: Player)
	if sessions[player] or loading[player] or shuttingDown then
		return
	end
	local count = 0
	for _ in sessions do
		count += 1
	end
	for _ in loading do
		count += 1
	end
	if count >= Settings.maxRooms then
		player:Kick("This showroom lane is full. Please join another server.")
		return
	end
	loading[player] = true
	local storage, reason = Storage.open(player.UserId)
	loading[player] = nil
	if not storage then
		if player.Parent == Players then
			player:Kick(reason)
		end
		return
	end
	if shuttingDown or player.Parent ~= Players then
		closeStorage(storage)
		return
	end
	local transaction = Transactions.new(os.clock())
	transaction.state = storage.state
	local session: Session = {
		transaction = transaction,
		room = Rooms.create(player),
		storage = storage,
		sequence = 0,
		syncTime = -math.huge,
		visitTime = -math.huge,
		visiting = player.UserId,
		characterConnection = nil,
		spawnTask = nil,
	}
	sessions[player] = session
	Rooms.render(session.room, storage.state)
	local function characterAdded(character: Model)
		if session.spawnTask and coroutine.status(session.spawnTask) ~= "dead" then
			task.cancel(session.spawnTask)
		end
		session.spawnTask = task.defer(function()
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if rootPart and sessions[player] == session and player.Character == character then
				home(player, session)
			end
			session.spawnTask = nil
		end)
	end
	session.characterConnection = player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		characterAdded(player.Character)
	end
	send(player, session, nil)
end
local connections: { RBXScriptConnection } = {}
table.insert(connections, Players.PlayerAdded:Connect(added))
table.insert(connections, Players.PlayerRemoving:Connect(remove))
for _, player in Players:GetPlayers() do
	task.spawn(added, player)
end
table.insert(
	connections,
	syncRemote.OnServerEvent:Connect(function(player: Player)
		local session = sessions[player]
		local now = os.clock()
		if not session or now - session.syncTime < 1 then
			return
		end
		session.syncTime = now
		if session.storage.ready and now < session.storage.safeUntil then
			Rules.settle(session.transaction.state, now)
		end
		send(player, session, nil)
	end)
)
table.insert(
	connections,
	intentRemote.OnServerEvent:Connect(function(player: Player, raw: unknown)
		local session = sessions[player]
		if
			not session
			or shuttingDown
			or not session.storage.ready
			or os.clock() >= session.storage.safeUntil
		then
			return
		end
		local reply, changed = Transactions.process(
			session.transaction,
			raw,
			os.clock(),
			Rooms.near(session.room, player),
			math.min(random:NextNumber(), 0.9999999999999999),
			math.floor(os.time() / 86400)
		)
		if not reply then
			return
		end
		if changed then
			Rooms.render(session.room, session.transaction.state)
			if session.storage.handle and not session.storage.busy then
				session.storage.status = "Autosave pending"
			end
		end
		send(player, session, reply)
	end)
)
table.insert(
	connections,
	visitRemote.OnServerEvent:Connect(function(player: Player, target: unknown)
		local session = sessions[player]
		if not session or os.clock() - session.visitTime < 2 then
			return
		end
		session.visitTime = os.clock()
		if typeof(target) ~= "number" or target % 1 ~= 0 or math.abs(target) > 9007199254740991 then
			return
		end
		local host = if target == 0 then player else Players:GetPlayerByUserId(target)
		local other = if host then sessions[host] else nil
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not other or not character or not humanoid or humanoid.Health <= 0 then
			noticeRemote:FireClient(player, "That showroom is no longer available.")
			return
		end
		session.visiting = (host :: Player).UserId
		character:PivotTo(other.room.spawn)
		send(player, session, nil)
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
		directory = {}
		for player, session in sessions do
			Storage.step(session.storage, now)
			if session.storage.ready then
				Rules.settle(session.transaction.state, now)
			end
			local state = session.transaction.state
			table.insert(directory, {
				userId = player.UserId,
				name = player.DisplayName,
				rate = Rules.rate(state),
				slots = table.clone(state.slots),
				theme = state.theme,
			})
		end
		table.sort(directory, function(a, b)
			return a.userId < b.userId
		end)
		for player, session in sessions do
			send(player, session, nil)
		end
	end)
)
game:BindToClose(function()
	shuttingDown = true
	for _, connection in connections do
		connection:Disconnect()
	end
	for player in sessions do
		task.spawn(remove, player)
	end
	local deadline = os.clock() + 25
	while (next(sessions) or next(loading) or closing > 0) and os.clock() < deadline do
		task.wait(0.1)
	end
	folder:Destroy()
	gardens:Destroy()
end)

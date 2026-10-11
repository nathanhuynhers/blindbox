--!strict
local A = require(game:GetService("ReplicatedStorage").Shared.AdminTypes)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(script.Parent.AdminConfig)
local Protocol = require(script.Parent.AdminProtocol)
local Rules = require(script.Parent.Rules)
local Economy = require(script.Parent.Economy)
local CollectionEconomy = require(script.Parent.CollectionEconomy)
local Profile = require(script.Parent.Profile)
local Overrides = require(script.Parent.AdminOverrides)
local Service = {}
export type Target = {
	state: Types.State,
	plot: number,
	ready: boolean,
	saveStatus: string,
	persistent: boolean,
	transferring: boolean,
}
export type Dependencies = {
	now: () -> number,
	wall: () -> number,
	token: () -> string,
	players: () -> { A.PlayerRow },
	target: (number) -> Target?,
	changed: (number) -> (),
	teleport: (number, number) -> (boolean, string),
	kick: (number, string) -> (boolean, string),
	random: () -> number,
	log: (A.Audit) -> (),
}
type Access = {
	token: string,
	sequence: number,
	tokens: number,
	time: number,
	last: A.Request?,
	reply: A.Reply?,
}
export type Controller = {
	receive: (number, unknown) -> A.Reply,
	remove: (number) -> (),
	consume: (number, string, number) -> string?,
	step: () -> (),
}
local function failure(message: string): A.Reply
	return { ok = false, message = message }
end
function Service.create(deps: Dependencies): Controller
	local access: { [number]: Access } = {}
	local overrides: Overrides.Store = {}
	local audit: { A.Audit } = {}
	local function record(
		admin: number,
		request: A.Request?,
		ok: boolean,
		message: string,
		action: string?
	)
		local row: A.Audit = {
			timestamp = deps.wall(),
			admin = admin,
			action = action or (if request then request.action else "Rejected"),
			target = if request then request.target else nil,
			amount = if request then request.amount else nil,
			quantity = if request then request.quantity else nil,
			figure = if request then request.figure else nil,
			collection = if request then request.collection else nil,
			rarity = if request then request.rarity else nil,
			ok = ok,
			message = message,
		}
		table.insert(audit, row)
		if #audit > Config.auditLimit then
			table.remove(audit, 1)
		end
		-- Logging cannot break an already-preflighted opening or administrative transaction.
		pcall(deps.log, row)
	end
	local function snapshot(userId: number): A.Inspector?
		local target = deps.target(userId)
		if not target then
			return nil
		end
		local state = target.state
		local profile = Profile.encode(state) -- existing deep-copy path; never expose a lease/token
		local active = Overrides.peek(overrides, userId, deps.now())
		return {
			userId = userId,
			revision = state.revision,
			coins = state.coins,
			owned = profile.owned,
			discovered = profile.discovered,
			display = profile.display,
			shelves = profile.shelves,
			pity = profile.pityByGroup,
			earnings = profile.earnings,
			rate = Rules.rate(state),
			bonus = Rules.bonus(state),
			boxesOpened = state.boxesOpened,
			step = state.step,
			loginStreak = state.loginStreak,
			goalProgress = state.goalProgress,
			offlinePending = state.offlinePending,
			plot = target.plot,
			ready = target.ready,
			saveStatus = target.saveStatus,
			persistent = target.persistent,
			transferring = target.transferring,
			override = if active then table.clone(active) else nil,
		}
	end
	local function boxes(pity: { [string]: Types.Pity }): { A.Box }
		local result: { A.Box } = {}
		for _, collection in Catalog.collections do
			local config = Economy.collections[collection.id]
			local curves: { [string]: { base: number, start: number, increment: number, guarantee: number } }? =
				nil
			if config.pity then
				local defined: { [string]: { base: number, start: number, increment: number, guarantee: number } } =
					{}
				for rarity, curve in Economy.pity[config.pity] do
					defined[rarity] = {
						base = curve.base,
						start = curve.start,
						increment = curve.increment,
						guarantee = curve.start + math.ceil((100 - curve.base) / curve.increment),
					}
				end
				curves = defined
			end
			table.insert(result, {
				id = collection.id,
				price = Rules.prices[collection.id],
				group = config.group,
				base = table.clone(Economy.buckets[config.buckets]),
				effective = CollectionEconomy.buckets(collection.id, pity),
				pity = curves,
			})
		end
		return result
	end
	local handlers: { [string]: (number, A.Request, Target) -> (boolean, string, { [string]: number }?) } =
		{}
	for _, action in { "GrantCoins", "RemoveCoins", "SetBalance" } do
		handlers[action] = function(_, request, target)
			local amount = request.amount :: number
			local change = if request.action == "SetBalance"
				then math.abs(target.state.coins - amount)
				else amount
			if change >= Config.largeChange and request.confirmed ~= true then
				return false, "Confirm this large Coin change.", nil
			end
			if change > Config.transactionLimit then
				return false, "Change exceeds the transaction limit.", nil
			end
			local ok, message = Rules.adminCoins(target.state, request.action, amount, deps.now())
			return ok, message, nil
		end
	end
	for _, action in { "GrantFigure", "RemoveFigure", "GrantCollection" } do
		handlers[action] = function(_, request, target)
			local remove = request.action == "RemoveFigure"
			if
				(remove or request.action == "GrantCollection" or (request.quantity or 1) > 1)
				and request.confirmed ~= true
			then
				return false, "Confirm this inventory change.", nil
			end
			local ids: { string } = {}
			if request.action == "GrantCollection" then
				for _, figure in Catalog.figures do
					if figure.collection == request.collection then
						table.insert(ids, figure.id)
					end
				end
			else
				table.insert(ids, request.figure :: string)
			end
			local ok, message =
				Rules.adminFigures(target.state, ids, request.quantity or 1, remove, deps.now())
			return ok, message, nil
		end
	end
	for _, action in { "SetPity", "ResetPity" } do
		handlers[action] = function(_, request, target)
			if request.confirmed ~= true then
				return false, "Confirm the pity change.", nil
			end
			if request.action == "ResetPity" then
				local ok, message =
					Rules.adminPity(target.state, request.collection :: string, "Legendary", 0)
				if ok then
					Rules.adminPity(target.state, request.collection :: string, "Mythical", 0)
				end
				return ok, message, nil
			end
			local ok, message = Rules.adminPity(
				target.state,
				request.collection :: string,
				request.rarity :: string,
				request.amount :: number
			)
			return ok, message, nil
		end
	end
	for _, action in { "ForceFigure", "ForceRarity", "ClearOverride" } do
		handlers[action] = function(admin, request, _)
			local id = request.target :: number
			if request.action == "ClearOverride" then
				overrides[id] = nil
				return true, "Override cleared.", nil
			end
			if request.confirmed ~= true then
				return false, "Confirm the next-opening override.", nil
			end
			local collection = request.collection :: string
			if request.figure and Catalog.byId[request.figure].collection ~= collection then
				return false, "Figure is not eligible for this box.", nil
			end
			if
				request.rarity
				and not Economy.buckets[Economy.collections[collection].buckets][request.rarity]
			then
				return false, "Rarity is not eligible for this box.", nil
			end
			overrides[id] = {
				collection = collection,
				figure = request.figure,
				rarity = request.rarity,
				expires = deps.now() + Config.overrideSeconds,
				admin = admin,
			}
			return true, "One opening override armed for five minutes.", nil
		end
	end
	handlers.Inspect = function()
		return true, "Authoritative state refreshed.", nil
	end
	handlers.Teleport = function(admin, request)
		local ok, message = deps.teleport(admin, request.target :: number)
		return ok, message, nil
	end
	handlers.Kick = function(_, request)
		if request.confirmed ~= true then
			return false, "Confirm kicking this player.", nil
		end
		local ok, message =
			deps.kick(request.target :: number, request.reason or "Removed by the game owner.")
		return ok, message, nil
	end
	handlers.Simulate = function(_, request, target)
		local pity: { [string]: Types.Pity } = {}
		for group, value in target.state.pityByGroup do
			pity[group] = table.clone(value)
		end
		local counts: { [string]: number } = {}
		for _ = 1, request.amount :: number do
			local id = CollectionEconomy.roll(deps.random(), request.collection :: string, pity)
			local rarity = Catalog.byId[id].rarity
			counts[rarity] = (counts[rarity] or 0) + 1
			CollectionEconomy.advance(pity, request.collection :: string, id)
		end
		return true,
			"Dry run complete. Pity evolved on a private copy; active overrides excluded.",
			counts
	end
	for action in Protocol.commands do
		assert(handlers[action], "Missing admin handler: " .. action)
	end
	return {
		receive = function(admin: number, raw: unknown): A.Reply
			if not Protocol.allowed(admin, "Owner") then
				-- Aggregate unauthorized spam per connection: bounded memory and output volume.
				if not access[admin] then
					access[admin] = { token = "", sequence = 0, tokens = 0, time = deps.now() }
					record(admin, nil, false, "Unauthorized")
				end
				return failure("Unauthorized")
			end
			local current = access[admin]
			if not current then
				current = { token = deps.token(), sequence = 0, tokens = 4, time = deps.now() }
				access[admin] = current
			end
			local now = deps.now()
			current.tokens = math.min(4, current.tokens + math.max(0, now - current.time) * 2)
			current.time = now
			if current.tokens < 1 then
				return failure("Rate limited. Wait and try again.")
			end
			current.tokens -= 1
			-- Bootstrap grants no mutation. Repeated bootstrap never resets replay protection.
			if raw == "Connect" then
				return {
					ok = true,
					message = "Owner access",
					token = current.token,
					sequence = current.sequence,
					players = deps.players(),
					boxes = boxes({}),
					audit = table.clone(audit),
					largeChange = Config.largeChange,
					transactionLimit = Config.transactionLimit,
				}
			end
			local request = Protocol.parse(raw)
			if
				not request
				or request.token ~= current.token
				or not Protocol.allowed(admin, Protocol.commands[request.action].permission)
			then
				record(admin, request, false, "Malformed request or invalid session token")
				return failure("Malformed request or invalid session token")
			end
			if
				request.sequence == current.sequence
				and current.last
				and Protocol.same(request, current.last)
			then
				return current.reply :: A.Reply
			end
			if request.sequence <= current.sequence then
				record(admin, request, false, "Replayed request")
				return failure("Replayed request")
			end
			-- Watermark survives receipt replacement; old requests can never execute again.
			current.sequence = request.sequence
			current.last = request
			current.reply = failure("Execution did not complete; refresh authoritative state.")
			local target = deps.target(request.target :: number)
			local beforeRevision = if target then target.state.revision else -1
			local reply: A.Reply
			if not target then
				reply = failure("Player has left or their profile is not loaded.")
			elseif
				Protocol.commands[request.action].mutation
				and (not target.ready or target.transferring)
			then
				reply = failure("Target data session is not writable.")
			elseif
				Protocol.commands[request.action].mutation
				and request.revision ~= target.state.revision
			then
				reply = failure("State changed. Refresh before confirming again.")
			else
				local ok, message, simulation = handlers[request.action](admin, request, target)
				reply = { ok = ok, message = message, simulation = simulation }
			end
			if Protocol.commands[request.action].mutation or not reply.ok then
				record(admin, request, reply.ok, reply.message)
			end
			if reply.ok and target and target.state.revision ~= beforeRevision then
				-- The mutation/audit has committed. Presentation failure never permits a second execution.
				local synchronized = pcall(deps.changed, request.target :: number)
				if not synchronized then
					reply.message ..= " Presentation refresh failed; refresh the inspector."
				end
			end
			reply.inspector = snapshot(request.target :: number)
			reply.players = deps.players()
			reply.boxes = boxes(if reply.inspector then reply.inspector.pity else {})
			reply.audit = table.clone(audit)
			reply.sequence = current.sequence
			current.reply = reply
			return reply
		end,
		remove = function(userId)
			access[userId] = nil
			overrides[userId] = nil
		end,
		consume = function(userId, collection, value)
			local active = Overrides.peek(overrides, userId, deps.now())
			local figure = Overrides.consume(overrides, userId, collection, value, deps.now())
			if figure and active then
				local consumed: A.Request = {
					token = "",
					sequence = 0,
					action = "OverrideConsumed",
					target = userId,
					collection = collection,
					figure = figure,
					rarity = Catalog.byId[figure].rarity,
				}
				record(
					active.admin,
					consumed,
					true,
					`Target {userId}, box {collection}, figure {figure}`,
					"OverrideConsumed"
				)
			end
			return figure
		end,
		step = function()
			for userId in overrides do
				Overrides.peek(overrides, userId, deps.now())
			end
		end,
	}
end
return Service

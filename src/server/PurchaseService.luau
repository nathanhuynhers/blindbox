--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Config = require(script.Parent.PurchaseConfig)
local Ledger = require(script.Parent.PurchaseLedger)
local Entitlements = require(script.Parent.Entitlements)
local Protocol = require(script.Parent.PurchaseProtocol)
local Availability = require(script.Parent.PurchaseAvailability)
export type Dependencies = {
	now: () -> number,
	ready: (number) -> boolean,
	update: Ledger.Update,
	owns: (number, number) -> boolean,
	-- false means no native prompt was attempted; thrown errors are uncertain.
	prompt: (number, Config.Product) -> boolean,
	-- Product implementation must preflight all policy/lineage/capacity/disclosure dependencies.
	eligible: (number, Config.Product) -> boolean,
	send: (number, Types.Snapshot, Types.Result?) -> (),
}
type Session = {
	entitlements: Entitlements.State,
	ledger: Ledger.Record?,
	ledgerStatus: string,
	prompt: string?,
	awaiting: boolean,
	promptReceipt: boolean,
	working: boolean,
	tokens: number,
	time: number,
	sequence: number,
	requests: { [string]: { action: string, product: string?, result: Types.Result } },
	requestCount: number,
	nextRefresh: number,
}
local Service = {}
function Service.create(deps: Dependencies, products: { Config.Product })
	Config.validate(products)
	local sessions: { [number]: Session } = {}
	local configured = false
	for _, product in products do
		if Config.configured(product) then
			configured = true
		end
	end
	local function find(key: string): Config.Product?
		for _, product in products do
			if product.key == key then
				return product
			end
		end
		return nil
	end
	local function byId(id: number, kind: Types.PlatformKind): Config.Product?
		for _, product in products do
			if product.platformId == id and product.kind == kind then
				return product
			end
		end
		return nil
	end
	local function snapshot(userId: number, session: Session): Types.Snapshot
		local reserved, count, fulfilled = Ledger.summary(session.ledger or Ledger.empty())
		local highest = 1
		for _, product in products do
			local ownership = Entitlements.view(session.entitlements, product.key)
			if ownership == "Owned" and product.coinTier then
				highest = math.max(highest, product.coinTier)
			end
		end
		local states: { Types.ProductState } = {}
		for _, product in products do
			local ownership: Types.Ownership
			local fresh: boolean
			ownership, fresh = Entitlements.view(session.entitlements, product.key)
			local eligible = false
			if product.integrationReady and deps.ready(userId) then
				local ok, value = pcall(deps.eligible, userId, product)
				eligible = ok and value == true
			end
			local reason = Availability.reason(product, {
				ready = deps.ready(userId),
				ledgerReady = session.ledger ~= nil and session.ledgerStatus == "Ready",
				ledgerCount = count,
				ownership = ownership,
				fresh = fresh,
				highestCoinTier = highest,
				prompt = session.prompt ~= nil or session.working,
				eligible = eligible,
			})
			table.insert(states, {
				key = product.key,
				kind = product.kind,
				platformId = product.platformId,
				available = reason == "Available",
				reason = reason,
				ownership = ownership,
				ownershipFresh = fresh,
				fulfillment = if session.ledgerStatus == "Recovering"
					then "Recovering"
					elseif session.prompt == product.key then "Pending"
					elseif fulfilled[product.key] then "Reserved"
					else "None",
			})
		end
		session.sequence += 1
		return {
			sequence = session.sequence,
			ready = deps.ready(userId),
			ledgerStatus = session.ledgerStatus,
			promptProduct = session.prompt,
			products = states,
			reserved = reserved,
			receiptCount = count,
		}
	end
	local function send(userId: number, session: Session, result: Types.Result?)
		if sessions[userId] == session then
			deps.send(userId, snapshot(userId, session), result)
		end
	end
	local function refresh(userId: number, session: Session)
		if session.working or not deps.ready(userId) or deps.now() < session.nextRefresh then
			return
		end
		session.nextRefresh = deps.now() + 10
		session.working = true
		if configured then
			local record = Ledger.load(deps.update, userId)
			if record then
				session.ledger = record
			end
			session.ledgerStatus = if record then "Ready" else "Recovering"
		end
		for _, product in products do
			if sessions[userId] ~= session or not deps.ready(userId) then
				break
			end
			if product.kind == "Pass" and Config.configured(product) then
				Entitlements.refresh(
					session.entitlements,
					product.key,
					userId,
					product.platformId :: number,
					deps.owns
				)
			end
		end
		session.working = false
		send(userId, session, nil)
	end
	local api = {}
	function api.add(userId: number)
		-- A new join gets a new object; late replies cannot update a replacement session.
		local session: Session = {
			entitlements = {},
			ledger = if configured then nil else Ledger.empty(),
			ledgerStatus = if configured then "Loading" else "Disabled",
			prompt = nil,
			awaiting = false,
			promptReceipt = false,
			working = false,
			tokens = 4,
			time = deps.now(),
			sequence = 0,
			requests = {},
			requestCount = 0,
			nextRefresh = -math.huge,
		}
		sessions[userId] = session
		refresh(userId, session)
	end
	function api.remove(userId: number)
		sessions[userId] = nil
	end
	-- Server consumers resolve authority here; never read client snapshots as proof.
	function api.ownership(userId: number, key: string): (Types.Ownership, boolean)
		local session = sessions[userId]
		if session then
			return Entitlements.view(session.entitlements, key)
		end
		local unknown: Types.Ownership = "Unknown"
		return unknown, false
	end
	function api.refresh(userId: number)
		local session = sessions[userId]
		if session then
			refresh(userId, session)
		end
	end
	function api.request(userId: number, raw: unknown)
		local session = sessions[userId]
		if not session then
			return
		end
		local now = deps.now()
		session.tokens = math.min(4, session.tokens + math.max(0, now - session.time))
		session.time = now
		if session.tokens < 1 then
			return
		end
		session.tokens -= 1
		local request = Protocol.parse(raw)
		if not request then
			return
		end
		if request.action ~= "Purchase" then
			if request.action == "Refresh" then
				refresh(userId, session)
			end
			send(userId, session, { id = request.id, status = "State", reason = "Snapshot" })
			return
		end
		local prior = session.requests[request.id]
		if prior then
			if prior.action == request.action and prior.product == request.product then
				send(userId, session, prior.result)
			else
				send(userId, session, {
					id = request.id,
					product = request.product,
					status = "Rejected",
					reason = "RequestIdReused",
				})
			end
			return
		end
		local result: Types.Result = {
			id = request.id,
			product = request.product,
			status = "Rejected",
			reason = "Unavailable",
		}
		-- Bound retained request IDs without evicting IDs that could open a second prompt.
		if session.requestCount >= 256 then
			result.reason = "RequestCapacity"
			send(userId, session, result)
			return
		end
		session.requests[request.id] =
			{ action = request.action, product = request.product, result = result }
		session.requestCount += 1
		do
			local product = find(request.product :: string)
			if not product then
				result.reason = "UnknownProduct"
			else
				local view = snapshot(userId, session)
				for _, state in view.products do
					if state.key == product.key then
						result.reason = state.reason
					end
				end
				if result.reason == "Available" then
					-- Acquire before the platform call yields. Recheck authoritative readiness after eligibility.
					if sessions[userId] ~= session or session.prompt ~= nil or session.working then
						result.reason = "PurchasePending"
					elseif not deps.ready(userId) then
						result.reason = "ProfileUnavailable"
					else
						session.prompt, session.awaiting, session.promptReceipt =
							product.key, false, false
						local ok, opened = pcall(deps.prompt, userId, product)
						if ok and opened then
							result.status, result.reason = "PromptOpened", "PlatformPrompt"
						elseif ok then
							session.prompt = nil
							result.reason = "PlatformUnavailable"
						else
							-- An uncertain prompt error cannot authorize another prompt automatically.
							result.status, result.reason = "Recovering", "PromptUncertain"
						end
					end
				end
			end
		end
		send(userId, session, result)
	end
	function api.finished(userId: number, id: number, kind: Types.PlatformKind, purchased: boolean)
		local session = sessions[userId]
		local product = byId(id, kind)
		if not session or not product then
			return
		end
		if kind == "Pass" then
			-- Event is only a refresh trigger, never ownership proof (even if purchased=true).
			Entitlements.refresh(session.entitlements, product.key, userId, id, deps.owns)
		elseif session.prompt == product.key then
			session.awaiting = purchased
			if purchased and session.promptReceipt then
				session.prompt = nil
			end
		end
		if session.prompt == product.key and (kind == "Pass" or not purchased) then
			session.prompt = nil
		end
		send(userId, session, {
			id = "platform",
			product = product.key,
			status = if kind == "Pass"
				then "State"
				elseif purchased then "AwaitingReceipt"
				else "Cancelled",
			reason = if kind == "Pass" then "OwnershipRefreshed" else "PromptClosed",
		})
	end
	function api.receipt(raw: unknown): boolean
		local receipt = Ledger.receipt(raw)
		if not receipt then
			return false
		end
		local product = byId(receipt.productId, "DeveloperProduct")
		-- Recovery ignores sales, policy, price, wallet space and transient prompt state.
		if not product or not product.grant then
			return false
		end
		local session = sessions[receipt.userId]
		if not session or session.working or not deps.ready(receipt.userId) then
			return false
		end
		session.working = true
		local record =
			Ledger.commit(deps.update, receipt.userId, "receipt:" .. receipt.purchaseId, {
				product = product.key,
				platformId = receipt.productId,
				kind = "DeveloperProduct",
				grant = product.grant,
			})
		session.working = false
		if record then
			session.ledger, session.ledgerStatus = record, "Ready"
			if session.prompt == product.key then
				session.promptReceipt = true
				if session.awaiting then
					session.prompt, session.awaiting = nil, false
				end
			end
		else
			session.ledgerStatus = "Recovering"
		end
		send(receipt.userId, session, {
			id = receipt.purchaseId,
			product = product.key,
			status = if record then "Reserved" else "Recovering",
			reason = if record then "DurableRewardReserved" else "SaveUnconfirmed",
		})
		return record ~= nil
	end
	-- Server-only once-per-account bundle reconciliation. Product modules decide when
	-- to invoke this; pass events and clients cannot mint a grant.
	function api.claimPass(userId: number, key: string): boolean
		local session, product = sessions[userId], find(key)
		if
			not session
			or not product
			or product.kind ~= "Pass"
			or not product.grant
			or not Config.configured(product)
			or session.working
			or not deps.ready(userId)
		then
			return false
		end
		local owned, fresh = Entitlements.view(session.entitlements, key)
		if owned ~= "Owned" or not fresh then
			return false
		end
		session.working = true
		local record = Ledger.commit(deps.update, userId, "pass:" .. tostring(product.platformId), {
			product = key,
			platformId = product.platformId :: number,
			kind = "Pass",
			grant = product.grant,
		})
		session.working = false
		if record then
			session.ledger, session.ledgerStatus = record, "Ready"
		else
			session.ledgerStatus = "Recovering"
		end
		send(userId, session, nil)
		return record ~= nil
	end
	return api
end
return Service

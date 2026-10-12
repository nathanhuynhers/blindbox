--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.PurchaseConfig)
local Service = require(script.Parent.PurchaseService)
local Storage = require(script.Parent.Storage)
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Ledger = require(script.Parent.PurchaseLedger)
export type Integration = {
	eligible: (number, Config.Product) -> boolean,
	prepare: (number, Config.Product) -> boolean,
	fulfill: (Ledger.Receipt, Config.Product) -> boolean?,
	deliverReserved: ((number, string, Ledger.Entry) -> boolean?)?,
	packageState: ((number, Config.Product) -> Types.PackageState?)?,
}
local Runtime = {}
function Runtime.start(
	folder: Folder,
	sessionFor: (Player) -> Storage.Session?,
	ownershipChanged: ((number) -> ())?,
	integration: Integration?
)
	local request = Instance.new("RemoteEvent")
	request.Name, request.Parent = "PurchaseRequest", folder
	local state = Instance.new("RemoteEvent")
	state.Name, state.Parent = "PurchaseState", folder
	local store: GlobalDataStore? = nil
	local alive = true
	local owners: { [number]: boolean } = {}
	local refreshTask: thread? = nil
	local function ready(userId: number): boolean
		local player = Players:GetPlayerByUserId(userId)
		local session = if player then sessionFor(player) else nil
		return session ~= nil
			and session.handle ~= nil
			and session.ready
			and not session.closed
			and not session.transferring
			and not session.busy
			and session.pendingSave == nil
			and session.pendingRelease == nil
			and os.clock() < session.safeUntil
	end
	local service = Service.create({
		ownershipChanged = ownershipChanged,
		prepare = if integration then integration.prepare else nil,
		fulfill = if integration then integration.fulfill else nil,
		deliverReserved = if integration then integration.deliverReserved else nil,
		packageState = if integration then integration.packageState else nil,
		now = os.clock,
		ready = ready,
		update = function(key, transform)
			-- No paid store is accessed at all while every product ID is absent.
			if not store then
				store = DataStoreService:GetDataStore(
					if RunService:IsStudio() then Config.studioStore else Config.liveStore
				)
			end
			return (store :: GlobalDataStore):UpdateAsync(key, transform)
		end,
		owns = function(userId, passId)
			return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
		end,
		prompt = function(userId, product)
			local player = Players:GetPlayerByUserId(userId)
			assert(player and ready(userId), "Purchase owner unavailable")
			local profile = sessionFor(player)
			local id = product.platformId :: number
			local kind = if product.kind == "Pass"
				then Enum.InfoType.GamePass
				else Enum.InfoType.Product
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, kind)
			end)
			if
				not ok
				or info.IsForSale ~= true
				or not ready(userId)
				or Players:GetPlayerByUserId(userId) ~= player
				or sessionFor(player) ~= profile
			then
				return false
			end
			-- Metadata lookup yields. Recheck policy/capacity immediately before the native prompt.
			if
				not integration
				or not integration.eligible(userId, product)
				or not ready(userId)
			then
				return false
			end
			if product.kind == "Pass" then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
			return true
		end,
		-- Intentionally closed until separately approved product integrations register
		-- authoritative policy, lineage, capacity and disclosure preflight here.
		eligible = function(userId, product)
			return integration ~= nil and integration.eligible(userId, product)
		end,
		send = function(userId, snapshot: Types.Snapshot, result: Types.Result?)
			local player = Players:GetPlayerByUserId(userId)
			if player then
				state:FireClient(player, snapshot, result)
			end
		end,
	}, Config.products)
	local connections: { RBXScriptConnection } = {}
	table.insert(
		connections,
		request.OnServerEvent:Connect(function(player: Player, raw: unknown)
			-- Callback Player is the sole identity source. No client completion endpoint.
			service.request(player.UserId, raw)
		end)
	)
	table.insert(
		connections,
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
			service.finished(player.UserId, id, "Pass", purchased)
		end)
	)
	table.insert(
		connections,
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, id, purchased)
			-- Presentation only. This event cannot fulfill a purchase.
			service.finished(userId, id, "DeveloperProduct", purchased)
		end)
	)
	MarketplaceService.ProcessReceipt = function(receipt)
		return if service.receipt(receipt)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local configured = false
	for _, product in Config.products do
		if Config.configured(product) then
			configured = true
		end
	end
	if configured then
		refreshTask = task.spawn(function()
			while alive do
				task.wait(30)
				if not alive then
					break
				end
				for userId in owners do
					task.spawn(service.refresh, userId)
				end
			end
		end)
	end
	return {
		add = function(userId: number)
			owners[userId] = true
			service.add(userId)
		end,
		remove = function(userId: number)
			owners[userId] = nil
			service.remove(userId)
		end,
		claimPass = service.claimPass,
		busy = service.busy,
		ownership = service.ownership,
		destroy = function()
			alive = false
			if refreshTask then
				task.cancel(refreshTask)
				refreshTask = nil
			end
			for userId in owners do
				service.remove(userId)
			end
			table.clear(owners)
			for _, connection in connections do
				connection:Disconnect()
			end
			request:Destroy()
			state:Destroy()
			MarketplaceService.ProcessReceipt = function()
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end,
	}
end
return Runtime

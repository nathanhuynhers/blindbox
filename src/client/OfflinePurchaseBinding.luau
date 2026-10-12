--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local Client = require(script.Parent.OfflinePurchaseClient)
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Presentation = require(script.Parent.StorePresentation)
local Binding = {}
function Binding.create(
	remotes: Instance,
	format: (number) -> string,
	paint: (Presentation.OfflineInput) -> ()
)
	local request = remotes:WaitForChild("PurchaseRequest") :: RemoteEvent
	local state = remotes:WaitForChild("PurchaseState") :: RemoteEvent
	local alive = true
	local cachedId: number? = nil
	local cached: string? = nil
	local loading = false
	local refresh: (() -> ())? = nil
	local pricingTask: thread? = nil
	local requestedAfterProfile = false
	local client = Client.create({
		now = os.clock,
		id = function()
			return "offline:" .. HttpService:GenerateGUID(false)
		end,
		send = function(value)
			request:FireServer(value)
		end,
		format = format,
		paint = paint,
		price = function(product)
			local id = product.platformId
			if not id or product.kind ~= "DeveloperProduct" or not product.available then
				return nil
			end
			if cachedId == id then
				return cached
			end
			if loading then
				return nil
			end
			cachedId, cached, loading = id, nil, true
			pricingTask = task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
				end)
				if not alive then
					return
				end
				loading = false
				if
					ok
					and info.IsForSale == true
					and typeof(info.PriceInRobux) == "number"
					and info.PriceInRobux >= 0
					and info.PriceInRobux < math.huge
					and info.PriceInRobux % 1 == 0
				then
					cached = `R$ {info.PriceInRobux}`
				end
				if refresh then
					refresh()
				end
			end)
			return nil
		end,
	})
	refresh = client.priceChanged
	-- Subscribe before State; neither an initial snapshot nor pricing can auto-prompt.
	local connection = state.OnClientEvent:Connect(
		function(snapshot: Types.Snapshot, result: Types.Result?)
			client.update(snapshot, result)
		end
	)
	request:FireServer({
		id = "offline-state:" .. HttpService:GenerateGUID(false),
		action = "State",
	})
	return {
		award = function(view)
			client.award(view)
			if not requestedAfterProfile then
				requestedAfterProfile = true
				request:FireServer({
					id = "offline-ready:" .. HttpService:GenerateGUID(false),
					action = "State",
				})
			end
		end,
		purchase = client.purchase,
		busy = client.busy,
		step = client.step,
		destroy = function()
			alive, refresh = false, nil
			connection:Disconnect()
			if pricingTask and coroutine.status(pricingTask) ~= "dead" then
				task.cancel(pricingTask)
			end
			pricingTask = nil
			client.destroy()
		end,
	}
end
return Binding

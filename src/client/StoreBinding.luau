--!strict
-- Shared P02 subscription/price cache and session purchase lock, including MN-22.
local Marketplace = game:GetService("MarketplaceService")
local Http = game:GetService("HttpService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Purchase = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Boost = require(game:GetService("ReplicatedStorage").Shared.BoostTypes)
local Convenience = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local Offline = require(script.Parent.OfflinePurchaseClient)
local Client = require(script.Parent.PurchaseClient)
local Projection = require(script.Parent.StoreProjection)
local Presentation = require(script.Parent.StorePresentation)
local Price = require(script.Parent.PurchasePrice)
local Binding = {}
export type Controller = {
	busy: () -> boolean,
	purchase: (string, number?) -> boolean,
	double: () -> boolean,
	refresh: () -> (),
	gameplay: (Types.Snapshot) -> (),
	convenience: (Convenience.Snapshot) -> (),
	activate: (string) -> (),
	step: () -> (),
	destroy: () -> (),
}
function Binding.create(
	remotes: Instance,
	canPrompt: () -> boolean,
	paint: (Presentation.Input) -> (),
	offlinePaint: (Presentation.OfflineInput) -> (),
	format: (number) -> string,
	message: (string) -> ()
): Controller
	local request = remotes:WaitForChild("PurchaseRequest") :: RemoteEvent
	local state = remotes:WaitForChild("PurchaseState") :: RemoteEvent
	local boostRequest = remotes:WaitForChild("BoostActivate") :: RemoteEvent
	local boostResult = remotes:WaitForChild("BoostResult") :: RemoteEvent
	local alive = true
	local gameplay: Types.Snapshot? = nil
	local convenience: Convenience.Snapshot? = nil
	local prices: { [string]: { text: string?, at: number, loading: boolean } } = {}
	local tasks: { [thread]: boolean } = {}
	local update: () -> () = function() end
	local offline: Offline.Controller? = nil
	local focus: GuiObject? = nil
	local function restoreFocus()
		local selected = focus
		if selected and not selected.Parent then
			local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local candidate = if gui then gui:FindFirstChild(selected.Name, true) else nil
			selected = if candidate and candidate:IsA("GuiObject") then candidate else nil
		end
		local ancestor: Instance? = selected
		while ancestor do
			if
				ancestor:IsA("GuiObject") and not ancestor.Visible
				or ancestor:IsA("ScreenGui") and not ancestor.Enabled
			then
				return
			end
			ancestor = ancestor.Parent
		end
		if selected and selected.Parent then
			GuiService.SelectedObject = selected
		end
	end
	local activation: Boost.Request? = nil
	local activationAt = -math.huge
	local activationSent = -math.huge
	local function id(): string
		return "store:" .. Http:GenerateGUID(false)
	end
	local function price(product: Purchase.ProductState): string?
		local platformId, kind = product.platformId, product.kind
		if not product.available or not platformId or not kind then
			return nil
		end
		local key = kind .. ":" .. platformId
		local cached = prices[key]
		local now = os.clock()
		if cached and (cached.loading or now - cached.at < (if cached.text then 120 else 10)) then
			return cached.text
		end
		local entry = { text = nil :: string?, at = now, loading = true }
		prices[key] = entry
		local work: thread
		work = task.defer(function()
			local ok, info = pcall(function()
				return Marketplace:GetProductInfoAsync(
					platformId,
					if kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
				)
			end)
			if not alive then
				return
			end
			entry.loading, entry.at = false, os.clock()
			local amount = if ok then Price.read(info) else nil
			entry.text = if amount then "R$ " .. format(amount) else nil
			tasks[work] = nil
			update()
			if offline then
				offline.priceChanged()
			end
		end)
		tasks[work] = true
		return nil
	end
	local client = Client.create({
		now = os.clock,
		id = id,
		price = price,
		canPrompt = canPrompt,
		send = function(value)
			request:FireServer(value)
		end,
		changed = function()
			update()
		end,
	})
	update = function()
		if alive then
			local projected =
				Projection.make(client, gameplay, convenience, price, workspace:GetServerTimeNow())
			projected.promptActive = projected.promptActive or activation ~= nil
			local function metadata(offer: Presentation.Offer, logical: string?)
				local item = if logical then client.product(logical) else nil
				if item and item.platformId and item.kind and item.available then
					local entry = prices[item.kind .. ":" .. item.platformId]
					if entry and not entry.loading and not entry.text then
						offer.availability, offer.buyAllowed, offer.reason =
							"unavailable",
							false,
							"We couldn't get your price from Roblox. Check again later."
					elseif entry then
						offer.priceLoading = entry.loading
					end
				end
				if activation then
					offer.buyAllowed = false
				end
			end
			for key, offer in projected.offers do
				metadata(offer, Projection.key(key, nil))
			end
			for minutes, offer in projected.coinDurations do
				metadata(offer, Projection.key("boostCoins", minutes))
			end
			paint(projected)
		end
	end
	offline = Offline.create({
		now = os.clock,
		id = id,
		price = price,
		format = format,
		paint = offlinePaint,
		send = function(value)
			client.submit(value)
		end,
	})
	local connections = {
		state.OnClientEvent:Connect(function(snapshot: Purchase.Snapshot, result: Purchase.Result?)
			local previous = client.view()
			local wasPrompting = previous ~= nil and previous.promptProduct ~= nil
			if client.receive(snapshot, result) and offline then
				offline.update(snapshot, result)
				if wasPrompting and not snapshot.promptProduct then
					restoreFocus()
				end
			end
		end),
		boostResult.OnClientEvent:Connect(function(result: Boost.Result)
			if activation and result.id == activation.id then
				if result.ok or result.reason ~= "SavingUnavailable" then
					activation = nil
				end
				message(
					if result.ok
						then "Boost activation saved. Your confirmed timers show in My Perks."
						else "Activation unconfirmed: "
							.. result.reason
							.. ". Your tokens remain protected; check again for recovery."
				)
				update()
			end
		end),
		Input.WindowFocused:Connect(function()
			client.refresh()
		end),
	}
	request:FireServer({ id = id(), action = "State" })
	local requestedReady = false
	return {
		busy = function()
			return client.busy() or activation ~= nil
		end,
		purchase = function(key: string, minutes: number?): boolean
			if activation then
				return false
			end
			focus = GuiService.SelectedObject
			local logical = Projection.key(key, minutes)
			return logical ~= nil and client.purchase(logical)
		end,
		double = function(): boolean
			focus = GuiService.SelectedObject
			return not activation
				and client.canPurchase("offline_double")
				and offline ~= nil
				and offline.purchase()
		end,
		refresh = client.refresh,
		gameplay = function(value: Types.Snapshot)
			gameplay = value
			if value.offlineAward and offline then
				offline.award(value.offlineAward)
			end
			if value.ready and not requestedReady then
				requestedReady = true
				client.refresh()
			end
			update()
		end,
		convenience = function(value: Convenience.Snapshot)
			convenience = value
			update()
		end,
		activate = function(token: string)
			local current = gameplay
			if
				activation
				or client.busy()
				or not canPrompt()
				or not current
				or not current.ready
				or not current.boosts
				or not current.boosts.paidAllowed
				or not current.boosts.clockValid
				or os.clock() - activationAt < 1
			then
				return
			end
			local key: Purchase.TokenId = token :: Purchase.TokenId
			if not current.boosts.tokens[key] or current.boosts.tokens[key] <= 0 then
				return
			end
			activation = { id = id(), token = key, revision = current.revision }
			activationAt, activationSent = os.clock(), os.clock()
			boostRequest:FireServer(activation)
			message("Saving boost activation. Don't activate again to retry.")
		end,
		step = function()
			client.step()
			if activation and os.clock() - activationSent >= 2 then
				activationSent = os.clock()
				boostRequest:FireServer(activation)
			end
		end,
		destroy = function()
			alive = false
			for _, connection in connections do
				connection:Disconnect()
			end
			for work in tasks do
				if coroutine.status(work) ~= "dead" then
					task.cancel(work)
				end
			end
			client.destroy()
			if offline then
				offline.destroy()
			end
		end,
	}
end
return Binding

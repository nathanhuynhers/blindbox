--!strict
-- Presentation only: P02 remains the sole platform prompt and receipt authority.
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local OfflineTypes = require(game:GetService("ReplicatedStorage").Shared.OfflineTypes)
local Presentation = require(script.Parent.StorePresentation)
export type Dependencies = {
	now: () -> number,
	id: () -> string,
	send: (Types.Request) -> (),
	price: (Types.ProductState) -> string?,
	format: (number) -> string,
	paint: (Presentation.OfflineInput) -> (),
}
local Client = {}
function Client.create(deps: Dependencies)
	local view: OfflineTypes.View? = nil
	local catalog: Types.Snapshot? = nil
	local outcome: Presentation.Outcome = "idle"
	local note: string? = nil
	local pending: Types.Request? = nil
	local sentAt = -math.huge
	local product: Types.ProductState? = nil
	local actualPrice: string? = nil
	local alive = true
	local function paint()
		local award = view
		if not alive or not award then
			return
		end
		deps.paint({
			fixture = false,
			baseText = deps.format(award.normal),
			doubleText = deps.format(award.doubled),
			freeText = deps.format(award.normal),
			eligible = award.claimable
				and not award.recoveryRequired
				and award.normal > 0
				and product ~= nil
				and product.available,
			buyAllowed = award.claimable
				and not award.recoveryRequired
				and product ~= nil
				and product.available
				and actualPrice ~= nil,
			priceText = actualPrice,
			claimed = not award.claimable,
			outcome = outcome,
			reason = if award.recoveryRequired
				then "An additional charged purchase needs support review. New purchases are paused."
				else note,
			freeClaimRestored = outcome == "cancelled",
		})
	end
	local api = {}
	function api.busy(): boolean
		return pending ~= nil
			or (catalog ~= nil and catalog.promptProduct ~= nil)
			or outcome == "prompting"
			or outcome == "saving"
			or outcome == "recovering"
	end
	function api.award(nextView: OfflineTypes.View)
		view = nextView
		if nextView.fulfilled then
			pending, outcome, note =
				nil, "idle", "Offline purchase saved. Reserved Coins remain protected."
		end
		if nextView.recoveryRequired and (not catalog or catalog.promptProduct == nil) then
			pending, outcome = nil, "idle"
		end
		paint()
	end
	function api.update(snapshot: Types.Snapshot, result: Types.Result?)
		if not alive or (catalog and snapshot.sequence <= catalog.sequence) then
			return
		end
		catalog, product = snapshot, nil
		for _, item in snapshot.products do
			if item.key == "offline_double" then
				product = item
				break
			end
		end
		local item = product
		-- Never ask for a price or display planning metadata for an unavailable offer.
		actualPrice = if item and item.available then deps.price(item) else nil
		if result and result.product == "offline_double" then
			if pending and (result.id == pending.id or result.status ~= "Rejected") then
				pending = nil
			end
			if result.status == "PromptOpened" then
				-- A cached authorization reply carries the CURRENT prompt snapshot.
				outcome, note =
					if snapshot.promptProduct == "offline_double" then "prompting" else "idle", nil
			elseif result.status == "AwaitingReceipt" or result.status == "Reserved" then
				outcome, note = "saving", nil
			elseif result.status == "Recovering" then
				outcome, note = "recovering", nil
			elseif result.status == "Cancelled" then
				outcome, note =
					"cancelled",
					"Purchase window closed. Claim is still free; any delayed purchase will recover."
			elseif result.status == "Verified" then
				outcome, note = "idle", "Offline purchase saved. Reserved Coins remain protected."
			elseif result.status == "Rejected" then
				outcome, note = "idle", "Double & Claim unavailable. Claim is still free."
			end
		elseif snapshot.promptProduct ~= nil then
			outcome = "prompting"
		elseif not pending and outcome == "prompting" then
			outcome = "idle"
		end
		if view and view.fulfilled then
			outcome = "idle"
		end
		if view and view.recoveryRequired and snapshot.promptProduct == nil then
			outcome = "idle"
		end
		paint()
	end
	function api.purchase(): boolean
		local award, item = view, product
		local busy = outcome == "prompting" or outcome == "saving" or outcome == "recovering"
		if
			not alive
			or pending
			or busy
			or not award
			or not award.claimable
			or award.recoveryRequired
			or award.normal <= 0
			or not item
			or not item.available
			or not actualPrice
		then
			return false
		end
		local request: Types.Request =
			{ id = deps.id(), action = "Purchase", product = "offline_double" }
		pending, sentAt, outcome, note = request, deps.now(), "prompting", nil
		paint()
		deps.send(request)
		return true
	end
	function api.step()
		-- A lost authorization reply retries its EXACT request id, never a new purchase.
		if alive and pending and deps.now() - sentAt >= 2 then
			sentAt = deps.now()
			deps.send(pending)
		end
	end
	function api.priceChanged()
		local item = product
		actualPrice = if alive and item and item.available then deps.price(item) else nil
		paint()
	end
	function api.destroy()
		alive, pending, view, catalog = false, nil, nil, nil
	end
	return api
end
return Client

--!strict
-- Presentation only: P02 remains the sole platform prompt and receipt authority.
local Types = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local OfflineTypes = require(game:GetService("ReplicatedStorage").Shared.OfflineTypes)
local Presentation = require(script.Parent.StorePresentation)
export type Dependencies = {
	now: () -> number,
	id: () -> string,
	send: (Types.Request) -> (),
	creditSend: ((OfflineTypes.CreditRequest) -> ())?,
	price: (Types.ProductState) -> string?,
	format: (number) -> string,
	paint: (Presentation.OfflineInput) -> (),
}
local Client = {}
export type Controller = {
	busy: () -> boolean,
	creditUpdate: (OfflineTypes.View, OfflineTypes.CreditResult) -> (),
	award: (OfflineTypes.View) -> (),
	update: (Types.Snapshot, Types.Result?) -> (),
	purchase: () -> boolean,
	step: () -> (),
	priceChanged: () -> (),
	destroy: () -> (),
}
function Client.create(deps: Dependencies)
	local view: OfflineTypes.View? = nil
	local catalog: Types.Snapshot? = nil
	local outcome: Presentation.Outcome = "idle"
	local note: string? = nil
	local pending: Types.Request? = nil
	local sentAt = -math.huge
	local creditPending: OfflineTypes.CreditRequest? = nil
	local creditSentAt = -math.huge
	local product: Types.ProductState? = nil
	local actualPrice: string? = nil
	local alive = true
	local function paint()
		local award = view
		if not alive or not award then
			return
		end
		if award.creditFlow then
			local amount = award.selectedNormal or award.normal
			local target = award.selectedAwardId or award.awardId
			local redeem = (award.credits or 0) > 0
			local enabled = target ~= nil
				and amount > 0
				and not award.recoveryRequired
				and award.redeemAllowed == true
				and (redeem or (product ~= nil and product.available and actualPrice ~= nil))
			local previous = award.selectedAwardId ~= nil and award.selectedAwardId ~= award.awardId
			deps.paint({
				fixture = false,
				creditFlow = true,
				olderReturn = previous,
				redemption = redeem,
				creditCount = award.credits or 0,
				freeClaimRestored = outcome == "cancelled",
				baseText = deps.format(amount),
				freeText = deps.format(award.claimable and award.normal or 0),
				doubleText = deps.format(2 * amount),
				freeClaimAvailable = award.claimable,
				eligible = target ~= nil
					and amount > 0
					and (not award.fulfilled or award.selectedAwardId ~= nil),
				buyAllowed = enabled,
				priceText = actualPrice,
				claimed = award.fulfilled == true and not award.selectedAwardId,
				outcome = outcome,
				reason = note
					or (
						if redeem
							then "Your saved credit is ready. Confirm the return to redeem it."
							else "Buy one saved, single-use credit, then confirm its redemption. Free Claim stays available."
					),
				actionText = if redeem then "Redeem +" .. deps.format(amount) else "Buy credit",
				detailText = if redeem
					then if previous then "Previous return · 1 credit" else "Uses 1 saved credit"
					else actualPrice or "Buying unavailable",
			})
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
		return creditPending ~= nil
			or pending ~= nil
			or (catalog ~= nil and catalog.promptProduct ~= nil)
			or outcome == "prompting"
			or outcome == "saving"
			or outcome == "recovering"
	end
	function api.award(nextView: OfflineTypes.View)
		view = nextView
		if nextView.fulfilled and (not catalog or catalog.promptProduct == nil) then
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
					"Purchase window closed. Claim is still free; any delayed purchase saves a credit for confirmation."
			elseif result.status == "Verified" then
				outcome, note =
					"idle",
					if view and view.creditFlow
						then "Credit saved. Confirm redemption to add the frozen return."
						else "Offline purchase saved. Reserved Coins remain protected."
			elseif result.status == "Rejected" then
				outcome, note = "idle", "Double & Claim unavailable. Claim is still free."
			end
		elseif snapshot.promptProduct ~= nil then
			outcome = "prompting"
		elseif snapshot.recoveryProduct ~= nil or (item and item.fulfillment == "Recovering") then
			outcome = "recovering"
		elseif not pending and outcome == "prompting" then
			outcome = "idle"
		end
		if snapshot.promptProduct ~= nil and outcome == "idle" then
			outcome = "prompting"
		end
		if view and view.fulfilled and snapshot.promptProduct == nil then
			outcome = "idle"
		end
		if view and view.recoveryRequired and snapshot.promptProduct == nil then
			outcome = "idle"
		end
		paint()
	end
	function api.purchase(): boolean
		if view and view.creditFlow then
			local award = view
			local target = award.selectedAwardId or award.awardId
			local redeem = (award.credits or 0) > 0
			if
				not alive
				or api.busy()
				or not target
				or not award.redeemAllowed
				or award.recoveryRequired
				or (award.selectedNormal or award.normal) <= 0
				or not deps.creditSend
				or (not redeem and (not product or not product.available or not actualPrice))
			then
				return false
			end
			local request: OfflineTypes.CreditRequest =
				{ id = deps.id(), action = if redeem then "Redeem" else "Select", awardId = target }
			creditPending = request
			creditSentAt, outcome, note = deps.now(), "saving", nil
			paint()
			deps.creditSend(request)
			return true
		end
		local award, item = view, product
		local busy = outcome == "prompting" or outcome == "saving" or outcome == "recovering"
		if
			not alive
			or pending
			or (catalog ~= nil and catalog.promptProduct ~= nil)
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
	function api.creditUpdate(nextView: OfflineTypes.View, result: OfflineTypes.CreditResult)
		local request = creditPending
		if
			not alive
			or not request
			or result.id ~= request.id
			or result.awardId ~= request.awardId
		then
			return
		end
		view = nextView
		if result.status == "Recovering" then
			outcome, note = "saving", "Your credit operation is being saved. Reconnect to recover."
			paint()
			return
		end
		creditPending = nil
		outcome, note =
			"idle",
			if result.status == "Redeemed"
				then "Credit redeemed once. Your reserved Coins remain protected."
				else nil
		if
			request.action == "Select"
			and result.status == "Selected"
			and nextView.selectedAwardId == request.awardId
			and product
			and product.available
			and actualPrice
			and catalog
			and catalog.promptProduct == nil
		then
			local purchase: Types.Request =
				{ id = deps.id(), action = "Purchase", product = "offline_double" }
			pending, sentAt, outcome = purchase, deps.now(), "prompting"
			paint()
			deps.send(purchase)
			return
		end
		if result.status == "Rejected" then
			note = "Credit operation unavailable: "
				.. result.reason
				.. ". Your credit has been kept."
		end
		paint()
	end
	function api.step()
		if alive and creditPending and deps.creditSend and deps.now() - creditSentAt >= 2 then
			creditSentAt = deps.now()
			deps.creditSend(creditPending)
		end
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
		alive, pending, creditPending, view, catalog = false, nil, nil, nil, nil
	end
	return api
end
return Client

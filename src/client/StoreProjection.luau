--!strict
-- Maps existing authoritative owner contracts into the approved presentation.
local Purchase = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Convenience = require(game:GetService("ReplicatedStorage").Shared.ConvenienceTypes)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local Presentation = require(script.Parent.StorePresentation)
local Client = require(script.Parent.PurchaseClient)
local Projection = {}
Projection.keys = table.freeze({
	starter = "starter",
	vip = "vip",
	coins2 = "coins_2",
	coins4 = "coins_4",
	coins8 = "coins_8",
	autoOpen = "auto_open",
	autoCollect = "auto_collect",
	speed = "movement",
	luck = "luck",
	doubleClaim = "offline_double",
	boostCoins = "coins_boost_30",
	boostLuck2 = "luck_boost_2",
	boostLuck4 = "luck_boost_4",
	boostCombo = "combo_boost",
	pouch = "pack_small",
	stack = "pack_medium",
	sack = "pack_large",
	chest = "pack_huge",
	slot5 = "display_5",
	slot6 = "display_6",
}) :: { [string]: string }
function Projection.key(key: string, minutes: number?): string?
	if key == "boostCoins" then
		return "coins_boost_" .. tostring(minutes or 30)
	end
	return Projection.keys[key]
end
local reasons: { [string]: Presentation.Availability } = {
	Unconfigured = "unconfigured",
	SalesDisabled = "unavailable",
	IntegrationPending = "unavailable",
	OwnershipUnavailable = "loading",
	ProfileUnavailable = "unavailable",
	StorageUnavailable = "unavailable",
	Superseded = "superseded",
	Owned = "owned",
	AlreadyClaimed = "claimed",
	PolicyRestricted = "restricted",
	Restricted = "restricted",
	CapacityUnavailable = "nofit",
	EligibilityUnavailable = "unavailable",
	ValidationPending = "unavailable",
	Available = "available",
}
local notes: { [string]: string } = {
	Unconfigured = "This offer isn't configured yet.",
	SalesDisabled = "This offer isn't on sale yet.",
	IntegrationPending = "This offer isn't ready yet.",
	EligibilityUnavailable = "We couldn't confirm eligibility. Please check again later.",
	ValidationPending = "This benefit isn't available yet.",
	PlatformUnavailable = "Roblox couldn't open this offer. Please check again later.",
}
local activationNotes: { [string]: string } = {
	Ready = "Ready",
	RedundantLuck = "Already covered by permanent Luck",
	IncompatibleOrQueued = "Wait for the current boost to expire or have room for more time",
	Capacity = "Activation unavailable",
	ClockUnavailable = "Timer verification unavailable",
	NoToken = "No unused token",
}
function Projection.make(
	client: Client.Controller,
	gameplay: Types.Snapshot?,
	convenience: Convenience.Snapshot?,
	price: (Purchase.ProductState) -> string?,
	now: number
): Presentation.Input
	local input = Presentation.empty()
	input.now, input.promptActive = now, client.busy()
	local catalog = client.view()
	input.ownershipReady = catalog ~= nil and catalog.ready
	local function offer(key: string): Presentation.Offer
		local item, state = client.product(key), client.state(key)
		if not item then
			return { availability = "loading", outcome = "idle" }
		end
		local availability: Presentation.Availability = reasons[item.reason] or "unavailable"
		if item.package and item.package.claimed then
			availability = "claimed"
		elseif item.ownership == "Owned" then
			availability = "owned"
		elseif
			item.coinTier
			and gameplay
			and gameplay.coinModifiers
			and gameplay.coinModifiers.verifiedTier >= item.coinTier
		then
			availability = "superseded"
		end
		local benefit: string? = nil
		if item.coinTier then
			benefit = `{item.coinTier}× Display Coins, online and offline`
		end
		if item.benefits then
			if key == "offline_double" then
				benefit =
					"One saved, single-use credit. Confirm a frozen return to add its extra Coins once."
			elseif item.benefits.movementSpeed then
				benefit = `Walk speed {item.benefits.movementSpeed}; free 36 remains available`
			elseif item.benefits.displayRateBonus and item.benefits.dailyCoins then
				benefit =
					`+{item.benefits.displayRateBonus * 100}% Display income and +{item.benefits.dailyCoins} Coins with each daily box`
			elseif item.benefits.displaySlot then
				benefit = `Unlocks Display slot {item.benefits.displaySlot} permanently`
			elseif item.benefits.luckWeight then
				benefit =
					`Rare-or-better weights ×{item.benefits.luckWeight}; check the exact odds below`
			elseif item.benefits.cadenceSeconds then
				benefit = if key == "auto_open"
					then `One box at a time, at least {item.benefits.cadenceSeconds} s apart`
					else `Collect Display Coins every {item.benefits.cadenceSeconds} s while online`
			end
		end
		if item.grant then
			local pieces: { string } = {}
			if item.grant.coins > 0 then
				table.insert(pieces, tostring(item.grant.coins) .. " fixed Coins")
			end
			for token, count in item.grant.tokens do
				local promise = if catalog and catalog.tokenBenefits
					then catalog.tokenBenefits[token :: Purchase.TokenId]
					else nil
				if promise then
					table.insert(
						pieces,
						`{count} unused token · {promise.seconds / 60} min · Coins ×{promise.coins}, Luck weight ×{promise.luck}`
					)
				end
			end
			if #pieces > 0 then
				benefit = table.concat(pieces, " + ")
			end
		end
		return {
			benefit = benefit,
			availability = availability,
			priceText = if item.available then price(item) else nil,
			outcome = if state then state.outcome :: Presentation.Outcome else "idle",
			reason = notes[if state and state.reason then state.reason else item.reason],
			buyAllowed = client.canPurchase(key)
				and benefit ~= nil
				and (
					key ~= "luck"
						and key ~= "luck_boost_2"
						and key ~= "luck_boost_4"
						and key ~= "combo_boost"
					or gameplay ~= nil
						and gameplay.odds ~= nil
						and gameplay.baseOdds ~= nil
						and gameplay.luckOfferOdds ~= nil
				),
			supersededBy = if gameplay and gameplay.coinModifiers
				then tostring(gameplay.coinModifiers.verifiedTier) .. "x Coins"
				else nil,
			ownedCoinTier = if gameplay and gameplay.coinModifiers
				then gameplay.coinModifiers.verifiedTier
				else nil,
			package = item.package,
		}
	end
	for key, logical in Projection.keys do
		input.offers[key] = offer(logical)
	end
	for _, minutes in { 15, 30, 60 } do
		input.coinDurations[minutes] = offer("coins_boost_" .. minutes)
	end
	if convenience then
		input.offers.autoCollect.toggle = convenience.collectEnabled
		input.offers.speed.toggle = convenience.movementEnabled
		local run = convenience.open
		input.automation = {
			status = if run.running then "running" else "stopped",
			collection = run.collection,
			count = run.limit,
			completed = run.completed,
			reserve = tostring(run.reserve),
			spend = tostring(run.spent),
			reason = run.reason,
			boxPrice = if gameplay then gameplay.prices[run.collection] else nil,
		}
	end
	if gameplay then
		-- Saved slots (legacy coin unlocks included) count as owned without the pass, and a
		-- slot pass only sells for the next slot. The server enforces both; this is the copy.
		local unlocked = gameplay.unlocked
		for slot, logical in DisplayConfig.unlockPasses do
			assert(Projection.keys["slot" .. slot] == logical, "Slot pass key mismatch")
			local current = input.offers["slot" .. slot]
			-- Partial fixtures carry no gameplay slot count.
			if unlocked == nil then
				continue
			elseif unlocked >= slot then
				input.offers["slot" .. slot] = {
					availability = "owned",
					outcome = current.outcome,
					actionText = "UNLOCKED",
					benefit = current.benefit,
					reason = `Display slot {slot} is unlocked and yours to keep.`,
				}
			elseif unlocked < slot - 1 and current.outcome == "idle" then
				input.offers["slot" .. slot] = {
					availability = "ineligible",
					outcome = "idle",
					actionText = `Unlock slot {slot - 1} first`,
					benefit = current.benefit,
					reason = `Unlock Display slot {slot - 1} first, then this pass opens up.`,
				}
			end
		end
		local award = gameplay.offlineAward
		if
			award
			and award.creditFlow
			and ((award.credits or 0) > 0 or award.selectedAwardId ~= nil)
		then
			input.offers.doubleClaim = {
				availability = "owned",
				outcome = "idle",
				actionText = "View saved return",
				buyAllowed = gameplay.ready and not client.busy(),
				benefit = `{award.credits or 0} saved credits; frozen return {award.selectedNormal or award.normal} Coins.`,
				reason = "Open the return card to review and confirm redemption. Closing it keeps your credits.",
			}
		end
		input.modifiers = if gameplay.earningFactors
			then `Display Coins: permanent ×{gameplay.earningFactors.permanentTier} · VIP ×{gameplay.earningFactors.vipFactor} · timed ×{gameplay.earningFactors.timedCoinFactor}`
			else "Checking active modifiers…"
		input.odds = gameplay.odds
		input.baseOdds = gameplay.baseOdds
		input.luckOfferOdds = gameplay.luckOfferOdds
		local boosts = gameplay.boosts
		if boosts then
			input.modifiers = (input.modifiers or "") .. ` · Luck weight ×{boosts.luckWeight}`
			local tokens = catalog and catalog.tokenBenefits
			if tokens then
				for key, count in boosts.tokens do
					local benefit = tokens[key :: Purchase.TokenId]
					if not benefit then
						continue
					end
					local product = if key == "Luck2_30"
						then "boostLuck2"
						elseif key == "Luck4_30" then "boostLuck4"
						elseif key == "Combo2_30" then "boostCombo"
						else "boostCoins"
					table.insert(input.tokens, {
						key = key,
						product = product,
						count = count,
						minutes = benefit.seconds / 60,
						activation = if boosts.paidAllowed
								and boosts.clockValid
								and gameplay.ready
							then if boosts.activationReasons
								then activationNotes[boosts.activationReasons[key :: Purchase.TokenId]]
									or "Unavailable"
								else "Unavailable"
							else "Unavailable",
					})
				end
				table.sort(input.tokens, function(a, b)
					return a.key < b.key
				end)
			end
			for _, entry in
				{
					{ key = "boostCoins", timer = boosts.coin },
					{
						key = if boosts.luck and boosts.luck.strength == 4
							then "boostLuck4"
							else "boostLuck2",
						timer = boosts.luck,
					},
				}
			do
				local timer = entry.timer
				if timer then
					table.insert(input.timers, {
						key = entry.key,
						label = if entry.key == "boostCoins"
							then "Coin boost ×" .. timer.strength
							else "Luck weight ×" .. timer.strength,
						startsAt = timer.started,
						endsAt = timer.expires,
						endText = "UTC " .. tostring(timer.expires),
						suppressed = not boosts.paidAllowed
							or not boosts.clockValid
							or (entry.key ~= "boostCoins" and boosts.redundantLuck),
					})
				end
			end
		end
	end
	return input
end
return Projection

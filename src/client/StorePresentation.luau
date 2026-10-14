--!strict
-- Presentation-only boundary. StoreProjection maps verified owner contracts here.
local Presentation = {}
local PurchaseTypes = require(game:GetService("ReplicatedStorage").Shared.PurchaseTypes)
export type Availability =
	"loading"
	| "available"
	| "owned"
	| "superseded"
	| "claimed"
	| "ineligible"
	| "redundant"
	| "restricted"
	| "unavailable"
	| "unconfigured"
	| "nofit"
export type Outcome =
	"idle"
	| "prompting"
	| "verifying"
	| "saving"
	| "recovering"
	| "granted"
	| "cancelled"
	| "failed"
export type Offer = {
	actionText: string?,
	benefit: string?,
	buyAllowed: boolean?,
	package: PurchaseTypes.PackageState?,
	availability: Availability,
	priceText: string?, -- localized platform metadata, never a catalog fallback
	priceLoading: boolean?,
	ownershipLoading: boolean?,
	outcome: Outcome,
	noChargeConfirmed: boolean?,
	reason: string?,
	supersededBy: string?,
	ownedCoinTier: number?,
	hidden: boolean?, -- explicit backend configuration, not an assumed D3 subset
	toggle: boolean?,
}
export type Token = {
	key: string,
	product: string,
	count: number,
	minutes: number,
	activation: string,
}
export type Timer = {
	key: string,
	label: string,
	startsAt: number,
	endsAt: number,
	endText: string,
	suppressed: boolean?,
}
export type Automation = {
	status: "off" | "ready" | "running" | "paused" | "stopped",
	collection: string,
	count: number,
	completed: number,
	reserve: string,
	spend: string,
	boxPrice: number?, -- verified current box price; used only for local setup cost presentation
	reason: string?,
}
export type Input = {
	modifiers: string?,
	odds: { [string]: number }?,
	baseOdds: { [string]: number }?,
	luckOfferOdds: { [number]: { [string]: number } }?,
	fixture: boolean,
	now: number, -- server UTC observation; fixtures use their own clock
	offers: { [string]: Offer },
	coinDurations: { [number]: Offer },
	tokens: { Token },
	timers: { Timer },
	automation: Automation?,
	promptActive: boolean,
	ownershipReady: boolean,
	longLabels: boolean?,
}
export type View = { stamp: string, note: string, price: string?, pending: boolean }
export type OfflineInput = {
	olderReturn: boolean?,
	creditFlow: boolean?,
	redemption: boolean?,
	actionText: string?,
	detailText: string?,
	freeClaimAvailable: boolean?,
	creditCount: number?,
	fixture: boolean,
	baseText: string,
	doubleText: string, -- exact server 2N; never parsed from formatted UI text
	freeText: string, -- actual free claim amount, including capacity clipping
	eligible: boolean,
	buyAllowed: boolean?,
	priceText: string?,
	claimed: boolean?,
	freeClaimRestored: boolean?,
	outcome: Outcome,
	noChargeConfirmed: boolean?,
	reason: string?,
}

function Presentation.empty(): Input
	return {
		fixture = false,
		now = 0,
		offers = {},
		coinDurations = {},
		tokens = {},
		timers = {},
		promptActive = false,
		ownershipReady = false,
	}
end

function Presentation.offer(input: Input, key: string, minutes: number?): Offer
	if key == "boostCoins" and minutes and input.coinDurations[minutes] then
		return input.coinDurations[minutes]
	end
	return input.offers[key] or { availability = "unconfigured", outcome = "idle" }
end
-- Wall-clock observations alone never rebuild controls or reset confirmation.
function Presentation.signature(input: Input): string
	local parts = {
		tostring(input.fixture),
		tostring(input.promptActive),
		tostring(input.ownershipReady),
		tostring(input.longLabels),
		input.modifiers or "",
	}
	local function offer(key: string, value: Offer)
		table.insert(
			parts,
			key
				.. ":"
				.. value.availability
				.. ":"
				.. value.outcome
				.. ":"
				.. (value.priceText or "")
				.. ":"
				.. tostring(value.buyAllowed)
				.. ":"
				.. tostring(value.toggle)
				.. ":"
				.. tostring(value.hidden)
				.. ":"
				.. (value.reason or "")
				.. ":"
				.. (value.benefit or "")
				.. ":"
				.. (value.actionText or "")
		)
	end
	local keys: { string } = {}
	for key in input.offers do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		offer(key, input.offers[key])
	end
	for _, minutes in { 15, 30, 60 } do
		if input.coinDurations[minutes] then
			offer(tostring(minutes), input.coinDurations[minutes])
		end
	end
	for _, token in input.tokens do
		table.insert(parts, `{token.key}:{token.count}:{token.activation}`)
	end
	for _, timer in input.timers do
		table.insert(parts, `{timer.key}:{timer.endsAt}:{timer.suppressed}`)
	end
	if input.automation then
		table.insert(
			parts,
			`{input.automation.status}:{input.automation.completed}:{input.automation.reason}`
		)
	end
	local ids: { string } = {}
	for id in pairs(input.odds or {}) do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		table.insert(parts, id .. ":" .. tostring((input.odds or {})[id]))
	end
	for _, key in keys do
		local value = input.offers[key]
		if value.package then
			table.insert(
				parts,
				tostring(value.package.dailySupplementAvailable)
					.. ":"
					.. tostring(value.package.assistedCredit)
			)
		end
	end
	return table.concat(parts, "|")
end

function Presentation.view(input: Input, key: string, minutes: number?): View
	local offer = Presentation.offer(input, key, minutes)
	local stamp, note = "Coming soon", "Buying isn't switched on yet. Prices will come from Roblox."
	local pending = false
	if offer.outcome == "prompting" then
		stamp, note, pending = "In Roblox window", "Finish or cancel in the Roblox window.", true
	elseif offer.outcome == "verifying" then
		stamp, note, pending =
			"Verifying…", "Checking ownership with Roblox. Confirmation is still pending.", true
	elseif offer.outcome == "saving" or offer.outcome == "recovering" then
		stamp = if offer.outcome == "saving" then "Saving…" else "Arriving soon"
		note, pending =
			"Your purchase is being saved. It will be recovered if you reconnect. Don't purchase again to retry. You can keep playing.",
			true
	elseif offer.outcome == "granted" then
		stamp, note =
			"Delivered!", "Confirmed delivery. Check My Perks for passes and unused boost tokens."
		if key == "pouch" or key == "stack" or key == "sack" or key == "chest" then
			note = "Coins added. This delivery is confirmed."
		elseif string.sub(key, 1, 5) == "boost" then
			note =
				"Delivered to My Perks. Your unused token is ready for activation; buying did not start a timer."
		end
	elseif offer.ownershipLoading or offer.availability == "loading" then
		stamp, note =
			"Checking ownership…", "Checking your ownership and availability. Please wait."
	elseif offer.availability == "owned" then
		stamp, note =
			"OWNED", "Ownership is verified. Check your active modifiers and settings below."
		if offer.toggle ~= nil then
			stamp ..= if offer.toggle then " · ON" else " · OFF"
			note = if offer.toggle then "Your setting is on." else "Your setting is off."
		end
	elseif offer.availability == "superseded" then
		stamp = "Included in " .. (offer.supersededBy or "higher tier")
		note = stamp .. ". Nothing to buy."
	elseif offer.availability == "claimed" then
		stamp, note = "CLAIMED", "Claimed. Its Coins and boost were delivered."
	elseif offer.availability == "redundant" then
		stamp, note =
			"Already covered",
			"This boost won't improve your current Luck. Your unused boost has been kept."
	elseif offer.availability == "restricted" then
		stamp, note =
			"Not available",
			"This purchase isn't available for your account. You can still earn Coins and open boxes through gameplay."
	elseif offer.availability == "ineligible" then
		stamp, note =
			"Not eligible", offer.reason or "This product isn't usable in your current state."
	elseif offer.availability == "nofit" then
		stamp, note =
			"Wallet too full",
			"These Coins won't fit in your wallet right now. Spend some Coins first."
	elseif offer.availability == "unavailable" then
		stamp, note =
			"Try again later",
			"We couldn't verify this purchase's availability. Please try again. Your earned Coins and free rewards are still available."
	elseif offer.availability == "available" then
		if offer.priceLoading or not offer.priceText then
			stamp, note = "Getting price…", "Getting your price from Roblox…"
		else
			stamp, note =
				if offer.buyAllowed then offer.priceText else "Buying disabled",
				if offer.buyAllowed
					then "Confirm this purchase in the Roblox window."
					else "Buying is not switched on."
		end
	end
	if offer.outcome == "cancelled" then
		note = if offer.noChargeConfirmed
			then "Purchase cancelled. You weren't charged."
			else "Prompt closed. Waiting for purchase verification."
	elseif offer.outcome == "failed" then
		stamp = if offer.noChargeConfirmed then "Didn't go through" else "Arriving soon"
		note = if offer.noChargeConfirmed
			then "Roblox couldn't complete the purchase. You weren't charged. Try again later."
			else "Delivery is unresolved. Don't purchase again to retry. Check again or reconnect for recovery."
		pending = not offer.noChargeConfirmed
	end
	if key == "doubleClaim" then
		stamp, note =
			"On welcome back",
			"Double & Claim covers this return only. Claim always stays free. Check its price on welcome back."
	end
	if offer.reason and not pending then
		note = offer.reason
	end
	local package = offer.package
	if package and key == "vip" then
		note ..= ` Actual VIP Display factor: ×{package.appliedVipFactor}. Daily extra: {package.dailyCoins or 0} Coins. {if package.dailySupplementAvailable
			then "Available with your daily box."
			else "The next eligible daily box carries the extra Coins."}`
	elseif package and package.confirmed and package.assistedCredit > 0 then
		note =
			"Delivery saved. Purchased Coins are protected credit; they aren't spendable yet. Check My Perks for unused tokens."
	end
	if input.promptActive and not pending then
		note ..= " Another purchase prompt is active."
	end
	if
		offer.ownedCoinTier
		and (key == "coins4" or key == "coins8")
		and offer.availability == "available"
	then
		note ..= ` Full price. You already own {offer.ownedCoinTier}x Coins; tiers don't give credit toward each other.`
	end
	-- Illustrative prices are only ever rendered on a clearly marked isolated fixture host.
	local price = if offer.availability == "available"
			and not offer.priceLoading
			and not offer.ownershipLoading
			and not pending
			and (offer.outcome == "idle" or offer.outcome == "cancelled")
		then offer.priceText
		else nil
	if input.fixture then
		note = "PREVIEW ONLY · No purchases or rewards. " .. note
		if price then
			stamp = "Preview R$ " .. price
		end
	end
	if offer.actionText and not pending then
		stamp = offer.actionText
	end
	return {
		stamp = stamp,
		note = note,
		price = if input.fixture or offer.buyAllowed then price else nil,
		pending = pending,
	}
end

function Presentation.remaining(timer: Timer, now: number): string
	local seconds = math.max(0, math.ceil(timer.endsAt - now))
	if seconds == 0 then
		return "Expired"
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Presentation.offline(input: OfflineInput): (string, boolean)
	local busy = input.outcome == "prompting"
		or input.outcome == "verifying"
		or input.outcome == "saving"
		or input.outcome == "recovering"
	if input.outcome == "prompting" then
		return "Finish or cancel in the Roblox window.", true
	end
	if busy then
		return "Your purchase is being saved. It will be recovered if you reconnect. Don't purchase again to retry.",
			true
	end
	if input.outcome == "granted" then
		return `Yay! +{input.doubleText} Coins claimed!`, true
	end
	if input.outcome == "cancelled" then
		if input.reason then
			return input.reason, not (input.freeClaimRestored or input.noChargeConfirmed)
		end
		return if input.noChargeConfirmed
			then "Purchase cancelled. You weren't charged. Claim is still free."
			else "Waiting for purchase verification. Don't purchase again to retry.",
			not input.noChargeConfirmed
	end
	if input.outcome == "failed" then
		return if input.noChargeConfirmed
			then "The purchase didn't go through. You weren't charged. Claim is still free."
			else "Delivery is unresolved. Don't purchase again to retry. Reconnect for recovery.",
			not input.noChargeConfirmed
	end
	return input.reason or "Double & Claim · 2× this return · Price TBD. Buying disabled.", false
end

return Presentation

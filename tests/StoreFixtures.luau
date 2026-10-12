--!strict
-- Outside every Rojo mapping. Install temporarily in the client only for private Studio QA.
local Presentation = require(script.Parent.StorePresentation)
local Fixtures = {}
Fixtures.states = {
	"available",
	"priceLoading",
	"ownershipLoading",
	"owned",
	"superseded",
	"claimed",
	"ineligible",
	"redundant",
	"restricted",
	"unavailable",
	"unconfigured",
	"nofit",
	"prompting",
	"verifying",
	"saving",
	"recovering",
	"granted",
	"cancelled",
	"failed",
	"uncertainFailure",
	"perks",
	"hidden",
	"longLabels",
	"largePrices",
}
local prices: { [string]: string } = {
	starter = "49",
	vip = "199",
	coins2 = "149",
	coins4 = "399",
	coins8 = "999",
	autoOpen = "199",
	autoCollect = "149",
	speed = "49",
	luck = "399",
	boostCoins = "49",
	boostLuck2 = "49",
	boostLuck4 = "99",
	boostCombo = "79",
	pouch = "49",
	stack = "149",
	sack = "499",
	chest = "1,999",
}
function Fixtures.make(state: string): Presentation.Input
	local input = Presentation.empty()
	input.fixture, input.ownershipReady, input.now = true, true, 1800000000
	for key, price in prices do
		local offer: Presentation.Offer =
			{ availability = "available", outcome = "idle", priceText = price }
		if state == "priceLoading" then
			offer.priceLoading = true
		elseif state == "ownershipLoading" then
			offer.ownershipLoading = true
		elseif
			state == "prompting"
			or state == "verifying"
			or state == "saving"
			or state == "recovering"
			or state == "granted"
			or state == "cancelled"
			or state == "failed"
		then
			offer.outcome = state :: Presentation.Outcome
			offer.noChargeConfirmed = state == "cancelled" or state == "failed"
		elseif state == "uncertainFailure" then
			offer.outcome = "failed"
		elseif state == "largePrices" then
			offer.priceText = "1,234,567"
		elseif
			state ~= "available"
			and state ~= "perks"
			and state ~= "hidden"
			and state ~= "longLabels"
		then
			offer.availability = state :: Presentation.Availability
		end
		offer.supersededBy = "8x Coins"
		offer.reason =
			"This benefit is not usable in the current account state. Your earned Coins and free rewards remain available."
		input.offers[key] = offer
	end
	input.coinDurations = {
		[15] = table.clone(input.offers.boostCoins),
		[30] = table.clone(input.offers.boostCoins),
		[60] = table.clone(input.offers.boostCoins),
	}
	if state ~= "largePrices" then
		input.coinDurations[15].priceText, input.coinDurations[30].priceText, input.coinDurations[60].priceText =
			"29", "49", "79"
	end
	input.longLabels = state == "longLabels"
	input.promptActive = state == "prompting"
	if state == "hidden" then
		for _, key in
			{
				"coins4",
				"coins8",
				"sack",
				"chest",
				"luck",
				"boostLuck2",
				"boostLuck4",
				"boostCombo",
			}
		do
			input.offers[key].hidden = true
		end
	end
	if state == "perks" then
		for _, key in { "coins8", "vip", "autoOpen", "autoCollect", "speed" } do
			input.offers[key].availability = "owned"
		end
		input.offers.autoCollect.toggle, input.offers.speed.toggle = true, false
		input.offers.coins2.availability, input.offers.coins4.availability =
			"superseded", "superseded"
		input.offers.starter.availability = "claimed"
		input.offers.pouch.outcome = "recovering"
		input.offers.boostCombo.outcome = "saving"
		input.tokens = {
			{
				key = "coin15",
				product = "boostCoins",
				count = 2,
				minutes = 15,
				activation = "Ready",
			},
			{
				key = "luck4",
				product = "boostLuck4",
				count = 1,
				minutes = 30,
				activation = "Wait for the current Luck strength to expire",
			},
			{
				key = "combo",
				product = "boostCombo",
				count = 1,
				minutes = 30,
				activation = "This boost won't improve your current Luck. Your unused boost has been kept.",
			},
		}
		input.timers = {
			{
				key = "boostCoins",
				label = "2x Coins",
				startsAt = input.now - 300,
				endsAt = input.now + 600,
				endText = "2027-01-15 08:10 UTC (fixture)",
			},
			{
				key = "boostLuck2",
				label = "Luck ×2",
				startsAt = input.now - 900,
				endsAt = input.now + 900,
				endText = "2027-01-15 08:15 UTC (fixture)",
			},
		}
		input.automation = {
			status = "ready",
			collection = "Pocket Grove",
			count = 10,
			completed = 0,
			reserve = "4,500",
			spend = "15,000",
			boxPrice = 1500,
		}
	end
	return input
end
function Fixtures.offline(state: Presentation.Outcome): Presentation.OfflineInput
	return {
		fixture = true,
		baseText = "10,000",
		freeText = "10,000",
		doubleText = "20,000",
		eligible = true,
		outcome = state,
		noChargeConfirmed = state == "cancelled" or state == "failed",
	}
end
return Fixtures

--!strict
-- Change configuration before loading the real economy, inside this isolated test process.
local Config = require("./Economy")
Config.tiers.moon.price = 123456789
Config.collections.moon.expectedIncome = 7777
local Catalog = require("./Catalog")
local Economy = require("./CollectionEconomy")
local odds = Economy.odds({})
local expected = 0
for _, figure in Catalog.figures do
	if figure.collection == "moon" then
		expected += odds[figure.id] / 100 * Economy.rates[figure.id]
	end
end
assert(Economy.prices.moon == 123456789, "Price change must reach purchases")
assert(math.abs(expected - 7777) < 1e-7, "Income target must remain independent of price/payback")
assert(Economy.prices.grove == 1500, "Independent collection tuning must preserve legacy prices")
print("PASS: independent provisional income target and price configuration")

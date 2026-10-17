--!strict
-- Display slot progression: slot 4 for coins, 5 and 6 by gamepass, legacy slots never relocked.
local Rules = require("./Rules")
local Profile = require("./Profile")
local Economy = require("./Economy")
local DisplayConfig = require("./DisplayConfig")
local PurchaseConfig = require("./PurchaseConfig")
local checks = 0
local function check(condition: boolean, message: string)
	assert(condition, message)
	checks += 1
end
local function expand(state)
	return (Rules.mutate(state, { action = "Expand", id = "x" .. state.revision, revision = state.revision }, 0, 10))
end
local function owning(keys: { string })
	return function(key: string): boolean
		return table.find(keys, key) ~= nil
	end
end

check(Economy.expansionCosts[4] == 1000000, "slot 4 costs 1,000,000 coins")
check(Economy.expansionCosts[5] == nil and Economy.expansionCosts[6] == nil, "slots 5 and 6 are not coin slots")
for slot, key in DisplayConfig.unlockPasses do
	local product = PurchaseConfig.find(key)
	check(product ~= nil and product.permanent and product.kind == "Pass", "slot " .. slot .. " is a permanent pass")
	check(product ~= nil and PurchaseConfig.configured(product), "owner-supplied pass ID for slot " .. slot)
end
check(PurchaseConfig.find("display_5").defaultPrice == 149 and PurchaseConfig.find("display_6").defaultPrice == 299, "pass display prices")
check(PurchaseConfig.byId(2039798932, "Pass") == PurchaseConfig.find("display_5") and PurchaseConfig.byId(2038047221, "Pass") == PurchaseConfig.find("display_6"), "pass IDs route to their slot")

-- Slot 4: coins only, exact price.
local state = Rules.new(0)
state.coins = 999999
check(not expand(state) and state.display.unlocked == 3, "999,999 coins cannot buy slot 4")
state.coins = 1000000
check(expand(state) and state.display.unlocked == 4 and state.coins == 0, "1,000,000 coins buys slot 4")
state.coins = 10000000
check(not expand(state) and state.display.unlocked == 4 and state.coins == 10000000, "coins cannot buy slot 5")

-- Purchase gating: only the next locked slot's pass is sold.
local fresh = Rules.new(0)
check(not Rules.slotPassEligible(fresh, "display_5"), "slot 5 pass needs slot 4 first")
check(Rules.slotPassEligible(state, "display_5"), "slot 5 pass sells after slot 4")
check(not Rules.slotPassEligible(state, "display_6"), "slot 6 pass needs slot 5 first")
check(not Rules.slotPassEligible(state, "coins_2"), "other products are not slot passes")

-- Applying owned passes.
check(not Rules.applySlotPasses(fresh, owning({ "display_5", "display_6" })) and fresh.display.unlocked == 3, "website-bought passes wait for slot 4")
check(not Rules.applySlotPasses(state, owning({ "display_6" })) and state.display.unlocked == 4, "slot 6 pass waits for slot 5")
local revision = state.revision
check(Rules.applySlotPasses(state, owning({ "display_5" })) and state.display.unlocked == 5, "slot 5 pass unlocks slot 5")
check(state.revision == revision + 1 and state.display.slots[5] == "", "pass unlock is a dense, saved revision")
check(Rules.slotPassEligible(state, "display_6") and not Rules.slotPassEligible(state, "display_5"), "slot 6 sells once slot 5 is unlocked")
check(not Rules.applySlotPasses(state, owning({ "display_5" })), "an applied pass is idempotent")
check(Rules.applySlotPasses(state, owning({ "display_6" })) and state.display.unlocked == 6, "slot 6 pass unlocks slot 6")
local both = Rules.new(0)
both.display.unlocked, both.display.slots[4] = 4, ""
check(Rules.applySlotPasses(both, owning({ "display_5", "display_6" })) and both.display.unlocked == 6, "both passes apply in order")
check(not Rules.slotPassEligible(both, "display_5") and not Rules.slotPassEligible(both, "display_6"), "nothing sells at six slots")

-- Legacy owners: coin-bought slots 5 and 6 stay without any pass, through save and reload.
local legacy = Rules.new(0)
for _, id in { "grove.pebble", "grove.star" } do
	legacy.owned[id], legacy.discovered[id] = 1, true
end
legacy.display.unlocked = 6
for slot = 4, 6 do
	legacy.display.slots[slot] = ""
end
legacy.display.slots[6] = "grove.pebble"
check(not Rules.applySlotPasses(legacy, owning({})) and legacy.display.unlocked == 6, "missing passes never relock")
local loaded = Profile.decode(Profile.encode(legacy), 0)
check(loaded ~= nil and loaded.display.unlocked == 6 and loaded.display.slots[6] == "grove.pebble", "legacy six slots survive save/load")
check(loaded ~= nil and Rules.mutate(loaded, { action = "Place", id = "p", revision = loaded.revision, figure = "grove.star", slot = 5 }, 0, 10), "legacy slot 5 stays usable")
local five = Rules.new(0)
five.display.unlocked = 5
for slot = 4, 5 do
	five.display.slots[slot] = ""
end
check(not Rules.applySlotPasses(five, owning({})) and five.display.unlocked == 5, "legacy five slots kept")
check(Rules.slotPassEligible(five, "display_6"), "legacy slot 5 counts toward the slot 6 pass")
local ok, message = Rules.mutate(legacy, { action = "Expand", id = "e", revision = legacy.revision }, 0, 10)
check(not ok and message == "All Display slots are unlocked.", "full Display rejects expansion")

print(`PASS: {checks} display slot progression and legacy ownership checks`)

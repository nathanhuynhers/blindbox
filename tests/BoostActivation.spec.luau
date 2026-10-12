--!strict
-- Run only in the harness's isolated gate-enabled copy. Production gate is never edited.
local Engine = require("./AfkEngine")
local Storage = require("./Storage")
local Runtime = require("./BoostRuntime")
local Boosts = require("./Boosts")
local Rules = require("./Rules")
local Luck = require("./LuckModifiers")
local Config = require("./PurchaseConfig")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local eligibility = { policy = "Allowed", lineageValidated = true, disclosureReady = true }
check(Boosts.effectsValidated, "Isolated validation fixture enabled")
for _, policy in { "Restricted", "Unknown" } do check(not Runtime.allowed({ policy = policy, lineageValidated = true, disclosureReady = true }), "Per-player restriction " .. policy) end
check(not Runtime.allowed({ policy = "Allowed", lineageValidated = false, disclosureReady = true }), "Lineage required")
check(not Runtime.allowed({ policy = "Allowed", lineageValidated = true, disclosureReady = false }), "Disclosure required")
local s = Storage.open(8001)
assert(s and s.handle)
check(Runtime.fulfill(s, "receipt:activation", { product = "fixture", platformId = 101, kind = "DeveloperProduct", grant = { coins = 0, tokens = { Combo2_30 = 2 } } }, Engine.now), "Durable tokens")
Runtime.sync(s, Config.products, function() return "Unknown", false end, eligibility, Engine.os.time(), Engine.now)
local function request(id, token) return { id = id, token = token or "Combo2_30", revision = s.state.revision } end
local denied = Runtime.activate(s, request("restricted"), { policy = "Restricted", lineageValidated = true, disclosureReady = true }, Engine.os.time(), Engine.now)
check(denied and not denied.ok and s.state.boosts.tokens.Combo2_30 == 2, "Current policy rechecked at activation")
local result = Runtime.activate(s, request("activate"), eligibility, Engine.os.time(), Engine.now)
check(result and result.ok and s.ready and not s.state.boostCommitPending, "Confirmed durable activation")
check(s.state.boosts.coin.expires == s.state.boosts.luck.expires and Rules.luck(s.state) == 2, "Combo both applied")
check(Engine.database.Player_8001.data.boosts.tokens.Combo2_30 == 1 and Engine.database.Player_8001.data.boosts.activations.activate ~= nil, "Consume plus timers plus marker saved atomically")
check(Runtime.activate(s, { id = "activate", token = "Combo2_30", revision = 0 }, eligibility, Engine.os.time(), Engine.now).ok, "Replay ignores stale revision after confirmed commit")
check(s.state.boosts.tokens.Combo2_30 == 1, "Activation never repeated")
check(not Runtime.activate(s, { id = "activate", token = "Coins2_15", revision = 0 }, eligibility, Engine.os.time(), Engine.now).ok, "Changed replay rejected")
local expiry = s.state.boosts.coin.expires
Engine.before = 3
result = Runtime.activate(s, request("extend"), eligibility, Engine.os.time(), Engine.now)
check(result and not result.ok and not s.ready and s.state.boostCommitPending, "Save failure no confirmation")
check(Rules.luck(s.state) == 1 and Rules.earningFactors(s.state).timedCoinFactor == 1, "Unconfirmed extension paused")
check(Storage.flush(s, false), "Recover activation snapshot")
check(s.state.boosts.coin.expires == expiry + 1800 and s.state.boosts.tokens.Combo2_30 == nil, "Extension consumed exactly once")
check(Runtime.activate(s, { id = "extend", token = "Combo2_30", revision = 0 }, eligibility, Engine.os.time(), Engine.now).ok, "Recovered replay")
check(Storage.close(s), "Logout")
Engine.now += 4000
local rejoined = Storage.open(8001)
assert(rejoined)
Runtime.sync(rejoined, Config.products, function() return "Unknown", false end, eligibility, Engine.os.time(), Engine.now)
check(Rules.luck(rejoined.state) == 1 and Rules.boostView(rejoined.state).coinRemaining == 0, "Wall clock expires through logout")
check(rejoined.state.boosts.activations.extend ~= nil, "Durable request marker retained")
check(Storage.close(rejoined), "Release rejoined fixture")
print("Boost activation:", checks, "checks passed")

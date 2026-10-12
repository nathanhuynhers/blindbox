--!strict
-- Run only in the isolated copy with the two purchase gates explicitly lifted by run.py.
-- Actual OfflineRuntime, Profile, Storage, Persistence and AFK boundaries, fake DataStore.
local E = require("./AfkEngine")
local Storage = require("./Storage")
local Runtime = require("./OfflineRuntime")
local Awards = require("./OfflineAwards")
local Profile = require("./Profile")
local Rules = require("./Rules")
local Persistence = require("./Persistence")
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local player = { UserId = 7 }
E.game:GetService("Players").GetPlayerByUserId = function(_, id)
	return if id == player.UserId then player else nil
end
local owner = assert(Storage.open(7))
local notifications = 0
local integration = Runtime.create(function(p)
	return if p == player then owner else nil
end, function(p)
	check(p == player, "Actual runtime notifies only owner")
	notifications += 1
end)
local product = { key = "offline_double", kind = "DeveloperProduct", platformId = 101 }
local function computed(n)
	owner.state.offlinePending = n
	owner.state.offlineSeconds = 3600
	Awards.freeze(owner.state, "display-boost-overlap-v1")
	owner.state.schemaVersion = 17
end
computed(10)
check(
	integration.eligible(7, product) and not integration.eligible(8, product),
	"Actual runtime eligibility/owner boundary"
)
E.before = 3
check(
	not integration.prepare(7, product),
	"Unconfirmed actual reservation save never authorizes prompt"
)
check(
	not owner.ready
		and owner.state.offlineCommitPending
		and owner.pendingSave.offlineData.active == "101",
	"Failed write freezes authority and exact reservation snapshot"
)
check(
	not integration.fulfill({ userId = 7, productId = 101, purchaseId = "early" }, product),
	"No receipt acknowledgement during uncertain write"
)
check(
	Storage.flush(owner, false) and owner.ready and not owner.state.offlineCommitPending,
	"Existing generation reconciliation restores readiness"
)
check(integration.prepare(7, product), "Actual durable reservation confirms before prompting")
local saved = Profile.decode(E.database.Player_7.data, E.now)
check(
	saved.schemaVersion == 17 and saved.offlineData.bindings["101"].award.normal == 10,
	"Exact frozen N stored in same profile"
)
E.after = 3
check(
	not integration.fulfill({ userId = 7, productId = 101, purchaseId = "lost" }, product),
	"Lost real persistence responses defer acknowledgement"
)
check(
	E.database.Player_7.data.offlineData.receipts.lost == "101"
		and owner.pendingSave.offlineData.assistedCredit == 10,
	"Grant/claim/credit/marker committed coherently despite lost response"
)
check(
	owner.state.coins == 4510 and owner.state.offlineData.assistedCredit == 10,
	"Exact 2N once before failure recovery"
)
check(Storage.flush(owner, false), "Confirm original pending save generation")
check(
	integration.fulfill({ userId = 7, productId = 101, purchaseId = "lost" }, product),
	"Duplicate confirms after save recovery"
)
check(
	owner.state.coins == 4510 and owner.state.offlineData.assistedCredit == 10,
	"No 4N after recovery/replay"
)
check(
	not integration.fulfill({ userId = 7, productId = 101, purchaseId = "extra" }, product)
		and E.database.Player_7.data.offlineData.exceptions.extra == 101,
	"Charged extra is durable/unacknowledged through actual adapter"
)
check(not integration.eligible(7, product), "Recovery exception blocks competing offers")
-- Start another isolated account's profile, retain cancelled reservation through AFK/rejoin.
check(Storage.close(owner), "First owner closes safely")
owner = assert(Storage.open(9))
player = { UserId = 9 }
computed(10000)
check(integration.prepare(9, product), "Second isolated fixture reserved")
check(Storage.prepareTeleport(owner), "AFK handoff saves/release aggregate")
local source = owner
check(
	not integration.fulfill({ userId = 9, productId = 101, purchaseId = "during_handoff" }, product),
	"Frozen/released source cannot fulfill"
)
local destination = assert(Storage.open(9))
check(
	destination.state.coins == 14500
		and destination.state.offlinePending == 0
		and destination.state.offlineData.active == "101",
	"Destination auto-claims base, retaining cancelled reservation"
)
owner = destination
computed(7)
check(Storage.flush(owner, false), "New award persists beside older unresolved reservation")
check(
	integration.fulfill({ userId = 9, productId = 101, purchaseId = "delayed" }, product),
	"Old receipt fulfills after AFK/rejoin/newer award"
)
check(
	owner.state.coins == 14500
		and owner.state.offlinePending == 7
		and owner.state.offlineData.assistedCredit == 10000,
	"Only old extra N; newest N untouched"
)
check(not Storage.recoverTeleport(source), "Released source cannot reclaim destination's lease")
-- Schema16 fields survive promotion, snapshots own deep copies and malformed records fail closed.
local encoded = Profile.encode(owner.state)
local decoded = assert(Profile.decode(encoded, E.now))
check(
	decoded.schemaVersion == 17 and decoded.boosts.lastClock == owner.state.boosts.lastClock,
	"Schema17 preserves P04 fields"
)
encoded.offlineData.bindings["101"].award.normal = 0
check(
	owner.state.offlineData.bindings["101"].award.normal == 10000
		and Profile.decode(encoded, E.now) == nil,
	"Deep copies/invalid frozen identity block corrupt saves"
)
local future = Profile.encode(owner.state)
future.schemaVersion = 18
check(Profile.decode(future, E.now) == nil, "Unknown future schema fails closed")
for _, version in { 14, 15, 16 } do
	local old = Rules.new(0)
	old.schemaVersion, old.offlinePending, old.lastSeen = version, 42, 1000000
	local restored = assert(Profile.decode(Profile.encode(old), 0))
	check(
		restored.offlinePending == 42 and restored.offlineData == nil,
		"Legacy pending preserved during schema decode"
	)
	Rules.offline(restored, 1000010)
	check(
		restored.coins == 4542 and restored.offlinePending == 0,
		"Legacy rejoin remains ordinary free claim"
	)
end
local remaining = Profile.encode(owner.state)
remaining.schemaVersion = 16
check(Profile.decode(remaining, E.now) == nil, "Downgrade with reservation/credits is refused")
local conflict = {
	data = Profile.encode(owner.state),
	token = "other",
	writer = "other",
	expires = E.epoch + 9999,
	generation = 88,
}
local update = function(_, transform)
	return transform(conflict)
end
check(
	not Persistence.save(update, owner.handle, Profile.encode(owner.state), E.os.time(), false),
	"Competing profile writer cannot overwrite obligation"
)
check(
	not integration.fulfill({ userId = 8, productId = 101, purchaseId = "spoof" }, product),
	"Actual adapter rejects cross-owner receipt"
)
print(string.format("PASS: %d actual offline Storage/Persistence/AFK fixture checks", checks))

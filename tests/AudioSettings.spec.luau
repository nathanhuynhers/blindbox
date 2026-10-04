--!strict
-- Schema-v12 audio settings: SetVolume validation, the mutation, the transaction path and
-- fail-closed persistence with upgrades from every supported older schema.
local Rules = require("./Rules")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local function intent(fields: { [string]: any }): { [string]: any }
	local base: { [string]: any } = { action = "SetVolume", id = "v", revision = 0 }
	for key, value in fields do
		base[key] = value
	end
	return base
end

-- Fresh profiles start at full volume.
local fresh = Rules.new(0)
check(fresh.sfxVolume == 100 and fresh.musicVolume == 100, "fresh profiles start at 100%")

-- Protocol: only sfx/music, whole percent 0..100, and volume only on SetVolume.
check(Protocol.parse(intent({ choice = "sfx", volume = 40 })) ~= nil, "sfx 40 parses")
check(Protocol.parse(intent({ choice = "music", volume = 0 })) ~= nil, "music 0 parses")
check(Protocol.parse(intent({ choice = "music", volume = 100 })) ~= nil, "music 100 parses")
for _, bad in
	{
		intent({ choice = "ui", volume = 40 }),
		intent({ volume = 40 }),
		intent({ choice = "sfx" }),
		intent({ choice = "sfx", volume = -1 }),
		intent({ choice = "sfx", volume = 101 }),
		intent({ choice = "sfx", volume = 12.5 }),
		intent({ choice = "sfx", volume = 0 / 0 }),
		intent({ choice = "sfx", volume = math.huge }),
		intent({ choice = "sfx", volume = "50" }),
		intent({ choice = "sfx", volume = 50, figure = "grove.acorn" }),
		intent({ choice = "sfx", volume = 50, slot = 1 }),
		{ action = "Goal", id = "g", revision = 0, volume = 50 },
	}
do
	check(Protocol.parse(bad) == nil, "malformed SetVolume or stray volume rejected")
end
local a = Protocol.parse(intent({ choice = "sfx", volume = 40 })) :: any
local b = Protocol.parse(intent({ choice = "sfx", volume = 60 })) :: any
check(not Protocol.same(a, b), "receipts tell different volumes apart")

-- The transaction path: saves, bumps the revision (autosave) and replays by receipt.
local session = Transactions.new(0)
local reply =
	Transactions.process(session, intent({ id = "s1", choice = "music", volume = 35 }), 1, true, 0)
check(reply ~= nil and reply.ok and session.state.musicVolume == 35, "SetVolume saves music")
check(session.state.sfxVolume == 100 and session.state.revision == 1, "only music changed")
local replay =
	Transactions.process(session, intent({ id = "s1", choice = "music", volume = 35 }), 2, true, 0)
check(replay == reply and session.state.revision == 1, "a retried save replays its receipt")
local stale =
	Transactions.process(session, intent({ id = "s2", choice = "sfx", volume = 20 }), 3, true, 0)
check(stale ~= nil and not stale.ok and session.state.sfxVolume == 100, "stale revision rejected")
local sfx = Transactions.process(
	session,
	intent({ id = "s3", choice = "sfx", volume = 20, revision = 1 }),
	4,
	true,
	0
)
check(sfx ~= nil and sfx.ok and session.state.sfxVolume == 20, "SetVolume saves sfx")

-- Persistence: v12 round-trips; invalid values fail closed.
local saved = Profile.encode(session.state)
check(saved.schemaVersion == 13, "encodes schema 13")
local restored = Profile.decode(saved, 0)
check(
	restored ~= nil and restored.sfxVolume == 20 and restored.musicVolume == 35,
	"volumes round-trip"
)
for _, value in { -1, 101, 50.5, 0 / 0, math.huge, "80" } do
	local corrupt = Profile.encode(session.state) :: any
	corrupt.musicVolume = value
	check(Profile.decode(corrupt, 0) == nil, "invalid music volume fails closed")
end
local missing = Profile.encode(session.state) :: any
missing.sfxVolume = nil
check(Profile.decode(missing, 0) == nil, "v12 without a volume fails closed")

-- Older schemas upgrade at full volume, and may not carry the new fields.
for version = 6, 11 do
	local old = Profile.encode(Rules.new(0)) :: any
	old.schemaVersion = version
	old.sfxVolume, old.musicVolume = nil, nil
	old.tutorialHidden = nil
	if version < 11 then
		old.lastLoginDay, old.loginStreak = nil, nil
	end
	if version < 10 then
		old.lastSeen, old.offlinePending = nil, nil
	end
	if version < 9 then
		old.shelfRewards = nil
	end
	if version < 8 then
		old.boxesOpened = nil
	end
	if version < 7 then
		old.earnings = nil
	end
	local upgraded = Profile.decode(old, 0)
	check(
		upgraded ~= nil and upgraded.sfxVolume == 100 and upgraded.musicVolume == 100,
		"v" .. version .. " upgrades at full volume"
	)
	local premature = table.clone(old)
	premature.sfxVolume = 50
	check(Profile.decode(premature, 0) == nil, "v" .. version .. " carrying a volume fails closed")
end
print(`PASS: {checks} audio settings validation, transaction and persistence checks`)

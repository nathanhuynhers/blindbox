--!strict
-- Schema-v11 consecutive Daily Login: streak rules, one claim per UTC day, atomic grants,
-- remote validation and fail-closed persistence. Uses the actual reward table, whatever it holds.
local Rules = require("./Rules")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local LoginRewards = require("./LoginRewards")
local Types = require("./Types")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local rolls = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95 }
local function claim(state: Types.State, day: number): (boolean, string, string?, { string }?)
	return Rules.mutate(state, { action = "Login", id = "login" .. day, revision = state.revision }, rolls, day)
end
local function boxes(reward: LoginRewards.Reward): number
	return if reward.boxes then reward.boxes.count else 0
end

check(#LoginRewards.days >= 1, "reward table has days")
check(LoginRewards.day(1) == 1 and LoginRewards.day(#LoginRewards.days + 1) == 1, "cycle loops to Day 1")

-- Seven-plus consecutive days: each claim grants exactly that day's table entry.
local state = Rules.new(0)
check(state.schemaVersion == 12 and state.lastLoginDay == -1 and state.loginStreak == 0, "fresh profile never claimed")
local start = 20000
for offset = 0, #LoginRewards.days do
	local day = start + offset
	local reward = LoginRewards.reward(offset + 1)
	local coins, opened = state.coins, state.boxesOpened
	local ok, _, figure, figures = claim(state, day)
	check(ok and state.loginStreak == offset + 1 and state.lastLoginDay == day, "consecutive claim advances the streak")
	check(state.coins == coins + reward.coins, "grants exactly the table's Coins")
	check(state.boxesOpened == opened + boxes(reward), "opens exactly the table's boxes")
	local granted = if figures then #figures elseif figure then 1 else 0
	check(granted == boxes(reward), "reply names every granted figure")
	for _, id in figures or { figure } do
		check(Catalog.byId[id].collection == (reward.boxes :: LoginRewards.Boxes).collection, "box rolls its collection")
	end
	-- Double claim on the same UTC day changes nothing.
	local revision, after = state.revision, state.coins
	check(not claim(state, day), "second claim on the same day fails")
	check(state.revision == revision and state.coins == after, "refused claim mutates nothing")
end
check(LoginRewards.day(state.loginStreak) == 1, "day after the last entry pays Day 1 again")

-- Missing a day resets to Day 1; a backwards clock never pays.
local streakDay = state.lastLoginDay
check(not claim(state, streakDay - 3), "clock rollback cannot claim")
check(claim(state, streakDay + 2) and state.loginStreak == 1, "a missed day restarts at Day 1")
check(Rules.loginStreak(state, state.lastLoginDay + 1) == 2, "tomorrow continues the restarted streak")
check(Rules.loginStreak(state, state.lastLoginDay + 5) == 1, "a later gap resets the preview")

-- Wallet ceiling and box safety limit refuse the whole claim.
local rich = Rules.new(0)
rich.coins = Economy.coinLimit
if LoginRewards.days[1].coins > 0 then
	check(not claim(rich, start) and rich.lastLoginDay == -1, "a full wallet refuses a Coin reward without using the day")
end
for index, reward in LoginRewards.days do
	local rewardBoxes = reward.boxes
	if rewardBoxes then
		local full = Rules.new(0)
		full.lastLoginDay, full.loginStreak = start - 1, index - 1
		for _, figure in Catalog.figures do
			if figure.collection == rewardBoxes.collection then
				full.owned[figure.id], full.discovered[figure.id] = Economy.copyLimit, true
				break
			end
		end
		local coins = full.coins
		check(not claim(full, start) and full.coins == coins and full.lastLoginDay == start - 1, "box safety limit refuses atomically")
		break
	end
end

-- Remote validation: allowlisted, no extra fields, receipts replay without a second grant.
check(Protocol.parse({ action = "Login", id = "a", revision = 0 }) ~= nil, "bare Login parses")
check(Protocol.parse({ action = "Login", id = "a", revision = 0, choice = "grove" }) == nil, "client cannot pick a box")
check(Protocol.parse({ action = "Login", id = "a", revision = 0, figure = "grove.star" }) == nil, "client cannot pick a figure")
check(Protocol.parse({ action = "Login", id = "a", revision = 0, slot = 1 }) == nil, "client cannot send a day")
check(Protocol.parse({ action = "Login", id = "a", revision = 0, coins = 1e9 } :: any) == nil, "client cannot send a reward")
local session = Transactions.new(0)
local raw = { action = "Login", id = "login-once", revision = 0 }
local reply = Transactions.process(session, raw, 0, false, rolls, start)
local coins = session.state.coins
check(reply ~= nil and reply.ok and session.state.loginStreak == 1, "remote claim succeeds once")
check(Transactions.process(session, raw, 0.1, false, rolls, start) == reply and session.state.coins == coins, "replay returns the receipt")
local again = Transactions.process(session, { action = "Login", id = "login-twice", revision = session.state.revision }, 1, false, rolls, start)
check(again ~= nil and not again.ok and session.state.coins == coins, "fresh request id cannot claim twice in a day")
for index = 1, 10 do
	Transactions.process(session, { action = "Login", id = "spam" .. index, revision = session.state.revision }, 1, false, rolls, start)
end
check(session.tokens < 1, "the shared token bucket rate-limits claim spam")

-- Persistence: v11 round trip, v6-v10 upgrade to never-claimed, fail-closed invalid pairs.
local restored = Profile.decode(Profile.encode(state), 0)
check(
	restored ~= nil and restored.lastLoginDay == state.lastLoginDay and restored.loginStreak == state.loginStreak,
	"v11 round trip keeps the streak"
)
check(Profile.encode(state).schemaVersion == 12, "encodes schema 12")
for _, version in { 6, 7, 8, 9, 10 } do
	local old = Profile.encode(Rules.new(0)) :: any
	old.schemaVersion, old.lastLoginDay, old.loginStreak = version, nil, nil
	old.sfxVolume, old.musicVolume = nil, nil
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
	check(upgraded ~= nil and upgraded.lastLoginDay == -1 and upgraded.loginStreak == 0, "older schema upgrades unclaimed")
	check(old.lastLoginDay == nil, "upgrade does not mutate its input")
	local premature = Profile.encode(Rules.new(0)) :: any
	premature.schemaVersion = version
	premature.lastSeen = if version >= 10 then premature.lastSeen else nil
	premature.offlinePending = if version >= 10 then premature.offlinePending else nil
	premature.shelfRewards = if version >= 9 then premature.shelfRewards else nil
	premature.boxesOpened = if version >= 8 then premature.boxesOpened else nil
	premature.earnings = if version >= 7 then premature.earnings else nil
	check(Profile.decode(premature, 0) == nil, "older schema carrying login fields fails closed")
end
for _, pair in { { -1, 3 }, { 20000, 0 }, { 20000, -1 }, { 20000, 1.5 }, { 0 / 0, 1 }, { -2, 0 } } do
	local bad = Profile.encode(state) :: any
	bad.lastLoginDay, bad.loginStreak = pair[1], pair[2]
	check(Profile.decode(bad, 0) == nil, "inconsistent or invalid login pair fails closed")
end
local missing = Profile.encode(state) :: any
missing.loginStreak = nil
check(Profile.decode(missing, 0) == nil, "v11 without the streak fails closed")
local future = Profile.encode(state) :: any
future.schemaVersion = 13
check(Profile.decode(future, 0) == nil, "unknown future schema fails closed")

-- Box days hand off to the existing opening: one figure as a single reveal, several as a batch.
local OpeningResult = require("./OpeningResult")
local fresh = Rules.new(0)
local after = Rules.new(0)
local one, many = "grove.star", { "grove.star", "grove.moth" }
for _, id in many do
	after.owned[id], after.discovered[id] = 1, true
end
local request: Types.Intent = { action = "Login", id = "box", revision = 0 }
check(
	OpeningResult.fromReply(request, fresh, after, { id = "box", ok = true, message = "", figure = one }) ~= nil,
	"single-box Login reply opens one box"
)
check(
	#OpeningResult.fromBatch(request, fresh, after, { id = "box", ok = true, message = "", figures = many }) == 3,
	"multi-box Login reply plays tease plus each reveal"
)
check(
	OpeningResult.fromReply(request, fresh, after, { id = "box", ok = true, message = "" }) == nil,
	"Coin-only Login reply opens nothing"
)

print("PASS: " .. checks .. " Daily Login streak, claim, remote and persistence checks")

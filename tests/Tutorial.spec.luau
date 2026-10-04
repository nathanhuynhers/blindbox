--!strict
-- Schema-13 Welcome Quest authority: stages advance only from the action they teach, the
-- Welcome Box and Welcome x10 are one-time guaranteed grants, and every stage survives a
-- save/rejoin without repeating a reward. Real Rules/Transactions/Profile; no Studio.
local Rules = require("./Rules")
local Profile = require("./Profile")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local Economy = require("./Economy")
local Catalog = require("./Catalog")
local Rarity = require("./Rarity")
local Tutorial = require("./Tutorial")
local Types = require("./Types")
local checks = 0
local function check(condition: boolean, description: string)
	assert(condition, description)
	checks += 1
end
local grove = Economy.welcome.collection
local function rank(id: string): number
	return table.find(Rarity.order, Catalog.byId[id].rarity) or 0
end
local function rolls(value: number): { number }
	return table.create(10, value)
end
local sequence, clock = 0, 0
-- Each request one second later, so the transaction token bucket never throttles the script.
local function tick(): number
	clock += 1
	return clock
end
local function intent(state: Types.State, action: string, fields: { [string]: any }?): { [string]: any }
	sequence += 1
	local made: { [string]: any } = { action = action, id = action .. sequence, revision = state.revision }
	for key, value in fields or {} do
		made[key] = value
	end
	return made
end
local function send(session: Transactions.Session, action: string, fields: { [string]: any }?, roll: { number }?)
	local reply = Transactions.process(session, intent(session.state, action, fields), tick(), true, roll or rolls(0.5), 20000)
	return reply
end
local function collect(session: Transactions.Session, slot: number)
	local id = session.state.display.slots[slot]
	session.state.earnings[id] = (session.state.earnings[id] or 0) + 50
	local reply = Transactions.process(session, intent(session.state, "Collect", { slot = slot, figure = id }), tick(), true, 0, 20000, nil, true)
	return reply
end
-- Save and load as a rejoin would: through the persisted aggregate only.
local function rejoin(session: Transactions.Session): Transactions.Session
	local fresh = Transactions.new(clock)
	fresh.state = assert(Profile.decode(Profile.encode(session.state), clock), "profile round trip")
	return fresh
end

-- Intents carry no payload; Protocol rejects extras.
for _, action in { "Welcome", "WelcomeTen", "SkipTutorial" } do
	check(Protocol.parse({ action = action, id = "a", revision = 0 }) ~= nil, action .. " parses")
	check(Protocol.parse({ action = action, id = "a", revision = 0, choice = "tide" }) == nil, action .. " rejects a choice")
	check(Protocol.parse({ action = action, id = "a", revision = 0, figure = "grove.star" }) == nil, action .. " rejects a figure")
end

-- Fresh player starts the quest.
local fresh = Rules.new(0)
check(fresh.step == Tutorial.welcome and fresh.tutorialHidden == false, "new player starts at the Welcome Box")

-- Welcome Box: Uncommon or better for every roll, normal odds untouched.
local floor = table.find(Rarity.order, Economy.welcome.box :: Rarity.Id) or 0
local seen: { [string]: boolean } = {}
for value = 0, 999 do
	local state = Rules.new(0)
	local ok, _, figure = Rules.mutate(state, { action = "Welcome", id = "w", revision = 0 }, rolls(value / 1000), 1)
	check(ok and figure ~= nil and rank(figure :: string) >= floor, "Welcome Box is Uncommon or Rare")
	check(Catalog.byId[figure :: string].collection == grove and state.owned[figure :: string] == 1, "Welcome Box grants one Grove figure")
	seen[Catalog.byId[figure :: string].rarity] = true
	check(state.coins == Economy.startingCoins and state.step == Tutorial.display, "free, and moves to Display")
end
check(seen.Uncommon and seen.Rare and not seen.Common, "both allowed rarities occur; Common never does")
check(Rules.roll(0, grove) ~= Rules.roll(0, grove, nil, "Uncommon") and rank(Rules.roll(0, grove)) == 1, "normal Grove rolls keep Common")

-- One Welcome Box only, even with a different request id.
local session = Transactions.new(0)
local first = assert(send(session, "Welcome"), "welcome reply")
check(first.ok and first.figure ~= nil and session.state.boxesOpened == 1, "claims the Welcome Box")
local owned = session.state.owned[first.figure :: string]
check(not (assert(send(session, "Welcome"))).ok and session.state.owned[first.figure :: string] == owned, "cannot repeat the Welcome Box")
check(not (assert(send(session, "WelcomeTen"))).ok, "Welcome x10 is locked until the quest is done")

-- Rejoin after the Welcome Box resumes at Display, without a second box.
session = rejoin(session)
check(session.state.step == Tutorial.display, "rejoin resumes at Display")
check(not (assert(send(session, "Welcome"))).ok, "rejoin cannot reclaim the Welcome Box")

-- Coin rewards and other actions never complete Display or collection steps.
local figure = first.figure :: string
check((assert(send(session, "Buy", { choice = grove }))).ok and session.state.step == Tutorial.display, "buying early does not skip ahead")
check((assert(send(session, "Place", { figure = figure, slot = 1 }))).ok and session.state.step == Tutorial.collect, "placing a figure advances")
local coins = session.state.coins
check((assert(send(session, "Login"))).ok and session.state.coins > coins, "Daily Login pays Coins")
check(session.state.step == Tutorial.collect, "Daily Login reward cannot complete collection")
session.state.goalProgress = 3
check((assert(send(session, "Goal"))).ok and session.state.coins > coins, "goal reward pays")
check(session.state.step == Tutorial.collect, "Goal reward cannot complete collection")
session.state.offlinePending = 250
check((assert(send(session, "ClaimOffline"))).ok and session.state.step == Tutorial.collect, "offline Coins cannot complete collection")
check(not (assert(send(session, "Collect", { slot = 1, figure = figure }))).ok and session.state.step == Tutorial.collect, "a remote Collect cannot complete collection")
session.state.coins += 1000 -- A Studio grant or any other wallet change.
check(session.state.step == Tutorial.collect, "wallet changes alone do nothing")

-- Rejoin after placement keeps the collect step.
session = rejoin(session)
check(session.state.step == Tutorial.collect, "rejoin resumes at collect")
check((assert(collect(session, 1))).ok and session.state.step == Tutorial.buy, "real Display collection advances")

-- Rejoin before the second purchase, then the Daily free box does not count, a paid one does.
session = rejoin(session)
check(session.state.step == Tutorial.buy, "rejoin resumes before the paid box")
session.state.lastDailyDay = -1
check((assert(send(session, "Daily"))).ok and session.state.step == Tutorial.buy, "the free Daily box does not count")
check(not (assert(send(session, "WelcomeTen"))).ok, "no x10 before the paid box")
coins = session.state.coins
check((assert(send(session, "Buy", { choice = "tide" }))).ok and session.state.step == Tutorial.reward, "a paid box completes the quest")
check(session.state.coins == coins - Rules.prices.tide, "the paid box costs its normal price")

-- Rejoin before opening the x10 keeps exactly one pending reward.
session = rejoin(session)
check(session.state.step == Tutorial.reward, "the x10 waits across rejoin")
local opened, wallet = session.state.boxesOpened, session.state.coins
local ten = assert(send(session, "WelcomeTen", nil, rolls(0)), "x10 reply")
check(ten.ok and ten.figures ~= nil and #(ten.figures :: { string }) == 10, "grants ten figures")
check(session.state.coins == wallet and session.state.boxesOpened == opened + 10, "free and counted as ten boxes")
check(session.state.step == Tutorial.shelves, "moves to the optional Shelves tip")
local rare = false
for _, id in ten.figures :: { string } do
	check(Catalog.byId[id].collection == grove, "every x10 figure is Grove")
	rare = rare or rank(id) >= (table.find(Rarity.order, Economy.welcome.ten :: Rarity.Id) or 0)
end
check(rare, "the all-Common roll still contains a Rare")
check(not (assert(send(session, "WelcomeTen"))).ok and session.state.boxesOpened == opened + 10, "x10 cannot repeat")
session = rejoin(session)
check(not (assert(send(session, "WelcomeTen"))).ok and not (assert(send(session, "Welcome"))).ok, "no Welcome reward after rejoin")

-- x10 guarantee: always at least one Rare; natural Rares are kept, not replaced.
for value = 0, 99 do
	local state = Rules.new(0)
	state.step = Tutorial.reward
	local values = table.create(10, value / 100)
	local ok, _, _, figures = Rules.mutate(state, { action = "WelcomeTen", id = "t", revision = 0 }, values, 1)
	local best, rares = 0, 0
	for _, id in figures :: { string } do
		best = math.max(best, rank(id))
		rares += if rank(id) >= 3 then 1 else 0
	end
	check(ok and best >= 3, "every x10 has a Rare")
	if value >= 90 then
		check(rares == 10, "naturally Rare rolls are all kept")
	end
end
local natural = Rules.new(0)
natural.step = Tutorial.reward
local mixed = { 0.95, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
local _, _, _, mixedFigures = Rules.mutate(natural, { action = "WelcomeTen", id = "m", revision = 0 }, mixed, 1)
check(rank((mixedFigures :: { string })[10]) == 1, "an early Rare leaves the last roll normal")

-- The optional Shelves tip ends only on a real Shelf placement.
local Shelves = require("./Shelves")
local ShelfConfig = require("./ShelfConfig")
local access = { actorId = 1, ownerId = 1, insidePlot = true, view = Shelves.newView() }
local function shelfSend(action: string, fields: { [string]: any })
	fields.carouselRevision = access.view.revision
	local reply = Transactions.process(session, intent(session.state, action, fields), tick(), true, 0, 20000, access)
	return reply
end
check(not (assert(shelfSend("ShelfNext", {}))).ok and session.state.step == Tutorial.shelves, "Shelf navigation does not finish the tip")
local place = assert(shelfSend("ShelfPlace", {
	figure = (ten.figures :: { string })[1],
	shelfId = "shelf:1",
	shelfSlotId = ShelfConfig.slots()[1],
}))
check(place.ok and session.state.step == Tutorial.done, "placing on a Shelf finishes the tip")
check(rejoin(session).state.step == Tutorial.done, "finished quest persists")

-- Skip hides guidance once, persists, and never grants or blocks rewards.
local skipper = Transactions.new(0)
local before = skipper.state.coins
check((assert(send(skipper, "SkipTutorial"))).ok and skipper.state.tutorialHidden, "skip hides guidance")
check(not (assert(send(skipper, "SkipTutorial"))).ok and skipper.state.coins == before, "skip again changes nothing")
skipper = rejoin(skipper)
check(skipper.state.tutorialHidden and skipper.state.step == Tutorial.welcome, "skip persists across rejoin")
check((assert(send(skipper, "Welcome"))).ok and not (assert(send(skipper, "Welcome"))).ok, "a skipped player can still claim the box once")
local done = Rules.new(0)
done.step = Tutorial.done
check(not Rules.mutate(done, { action = "SkipTutorial", id = "s", revision = 0 }, rolls(0), 1), "a finished quest has nothing to skip")

-- Persistence: v13 validation and the one-time legacy mapping.
local saved = Profile.encode(session.state)
check(saved.schemaVersion == 13 and saved.step == Tutorial.done and saved.tutorialHidden == false, "encodes stage and skip")
for _, broken in { 0, 8, 2.5 } do
	local copy = Profile.encode(session.state)
	copy.step = broken
	check(Profile.decode(copy, 0) == nil, "invalid stage fails closed")
end
local missing = Profile.encode(session.state) :: any
missing.tutorialHidden = nil
check(Profile.decode(missing, 0) == nil, "v13 requires the skip flag")
local function legacy(state: Types.State, step: number): any
	local old = Profile.encode(state) :: any
	old.schemaVersion, old.tutorialHidden, old.step = 12, nil, step
	return old
end
local blank = Rules.new(0)
check((assert(Profile.decode(legacy(blank, 1), 0))).step == Tutorial.welcome, "an untouched v12 profile starts the quest")
local veteran = assert(Profile.decode(legacy(session.state, 5), 0))
check(veteran.step == Tutorial.done and not veteran.tutorialHidden, "an established v12 profile is finished, no rewards")
local partial = assert(Profile.decode(legacy(session.state, 2), 0))
check(partial.step == Tutorial.done, "old stages are never reinterpreted as reward stages")
local hidden = legacy(blank, 1)
hidden.tutorialHidden = true
check(Profile.decode(hidden, 0) == nil, "old schemas cannot carry the v13 field")
check(Profile.decode(legacy(blank, 6), 0) == nil, "old schemas keep their 1..5 range")

print("PASS: " .. checks .. " Welcome Quest authority, reward and persistence checks")

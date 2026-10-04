--!strict
-- Read-only presentation projections. The server still validates every action and all values.
--
-- Economy boundary: every value the economy redesign changes (box price, odds, per-figure rate,
-- set bonus, free-box options, slot price, goal reward) is read in the "Economy fields" section
-- below and nowhere else. Screens call these functions; they never index those snapshot fields.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local DisplayConfig = require(game:GetService("ReplicatedStorage").Shared.DisplayConfig)
local LoginRewards = require(game:GetService("ReplicatedStorage").Shared.LoginRewards)
local State = {}

-- Formatting -------------------------------------------------------------------------------

local function finite(value: number): number
	return if value ~= value or value == math.huge or value == -math.huge then 0 else value
end

function State.number(value: number): string
	local integer = tostring(math.floor(math.max(0, finite(value))))
	local reversed = string.gsub(string.reverse(integer), "(%d%d%d)", "%1,")
	local result = string.reverse(reversed)
	return (string.gsub(result, "^,", ""))
end

-- Abbreviations round down so an affordable-looking balance is never overstated.
function State.compact(value: number): string
	value = math.max(0, finite(value))
	if value < 10000 then
		return State.number(value)
	end
	local units: { { any } } = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, unit in units do
		local size = unit[1] :: number
		if value >= size then
			return string.format("%g%s", math.floor(value / size * 10) / 10, unit[2] :: string)
		end
	end
	return State.number(value)
end

local function trim(text: string): string
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

-- Rates keep useful fractions while small (1.25/s) and abbreviate when large (2.4M/s).
function State.amount(value: number): string
	value = math.max(0, finite(value))
	if value >= 10000 then
		return State.compact(value)
	end
	if value >= 100 then
		return State.number(value)
	end
	return trim(string.format("%.2f", math.floor(value * 100 + 0.5) / 100))
end

function State.rate(value: number): string
	return "+" .. State.amount(value) .. "/s"
end

function State.percent(value: number): string
	value = math.clamp(finite(value), 0, 100)
	if value == 0 then
		return "0%"
	end
	local text = if value >= 1
		then string.format("%.1f", math.floor(value * 10 + 0.5) / 10)
		else string.format("%.3f", math.floor(value * 1000 + 0.5) / 1000)
	return trim(text) .. "%"
end

-- Economy fields (merge surface) -----------------------------------------------------------

-- Box price for one collection (server-published per collection).
function State.price(snapshot: Types.Snapshot, collection: string): number
	return snapshot.prices[collection] or 0
end

-- Effective Display rate for the copies owned now (duplicates included by the server).
function State.figureRate(snapshot: Types.Snapshot, id: string): number
	return snapshot.rates[id] or 0
end

-- Current chance (includes increasing-chance luck) and the published base chance.
function State.figureOdds(snapshot: Types.Snapshot, id: string): number
	return snapshot.odds[id] or 0
end

function State.baseOdds(snapshot: Types.Snapshot, id: string): number
	return snapshot.baseOdds[id] or snapshot.odds[id] or 0
end

function State.totalRate(snapshot: Types.Snapshot): number
	return snapshot.rate
end

-- Set bonus as Coins/second already included in totalRate (server computes the percentage).
function State.bonusAmount(snapshot: Types.Snapshot): number
	return snapshot.bonus
end

-- Uncollected Coins banked by one displayed figure (collected in the world, never here).
function State.earnings(snapshot: Types.Snapshot, id: string): number
	return math.floor(snapshot.earnings[id] or 0)
end

function State.freeBoxOptions(snapshot: Types.Snapshot): { string }
	return if snapshot.dailyCollection ~= "" then { snapshot.dailyCollection } else {}
end

-- Only the next slot is purchasable; its price comes from the snapshot.
function State.unlockPrice(snapshot: Types.Snapshot, slot: number): number?
	local method = DisplayConfig.unlockMethods[slot]
	return if slot == snapshot.unlocked + 1
			and method == "Coins"
			and snapshot.expansionCost > 0
		then snapshot.expansionCost
		else nil
end

-- Locked-slot copy: a later coin slot unlocks in order; anything else is not available yet.
function State.lockedText(_snapshot: Types.Snapshot, slot: number): string
	return if DisplayConfig.unlockMethods[slot] == "Coins"
		then "Unlock slot " .. math.max(1, slot - 1) .. " first"
		else "Coming later"
end

function State.goalReward(snapshot: Types.Snapshot): number
	return snapshot.goalReward
end

-- Unclaimed offline Coins (formatted) and the absence that earned them, or nil when none.
function State.offline(snapshot: Types.Snapshot): (string?, string)
	if snapshot.offlinePending <= 0 then
		return nil, ""
	end
	local seconds = math.floor(snapshot.offlineSeconds)
	local hours, minutes = seconds // 3600, seconds % 3600 // 60
	return State.number(snapshot.offlinePending),
		if hours > 0 then `{hours}h {minutes}m` else `{math.max(1, minutes)}m`
end

-- Collections ------------------------------------------------------------------------------

local membersById: { [string]: { string } } = {}
for _, figure in Catalog.figures do
	local members = membersById[figure.collection]
	if not members then
		members = {}
		membersById[figure.collection] = members
	end
	table.insert(members, figure.id)
end

function State.members(collection: string): { string }
	return membersById[collection] or {}
end

function State.collectionName(collection: string): string
	for _, entry in Catalog.collections do
		if entry.id == collection then
			return entry.name
		end
	end
	return collection
end

function State.completion(snapshot: Types.Snapshot, collection: string): (number, number)
	local found, members = 0, State.members(collection)
	for _, id in members do
		if snapshot.discovered[id] then
			found += 1
		end
	end
	return found, #members
end

function State.totalCompletion(snapshot: Types.Snapshot): (number, number)
	local found = 0
	for _, figure in Catalog.figures do
		if snapshot.discovered[figure.id] then
			found += 1
		end
	end
	return found, #Catalog.figures
end

function State.progressText(snapshot: Types.Snapshot, collection: string): string
	local found, total = State.completion(snapshot, collection)
	return if found >= total and total > 0
		then "Complete! Every figure found"
		else string.format(
			"%d of %d found · %d left to discover",
			found,
			total,
			total - found
		)
end

-- "all" | "found" | "missing"
export type Filter = string
function State.filtered(snapshot: Types.Snapshot, collection: string, filter: Filter): { string }
	local ids: { string } = {}
	for _, id in State.members(collection) do
		local found = snapshot.discovered[id] == true
		if filter == "all" or (filter == "found") == found then
			table.insert(ids, id)
		end
	end
	return ids
end

export type OddsRow = { rarity: string, count: number, total: number, base: number, each: number? }
-- Per-rarity rows derived from server-provided odds; "each" only when the rarity is uniform.
function State.rarityOdds(snapshot: Types.Snapshot, collection: string): { OddsRow }
	local rows: { OddsRow } = {}
	for _, rarity in Rarity.order do
		local count, total, base, first, uniform = 0, 0, 0, nil :: number?, true
		for _, id in State.members(collection) do
			if Catalog.byId[id].rarity == rarity then
				local odds = State.figureOdds(snapshot, id)
				count += 1
				total += odds
				base += State.baseOdds(snapshot, id)
				if first == nil then
					first = odds
				elseif math.abs(odds - first) > 1e-9 then
					uniform = false
				end
			end
		end
		if count > 0 then
			table.insert(rows, {
				rarity = rarity,
				count = count,
				total = total,
				base = base,
				each = if uniform and count > 1 then first else nil,
			})
		end
	end
	return rows
end

function State.oddsLabel(row: OddsRow): string
	local text = if row.count == 1
		then "1 figure"
		elseif row.each then string.format(
			"%d figures, %s each",
			row.count,
			State.percent(row.each)
		)
		else string.format("%d figures", row.count)
	-- Increasing-chance luck: show the base next to a raised current chance.
	return if row.total > row.base + 1e-6
		then text .. " · base " .. State.percent(row.base)
		else text
end

-- Copies and Display -----------------------------------------------------------------------

function State.copies(snapshot: Types.Snapshot, id: string): (number, number)
	local owned, displayed = snapshot.owned[id] or 0, 0
	for _, placed in snapshot.slots do
		if placed == id then
			displayed += 1
		end
	end
	-- One Display placement per unique figure; extra copies boost its rate instead.
	return owned, if owned > 0 and displayed == 0 then 1 else 0
end

function State.displayed(snapshot: Types.Snapshot, id: string): boolean
	return id ~= "" and table.find(snapshot.slots, id) ~= nil
end

function State.shelfAvailable(snapshot: Types.Snapshot, id: string): number
	return math.max(0, snapshot.shelfAvailable[id] or 0)
end

function State.emptySlots(snapshot: Types.Snapshot): { number }
	local slots: { number } = {}
	for slot = 1, math.min(snapshot.unlocked, DisplayConfig.maxSlots) do
		if (snapshot.slots[slot] or "") == "" then
			table.insert(slots, slot)
		end
	end
	return slots
end

export type Pick = { id: string, rate: number }
local function better(a: Pick, b: Pick): boolean
	if a.rate ~= b.rate then
		return a.rate > b.rate
	end
	local ra, rb = Rarity.rank(Catalog.byId[a.id].rarity), Rarity.rank(Catalog.byId[b.id].rarity)
	if ra ~= rb then
		return ra > rb
	end
	return Catalog.byId[a.id].name < Catalog.byId[b.id].name
end
-- Owned figures not already displayed, best earners first (top one is tagged BEST).
function State.picker(snapshot: Types.Snapshot): { Pick }
	local picks: { Pick } = {}
	for _, figure in Catalog.figures do
		local _, free = State.copies(snapshot, figure.id)
		if free > 0 and not State.displayed(snapshot, figure.id) then
			table.insert(picks, { id = figure.id, rate = State.figureRate(snapshot, figure.id) })
		end
	end
	table.sort(picks, better)
	return picks
end

export type Placement = { kind: string, slot: number, replaces: string?, gain: number }
-- Empty unlocked slot: place there. Full: swap out the lowest earner only if this earns more.
function State.placement(snapshot: Types.Snapshot, id: string): Placement?
	local _, free = State.copies(snapshot, id)
	if free < 1 or State.displayed(snapshot, id) or not Catalog.byId[id] then
		return nil
	end
	local rate = State.figureRate(snapshot, id)
	local empty = State.emptySlots(snapshot)
	if #empty > 0 then
		return { kind = "empty", slot = empty[1], replaces = nil, gain = rate }
	end
	local lowest: number?, lowestRate = nil, math.huge
	for slot = 1, math.min(snapshot.unlocked, DisplayConfig.maxSlots) do
		local placed = snapshot.slots[slot] or ""
		local placedRate = State.figureRate(snapshot, placed)
		if placed ~= "" and placedRate < lowestRate then
			lowest, lowestRate = slot, placedRate
		end
	end
	if lowest and rate > lowestRate then
		return {
			kind = "swap",
			slot = lowest,
			replaces = snapshot.slots[lowest],
			gain = rate - lowestRate,
		}
	end
	return nil
end

export type Bonus = { active: boolean, collection: string?, best: number, amount: number }
function State.setBonus(snapshot: Types.Snapshot): Bonus
	local seen: { [string]: boolean } = {}
	local counts: { [string]: number } = {}
	local best, bestCollection = 0, nil :: string?
	for _, id in snapshot.slots do
		local figure = Catalog.byId[id]
		if figure and not seen[id] then
			seen[id] = true
			counts[figure.collection] = (counts[figure.collection] or 0) + 1
			if counts[figure.collection] > best then
				best, bestCollection = counts[figure.collection], figure.collection
			end
		end
	end
	local amount = State.bonusAmount(snapshot)
	return {
		active = amount > 0,
		collection = bestCollection,
		best = math.min(3, best),
		amount = amount,
	}
end

-- Money ------------------------------------------------------------------------------------

function State.need(snapshot: Types.Snapshot, price: number): string?
	local short = math.max(0, price - snapshot.coins)
	return if short <= 0 then nil else "Need " .. State.compact(short) .. " more"
end

-- Reveal card ------------------------------------------------------------------------------

export type Another = { collection: string, price: number, need: string? }
export type Reveal = {
	figureId: string,
	isNew: boolean,
	quantity: number,
	earns: string,
	chance: string,
	progress: string,
	place: Placement?,
	placeLabel: string,
	placeDetail: string,
	another: Another,
	-- Set while more reveals from an Open 10 are queued; replaces Open another and Keep.
	next: string?,
}
function State.reveal(
	snapshot: Types.Snapshot,
	id: string,
	isNew: boolean,
	quantity: number
): Reveal
	local figure = Catalog.byId[id]
	local found, total = State.completion(snapshot, figure.collection)
	local place = State.placement(snapshot, id)
	local price = State.price(snapshot, figure.collection)
	local label, detail = "Put on Display", ""
	if place and place.kind == "empty" then
		local empty = #State.emptySlots(snapshot)
		detail = string.format(
			"You have %d empty slot%s · %s",
			empty,
			if empty == 1 then "" else "s",
			State.rate(place.gain)
		)
	elseif place and place.replaces then
		label = "Swap for " .. Catalog.byId[place.replaces].name
		detail = State.rate(place.gain) .. " more"
	end
	return {
		figureId = id,
		isNew = isNew,
		quantity = quantity,
		earns = "Earns " .. State.amount(State.figureRate(snapshot, id)) .. " coins/s on Display",
		chance = State.percent(State.figureOdds(snapshot, id)) .. " chance",
		progress = string.format(
			"%s · %d of %d found",
			State.collectionName(figure.collection),
			found,
			total
		),
		place = place,
		placeLabel = label,
		placeDetail = detail,
		another = {
			collection = figure.collection,
			price = price,
			need = State.need(snapshot, price),
		},
	}
end

-- HUD, dock and goals ----------------------------------------------------------------------

export type Badges = { [string]: string }
-- Dock badges: Display "N empty" (unlocked empty slots), Shop "FREE", Goals claimable count.
function State.badges(snapshot: Types.Snapshot): Badges
	local badges: Badges = {}
	local empty = #State.emptySlots(snapshot)
	if empty > 0 then
		badges.Display = empty .. " empty"
	end
	if snapshot.dailyReady then
		badges.Shop = "FREE"
	end
	if State.goal(snapshot) == "ready" then
		badges.Goals = "1"
	end
	-- Not a dock tile: the HUD Daily button shows it.
	if snapshot.loginReady then
		badges.Login = "!"
	end
	return badges
end

function State.goal(snapshot: Types.Snapshot): string
	return if snapshot.goalClaimed
		then "claimed"
		elseif snapshot.goalProgress >= 3 then "ready"
		else "progress"
end

export type LoginStatus = "claimed" | "ready" | "locked"
export type LoginDay = { day: number, reward: LoginRewards.Reward, status: LoginStatus }
-- Daily Login grid: the cycle position of today's claim, each day's reward and status, and
-- the streak already completed (today's unclaimed day not counted).
function State.loginDays(snapshot: Types.Snapshot): (number, { LoginDay }, number)
	local today = LoginRewards.day(snapshot.loginStreak)
	local days: { LoginDay } = {}
	for index, reward in LoginRewards.days do
		days[index] = {
			day = index,
			reward = reward,
			status = if index < today or (index == today and not snapshot.loginReady)
				then "claimed"
				elseif index == today then "ready"
				else "locked",
		}
	end
	return today,
		days,
		if snapshot.loginReady then snapshot.loginStreak - 1 else snapshot.loginStreak
end

-- One line per reward part, e.g. "1,000 coins" over "Tidepool Tales box".
function State.loginReward(reward: LoginRewards.Reward): string
	local lines: { string } = {}
	if reward.coins > 0 then
		table.insert(lines, State.compact(reward.coins) .. " coins")
	end
	local boxes = reward.boxes
	if boxes then
		local name = State.collectionName(boxes.collection) .. " box"
		table.insert(lines, if boxes.count > 1 then boxes.count .. "× " .. name else name)
	end
	return table.concat(lines, "\n")
end

-- Text plus seconds until the shown minute changes (callers refresh at most once a minute).
function State.countdown(nextDay: number, now: number): (string, number)
	local remaining = math.max(0, finite(nextDay - now))
	if remaining <= 0 then
		return "any moment", 60
	end
	local minutes = math.ceil(remaining / 60)
	local text = if minutes >= 60
		then string.format("%dh %dm", minutes // 60, minutes % 60)
		else string.format("%dm", minutes)
	local delay = remaining % 60
	return text, math.clamp(if delay < 0.05 then 60 else delay + 0.05, 1, 60)
end

-- Equal cells across an exact width; never truncates the last column.
function State.cells(width: number, columns: number, gap: number): number
	return math.max(1, math.floor((width - gap * (columns - 1)) / math.max(1, columns)))
end

return State

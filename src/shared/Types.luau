--!strict
local Rarity = require(script.Parent.Rarity)
export type Figure = {
	id: string,
	name: string,
	rarity: Rarity.Id,
	color: Color3,
	shape: string,
	collection: string,
	description: string?,
}
export type Intent = {
	action: string,
	id: string,
	revision: number,
	figure: string?,
	slot: number?,
	choice: string?,
	shelfId: string?,
	shelfSlotId: string?,
	carouselRevision: number?,
}
export type Display = { unlocked: number, slots: { string } }
export type ShelfUnit = {
	id: string,
	placements: { [string]: string },
	customization: { [string]: string },
}
-- Dormant preservation of formerly valid v4 logical units above 3; never rendered/acquired.
export type LegacyShelfOverflow = {
	sourceId: string,
	logicalUnit: number,
	placements: { [string]: string },
}
export type Shelves = { units: { ShelfUnit }, legacyOverflow: { LegacyShelfOverflow }? }
export type VisibleShelf = { id: string, index: number, placements: { [string]: string } }
export type ShelfView = {
	ownedCount: number,
	visible: { VisibleShelf },
	carouselRevision: number,
	canNavigate: boolean,
}
export type Profile = {
	schemaVersion: number,
	coins: number,
	earnings: { [string]: number },
	pityByGroup: { [string]: Pity },
	owned: { [string]: number },
	discovered: { [string]: boolean },
	display: Display,
	shelves: Shelves,
	step: number,
	lastDailyDay: number,
	-- Consecutive Daily Login: last claimed UTC day (-1 never) and the streak it completed.
	lastLoginDay: number,
	loginStreak: number,
	goalDay: number,
	goalProgress: number,
	goalClaimed: boolean,
	boxesOpened: number,
	-- Collections whose first completion already granted a free Shelf Unit.
	shelfRewards: { [string]: boolean },
	-- UTC os.time() of the last save; 0 = unknown (new or pre-v10 profile), never awards offline time.
	lastSeen: number,
	-- Whole offline Coins awaiting the return popup's claim; auto-claimed on the next join.
	offlinePending: number,
}
-- offlineSeconds is runtime-only: the absence that produced offlinePending this session.
export type State = Profile & { revision: number, time: number, offlineSeconds: number }
export type Pity = { legendaryDryRolls: number, mythicalDryRolls: number }
export type Snapshot = {
	shelves: ShelfView,
	shelfAvailable: { [string]: number },
	coins: number,
	earnings: { [string]: number },
	owned: { [string]: number },
	discovered: { [string]: boolean },
	slots: { string },
	revision: number,
	sequence: number,
	rate: number,
	step: number,
	rates: { [string]: number },
	odds: { [string]: number },
	prices: { [string]: number },
	baseRates: { [string]: number },
	nextRates: { [string]: number },
	baseOdds: { [string]: number },
	dailyCollection: string,
	unlocked: number,
	expansionCost: number,
	-- Next Shelf Unit price; 0 once the shelf cap is reached.
	shelfPrice: number,
	dailyReady: boolean,
	-- Today's login reward is unclaimed; loginStreak is the streak today's claim makes (or made).
	loginReady: boolean,
	loginStreak: number,
	goalProgress: number,
	goalClaimed: boolean,
	goalReward: number,
	nextDay: number,
	saveStatus: string,
	ready: boolean,
	bonus: number,
	offlinePending: number,
	offlineSeconds: number,
}
export type Reply = {
	id: string,
	ok: boolean,
	message: string,
	figure: string?,
	figures: { string }?,
}
return {}

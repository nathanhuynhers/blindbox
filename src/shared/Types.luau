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
	pityByGroup: { [string]: Pity },
	owned: { [string]: number },
	discovered: { [string]: boolean },
	display: Display,
	shelves: Shelves,
	step: number,
	lastDailyDay: number,
	goalDay: number,
	goalProgress: number,
	goalClaimed: boolean,
}
export type State = Profile & { revision: number, fraction: number, time: number }
export type Pity = { legendaryDryRolls: number, mythicalDryRolls: number }
export type Snapshot = {
	shelves: ShelfView,
	coins: number,
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
	dailyReady: boolean,
	goalProgress: number,
	goalClaimed: boolean,
	goalReward: number,
	nextDay: number,
	saveStatus: string,
	ready: boolean,
	bonus: number,
}
export type Reply = { id: string, ok: boolean, message: string, figure: string? }
return {}

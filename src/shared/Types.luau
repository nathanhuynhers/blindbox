--!strict
export type Figure = {
	id: string,
	name: string,
	rarity: string,
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
	pageId: string?,
	shelfSlotId: string?,
	pageRevision: number?,
}
export type Display = { unlocked: number, slots: { string } }
export type ShelfPage = {
	id: string,
	placements: { [string]: string },
	customization: { [string]: string },
}
export type Shelves = { pages: { ShelfPage } }
export type ShelfView = {
	pageId: string,
	pageIndex: number,
	pageCount: number,
	pageRevision: number,
	placements: { [string]: string },
}
export type Profile = {
	schemaVersion: number,
	coins: number,
	scrap: number,
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
export type Snapshot = {
	shelves: ShelfView,
	coins: number,
	scrap: number,
	owned: { [string]: number },
	discovered: { [string]: boolean },
	slots: { string },
	revision: number,
	sequence: number,
	rate: number,
	step: number,
	rates: { [string]: number },
	odds: { [string]: number },
	price: number,
	redeemCost: number,
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

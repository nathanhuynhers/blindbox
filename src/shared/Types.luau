--!strict
export type Figure = {
	id: string,
	name: string,
	rarity: string,
	color: Color3,
	shape: string,
	collection: string,
}
export type Intent = {
	action: string,
	id: string,
	revision: number,
	figure: string?,
	slot: number?,
	choice: string?,
}
export type Profile = {
	schemaVersion: number,
	coins: number,
	scrap: number,
	owned: { [string]: number },
	discovered: { [string]: boolean },
	slots: { string },
	step: number,
	unlocked: number,
	theme: string,
	themes: { [string]: boolean },
	lastDailyDay: number,
	goalDay: number,
	goalProgress: number,
	goalClaimed: boolean,
}
export type State = Profile & { revision: number, fraction: number, time: number }
export type PublicRoom = {
	userId: number,
	name: string,
	rate: number,
	slots: { string },
	theme: string,
}
export type Snapshot = {
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
	theme: string,
	themes: { [string]: boolean },
	expansionCost: number,
	themeCost: number,
	dailyReady: boolean,
	goalProgress: number,
	goalClaimed: boolean,
	goalReward: number,
	nextDay: number,
	saveStatus: string,
	ready: boolean,
	rooms: { PublicRoom },
	visiting: number,
	bonus: number,
}
export type Reply = { id: string, ok: boolean, message: string, figure: string? }
return {}

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
	roomId: string?,
	anchorId: string?,
	runtimeId: string?,
}
export type Display = { unlocked: number, slots: { string } }
export type Showroom = {
	roomId: string,
	sourceType: string,
	sourceCollectionId: string?,
	theme: string,
	placements: { [string]: string },
	customization: { [string]: string },
}
export type Showrooms = {
	rooms: { [string]: Showroom },
	palette: string,
	palettes: { [string]: boolean },
}
export type GalleryView = {
	ownerId: number,
	ownerName: string,
	runtimeId: string, -- Current hall or room generation; changes on room recreation.
	roomId: string?,
	room: Showroom?,
	canEdit: boolean,
	rooms: { { roomId: string, name: string } },
}
export type Profile = {
	schemaVersion: number,
	coins: number,
	scrap: number,
	owned: { [string]: number },
	discovered: { [string]: boolean },
	display: Display,
	showrooms: Showrooms,
	step: number,
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
	gallery: GalleryView?,
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

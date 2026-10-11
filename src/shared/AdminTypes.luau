--!strict
local Types = require(script.Parent.Types)
export type Request = {
	token: string,
	sequence: number,
	action: string,
	target: number?,
	revision: number?,
	amount: number?,
	quantity: number?,
	figure: string?,
	collection: string?,
	rarity: string?,
	reason: string?,
	confirmed: boolean?,
}
export type Override = {
	collection: string,
	figure: string?,
	rarity: string?,
	expires: number,
	admin: number,
}
export type Audit = {
	timestamp: number,
	admin: number,
	target: number?,
	action: string,
	amount: number?,
	quantity: number?,
	figure: string?,
	collection: string?,
	rarity: string?,
	ok: boolean,
	message: string,
}
export type PlayerRow = {
	userId: number,
	username: string,
	displayName: string,
	plot: number?,
	ready: boolean,
}
export type Inspector = {
	userId: number,
	revision: number,
	coins: number,
	owned: { [string]: number },
	discovered: { [string]: boolean },
	display: Types.Display,
	shelves: Types.Shelves,
	pity: { [string]: Types.Pity },
	earnings: { [string]: number },
	rate: number,
	bonus: number,
	boxesOpened: number,
	step: number,
	loginStreak: number,
	goalProgress: number,
	offlinePending: number,
	plot: number,
	ready: boolean,
	saveStatus: string,
	persistent: boolean,
	transferring: boolean,
	override: Override?,
}
export type Box = {
	id: string,
	price: number,
	group: string,
	base: { [string]: number },
	effective: { [string]: number },
	pity: { [string]: { base: number, start: number, increment: number, guarantee: number } }?,
}
export type Reply = {
	ok: boolean,
	message: string,
	token: string?,
	sequence: number?,
	players: { PlayerRow }?,
	inspector: Inspector?,
	boxes: { Box }?,
	audit: { Audit }?,
	simulation: { [string]: number }?,
	largeChange: number?,
	transactionLimit: number?,
}
return {}

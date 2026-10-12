--!strict
-- Schema definitions only. Instances of durable records stay in the server profile.
export type Award = {
	id: string,
	normal: number,
	assisted: number,
	calculationVersion: string,
	baseClaimed: boolean,
}
export type Reservation = { award: Award, productId: number, receiptId: string? }
export type Record = {
	version: number,
	serial: number,
	current: Award?,
	active: string?,
	bindings: { [string]: Reservation },
	receipts: { [string]: string },
	exceptions: { [string]: number },
	earnedCredit: number,
	assistedCredit: number,
}
export type View = {
	awardId: string?,
	normal: number,
	doubled: number,
	claimable: boolean,
	fulfilled: boolean?,
	recoveryRequired: boolean?,
	earnedCredit: number,
	assistedCredit: number,
}
return table.freeze({})

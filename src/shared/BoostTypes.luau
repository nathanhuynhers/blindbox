--!strict
local PurchaseTypes = require(script.Parent.PurchaseTypes)
export type Timer = { strength: number, started: number, expires: number }
export type Delivery = {
	product: string,
	platformId: number,
	token: PurchaseTypes.TokenId,
	count: number,
}
export type Activation = { token: PurchaseTypes.TokenId, coinExpiry: number, luckExpiry: number }
export type Record = {
	lastClock: number,
	tokens: { [PurchaseTypes.TokenId]: number },
	coin: Timer?,
	luck: Timer?,
	deliveries: { [string]: Delivery },
	activations: { [string]: Activation },
}
export type LuckView = {
	verifiedPermanent: number,
	permanent: number,
	ownershipFresh: boolean,
	reason: string,
}
export type View = {
	tokens: { [PurchaseTypes.TokenId]: number },
	coin: Timer?,
	luck: Timer?,
	coinRemaining: number,
	luckRemaining: number,
	coinFactor: number,
	luckWeight: number,
	clockValid: boolean,
	paidAllowed: boolean,
	redundantLuck: boolean,
}
export type Request = { id: string, token: PurchaseTypes.TokenId, revision: number }
export type Result = { id: string, ok: boolean, reason: string }
return table.freeze({})

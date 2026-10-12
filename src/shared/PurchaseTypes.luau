--!strict
-- Public wire contracts only. Product authority and durable records stay on the server.
export type PlatformKind = "Pass" | "DeveloperProduct"
export type Ownership = "Unknown" | "NotOwned" | "Owned"
export type TokenId =
	"Coins2_15"
	| "Coins2_30"
	| "Coins2_60"
	| "Luck2_30"
	| "Luck4_30"
	| "Combo2_30"
export type Grant = { coins: number, tokens: { [TokenId]: number } }
export type Request = { id: string, action: "State" | "Refresh" | "Purchase", product: string? }
export type Result = {
	id: string,
	product: string?,
	status: "Rejected"
		| "PromptOpened"
		| "Cancelled"
		| "AwaitingReceipt"
		| "Reserved"
		| "Verified"
		| "Recovering"
		| "State",
	reason: string,
}
export type PackageState = {
	eligible: boolean,
	eligibilityReason: string,
	confirmed: boolean,
	claimed: boolean,
	coins: number?,
	token: TokenId?,
	tokenSeconds: number?,
	vipFactor: number?,
	dailyCoins: number?,
	dailyClaimed: boolean?,
	dailySupplementAvailable: boolean?,
	appliedVipFactor: number,
	fulfilledCoins: number,
	fulfilledTokens: number,
	assistedCredit: number,
	walletCredited: number,
	creditUsable: boolean,
}
export type ProductState = {
	confirmedDeliveries: number?,
	grant: Grant?,
	coinTier: number?,
	benefits: { [string]: number }?,
	key: string,
	kind: PlatformKind?,
	platformId: number?,
	available: boolean,
	reason: string,
	ownership: Ownership,
	ownershipFresh: boolean,
	fulfillment: "None" | "Pending" | "Reserved" | "Recovering",
	package: PackageState?,
}
export type Snapshot = {
	recoveryProduct: string?,
	tokenBenefits: { [TokenId]: { coins: number, luck: number, seconds: number } }?,
	sequence: number,
	ready: boolean,
	ledgerStatus: string,
	promptProduct: string?,
	products: { ProductState },
	reserved: Grant,
	-- Reserved means durable value waiting for gameplay integration, never wallet credit.
	receiptCount: number,
}
-- Future offline integration input: SERVER-created and frozen before prompting.
-- Not accepted on the purchase remote; see docs/PURCHASE_FOUNDATION.md.
export type OfflineAward = {
	awardId: string,
	normal: number,
	calculationVersion: string,
	baseClaimed: boolean,
}
return table.freeze({})

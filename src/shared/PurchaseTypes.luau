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
export type ProductState = {
	key: string,
	kind: PlatformKind?,
	platformId: number?,
	available: boolean,
	reason: string,
	ownership: Ownership,
	ownershipFresh: boolean,
	fulfillment: "None" | "Pending" | "Reserved" | "Recovering",
}
export type Snapshot = {
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

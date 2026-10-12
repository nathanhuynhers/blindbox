--!strict
-- Dedicated owner-only contracts; no platform purchase or client-supplied spend authority.
local Types = require(script.Parent.Types)
export type OpeningDelivery = {
	request: Types.Intent,
	before: Types.Snapshot,
	after: Types.Snapshot,
	reply: Types.Reply,
}
export type Action =
	"State"
	| "Start"
	| "Stop"
	| "Collection"
	| "Presented"
	| "AutoCollect"
	| "Movement"
export type Request = {
	id: string,
	serial: number,
	action: Action,
	collection: string?,
	limit: number?,
	reserve: number?,
	requestId: string?,
	enabled: boolean?,
}
export type OpenStatus = {
	running: boolean,
	phase: "Idle" | "Ready" | "Pending" | "Presenting",
	collection: string,
	limit: number,
	reserve: number,
	completed: number,
	spent: number,
	reason: string,
	requestId: string?,
}
export type Snapshot = {
	sequence: number,
	open: OpenStatus,
	openAllowed: boolean,
	collectEnabled: boolean,
	collectAllowed: boolean,
	collectReason: string,
	movementEnabled: boolean,
	movementAllowed: boolean,
	speed: number,
}
return table.freeze({})

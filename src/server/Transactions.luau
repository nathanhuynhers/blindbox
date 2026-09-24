--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Rules = require(script.Parent.Rules)
local Protocol = require(script.Parent.Protocol)
type Receipt = { intent: Types.Intent, reply: Types.Reply, time: number }
export type Session =
	{ state: Types.State, receipts: { Receipt }, tokens: number, tokenTime: number }
local Transactions = {}
function Transactions.new(now: number): Session
	return { state = Rules.new(now), receipts = {}, tokens = 4, tokenTime = now }
end
-- No yields: validation, settlement, mutation and receipt storage execute as one unit.
function Transactions.process(
	session: Session,
	raw: unknown,
	now: number,
	nearShelf: boolean,
	roll: number,
	day: number?
): (Types.Reply?, boolean)
	session.tokens = math.min(4, session.tokens + math.max(0, now - session.tokenTime) * 2)
	session.tokenTime = now
	if session.tokens < 1 then
		return nil, false
	end
	session.tokens -= 1
	local intent = Protocol.parse(raw)
	if not intent then
		return nil, false
	end
	Rules.settle(session.state, now)
	for index = #session.receipts, 1, -1 do
		if now - session.receipts[index].time > 120 then
			table.remove(session.receipts, index)
		end
	end
	for _, receipt in session.receipts do
		if receipt.intent.id == intent.id then
			if Protocol.same(receipt.intent, intent) then
				return receipt.reply, false
			end
			return {
				id = intent.id,
				ok = false,
				message = "Request ID reused with different contents.",
			},
				false
		end
	end
	local ok = false
	local message = "State changed. Try again."
	local figure: string? = nil
	if intent.revision == session.state.revision then
		if (intent.action == "Place" or intent.action == "Remove") and not nearShelf then
			message = "Walk closer to your own shelf."
		else
			ok, message, figure = Rules.mutate(session.state, intent, roll, day)
		end
	end
	local reply: Types.Reply = { id = intent.id, ok = ok, message = message, figure = figure }
	table.insert(session.receipts, { intent = intent, reply = reply, time = now })
	if #session.receipts > 64 then
		table.remove(session.receipts, 1)
	end
	return reply, ok
end
return Transactions

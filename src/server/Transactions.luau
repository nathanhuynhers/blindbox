--!strict
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Tutorial = require(game:GetService("ReplicatedStorage").Shared.Tutorial)
local Rules = require(script.Parent.Rules)
local Protocol = require(script.Parent.Protocol)
local Shelves = require(script.Parent.Shelves)
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
	insideOwnPlot: boolean,
	roll: number | { number },
	day: number?,
	access: Shelves.Access?,
	collectAuthorized: boolean?
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
	-- Place settles inside Rules only after validation; rejects/replays cannot mutate gameplay.
	if intent.action ~= "Place" then
		Rules.settle(session.state, now)
	end
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
	local figures: { string }? = nil
	if intent.revision == session.state.revision then
		if intent.action == "Collect" and collectAuthorized ~= true then
			message = "Click or tap your own displayed figure nearby."
		elseif string.sub(intent.action, 1, 5) == "Shelf" then
			ok, message, figure = Shelves.mutate(session.state, intent, access, now)
			-- The optional Shelves tip ends only when a figure is actually placed.
			if ok and intent.action == "ShelfPlace" and session.state.step == Tutorial.shelves then
				session.state.step = Tutorial.done
			end
		elseif (intent.action == "Place" or intent.action == "Remove") and not insideOwnPlot then
			message = "Return to your own plot to edit your Display."
		else
			ok, message, figure, figures = Rules.mutate(session.state, intent, roll, day, now)
		end
	end
	local reply: Types.Reply =
		{ id = intent.id, ok = ok, message = message, figure = figure, figures = figures }
	table.insert(session.receipts, { intent = intent, reply = reply, time = now })
	if #session.receipts > 64 then
		table.remove(session.receipts, 1)
	end
	return reply, ok
end
return Transactions

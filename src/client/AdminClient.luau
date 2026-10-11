--!strict
local A = require(game:GetService("ReplicatedStorage").Shared.AdminTypes)
local Client = {}
export type Controller = {
	connect: () -> A.Reply,
	request: (A.Request) -> A.Reply,
	retry: () -> A.Reply,
	busy: () -> boolean,
	uncertain: () -> boolean,
}
-- One outstanding request, with exact retry contents. UI renders only confirmed replies.
function Client.create(invoke: (unknown) -> A.Reply): Controller
	local token = ""
	local sequence = 0
	local busy = false
	local uncertain: A.Request? = nil
	local function perform(request: A.Request): A.Reply
		if busy then
			return { ok = false, message = "A request is processing." }
		end
		busy = true
		local ok, reply = pcall(invoke, request)
		busy = false
		if not ok then
			uncertain = request
			return {
				ok = false,
				message = "Connection interrupted. Retry this exact request before continuing.",
			}
		end
		uncertain = nil
		return reply
	end
	return {
		connect = function()
			if busy then
				return { ok = false, message = "A request is processing." }
			end
			busy = true
			local ok, reply = pcall(invoke, "Connect")
			busy = false
			if not ok then
				return { ok = false, message = "Admin connection unavailable." }
			end
			if reply.ok and reply.token then
				token = reply.token
				sequence = reply.sequence or 0
			end
			return reply
		end,
		request = function(request)
			if busy or uncertain then
				return { ok = false, message = "Resolve the pending request first." }
			end
			if token == "" then
				return { ok = false, message = "Owner access required." }
			end
			sequence += 1
			request.token, request.sequence = token, sequence
			return perform(table.clone(request))
		end,
		retry = function()
			if not uncertain then
				return { ok = false, message = "No interrupted request." }
			end
			return perform(uncertain)
		end,
		busy = function()
			return busy
		end,
		uncertain = function()
			return uncertain ~= nil
		end,
	}
end
return Client

--!strict
local Client = require(script.Parent.ConvenienceClient)
local Opening = require(script.Parent.OpeningController)
local Presentation = {}
export type Bridge = { step: (number) -> (), completed: (string, boolean) -> () }
function Presentation.create(client: Client.Controller, opening: Opening.Controller): Bridge
	local evidence: { [string]: boolean } = {}
	local order: { string } = {}
	local lastAck = -math.huge
	return {
		step = function(now)
			local view = client.view()
			if not view or view.open.phase ~= "Presenting" or not view.open.requestId then
				return
			end
			local id = view.open.requestId
			if evidence[id] ~= nil then
				if now - lastAck >= 1 then
					lastAck = now
					if not evidence[id] then
						client.stop()
					end
					client.presented(id)
				end
			elseif view.open.running or view.open.reason == "Run complete" then
				opening.advanceAutomatic(id)
			end
		end,
		completed = function(id, finished)
			-- Completion may race the private automation snapshot. Bounded evidence
			-- also lets a dropped acknowledgement retry without replaying a reveal.
			if evidence[id] ~= nil then
				return
			end
			evidence[id] = finished
			table.insert(order, id)
			if #order > 64 then
				local old = table.remove(order, 1)
				if old then
					evidence[old] = nil
				end
			end
		end,
	}
end
return Presentation

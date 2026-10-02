--!strict
-- Run after tests/run.py generates isolated copies of the actual production modules.
local Rules = require("../build/tests/Rules")
local Economy = require("../build/tests/Economy")
local Catalog = require("../build/tests/Catalog")
local seed = 97531
local function random()
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end
local function optimize(state)
	local ids = {}
	for id in state.owned do table.insert(ids, id) end
	table.sort(ids, function(a,b) return Rules.figureRate(state,a)>Rules.figureRate(state,b) end)
	local slots={}
	for index=1,state.display.unlocked do slots[index]=ids[index] or "" end
	state.display.slots=slots
	local best, bestSlots=Rules.rate(state),table.clone(slots)
	-- Evaluate a three-figure themed core for every collection plus strongest remaining figures.
	for _, collection in Catalog.collections do
		local candidate,seen={},{}
		for _, id in ids do
			if Catalog.byId[id].collection==collection.id and #candidate<3 then
				table.insert(candidate,id);seen[id]=true
			end
		end
		if #candidate==3 then
			for _, id in ids do
				if #candidate<state.display.unlocked and not seen[id] then table.insert(candidate,id) end
			end
			while #candidate<state.display.unlocked do table.insert(candidate,"") end
			state.display.slots=candidate
			local rate=Rules.rate(state)
			if rate>best then best,bestSlots=rate,table.clone(candidate) end
		end
	end
	state.display.slots=bestSlots
end
local function fund(state,cost)
	if state.coins<cost then
		local rate=Rules.rate(state)
		assert(rate>0,"Unfunded start")
		Rules.settle(state,state.time+(cost-state.coins)/rate+0.001)
	end
end
local function buy(state,collection)
	optimize(state)
	local count=0;for _ in state.owned do count+=1 end
	local cost=Rules.expansionCost(state)
	if cost>0 and count>state.display.unlocked and cost<=Rules.prices[collection]*20 then
		fund(state,cost)
		assert(Rules.mutate(state,{action="Expand",id="sim",revision=state.revision},0,0))
		optimize(state)
	end
	fund(state,Rules.prices[collection])
	local ok,_,id=Rules.mutate(state,{action="Buy",choice=collection,id="sim",revision=state.revision},random(),0)
	assert(ok and id)
	optimize(state)
	return Catalog.byId[id].rarity
end
local function percentile(values,p)
	table.sort(values)
	return values[math.max(1,math.ceil(#values*p))]
end
local results={concept={},echo={},star={}}
local boxes={concept={},echo={},star={}}
for trial=1,300 do
	local state=Rules.new(0)
	for _=1,30 do buy(state,"grove") end
	for _=1,30 do buy(state,"tide") end
	for _, collection in {"concept","echo","star"} do
		local entered=state.time
		local count=0
		repeat
			count+=1
			local rarity=buy(state,collection)
			if rarity=="Mythical" then break end
			assert(count<10000,"Simulation tail bound")
		until false
		table.insert(results[collection],(state.time-entered)/3600)
		table.insert(boxes[collection],count)
	end
end
for _, collection in {"concept","echo","star"} do
	print(string.format("%s: hours p10=%.2f p25=%.2f median=%.2f p75=%.2f p90=%.2f; median boxes=%d",
		collection,percentile(results[collection],.1),percentile(results[collection],.25),
		percentile(results[collection],.5),percentile(results[collection],.75),percentile(results[collection],.9),
		percentile(boxes[collection],.5)))
end
print("300 seeded progression runs; strongest Display with themed alternatives, sequential slot purchases, 30 Grove + 30 Tide boxes before Concepts, then Echo then Stars; no reveal/interaction delay or daily rewards.")

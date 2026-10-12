--!strict
local Engine = require("./OpeningEngine")
local Movement = require("./PlayerMovement")
local Owner = require("./ConvenienceOwner")
local Rules = require("./Rules")
local Transactions = require("./Transactions")
local now, sequence, changes, deliveries = 100, 0, 0, 0
local valid, policy, alive, busy = true, true, true, false
local transaction=Transactions.new(now)
transaction.state.coins=10000; transaction.state.step=7
local storage={state=transaction.state,handle={},ready=true,closed=false,transferring=false,busy=false,safeUntil=1000}
Engine.player.Character.ChildAdded=Engine.signal()
local binding=Movement.bind(Engine.player)
local owner=Owner.create(storage,transaction,binding,{
	now=function() return now end,id=function() sequence+=1; return "auto:"..sequence end,
	current=function() return valid end,alive=function() return alive end,
	ownership=function() return true,true end,purchaseBusy=function() return busy end,
	policyAllowed=function() return policy end,spendable=function() return transaction.state.coins end,
	snapshot=function() return {owned=table.clone(transaction.state.owned),discovered=table.clone(transaction.state.discovered),coins=transaction.state.coins,revision=transaction.state.revision} end,
	rolls=function() return {0.1} end,day=function() return 10 end,window=function() return 0 end,
	deliver=function(value) deliveries+=1; assert(value.before.coins==10000 and value.after.coins==8500 and value.reply.ok,"immutable ordinary Buy baseline") end,
	changed=function() changes+=1 end,
})
owner.collection("grove"); assert(owner.open.start("grove",1,100),"explicit approved start")
owner.open.step(); assert(transaction.state.coins==8500 and deliveries==1,"ordinary Buy spends exactly once")
now+=4; table.clear(transaction.receipts); owner.open.step()
assert(deliveries==2 and transaction.state.coins==8500,"independent obligation survives receipt eviction")
assert(owner.open.presented("auto:1"),"confirmed presentation acknowledgement")
assert(not owner.open.busy() and not owner.open.view().running,"budget completion cannot restart")
policy=false; assert(not owner.open.start("grove",1,0),"closed policy cannot start")
policy=true; busy=true; assert(not owner.open.start("grove",1,0),"native purchase conflict refuses setup")
assert(transaction.state.coins==8500 and not owner.open.view().running,"native purchase conflict never spends")
busy=false; valid=false; assert(not owner.ready(),"replaced owner session denied")
valid=true; storage.pendingSave={}; assert(not owner.ready(),"uncertain save denied")
storage.pendingSave=nil; assert(owner.setPreference("auto_collect",true),"saved opt-in uses Rules")
local figure=next(transaction.state.owned)
transaction.state.display.slots[1]=figure; transaction.state.earnings[figure]=10.5
owner.collect.step(); assert(transaction.state.coins==8510 and transaction.state.earnings[figure]==0.5,"same bank helper preserves fractions, no second multiplier")
assert(transaction.state.step==7 and changes==2,"automatic transfer does not advance lesson")
owner.open.destroy(); owner.collect.destroy(); Movement.unbind(binding)
print("PASS: captured-session convenience adapter, ordinary transaction and recovery fixtures")

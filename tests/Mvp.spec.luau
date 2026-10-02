--!strict
local Rules = require("./Rules")
local Config = require("./Economy")
local Economy = require("./CollectionEconomy")
local Catalog = require("./Catalog")
local Protocol = require("./Protocol")
local Transactions = require("./Transactions")
local Profile = require("./Profile")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function close(a,b) return math.abs(a-b) < 1e-7 * math.max(1,math.abs(b)) end
local function request(action, state, figure, slot, choice)
 return {action=action,id=action..state.revision,revision=state.revision,figure=figure,slot=slot,choice=choice}
end
for _, collection in Catalog.collections do
 local sum, expected=0,0
 for _, figure in Catalog.figures do
  if figure.collection==collection.id then
   sum+=Rules.odds[figure.id]
   expected+=Rules.odds[figure.id]/100*Rules.rates[figure.id]
  end
 end
 local tier=Config.tiers[Config.collections[collection.id].tier]
 check(close(sum,100),"100% per collection")
 check(close(expected,tier.price/tier.paybackSeconds),"weighted income matches tier budget")
end
check(Rules.prices.echo==Rules.prices.star and Rules.rates["echo.moon-doze"]==Rules.rates["star.dreamcatcher"],"Prestige peers")
for _, value in {0,0.00001,0.2,0.6,0.75,0.9,0.999999999} do
 check(Catalog.byId[Rules.roll(value,"grove")].collection=="grove","roll bounded to chosen pool")
end
check(not pcall(Rules.roll,0/0) and not pcall(Rules.roll,1),"invalid random input rejected")
local common="grove.pebble"
local state=Rules.new(0)
for _=1,3 do check(Rules.mutate(state,request("Buy",state),0),"starter purchase") end
check(state.coins==0 and state.owned[common]==3,"fully random starters may duplicate")
check(Rules.mutate(state,request("Place",state,common,1),0),"place owned")
check(not Rules.mutate(state,request("Place",state,common,2),0),"duplicate cannot occupy a second slot")
check(close(Rules.rate(state),Rules.rates[common]*(1+0.6*2/7)),"duplicates enhance one earner")
local initialRate=Rules.rate(state)
Rules.settle(state,0.17)
check(close(state.coins+(state.earnings[common] or 0),initialRate*.17),"fraction retained")
Rules.settle(state,0.17)
check(close(state.coins+(state.earnings[common] or 0),initialRate*.17),"same timestamp cannot earn twice")
for _, figure in Catalog.figures do
 local cfg=Config.duplicates[figure.rarity]
 check(close(Economy.multiplier(figure.id,2),1+cfg.maximum/(1+cfg.curve)),"first duplicate")
 check(Economy.multiplier(figure.id,100000)<1+cfg.maximum,"asymptotic cap")
 check(Economy.multiplier(figure.id,101)>Economy.multiplier(figure.id,100),"later duplicate helps")
end
local pity={echo={legendaryDryRolls=100,mythicalDryRolls=500}}
local buckets=Economy.buckets("echo",pity)
check(close(buckets.Legendary,4) and close(buckets.Mythical,.4),"independent increasing odds")
check(close(buckets.Common/buckets.Uncommon,60/25),"lower probabilities retain proportions")
check(close(Economy.buckets("star",pity).Legendary,1),"collection pity isolation")
pity.echo={legendaryDryRolls=Config.counterLimit,mythicalDryRolls=Config.counterLimit}
buckets=Economy.buckets("echo",pity)
check(buckets.Legendary==8 and buckets.Mythical==2,"pity capped without guarantee")
check(Catalog.byId[Economy.roll(0,"echo",pity)].rarity=="Common","maximum pity still permits Common")
Economy.advance(pity,"echo","echo.moon-doze")
check(pity.echo.mythicalDryRolls==0 and pity.echo.legendaryDryRolls==Config.counterLimit,"independent Mythical reset")
Economy.advance(pity,"echo","echo.feather-hush")
check(pity.echo.legendaryDryRolls==0 and pity.echo.mythicalDryRolls==1,"independent Legendary reset")
local poor=Rules.new(0)
poor.pityByGroup.echo={legendaryDryRolls=80,mythicalDryRolls=400}
check(not Rules.mutate(poor,request("Buy",poor,nil,nil,"echo"),.99999),"unaffordable higher tier")
check(poor.pityByGroup.echo.legendaryDryRolls==80 and poor.coins==4500,"failure atomicity")
check(not Rules.mutate(poor,request("Daily",poor,nil,nil,"echo"),0,12),"no expensive free box")
check(poor.lastDailyDay==-1,"failed daily preserves eligibility")
check(Rules.mutate(poor,request("Daily",poor,nil,nil,"grove"),0,12),"Starter daily")
check(not Rules.mutate(poor,request("Daily",poor,nil,nil,"grove"),0,12),"daily once")
local large=Rules.new(0)
large.owned[common]=1000;large.discovered[common]=true
check(Rules.mutate(large,request("Buy",large),0) and large.owned[common]==1001,"no 200-copy cap")
large.owned[common]=Config.copyLimit
local coins=large.coins
check(not Rules.mutate(large,request("Buy",large),.99) and large.coins==coins,"safety guard never rerolls")
for _, action in {"Recycle","Redeem"} do
 check(Protocol.parse(request(action,state,common))==nil,"retired protocol action rejected")
 check(not Rules.mutate(state,request(action,state,common),0),"retired domain action rejected")
end
for _, raw in {false,1,{}, {action="Buy",id="x",revision=0/0}, {action="Buy",id="x",revision=math.huge},
 {action="Buy",id="x",revision=0,price=0}, {action="Buy",id="x",revision=0,pity=999}, {action="Buy",id="x",revision=0,ownerId=2},
 {action="Place",id="x",revision=0,figure=common,slot=0/0}, {action="Buy",id=string.rep("x",65),revision=0}} do
 check(Protocol.parse(raw)==nil,"malformed/spoofed request")
end
local session=Transactions.new(0);session.state.coins=1000000
local buy=request("Buy",session.state,nil,nil,"echo")
local first=Transactions.process(session,buy,0,true,0)
local retry=Transactions.process(session,buy,0,true,.999999)
check(first and first.ok and retry==first and session.state.coins==800000,"retry preserves spend and outcome")
check(session.state.pityByGroup.echo.legendaryDryRolls==1,"retry advances pity once")
local changed=table.clone(buy);changed.choice="star"
check(not Transactions.process(session,changed,1,true,0).ok,"request ID contents protected")
local stale=table.clone(buy);stale.id="stale"
check(not Transactions.process(session,stale,2,true,0).ok,"stale revision rejected")
local place=request("Place",session.state,first.figure,1)
check(not Transactions.process(session,place,3,false,0).ok,"distance guard")
place.id="near"
check(Transactions.process(session,place,4,true,0).ok,"owned nearby placement")
local oldRate=Rules.rate(session.state)
local before=session.state.coins+(session.state.earnings[first.figure] or 0)
local nextBuy=request("Buy",session.state,nil,nil,"echo")
check(Transactions.process(session,nextBuy,14,true,0).ok,"duplicate purchase")
check(close(session.state.coins+(session.state.earnings[first.figure] or 0),before+oldRate*10-200000),"settle old rate before duplicate")
check(Rules.rate(session.state)>oldRate,"new duplicate rate")
local spam=Transactions.new(0)
for _=1,4 do Transactions.process(spam,{},0,true,0) end
check(Transactions.process(spam,request("Buy",spam.state),0,true,0)==nil,"spam bounded")
local mixed=Transactions.new(0);mixed.state.coins=1000000
for i=1,1000 do
 local action=({"Buy","Place","Remove"})[i%3+1]
 local figure=Config.entries[i%#Config.entries+1].id
 local intent=request(action,mixed.state,if action=="Place" then figure else nil,if action~="Buy" then i%3+1 else nil)
 intent.id="mixed"..i
 Transactions.process(mixed,intent,i,true,(i*37%100)/100)
 check(Profile.decode(Profile.encode(mixed.state),i)~=nil,"mixed actions preserve profile invariants")
 check(#mixed.receipts<=64,"bounded receipts")
end
state.coins=Config.coinLimit-1
Rules.settle(state,10000)
check(state.coins==Config.coinLimit-1,"income stays banked")
local bank=state.earnings[common]
check(Rules.collect(state,1,common) and state.coins==Config.coinLimit,"partial wallet transfer")
check(close(state.earnings[common],bank-1),"full wallet retains overflow")
check(not Rules.collect(state,1,common),"full wallet cannot collect twice")
local restored=Profile.decode(Profile.encode(session.state),1000)
check(restored and restored.time==1000 and restored.earnings[first.figure]==session.state.earnings[first.figure],"bank persisted; no offline income")
local manual=Transactions.new(0)
manual.state.owned[common]=1;manual.state.discovered[common]=true;manual.state.display.slots[1]=common
Rules.settle(manual.state,10)
check(manual.state.coins==4500,"settlement never deposits automatically")
local collect=request("Collect",manual.state,common,1)
check(not Transactions.process(manual,collect,10,true,0).ok,"remote cannot authorize collection")
collect.id="physical"
local result=Transactions.process(manual,collect,11,true,0,nil,nil,true)
local balance=manual.state.coins
check(result and result.ok and balance>4500,"authorized physical collection")
check(Transactions.process(manual,collect,11,true,0,nil,nil,true)==result and manual.state.coins==balance,"collection receipt prevents double credit")
manual.state.earnings[common]=12.75
manual.state.display.slots[1]=""
check(not Rules.collect(manual.state,1,common) and manual.state.earnings[common]==12.75,"removed figure retains bank")
manual.state.display.slots[1]=common
check(Rules.collect(manual.state,1,common) and manual.state.earnings[common]==.75,"redisplay collection retains fractions")
local legacy=Profile.encode(manual.state); legacy.schemaVersion=6;legacy.earnings=nil;legacy.boxesOpened=nil
check(Profile.decode(legacy,20).coins==manual.state.coins,"schema 6 migrates without reset")
for _, amount in {-1,0/0,math.huge,Config.coinLimit+1} do
 local invalid=Profile.encode(manual.state); invalid.earnings[common]=amount
 check(Profile.decode(invalid,20)==nil,"invalid banks rejected")
end
local themed=Rules.new(0)
local ids={}
for _,entry in Catalog.figures do
 if entry.collection=="grove" and #ids<3 then table.insert(ids,entry.id) end
end
for slot,id in ids do
 themed.owned[id]=1;themed.discovered[id]=true;themed.display.slots[slot]=id
end
Rules.settle(themed,10)
local total=0
for _,id in ids do
 check(close(themed.earnings[id],Rules.figureRate(themed,id)*11),"themed bonus banked proportionally")
 total+=themed.earnings[id]
end
check(close(total,Rules.rate(themed)*10),"per-figure banks conserve total income")
local encoded=Profile.encode(themed)
encoded.earnings[ids[1]]=0
check(themed.earnings[ids[1]]>0,"saved banks deep copied")
local otherBank=themed.earnings[ids[2]]
check(Rules.collect(themed,1,ids[1]) and themed.earnings[ids[2]]==otherBank,"collection affects only selected figure")
local wallet=themed.coins
check(not Rules.collect(themed,1,ids[2]) and themed.coins==wallet,"stale target cannot collect replacement")
themed.earnings[ids[1]]=Config.coinLimit-1
Rules.settle(themed,100)
check(themed.earnings[ids[1]]==Config.coinLimit,"per-figure bank safety ceiling")
print("PASS: "..checks.." redesigned economy and transaction checks")

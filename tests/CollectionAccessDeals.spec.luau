--!strict
-- Isolated process: offer an expansion through the actual deal router without changing
-- production deal selection or price configuration.
local Economy = require("./Economy")
Economy.deals.weights = {{collection="moon",weight=1}}
local Rules = require("./Rules")
local Deals = require("./Deals")
local Access = require("./CollectionAccess")
local Catalog = require("./Catalog")
local Transactions = require("./Transactions")
local Profile = require("./Profile")
local UI = require("./UIState")
local checks = 0
local function check(value,message) checks+=1; assert(value,message) end
local session = Transactions.new(0)
local state = session.state
state.coins = 100000000
Rules.grantFigure(state,"grove.pebble",1)
state.display.slots[1] = "grove.pebble"
local priorStock = state.deals
local rolls = 0
local request = {action="Deal",id="locked-deal",revision=0,slot=1,window=10}
local reply = Transactions.process(session,request,20,false,0.99,10,nil,nil,10,function() rolls+=1 end)
check(reply and not reply.ok and string.find(reply.message,"locked"),"Deal cannot bypass purchase lock")
check(rolls==0 and state.coins==100000000 and state.boxesOpened==0 and state.time==0 and state.revision==0,"Locked deal never settles, spends, rolls or grants")
check(state.deals==priorStock and state.deals.window==-1 and state.deals.bought[1]==0,"Locked deal does not refresh or consume stock")
check(next(state.pityByGroup)==nil and not state.discovered["moon.rabbit"],"Locked deal cannot advance pity or discoveries")
local snapshot={coins=state.coins,deals=Deals.view(state,10),collectionAccess=Access.view(state.discovered)}
check(not UI.deal(snapshot,1,10*3600+100).canBuy and UI.deal(snapshot,1,10*3600+100).button=="Purchases locked","Deal presentation distinguishes locked from affordability")
for _,f in Catalog.figures do if f.collection=="echo" and f.rarity~="Mythical" then state.discovered[f.id]=true end end
check(Access.canBuy(state.discovered,"moon"),"Baseline discoveries authorize deal")
local price = Deals.price(Rules.prices.moon)
request={action="Deal",id="unlocked-deal",revision=0,slot=1,window=10}
reply=Transactions.process(session,request,21,false,0,10,nil,nil,10)
check(reply and reply.ok and state.coins==100000000-price and state.boxesOpened==1 and state.deals.bought[1]==1,"Unlocked deal retains exact discounted price and stock")
check(Transactions.process(session,request,22,false,0,10,nil,nil,10)==reply and state.deals.bought[1]==1,"Deal retry spends and consumes stock once")
check(Profile.decode(Profile.encode(state),0)~=nil,"Deal and discovery progress round trip")
print("PASS:",checks,"locked/unlocked expansion deal authority, presentation and retry checks")

--!strict
local Rules = require("./Rules")
local Lineage = require("./PaidLineage")
local Credits = require("./OfflineCredits")
local Awards = require("./OfflineAwards")
local Packages = require("./PackageGrants")
local Profile = require("./Profile")
local Config = require("./PurchaseConfig")
local Economy = require("./Economy")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function near(a,b,message) check(math.abs(a-b)<1e-7*math.max(1,math.abs(b)),message) end
local function promote(s)
	Credits.promote(s)
	Lineage.promote(s)
	return s
end
local function state()
	local s = promote(Rules.new(0))
	s.paidBoostsAllowed, s.boostClockValid, s.boostWall = true, true, 1000
	return s
end
local function pack(s, id)
	local product=Config.find("pack_small")
	check(Packages.deliver(s,"receipt:"..id,{product=product.key,platformId=product.platformId,kind="DeveloperProduct",grant=product.grant}),"Package delivered")
end
local s=state()
pack(s,"once")
check(Lineage.drain(s,true)==15000 and s.coins==19500 and s.lineage.earnedCoins==4500,"Fixed paid grant enters assisted wallet once")
check(Lineage.drain(s,true)==0,"No repeated credit transfer")
pack(s,"once")
check(Lineage.drain(s,true)==0,"Receipt replay cannot refill spent wallet")
local ok=Rules.mutate(s,{action="BuyTen",id="mixed",revision=0,choice="grove"},table.create(10,0.05),0,0)
check(ok and s.coins==4500 and s.lineage.earnedCoins==0,"Mixed batch spends earned Coins first")
check(next(s.lineage.earnedOwned)==nil and next(s.owned)~=nil,"Every mixed-funded result retains assisted provenance")
local encoded=Profile.encode(s)
local loaded=Profile.decode(encoded,0)
check(loaded~=nil and loaded.lineage.packageTransferred==15000,"Schema20 round trip")
check(Lineage.drain(loaded,true)==0,"Rejoin cannot re-credit spent paid Coins")
for _,field in {"earnedCoins","packageTransferred","offlineTransferred","assistedReserve"} do
	local bad=Profile.encode(s)
	bad.lineage[field]=0/0
	check(Profile.decode(bad,0)==nil,"Nonfinite lineage rejected: "..field)
end
local bad=Profile.encode(s); bad.lineage.earnedCoins=bad.coins+1
check(Profile.decode(bad,0)==nil,"Earned balance cannot exceed wallet")
bad=Profile.encode(s); bad.lineage.packageTransferred=bad.packages.assistedCredit+1
check(Profile.decode(bad,0)==nil,"Cannot invent transferred paid value")
bad=Profile.encode(s); bad.lineage.earnedOwned["grove.pebble"]=100
check(Profile.decode(bad,0)==nil,"Cannot invent earned copies")
bad=Profile.encode(s); bad.lineage.surprise=true
check(Profile.decode(bad,0)==nil,"Strict lineage record")
s=Rules.new(0)
Rules.grantFigure(s,"grove.pebble",1)
s.display.slots[1]="grove.pebble"
promote(s)
s.paidBoostsAllowed,s.boostClockValid,s.boostWall=true,true,1000
Rules.grantFigure(s,"grove.pebble",99,true)
s.earningFactors.permanentTier,s.earningFactors.vipFactor=8,1.1
s.boosts.coin={started=1000,expires=1300,strength=2}
local earnedRate=Lineage.earnedRates(s)["grove.pebble"]
Rules.settle(s,10)
near(s.lineage.earnedBanks["grove.pebble"],10*earnedRate,"Earned income uses only earned copies without paid modifiers")
check(s.earnings["grove.pebble"]>s.lineage.earnedBanks["grove.pebble"],"Duplicate and modifier increments are assisted")
local before=s.coins
local moved=Rules.transferBank(s,"grove.pebble")
check(moved>0 and s.coins==before+moved,"Real shared bank helper conserves total")
check(s.lineage.earnedCoins==4500+math.floor(10*earnedRate),"Only whole earned portion is classified earned")
check(Lineage.suspend(s),"Policy change moves paid wallet to protected reserve")
check(s.coins==s.lineage.earnedCoins and s.lineage.assistedReserve>0,"Policy change preserves earned wallet and paid value")
s.paidBoostsAllowed=false
check(Lineage.drain(s,false)==0,"Restricted credit remains saved")
check(not pcall(Lineage.spend,s,s.coins+1),"Restricted player cannot spend protected paid value")
local reserve=s.lineage.assistedReserve
s.paidBoostsAllowed=true
check(Lineage.drain(s,true)==reserve,"Allowed transition restores reserve")
check(Lineage.drain(s,true)==0,"Policy refresh cannot duplicate reserve")
s=state()
Rules.grantFigure(s,"grove.pebble",1)
s.earnings["grove.pebble"]=10.2
s.lineage.earnedBanks["grove.pebble"]=5.8
check(Rules.transferBank(s,"grove.pebble")==9,"Separate bank sources transfer whole Coins")
near(s.earnings["grove.pebble"],1.2,"Both fractions survive")
near(s.lineage.earnedBanks["grove.pebble"],0.8,"Earned fraction survives")
check(Rules.transferBank(s,"grove.pebble")==0,"Cannot merge fractional provenance into earned Coins")
check(Profile.decode(Profile.encode(s),0)~=nil,"Fractional bank partition remains valid")
s=state()
s.coins,s.lineage.earnedCoins=Economy.coinLimit,Economy.coinLimit
pack(s,"full")
check(Lineage.drain(s,true)==0 and s.lineage.packageTransferred==0,"Full wallet retains complete paid promise")
Lineage.spend(s,100)
check(Lineage.drain(s,true)==100 and s.lineage.packageTransferred==100,"Overflow transfers only available room")
check(s.packages.assistedCredit==15000,"Immutable lifetime promise remains intact")
s=state()
s.offlinePending,s.offlineSeconds=51,100
Awards.freeze(s,"lineage-test",17)
local beforeEarned=s.lineage.earnedCoins
check(Rules.claimOffline(s)==34 and s.lineage.earnedCoins==beforeEarned+34,"Offline base source partition")
check(Lineage.drain(s,true)==17,"Offline assistance is usable exactly once")
check(Lineage.drain(s,true)==0 and s.coins==4551,"Offline replay cannot duplicate assistance")
check(Profile.decode(Profile.encode(s),0)~=nil,"Offline paid transfer persists with original award")
-- Shared pity remains the same before and after lineage promotion.
local free=Rules.new(0); Rules.adminCoins(free,"SetCoins",2000000,0)
local tracked=Profile.decode(Profile.encode(free),0); promote(tracked)
tracked.paidBoostsAllowed=false
for i=1,20 do
	local intent={action="Buy",id="same"..i,choice="concept",revision=i-1}
	local a,_,figureA=Rules.mutate(free,intent,(i%7)/8,0,0)
	local b,_,figureB=Rules.mutate(tracked,intent,(i%7)/8,0,0)
	check(a==b and figureA==figureB,"Shared pity draw preserved "..i)
end
for group,counters in free.pityByGroup do
	check(tracked.pityByGroup[group].legendaryDryRolls==counters.legendaryDryRolls and tracked.pityByGroup[group].mythicalDryRolls==counters.mythicalDryRolls,"All rolls count toward the same pity")
end
print("PASS:",checks,"paid-Coin lineage, policy transitions, shared pity, conservation and schema checks")

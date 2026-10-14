--!strict
local Policy=require("./PaidPolicy")
local checks=0
local function check(value,message) checks+=1; assert(value,message) end
local now=0
local response={ArePaidRandomItemsRestricted=false}
local changes=0
local cache=Policy.create({now=function() return now end,fetch=function() return response end,changed=function() changes+=1 end})
cache.add(7)
check(cache.status(7)=="Unknown","Unverified player starts unknown")
cache.refresh(7)
check(cache.status(7)=="Allowed","Actual boolean false permits paid path")
now=60
check(cache.status(7)=="Unknown","Expired policy never remains allowed")
response={ArePaidRandomItemsRestricted=true}
cache.refresh(7)
check(cache.status(7)=="Restricted","Fresh restriction applied")
now=120; response={ArePaidRandomItemsRestricted="false"}; cache.refresh(7)
check(cache.status(7)=="Unknown","Malformed success fails closed")
local count=changes
cache.refresh(7)
check(changes==count,"Failed policy retry uses backoff")
now=122; response={}; cache.refresh(7)
check(cache.status(7)=="Unknown","Missing policy field fails closed")
now=126; response={ArePaidRandomItemsRestricted=false}; cache.refresh(7)
check(cache.status(7)=="Allowed","Recovery can permit future paid actions")
cache.remove(7)
check(cache.status(7)=="Unknown","Departed owner is removed")
local yieldOld=true
cache=Policy.create({now=function() return now end,fetch=function()
	if yieldOld then coroutine.yield(); return {ArePaidRandomItemsRestricted=true} end
	return {ArePaidRandomItemsRestricted=false}
end,changed=function() changes+=1 end})
cache.add(7)
local pending=coroutine.create(function() cache.refresh(7) end)
check(coroutine.resume(pending),"Policy API yields")
cache.remove(7); cache.add(7); yieldOld=false; cache.refresh(7)
check(cache.status(7)=="Allowed","New join independently verified")
local before=changes
check(coroutine.resume(pending),"Old query returns")
check(cache.status(7)=="Allowed" and changes==before,"Late old reply cannot replace a newer owner")
cache.destroy()
check(cache.status(7)=="Unknown" and #cache.due()==0,"Teardown forgets pending authority")
print("PASS:",checks,"policy freshness, strict result, retry and owner-generation checks")

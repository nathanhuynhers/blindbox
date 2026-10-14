--!strict
local Service = require("./PurchaseService")
local Config = require("./PurchaseConfig")
local checks = 0
local function check(value, message)
 checks += 1
 assert(value, message)
end
local function scenario(pass, pauseOnly)
 local product = table.clone(Config.find(if pass then "starter" else "pack_small"))
 product.kind = if pass then "Pass" else "DeveloperProduct"
 product.platformId, product.integrationReady = 101, true
 local records, delivered = {}, {}
 local ready, suspend, deliveries = true, false, 0
 local service = Service.create({
  now = function() return 0 end,
  ready = function() return ready end,
  update = function(key, transform)
   local candidate = transform(records[key])
   if candidate then records[key] = candidate end
   if suspend and key == "Player_7" then
    suspend = false
    coroutine.yield()
   end
   return records[key]
  end,
  owns = function() return true end,
  eligible = function() return false end,
  prompt = function() return false end,
  send = function() end,
  deliverReserved = function(_, marker)
   if not delivered[marker] then
    delivered[marker] = true
    deliveries += 1
   end
   return true
  end,
 }, {product})
 service.add(7)
 suspend = true
 local result = nil
 local worker = coroutine.create(function()
  result = if pass then service.claimPass(7, "starter")
   else service.receipt({PurchaseId="late",PlayerId=7,ProductId=101})
 end)
 check(coroutine.resume(worker) and coroutine.status(worker) == "suspended", "Actual durable commit yields")
 ready = false
 if not pauseOnly then
  service.remove(7)
  service.add(7)
  ready = true
 end
 check(coroutine.resume(worker), "Old callback resumes")
 check(deliveries == 0, "Old or paused callback cannot deliver into current profile")
 check(result == false, "Unconfirmed profile delivery remains retryable")
 check(records.Player_7 ~= nil and next(records.Player_7.entries) ~= nil, "Durable promise survives")
 ready = true
 service.refresh(7)
 local recovered = if pass then service.claimPass(7, "starter")
  else service.receipt({PurchaseId="late",PlayerId=7,ProductId=101})
 check(recovered and deliveries == 1, "Same immutable promise recovers once")
end
scenario(false, false)
scenario(false, true)
scenario(true, false)
scenario(true, true)
print(string.format("PASS: %d paid delivery session/lease boundary checks",checks))

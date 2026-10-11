--!strict
-- run.py runs this against copies of the actual modules with disabled/invalid owner config.
local Protocol = require("./AdminProtocol")
local Service = require("./AdminService")
local function forbidden() error("Unauthorized request reached an authority callback") end
local service = Service.create({
	now = function() return 0 end, wall = function() return 0 end, token = forbidden,
	players = forbidden, target = forbidden, changed = forbidden, teleport = forbidden, kick = forbidden,
	random = forbidden, log = function() end,
})
for _, id in { 103346374, 1, 0, -1 } do
	assert(not Protocol.allowed(id, "Owner"))
	assert(not service.receive(id, "Connect").ok)
	assert(not service.receive(id, { action = "GrantCoins", amount = 100 }).ok)
end
print("PASS: disabled/invalid owner configuration fails closed")

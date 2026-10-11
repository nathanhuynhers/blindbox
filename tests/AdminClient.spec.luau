--!strict
local Client = require("./AdminClient")
local A = require("./AdminTypes")
local calls = 0
local fail = false
local captured: A.Request? = nil
local client = Client.create(function(raw: unknown): A.Reply
	calls += 1
	if raw == "Connect" then return { ok = true, message = "authorized", token = string.rep("a", 36), sequence = 4 } end
	captured = raw :: A.Request
	if fail then error("network interruption") end
	return { ok = true, message = "confirmed" }
end)
local function request(): A.Request return { token = "", sequence = 0, action = "GrantCoins", target = 1, revision = 0, amount = 1 } end
assert(not client.request(request()).ok and calls == 0, "cannot request before authorization")
assert(client.connect().ok)
assert(client.request(request()).ok and captured ~= nil and captured.sequence == 5)
fail = true
assert(not client.request(request()).ok and client.uncertain())
local before = captured
local count = calls
assert(not client.request(request()).ok and calls == count, "uncertain mutation blocks new actions")
fail = false
assert(client.retry().ok and not client.uncertain() and captured == before, "retry retains exact request")
assert(client.request(request()).ok and captured ~= nil and captured.sequence == 7)
local denied = Client.create(function() return { ok = false, message = "Unauthorized" } end)
assert(not denied.connect().ok and not denied.request(request()).ok)
print("PASS: admin client authorization, confirmed feedback and exact retry assertions")

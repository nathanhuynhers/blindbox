--!strict
local Assets = require("./AssetManifest")
local Ids = require("./AssetIds")
local key = "TestPipeline.TestImage"
local original = Ids[key]
local checks = 0
local function expect(actual: string, expected: string)
	assert(actual == expected, "Asset resolution mismatch")
	checks += 1
end

Ids[key] = nil
expect(Assets.resolve(key), "")
Ids[key] = "12345678901234567"
expect(Assets.resolve(key), "rbxassetid://12345678901234567")
for _, invalid in { "", "0", "-1", "1.5", "rbxassetid://123", "123abc" } do
	Ids[key] = invalid
	expect(Assets.resolve(key), "")
end
Ids[key] = original
for semanticKey, id in Ids do
	expect(Assets.resolve(semanticKey), "rbxassetid://" .. id)
end
expect(Assets.Collection.PocketGrove.Emblem, "Collection.PocketGrove.Emblem")
expect(Assets.Collection.PocketGrove.ShopPattern, "Collection.PocketGrove.ShopPattern")
expect(Assets.Collection.TidepoolTales.Emblem, "Collection.TidepoolTales.Emblem")
expect(Assets.Collection.TidepoolTales.ShopPattern, "Collection.TidepoolTales.ShopPattern")
print(string.format("PASS: %d public asset manifest checks", checks))

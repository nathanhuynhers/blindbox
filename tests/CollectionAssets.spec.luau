--!strict
local Engine = require("./AssetMountEngine")
local Assets = require("./CollectionAssets")
local Scope = require("./UIScope")
local Manifest = require("./AssetManifest")
local scope = Scope.create()
local slot = Assets.mount(Engine.Instance.new("Frame"), "TestCorner", scope)
local image = Engine.nodes[#Engine.nodes]
local checks = 0
local function expect(production: boolean)
	assert(image.Visible == production, "Wrong production visibility")
	assert(slot.native.Visible == not production, "Wrong native visibility")
	assert(image.Visible ~= slot.native.Visible, "Artwork and fallback must never overlap")
	checks += 1
end
expect(false)
local grove = Assets.get("grove").cornerTopLeft
assert(grove and grove.id ~= "", "Uploaded Grove corner must resolve")
local seen: { [string]: boolean } = {}
for id, keys in
	{ grove = Manifest.Collection.PocketGrove, tide = Manifest.Collection.TidepoolTales }
do
	local skin = Assets.get(id)
	local entries = {
		{ asset = skin.cornerTopLeft, key = keys.CornerTopLeft },
		{ asset = skin.cornerTopRight, key = keys.CornerTopRight },
		{ asset = skin.cornerBottomLeft, key = keys.CornerBottomLeft },
		{ asset = skin.cornerBottomRight, key = keys.CornerBottomRight },
		{ asset = skin.emblem, key = keys.Emblem },
	}
	for _, entry in entries do
		local asset = entry.asset
		assert(
			asset and asset.id ~= "" and asset.id == Manifest.resolve(entry.key),
			"Wrong slot mapping"
		)
		assert(not seen[asset.id], "Collection artwork must not be reused across different slots")
		seen[asset.id] = true
		slot.set(asset)
		expect(true)
		assert(image.ScaleType == "Fit", "All Collection production art must preserve aspect ratio")
	end
end
slot.set(grove)
expect(true) -- Before loading completes: the regression that previously showed both.
assert(image.ScaleType == "Fit", "Production image must retain aspect-fit scaling")
for _, loaded in { true, false, true } do
	image.IsLoaded = loaded
	image:GetPropertyChangedSignal("IsLoaded").fire()
	expect(true)
end
slot.set(Assets.get("tide").corner)
expect(false)
slot.set(grove)
expect(true)
for _, invalid in { "", "rbxassetid://0", "rbxassetid://-1", "rbxassetid://123abc", "unresolved" } do
	slot.set({ id = invalid })
	assert(image.Image == "", "Invalid references must not be assigned")
	expect(false)
end
image.Image = grove.id
image:GetPropertyChangedSignal("Image").fire()
expect(true)
image.Image = ""
image:GetPropertyChangedSignal("Image").fire()
expect(false)
scope.destroy()
image.Image = grove.id
image:GetPropertyChangedSignal("Image").fire()
expect(false) -- Listener disconnected on teardown.
print(string.format("PASS: %d mutually exclusive artwork/fallback mount checks", checks))

--!strict
-- Uploaded artwork replaces ONLY decorative surfaces. Keep names/numbers/models out of images.
local Scope = require(script.Parent.UIScope)
local W = require(script.Parent.Widgets)
local Manifest = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
local Assets = {}
export type Image = { id: string, slice: { number }?, fit: boolean? }
export type Slot = { root: Frame, native: Frame, set: (Image) -> () }
export type Skin = {
	spread: Image,
	page: Image,
	corner: Image,
	cornerTopLeft: Image?,
	cornerTopRight: Image?,
	cornerBottomLeft: Image?,
	cornerBottomRight: Image?,
	tab: Image,
	emblem: Image,
	card: Image,
	cardSelected: Image,
	cardLocked: Image,
	detail: Image,
}
local function empty(): Image
	return { id = "" }
end
local function skin(): Skin
	return {
		spread = empty(),
		page = empty(),
		corner = empty(),
		tab = empty(),
		emblem = empty(),
		card = empty(),
		cardSelected = empty(),
		cardLocked = empty(),
		detail = empty(),
	}
end
-- Resolve adopted artwork through the shared semantic manifest; empty slots stay native.
-- Optional slice = {left, top, right, bottom} in source-image pixels enables nine-slice.
Assets.collections = { grove = skin(), tide = skin() } :: { [string]: Skin }
local function production(key: string): Image
	return { id = Manifest.resolve(key), fit = true }
end
local collectionKeys: { [string]: Manifest.CollectionKeys } = {
	grove = Manifest.Collection.PocketGrove,
	tide = Manifest.Collection.TidepoolTales,
}
for id, keys in collectionKeys do
	local artwork = Assets.collections[id]
	artwork.cornerTopLeft = production(keys.CornerTopLeft)
	artwork.cornerTopRight = production(keys.CornerTopRight)
	artwork.cornerBottomLeft = production(keys.CornerBottomLeft)
	artwork.cornerBottomRight = production(keys.CornerBottomRight)
	artwork.emblem = production(keys.Emblem)
end
Assets.buttons = { display = empty(), recycle = empty(), paper = empty() }
Assets.badges = { Common = empty(), Uncommon = empty(), Rare = empty() } :: { [string]: Image }
local fallback = skin()
function Assets.get(id: string): Skin
	return Assets.collections[id] or fallback
end
function Assets.mount(parent: Instance, name: string, scope: Scope.Scope): Slot
	local root = W.frame(parent, name)
	local native = W.frame(root, "Native")
	local image = Instance.new("ImageLabel")
	image.Name = "Artwork"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Parent = root
	local function refresh()
		local assigned = string.match(image.Image, "^rbxassetid://[1-9]%d*$") ~= nil
		-- Resolution chooses one representation. Loading state must never show both.
		image.Visible = assigned
		native.Visible = not assigned
	end
	scope.connect(image:GetPropertyChangedSignal("Image"), refresh)
	refresh()
	return {
		root = root,
		native = native,
		set = function(asset: Image)
			local slice = asset.slice
			image.ScaleType = if slice
				then Enum.ScaleType.Slice
				elseif asset.fit then Enum.ScaleType.Fit
				else Enum.ScaleType.Stretch
			if slice then
				image.SliceCenter = Rect.new(slice[1], slice[2], slice[3], slice[4])
			end
			image.Image = if string.match(asset.id, "^rbxassetid://[1-9]%d*$") then asset.id else ""
			refresh()
		end,
	}
end
return Assets

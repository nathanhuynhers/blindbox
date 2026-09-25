--!strict
-- Uploaded artwork replaces ONLY decorative surfaces. Keep names/numbers/models out of images.
local Scope = require(script.Parent.UIScope)
local W = require(script.Parent.Widgets)
local Assets = {}
export type Image = { id: string, slice: { number }? }
export type Slot = { root: Frame, native: Frame, set: (Image) -> () }
export type Skin = {
	spread: Image,
	page: Image,
	corner: Image,
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
-- Set e.g. Assets.collections.grove.spread.id to an uploaded rbxassetid://... .
-- Optional slice = {left, top, right, bottom} in source-image pixels enables nine-slice.
Assets.collections = { grove = skin(), tide = skin() } :: { [string]: Skin }
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
		local loaded = image.Image ~= "" and image.IsLoaded
		image.Visible = loaded
		native.Visible = not loaded
	end
	scope.connect(image:GetPropertyChangedSignal("IsLoaded"), refresh)
	refresh()
	return {
		root = root,
		native = native,
		set = function(asset: Image)
			local slice = asset.slice
			image.ScaleType = if slice then Enum.ScaleType.Slice else Enum.ScaleType.Stretch
			if slice then
				image.SliceCenter = Rect.new(slice[1], slice[2], slice[3], slice[4])
			end
			image.Image = asset.id
			refresh()
		end,
	}
end
return Assets

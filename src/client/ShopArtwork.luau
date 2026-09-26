--!strict
local Manifest = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
local W = require(script.Parent.Widgets)

local Artwork = {}
export type Slot = {
	root: Frame,
	native: Frame,
	image: ImageLabel,
	set: (string) -> (),
}

function Artwork.mount(parent: Instance, name: string, scaleType: Enum.ScaleType): Slot
	local root = W.frame(parent, name)
	local native = W.frame(root, "Native")
	local image = Instance.new("ImageLabel")
	image.Name = "Artwork"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = scaleType
	image.ImageColor3 = Color3.new(1, 1, 1)
	image.Parent = root
	local function set(key: string)
		local resolved = Manifest.resolve(key)
		image.Image = resolved
		image.Visible = resolved ~= ""
		native.Visible = resolved == ""
	end
	set("")
	return { root = root, native = native, image = image, set = set }
end

return Artwork

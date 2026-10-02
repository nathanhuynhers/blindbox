--!strict
-- One visual system for every screen: white panels, chunky plum outlines, hard drop shadows.
-- Values follow docs/ui-redesign/BRIEF.md and the approved mockup source.
local Manifest = require(game:GetService("ReplicatedStorage").Shared.AssetManifest)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Style = {}

local function hex(value: number): Color3
	return Color3.fromRGB(
		math.floor(value / 65536) % 256,
		math.floor(value / 256) % 256,
		value % 256
	)
end
Style.hex = hex

Style.ink = hex(0x2B1F4A)
Style.muted = hex(0x5C5276)
Style.surface = hex(0xFFFDF9)
Style.surface2 = hex(0xF6F2FC)
Style.divider = hex(0xECE5F6)
Style.track = hex(0xE2DAEF)
Style.white = hex(0xFFFFFF)
Style.violet = hex(0x6B4EE6)
Style.violetDark = hex(0x4B32C3)
Style.violetWash = hex(0xEFE8FF)
Style.gold = hex(0xFFC83D)
Style.coinRing = hex(0xC98A00)
Style.goldWash = hex(0xFFF6DA)
Style.readyWash = hex(0xFFF1C7)
Style.readyInk = hex(0x6B4A00)
Style.mint = hex(0xDDF3E6)
Style.mintInk = hex(0x174F36)
Style.mintText = hex(0x1E6B47)
Style.mintFill = hex(0x3BA272)
Style.alert = hex(0xD92D46)
Style.disabledFill = hex(0xEDE8F5)
Style.disabledBorder = hex(0xB9AFCB)
Style.unknownInk = hex(0x8C83A3)
Style.lockedFill = hex(0xF3F1F6)
Style.lockedBorder = hex(0xD6D0E0)
-- The world dim replaces the old blur and warm overlays while a screen is open.
Style.dim = hex(0x23183D)
Style.dimTransparency = 0.45
-- Reveal card (end of opening) sits over the cinematic.
Style.revealGround = hex(0x221839)
Style.revealChip = hex(0x3A2C5E)
Style.revealText = hex(0xE9E2FA)
Style.revealShadow = hex(0x120C22)
-- Shelves cabinet wood.
Style.wood = hex(0xC9965A)
Style.woodDark = hex(0x8A5A32)
Style.woodInner = hex(0xF7E7CC)
Style.woodLip = hex(0xA7713F)
Style.woodSpot = hex(0xFFF9EE)
Style.woodDash = hex(0xC9A777)

Style.outline = 3
Style.outlineSmall = 2
Style.shadow = 4
Style.target = 44
Style.transition = 0.12

-- Roblox font families from the brief. Flip `gotham` if either family fails to resolve in Studio.
local gotham = false
Style.gotham = gotham
local displayFamily = "rbxasset://fonts/families/FredokaOne.json"
local bodyFamily = "rbxasset://fonts/families/Nunito.json"
function Style.display(): Font
	return if gotham
		then Font.fromEnum(Enum.Font.GothamBold)
		else Font.new(displayFamily, Enum.FontWeight.Regular)
end
function Style.body(weight: Enum.FontWeight?): Font
	return if gotham
		then Font.fromEnum(Enum.Font.GothamMedium)
		else Font.new(bodyFamily, weight or Enum.FontWeight.ExtraBold)
end

export type Collection = {
	color: Color3,
	wash: Color3,
	ink: Color3,
	mono: string,
	short: string?,
	emblem: string,
}
local function collection(
	color: number,
	wash: number,
	mono: string,
	short: string,
	emblem: string
): Collection
	local accent = hex(color)
	return table.freeze({
		color = accent,
		wash = hex(wash),
		-- Banner/body text on the wash keeps 4.5:1 by darkening the accent toward black.
		ink = accent:Lerp(Color3.new(0, 0, 0), 0.45),
		mono = mono,
		short = short,
		emblem = emblem,
	})
end
-- A new collection is one entry here; anything missing falls back to the neutral accent.
Style.collections = table.freeze({
	grove = collection(0x4F8A3F, 0xE4F1DA, "PG", "Grove", Manifest.Collection.PocketGrove.Emblem),
	tide = collection(
		0x2F7FA6,
		0xDCEEF7,
		"TT",
		"Tidepool",
		Manifest.Collection.TidepoolTales.Emblem
	),
	concept = collection(0xA84C70, 0xF7E1EA, "C", "Concepts", Manifest.Collection.Concepts.Emblem),
	echo = collection(0xC46A2C, 0xFCEADB, "TE", "Echoes", Manifest.Collection.TenderEchoes.Emblem),
	star = collection(0x4A5BB8, 0xE1E5F8, "WS", "Stars", Manifest.Collection.WeAreAllStars.Emblem),
}) :: { [string]: Collection }
local neutral: Collection = table.freeze({
	color = hex(0x6B4EE6),
	wash = hex(0xEFE8FF),
	ink = hex(0x4B32C3),
	mono = "",
	short = nil,
	emblem = "",
})

-- Monogram from the name's initials so an unconfigured collection still gets an icon.
function Style.monogram(name: string): string
	local letters = ""
	for word in string.gmatch(name, "%a+") do
		letters ..= string.upper(string.sub(word, 1, 1))
		if #letters == 2 then
			break
		end
	end
	return if letters == "" then "?" else letters
end

function Style.collection(id: string): Collection
	return Style.collections[id] or neutral
end

function Style.mono(id: string, name: string): string
	local mono = Style.collection(id).mono
	return if mono == "" then Style.monogram(name) else mono
end

function Style.emblem(id: string): string
	local key = Style.collection(id).emblem
	return if key == "" then "" else Manifest.resolve(key)
end

function Style.rarity(id: string): (Color3, Color3)
	local definition = Rarity.get(id)
	return definition.tint, definition.onTint
end

return Style

--!strict
-- Small popover under the HUD gear: the Motion preference and a session-only Sound switch.
local Style = require(script.Parent.UIStyle)
local Kit = require(script.Parent.UIKit)
local Button = require(script.Parent.UIButton)
local Context = require(script.Parent.UIContext)
local Sfx = require(script.Parent.Sfx)
local Menu = {}

export type Menu = {
	root: Frame,
	catcher: TextButton,
	open: () -> boolean,
	set: (boolean) -> (),
	place: (x: number, y: number) -> (),
	first: () -> GuiObject,
}

function Menu.create(parent: Instance, ctx: Context.Context, setMotion: (boolean) -> ()): Menu
	-- A transparent catcher closes the popover on any outside tap.
	local catcher = Instance.new("TextButton")
	catcher.Name = "SettingsCatcher"
	catcher.Text = ""
	catcher.BackgroundTransparency = 1
	catcher.Selectable = false
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.Visible = false
	catcher.ZIndex = 40
	catcher.Parent = parent
	local card = Kit.card(parent, "Settings", Style.white, 18, 4)
	local root = card.root
	root.Visible = false
	root.ZIndex = 41
	root.SelectionGroup = true
	root.Size = UDim2.fromOffset(280, 242)
	local title = Kit.text(card.face, "Title", "Settings", 20, Style.display())
	Kit.rect(title, 16, 12, 248, 26)
	local motion = Kit.text(card.face, "MotionLabel", "Motion", 15)
	Kit.rect(motion, 16, 42, 248, 20)
	local hint = Kit.text(
		card.face,
		"MotionHint",
		"Reduced shortens openings and stops bounces",
		12,
		Style.body(Enum.FontWeight.Bold),
		Style.muted
	)
	Kit.rect(hint, 16, 62, 248, 18)
	local reduced = false
	local full: Button.Button, low: Button.Button
	local function paint()
		full.variant(if reduced then "white" else "selected")
		low.variant(if reduced then "selected" else "white")
		full.button:SetAttribute("Selected", not reduced)
		low.button:SetAttribute("Selected", reduced)
	end
	full = Button.create(
		card.face,
		"MotionFull",
		{
			variant = "selected",
			text = "Full",
			size = 16,
			radius = 14,
			drop = 0,
			outline = Style.outlineSmall,
			font = Style.body(Enum.FontWeight.ExtraBold),
		},
		ctx.scope,
		ctx.effects,
		function()
			reduced = false
			setMotion(true)
			paint()
		end
	)
	Kit.rect(full.button, 16, 92, 120, 46)
	low = Button.create(
		card.face,
		"MotionReduced",
		{
			variant = "white",
			text = "Reduced",
			size = 16,
			radius = 14,
			drop = 0,
			outline = Style.outlineSmall,
			font = Style.body(Enum.FontWeight.ExtraBold),
		},
		ctx.scope,
		ctx.effects,
		function()
			reduced = true
			setMotion(false)
			paint()
		end
	)
	Kit.rect(low.button, 144, 92, 120, 46)
	paint()
	-- Not saved: Roblox's own volume still applies, and every session starts with sound on.
	local soundLabel = Kit.text(card.face, "SoundLabel", "Sound", 15)
	Kit.rect(soundLabel, 16, 150, 248, 20)
	local on: Button.Button, off: Button.Button
	local function paintSound()
		local muted = Sfx.muted()
		on.variant(if muted then "white" else "selected")
		off.variant(if muted then "selected" else "white")
		on.button:SetAttribute("Selected", not muted)
		off.button:SetAttribute("Selected", muted)
	end
	local function toggle(name: string, muted: boolean)
		return Button.create(
			card.face,
			name,
			{
				variant = "white",
				text = if muted then "Off" else "On",
				size = 16,
				radius = 14,
				drop = 0,
				outline = Style.outlineSmall,
				font = Style.body(Enum.FontWeight.ExtraBold),
			},
			ctx.scope,
			ctx.effects,
			function()
				Sfx.setMuted(muted)
				paintSound()
			end
		)
	end
	on = toggle("SoundOn", false)
	Kit.rect(on.button, 16, 176, 120, 46)
	off = toggle("SoundOff", true)
	Kit.rect(off.button, 144, 176, 120, 46)
	paintSound()
	local function set(open: boolean)
		root.Visible = open
		catcher.Visible = open
	end
	ctx.scope.connect(catcher.Activated, function()
		set(false)
	end)
	return {
		root = root,
		catcher = catcher,
		open = function()
			return root.Visible
		end,
		set = set,
		place = function(x: number, y: number)
			root.Position = UDim2.fromOffset(x, y)
		end,
		first = function()
			return if reduced then low.button else full.button
		end,
	}
end

return Menu

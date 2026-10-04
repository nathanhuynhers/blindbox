--!strict
-- Small popover under the HUD gear: the Motion preference and saved Sound effects / Music
-- volume sliders. A slider applies instantly; the value is saved (SetVolume) when you let go.
local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
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
	update: (Types.Snapshot) -> (),
}

type Slider = {
	button: TextButton,
	paint: (number) -> (),
	fraction: (x: number) -> number,
}

local snap = 5 -- Drag and tap snap to 5%; gamepad steps 10%.
local width, knob = 248, 26 -- Design units; the knob travels inside the track.

local function slider(parent: Instance, name: string, label: string, y: number): Slider
	local caption = Kit.text(parent, name .. "Label", label, 15)
	Kit.rect(caption, 16, y, 180, 20)
	local value = Kit.text(parent, name .. "Value", "", 15, Style.display())
	value.TextXAlignment = Enum.TextXAlignment.Right
	Kit.rect(value, 196, y, 68, 20)
	-- A 44px-tall hit area around a 12px track, so touch targets stay large.
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Parent = parent
	Kit.rect(button, 16, y + 20, width, 44)
	button:SetAttribute("AccessibleName", label .. " volume")
	local track = Kit.frame(button, "Track", Style.track)
	Kit.rect(track, 0, 16, width, 12)
	Kit.round(track)
	local fill = Kit.frame(track, "Fill", Style.violet)
	fill.Size = UDim2.fromScale(1, 1)
	Kit.round(fill)
	local handle = Kit.frame(button, "Knob", Style.white)
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.Size = UDim2.fromOffset(knob, knob)
	handle.ZIndex = 3
	Kit.round(handle)
	Kit.stroke(handle, Style.ink, Style.outlineSmall)
	return {
		button = button,
		paint = function(percent: number)
			value.Text = percent .. "%"
			local centre = knob / 2 + percent / 100 * (width - knob)
			fill.Size = UDim2.new(0, centre, 1, 0)
			handle.Position = UDim2.fromOffset(centre, 22)
			button:SetAttribute("Volume", percent)
		end,
		-- Screen x to 0..1, matching the inset knob travel at any UI scale.
		fraction = function(x: number): number
			local size = track.AbsoluteSize.X
			local inset = size * knob / 2 / width
			local travel = size - 2 * inset
			return if travel > 0
				then math.clamp((x - track.AbsolutePosition.X - inset) / travel, 0, 1)
				else 0
		end,
	}
end

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
	root.Size = UDim2.fromOffset(280, 296)
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
	local kinds = { "sfx", "music" }
	local sliders: { [string]: Slider } = {
		sfx = slider(card.face, "SfxVolume", "Sound effects", 148),
		music = slider(card.face, "MusicVolume", "Music", 216),
	}
	-- saved: the server's value; wanted: a local change not saved yet; held: being dragged.
	local saved: { [string]: number } = { sfx = 100, music = 100 }
	local wanted: { [string]: number } = {}
	local held: string? = nil
	local function show(kind: string, percent: number)
		Sfx.setVolume(if kind == "music" then "music" else "sfx", percent / 100)
		sliders[kind].paint(percent)
	end
	-- One SetVolume at a time through the normal request queue; retried on the next snapshot.
	local function flush()
		for _, kind in kinds do
			local percent = wanted[kind]
			if percent == nil then
				continue
			elseif percent == saved[kind] then
				wanted[kind] = nil
			elseif held ~= kind and ctx.canAct() then
				ctx.send("SetVolume", nil, nil, kind, percent)
				return
			end
		end
	end
	local function choose(kind: string, percent: number, save: boolean)
		local value = math.clamp(math.round(percent / snap) * snap, 0, 100)
		wanted[kind] = value
		show(kind, value)
		if save then
			flush()
		end
	end
	for _, kind in kinds do
		local control = sliders[kind]
		ctx.scope.connect(control.button.InputBegan, function(value: unknown)
			local input = value :: InputObject -- InputBegan always passes an InputObject.
			local kindOf = input.UserInputType
			if kindOf == Enum.UserInputType.MouseButton1 or kindOf == Enum.UserInputType.Touch then
				held = kind
				choose(kind, control.fraction(input.Position.X) * 100, false)
			end
		end)
	end
	ctx.scope.connect(Input.InputChanged, function(value: unknown)
		local input = value :: InputObject
		local kind = held
		if not kind then
			return
		end
		local kindOf = input.UserInputType
		if kindOf == Enum.UserInputType.MouseMovement or kindOf == Enum.UserInputType.Touch then
			choose(kind, sliders[kind].fraction(input.Position.X) * 100, false)
		end
	end)
	ctx.scope.connect(Input.InputEnded, function(value: unknown)
		local input = value :: InputObject
		local kindOf = input.UserInputType
		if
			held
			and (kindOf == Enum.UserInputType.MouseButton1 or kindOf == Enum.UserInputType.Touch)
		then
			held = nil
			flush()
		end
	end)
	-- Gamepad: with a slider selected, D-pad left/right steps it 10% (saved at once).
	local function step(_: string, state: Enum.UserInputState, input: InputObject)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		for _, kind in kinds do
			if GuiService.SelectedObject == sliders[kind].button then
				local current = wanted[kind] or saved[kind]
				local delta = if input.KeyCode == Enum.KeyCode.DPadLeft then -10 else 10
				choose(kind, current + delta, true)
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end
	for _, kind in kinds do
		show(kind, saved[kind])
	end
	local function set(open: boolean)
		root.Visible = open
		catcher.Visible = open
		if open then
			Actions:BindActionAtPriority(
				"SettingsVolumeStep",
				step,
				false,
				2100,
				Enum.KeyCode.DPadLeft,
				Enum.KeyCode.DPadRight
			)
		else
			Actions:UnbindAction("SettingsVolumeStep")
		end
	end
	ctx.scope.add(function()
		Actions:UnbindAction("SettingsVolumeStep")
	end)
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
		-- The snapshot carries the saved volumes; a local edit wins until the server has it.
		update = function(snapshot: Types.Snapshot)
			saved.sfx = snapshot.sfxVolume or 100
			saved.music = snapshot.musicVolume or 100
			for _, kind in kinds do
				if wanted[kind] == nil and held ~= kind then
					show(kind, saved[kind])
				end
			end
			flush()
		end,
	}
end

return Menu

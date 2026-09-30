--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Theme = require(script.Parent.UITheme)
local Config = require(script.Parent.OpeningConfig)
local State = require(script.Parent.OpeningState)
local Result = require(script.Parent.OpeningResult)
local Scope = require(script.Parent.OpeningScope)
local View = {}
export type View = {
	draw: (State.State, boolean) -> (),
	primary: TextButton,
	hitTarget: TextButton,
	skip: TextButton,
}
local function label(parent: Instance, name: string, size: number): TextLabel
	local object = Instance.new("TextLabel")
	object.Name, object.BackgroundTransparency, object.Text = name, 1, ""
	object.Font, object.TextColor3, object.TextScaled, object.TextWrapped =
		Theme.font, Config.neutral, true, true
	object.ZIndex, object.Parent = 5, parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = 10, size, object
	return object
end
local function button(parent: Instance, name: string): TextButton
	local object = Instance.new("TextButton")
	object.Name, object.Text, object.Font, object.TextSize = name, "", Theme.heading, 17
	object.BackgroundColor3, object.TextColor3 = Config.neutral, Theme.ink
	object.ZIndex, object.Parent = 8, parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 18), object
	return object
end
function View.create(
	gui: ScreenGui,
	scope: Scope.Scope,
	result: Result.Result,
	profile: Config.Profile
): View
	local figure = Catalog.byId[result.figureId]
	local root = Instance.new("Frame")
	root.Name, root.Size, root.BackgroundTransparency, root.Parent =
		"OpeningOverlay", UDim2.fromScale(1, 1), 1, gui
	local blocker = Instance.new("TextButton")
	blocker.Name, blocker.Size, blocker.BackgroundTransparency, blocker.Text =
		"InputShield", UDim2.fromScale(1, 1), 1, ""
	blocker.Modal, blocker.Selectable, blocker.Parent = true, false, root
	local shade = Instance.new("Frame")
	shade.Name, shade.BorderSizePixel = "ResultScrim", 0
	shade.BackgroundColor3, shade.BackgroundTransparency = Color3.fromRGB(13, 17, 23), 0.2
	shade.Size, shade.Position, shade.Parent =
		UDim2.fromScale(1, 0.45), UDim2.fromScale(0, 0.55), root
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.55, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Parent = shade
	local content = Instance.new("Frame")
	content.Size, content.Position, content.BackgroundTransparency =
		UDim2.new(1, -40, 1, -32), UDim2.fromOffset(20, 16), 1
	content.Parent = root
	local heading = label(content, "CollectionName", 16)
	heading.Text, heading.TextTransparency = Config.collection(figure.collection).name, 0.15
	heading.Size, heading.TextXAlignment = UDim2.new(1, -116, 0, 32), Enum.TextXAlignment.Left
	local skip = button(content, "Skip")
	skip.Size, skip.Position, skip.BackgroundTransparency =
		UDim2.fromOffset(100, 48), UDim2.new(1, -100, 0, 0), 0.92
	skip.TextColor3 = Config.neutral
	local hit = Instance.new("TextButton")
	hit.Name, hit.Size, hit.Position, hit.Text =
		"TapBox", UDim2.fromScale(1, 0.64), UDim2.fromScale(0, 0.12), ""
	hit.BackgroundTransparency, hit.Selectable, hit.ZIndex, hit.Parent = 1, false, 6, content
	local info = Instance.new("CanvasGroup")
	info.Name, info.BackgroundTransparency, info.Parent = "Result", 1, content
	local badge = label(info, "NewBadge", 13)
	badge.Size, badge.Position, badge.AnchorPoint =
		UDim2.fromOffset(72, 25), UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0)
	badge.Text, badge.Font, badge.TextColor3 = "NEW", Theme.heading, profile.accent
	local name = label(info, "FigureName", 30)
	name.Font, name.Position, name.Size =
		Theme.heading, UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 38)
	local detail = label(info, "RarityAndQuantity", 15)
	detail.Position, detail.Size, detail.TextColor3 =
		UDim2.fromOffset(0, 68), UDim2.new(1, 0, 0, 42), profile.tint
	local primary = button(content, "OpenOrContinue")
	local hint = label(content, "InputHint", 12)
	hint.TextTransparency, hint.Size = 0.25, UDim2.new(1, 0, 0, 18)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	local curtain = Instance.new("Frame")
	curtain.Name, curtain.BackgroundColor3, curtain.BorderSizePixel =
		"Transition", Color3.fromRGB(15, 18, 24), 0
	-- Extend beyond the safe-area GUI to cover the camera at every screen edge.
	curtain.Position, curtain.Size = UDim2.fromOffset(-100, -100), UDim2.new(1, 200, 1, 200)
	curtain.ZIndex, curtain.Active, curtain.Parent = 30, false, root
	local buttonLimit = Instance.new("UISizeConstraint")
	buttonLimit.MaxSize, buttonLimit.Parent = Vector2.new(400, 54), primary
	local function layout()
		local compact = content.AbsoluteSize.Y < 468
			and content.AbsoluteSize.X > content.AbsoluteSize.Y
		local center = if compact then 0.77 else 0.5
		primary.AnchorPoint, primary.Position = Vector2.new(0.5, 1), UDim2.new(center, 0, 1, -24)
		primary.Size = if compact then UDim2.new(0.4, 0, 0, 50) else UDim2.new(0.72, 0, 0, 54)

		info.AnchorPoint = Vector2.new(0.5, 1)
		info.Size = UDim2.new(if compact then 0.42 else 0.95, 0, 0, 116)
		info.Position = UDim2.new(center, 0, 1, -90)
		hint.Position = UDim2.fromScale(center, 1)
		hint.Size = UDim2.fromScale(if compact then 0.45 else 1, 0.05)
	end
	layout()
	local resized = content:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	scope.add(function()
		resized:Disconnect()
	end)
	return {
		primary = primary,
		hitTarget = hit,
		skip = skip,
		draw = function(state, gamepad)
			local phase, p = state.phase, State.progress(state)
			local final = phase == "Reveal" or phase == "Result" or phase == "Closing"
			local ready = phase == "Result" and state.elapsed >= State.resultGuard
			info.Visible, shade.Visible = final, final or phase == "Await"
			info.GroupTransparency = if phase == "Reveal"
				then 1 - math.clamp((p - 0.35) / 0.65, 0, 1)
				else 0
			badge.Visible, name.Text = final and result.isNew, if final then figure.name else ""
			detail.Text = if final
				then figure.rarity .. (if result.isNew
					then ""
					else "  ·  " .. tostring(result.quantity) .. " owned")
				else ""
			primary.Visible, primary.Selectable, primary.Active =
				phase == "Await" or phase == "Result",
				phase == "Await" or ready,
				phase == "Await" or ready
			hit.Visible, skip.Visible = phase == "Await", State.canSkip(state)
			skip.Selectable = skip.Visible
			primary.Text = if phase == "Result"
				then (if gamepad then "A  ·  Continue" else "Continue")
				else (if gamepad then "A  ·  Open" else "Tap to Open")
			skip.Text = if gamepad then "B  ·  Skip" else "Skip"
			hint.Text = if phase == "Await"
				then (if gamepad
					then "A to open  ·  B to skip"
					else "Tap the box or press Enter / Space")
				else ""
			heading.Visible = not final and phase ~= "Enter"
			curtain.BackgroundTransparency = if phase == "Enter" or phase == "Closing"
				then math.abs(p * 2 - 1)
				else 1
			gui:SetAttribute("Phase", phase)
		end,
	}
end
return View

--!strict
-- Opening overlay: Tap to Open, Skip, input hint and the transition curtain stay as they were;
-- the end result panel is the Reveal card (RevealCard).
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Style = require(script.Parent.UIStyle)
local UIScope = require(script.Parent.UIScope)
local Config = require(script.Parent.OpeningConfig)
local State = require(script.Parent.OpeningState)
local Result = require(script.Parent.OpeningResult)
local Scope = require(script.Parent.OpeningScope)
local Projection = require(script.Parent.UIState)
local RevealCard = require(script.Parent.RevealCard)
local View = {}
export type View = {
	draw: (State.State, boolean) -> (),
	primary: TextButton,
	hitTarget: TextButton,
	-- Full-screen input catcher under every control ("click anywhere" in an Open 10).
	shield: TextButton,
	skip: TextButton,
	-- Reveal choices (display / another / keep); the controller owns their input.
	choices: { [string]: TextButton },
	firstChoice: () -> TextButton,
	refresh: (Projection.Reveal?) -> (),
}
local function label(parent: Instance, name: string, size: number): TextLabel
	local object = Instance.new("TextLabel")
	object.Name, object.BackgroundTransparency, object.Text = name, 1, ""
	object.FontFace, object.TextColor3, object.TextScaled, object.TextWrapped =
		Style.body(), Config.neutral, true, true
	object.ZIndex, object.Parent = 5, parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = 10, size, object
	return object
end
local function button(parent: Instance, name: string): TextButton
	local object = Instance.new("TextButton")
	object.Name, object.Text, object.FontFace, object.TextSize = name, "", Style.display(), 17
	object.BackgroundColor3, object.TextColor3 = Config.neutral, Style.ink
	object.ZIndex, object.Parent = 8, parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 18), object
	return object
end
function View.create(
	gui: ScreenGui,
	scope: Scope.Scope,
	result: Result.Result,
	profile: Config.Profile,
	reveal: Projection.Reveal?,
	effects: (() -> boolean)?
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
	shade.BackgroundColor3, shade.BackgroundTransparency = Style.revealGround, 0.05
	shade.Size, shade.Position, shade.Parent =
		UDim2.fromScale(1, 0.55), UDim2.fromScale(0, 0.45), root
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 0.25),
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
	-- The Reveal card's buttons use the shared UI kit, which owns its own connection scope.
	local cardScope = UIScope.create()
	scope.add(cardScope.destroy)
	local card = RevealCard.create(
		content,
		cardScope,
		result.figureId,
		result.isNew,
		result.quantity,
		effects or function()
			return true
		end,
		profile.rarity
	)
	card.set(reveal)
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
	-- Open 10 steps meet in the dark: later steps start dark and every step ends dark
	-- (the next step or the results grid takes over in the same frame).
	local chainedIn = result.sequence == "middle" or result.sequence == "last"
	local chainedOut = result.sequence ~= nil
	local buttonLimit = Instance.new("UISizeConstraint")
	buttonLimit.MaxSize, buttonLimit.Parent = Vector2.new(400, 54), primary
	local function layout()
		local compact = Config.compact(gui.AbsoluteSize)
		-- The bottom scrim was tinting the mobile toy back into a silhouette. Keep the
		-- compact gradient behind the choices only; desktop retains its original wash.
		shade.Position = if compact then UDim2.fromScale(0.48, 0) else UDim2.fromScale(0, 0.45)
		shade.Size = if compact then UDim2.fromScale(0.52, 1) else UDim2.fromScale(1, 0.55)
		gradient.Rotation = if compact then 0 else 90
		local center = if compact then 0.77 else 0.5
		primary.AnchorPoint, primary.Position = Vector2.new(0.5, 1), UDim2.new(center, 0, 1, -24)
		primary.Size = if compact then UDim2.new(0.4, 0, 0, 50) else UDim2.new(0.72, 0, 0, 54)
		hint.Position = UDim2.fromScale(center, 1)
		hint.Size = UDim2.fromScale(if compact then 0.45 else 1, 0.05)
		card.layout(compact)
	end
	layout()
	local resized = content:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	scope.add(function()
		resized:Disconnect()
	end)
	return {
		primary = primary,
		hitTarget = hit,
		shield = blocker,
		skip = skip,
		choices = card.choices,
		firstChoice = card.first,
		refresh = card.set,
		draw = function(state, gamepad)
			local phase, p = state.phase, State.progress(state)
			local final = not state.tease
				and (phase == "Reveal" or phase == "Result" or phase == "Closing")
			local ready = phase == "Result" and state.elapsed >= State.resultGuard
			card.root.Visible, shade.Visible = final, final or phase == "Await"
			card.root.GroupTransparency = if phase == "Reveal"
				then 1 - math.clamp((p - 0.35) / 0.65, 0, 1)
				else 0
			for _, choice in card.choices do
				choice.Active = ready
				choice.Selectable = ready
					and choice.Visible
					and choice:GetAttribute("Enabled") ~= false
			end
			primary.Visible, primary.Selectable, primary.Active =
				phase == "Await", phase == "Await", phase == "Await"
			hit.Visible, skip.Visible = phase == "Await", State.canSkip(state)
			skip.Selectable = skip.Visible
			primary.Text = if gamepad then "A  ·  Open" else "Tap to Open"
			skip.Text = if gamepad then "B  ·  Skip" else "Skip"
			hint.Text = if phase == "Await"
				then (if gamepad
					then "A to open  ·  B to skip"
					else "Tap the box or press Enter / Space")
				elseif phase == "Result" and gamepad then "A to choose  ·  B to keep"
				else ""
			heading.Visible = not final and phase ~= "Enter"
			curtain.BackgroundTransparency = if phase == "Enter" and chainedIn
				then math.clamp(p * 2 - 1, 0, 1)
				elseif phase == "Closing" and chainedOut then math.clamp(1 - p * 2, 0, 1)
				elseif phase == "Enter" or phase == "Closing" then math.abs(p * 2 - 1)
				else 1
			gui:SetAttribute("Phase", phase)
		end,
	}
end
return View

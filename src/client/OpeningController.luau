--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local Config = require(script.Parent.OpeningConfig)
local State = require(script.Parent.OpeningState)
local Result = require(script.Parent.OpeningResult)
local View = require(script.Parent.OpeningView)
local Audio = require(script.Parent.OpeningAudio)
local Scope = require(script.Parent.OpeningScope)
local Cinematic = require(script.Parent.OpeningCinematic)
local AudioSequence = require(script.Parent.OpeningAudioSequence)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Projection = require(script.Parent.UIState)
local Controller = {}
-- Reveal choices: "display" (place/swap), "another" (buy the same box), "keep" (close).
-- Open 10 steps (result.sequence) always report back, including "keep" and "skip" (skip all).
export type Choose = (string, Result.Result) -> ()
export type Controller = {
	present: (Result.Result, boolean, Rarity.Id?, Projection.Reveal?) -> boolean,
	refresh: (Projection.Reveal?) -> (),
	isActive: () -> boolean,
	skip: () -> (),
	cancel: () -> (),
	destroy: () -> (),
}
type Session = {
	state: State.State,
	scope: Scope.Scope,
	render: RBXScriptConnection?,
	interact: ((boolean) -> ())?,
	refresh: ((Projection.Reveal?) -> ())?,
	choice: string?,
}
local actionName, movementName = "BlindboxOpeningInput", "BlindboxOpeningMovement"
local function isGamepad(): boolean
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end
function Controller.create(
	focus: (boolean) -> (),
	report: (string) -> (),
	choose: Choose?
): Controller
	local audioCache = Scope.create()
	Audio.preload(audioCache)
	local active: Session? = nil
	local destroyed = false
	local seen: { [string]: boolean } = {}
	local receipts: { string } = {}
	local function close()
		local session = active
		if not session then
			return
		end
		active = nil
		State.cancel(session.state)
		session.scope.destroy()
	end
	local function fail(reason: unknown)
		close()
		warn("Opening presentation failed: " .. tostring(reason))
		report("Your figure is in your collection. The opening could not be displayed.")
	end
	local characterConnection = Players.LocalPlayer.CharacterRemoving:Connect(close)
	local addedConnection = Players.LocalPlayer.CharacterAdded:Connect(close)
	return {
		isActive = function()
			return active ~= nil
		end,
		cancel = close,
		skip = function()
			if active and active.interact then
				active.interact(true)
			end
		end,
		refresh = function(reveal)
			local session = active
			if session and session.refresh then
				session.refresh(reveal)
			end
		end,
		present = function(result, reduced, presentationRarity, reveal)
			-- A local development preview only. Never accepted through remotes/result metadata.
			if
				presentationRarity ~= nil
				and (not RunService:IsStudio() or not Rarity.isValid(presentationRarity))
			then
				return false
			end
			if destroyed or active or seen[result.requestId] then
				return false
			end
			local figure = Catalog.byId[result.figureId]
			local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if not figure or not playerGui or playerGui:FindFirstChild("BlindboxOpening") then
				return false
			end
			seen[result.requestId] = true
			table.insert(receipts, result.requestId)
			if #receipts > 64 then
				local oldest = table.remove(receipts, 1)
				if oldest then
					seen[oldest] = nil
				end
			end
			local profile, collection =
				Config.profile(presentationRarity or result.tease or figure.rarity),
				Config.collection(figure.collection)
			local scope = Scope.create()
			local session: Session = {
				state = State.create(profile.timing, reduced, result.direct, result.tease ~= nil),
				scope = scope,
				render = nil,
				interact = nil,
				refresh = nil,
				choice = nil,
			}
			active = session
			-- Signals already queued by Roblox can arrive after Disconnect. Never close a successor.
			local function closeSession()
				if active == session then
					close()
				end
			end
			local ok, reason = pcall(function()
				local selection = GuiService.SelectedObject
				scope.add(function()
					GuiService.SelectedObject = if selection and selection.Parent
						then selection
						else nil
				end)
				scope.add(function()
					focus(false)
				end)
				focus(true)
				local gui = Instance.new("ScreenGui")
				gui.Name, gui.ResetOnSpawn, gui.DisplayOrder = "BlindboxOpening", false, 100
				gui.ZIndexBehavior, gui.ScreenInsets =
					Enum.ZIndexBehavior.Sibling, Enum.ScreenInsets.DeviceSafeInsets
				gui.Parent = playerGui
				scope.add(function()
					gui:Destroy()
				end)
				local function connect(signal: RBXScriptSignal, callback: (...unknown) -> ())
					local connection = signal:Connect(function(...)
						if active == session then
							callback(...)
						end
					end)
					scope.add(function()
						connection:Disconnect()
					end)
				end
				connect(gui.Destroying, closeSession)
				connect(gui.AncestryChanged, function()
					if not gui:IsDescendantOf(playerGui) then
						closeSession()
					end
				end)
				connect(gui:GetPropertyChangedSignal("Enabled"), function()
					if not gui.Enabled then
						closeSession()
					end
				end)
				local view = View.create(gui, scope, result, profile, reveal, function()
					return not reduced
				end)
				local choices: { [string]: TextButton } = view.choices or {}
				local function choiceOf(object: Instance?): string?
					for key, choiceButton in choices do
						if choiceButton == object then
							return key
						end
					end
					return nil
				end
				local cinematic =
					Cinematic.create(scope, gui, result, profile, collection, reduced, closeSession)
				local audio = Audio.create(scope)
				local soundtrack = AudioSequence.create(audio, profile, collection, result.isNew)
				scope.add(function()
					if session.render then
						session.render:Disconnect()
						session.render = nil
					end
					ContextActionService:UnbindAction(actionName)
					ContextActionService:UnbindAction(movementName)
				end)
				local teaseIndex = 0
				local selectionPhase: State.Phase? = nil
				local function enterPhase()
					local phase: State.Phase = session.state.phase
					cinematic.enter(phase)
					soundtrack.enter(session.state)
				end
				local function cues()
					local state = session.state
					soundtrack.update(state)
					if state.phase == "RarityTease" then
						local _, index = Config.teaseBeat(profile, State.progress(state))
						for i = teaseIndex + 1, index do
							cinematic.tease(profile.tease[i])
						end
						teaseIndex = index
					end
				end
				local function draw(delta: number)
					if active ~= session then
						return
					end
					cues()
					cinematic.draw(session.state, delta)
					view.draw(session.state, isGamepad())
					if isGamepad() then
						local phase: State.Phase = session.state.phase
						if selectionPhase ~= phase and phase == "Await" then
							GuiService.SelectedObject = view.primary
						end
						selectionPhase = phase
						local current = GuiService.SelectedObject
						local onChoice = choiceOf(current) ~= nil
						if phase == "Result" and view.firstChoice then
							-- Gamepad A presses the selected Reveal choice; start on the best one.
							local first = view.firstChoice()
							if not onChoice or not (current :: GuiObject).Selectable then
								GuiService.SelectedObject = if first.Selectable then first else nil
							end
						elseif
							current ~= view.primary and current ~= view.skip
							or (current == view.primary and not view.primary.Selectable)
							or (current == view.skip and not view.skip.Visible)
						then
							GuiService.SelectedObject = if view.primary.Visible
									and view.primary.Selectable
								then view.primary
								elseif view.skip.Visible then view.skip
								else nil
						end
					end
				end
				local function safely(callback: () -> ())
					if active ~= session then
						return
					end
					local success, problem = pcall(function()
						callback()
						return true
					end)
					if not success and active == session then
						fail(problem)
					end
				end
				local function tick(delta: number)
					if active ~= session then
						return
					end
					safely(function()
						if State.advance(session.state, delta) then
							enterPhase()
						end
						if session.state.phase == "Done" then
							local choice = session.choice
							close()
							if
								choose
								and (choice and choice ~= "keep" or result.sequence ~= nil)
							then
								-- The session is fully closed (focus released) before acting.
								local chosen, problem = pcall(function()
									choose(choice or "keep", result)
								end)
								if not chosen then
									warn("Reveal choice failed: " .. tostring(problem))
								end
							end
							return
						end
						draw(math.min(delta, 0.1))
						if not State.animated(session.state) and session.render then
							session.render:Disconnect()
							session.render = nil
							gui:SetAttribute("RenderConnections", 0)
						end
					end)
				end
				local function wake()
					if State.animated(session.state) and not session.render then
						session.render = RunService.RenderStepped:Connect(tick)
						gui:SetAttribute("RenderConnections", 1)
					end
				end
				local function pick(key: string)
					local state = session.state
					local target = choices[key]
					if
						state.phase ~= "Result"
						or state.elapsed < State.resultGuard
						or (target and target:GetAttribute("Enabled") == false)
					then
						return
					end
					session.choice = key
				end
				local function interact(skip: boolean)
					if active ~= session then
						return
					end
					safely(function()
						if session.state.phase == "Result" then
							-- B/X keep; A/Enter/Space press the selected choice (default Keep).
							pick(
								if skip
									then "keep"
									else choiceOf(GuiService.SelectedObject) or "keep"
							)
							skip = false
						elseif skip and result.sequence then
							session.choice = "skip"
						end
						local changed = if skip and result.sequence
							then State.finish(session.state)
							elseif skip then State.skip(session.state)
							else State.activate(session.state)
						if changed then
							if skip then
								audio.stop()
								cinematic.skip()
							end
							enterPhase()
							draw(0)
							wake()
						end
					end)
				end
				session.interact = interact
				session.refresh = function(next)
					if active == session and view.refresh then
						view.refresh(next)
					end
				end
				local function activated(value: unknown, skip: boolean)
					if
						typeof(value) == "Instance"
						and value:IsA("InputObject")
						and string.find(value.UserInputType.Name, "Gamepad", 1, true) == nil
					then
						interact(skip)
					end
				end
				connect(view.primary.Activated, function(input)
					activated(input, false)
				end)
				connect(view.hitTarget.Activated, function(input)
					activated(input, false)
				end)
				connect(view.shield.Activated, function(input)
					-- Open 10: anywhere outside the Reveal choices moves on to the next figure.
					if result.sequence and session.state.phase == "Result" then
						activated(input, false)
					end
				end)
				connect(view.skip.Activated, function(input)
					activated(input, true)
				end)
				for key, choiceButton in choices do
					connect(choiceButton.Activated, function(input)
						if
							typeof(input) == "Instance"
							and input:IsA("InputObject")
							and string.find(input.UserInputType.Name, "Gamepad", 1, true) == nil
							and active == session
						then
							safely(function()
								pick(key)
								if session.choice == key and State.activate(session.state) then
									enterPhase()
									draw(0)
									wake()
								end
							end)
						end
					end)
				end
				connect(UserInputService.LastInputTypeChanged, function()
					safely(function()
						draw(0)
					end)
				end)
				local camera = workspace.CurrentCamera
				if camera then
					connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
						safely(function()
							draw(0)
						end)
					end)
				end
				ContextActionService:BindActionAtPriority(
					actionName,
					function(_, inputState, input)
						if inputState == Enum.UserInputState.Begin then
							interact(
								input.KeyCode == Enum.KeyCode.ButtonB
									or input.KeyCode == Enum.KeyCode.ButtonX
									or (
										GuiService.SelectedObject == view.skip
										and view.skip.Visible
									)
							)
						end
						return Enum.ContextActionResult.Sink
					end,
					false,
					3100,
					Enum.KeyCode.ButtonA,
					Enum.KeyCode.ButtonB,
					Enum.KeyCode.ButtonX,
					Enum.KeyCode.Return,
					Enum.KeyCode.Space
				)
				ContextActionService:BindActionAtPriority(
					movementName,
					function()
						return Enum.ContextActionResult.Sink
					end,
					false,
					3000,
					Enum.PlayerActions.CharacterForward,
					Enum.PlayerActions.CharacterBackward,
					Enum.PlayerActions.CharacterLeft,
					Enum.PlayerActions.CharacterRight,
					Enum.PlayerActions.CharacterJump
				)
				-- Clear existing thumbstick/keyboard movement immediately; input bindings own future movement.
				Players.LocalPlayer:Move(Vector3.zero, false)
				local character = Players.LocalPlayer.Character
				local humanoid = if character
					then character:FindFirstChildOfClass("Humanoid")
					else nil
				if humanoid then
					connect(humanoid.Died, closeSession)
				end
				enterPhase()
				draw(0)
				wake()
			end)
			if not ok then
				fail(reason)
				return false
			end
			return active == session
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			audioCache.destroy()
			characterConnection:Disconnect()
			addedConnection:Disconnect()
			close()
			table.clear(seen)
			table.clear(receipts)
		end,
	}
end
return Controller

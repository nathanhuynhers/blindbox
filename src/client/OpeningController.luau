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
local Flight = require(script.Parent.OpeningFlight)
local Rarity = require(game:GetService("ReplicatedStorage").Shared.Rarity)
local Controller = {}
export type Controller = {
	present: (Result.Result, boolean, Rarity.Id?) -> boolean,
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
}
local actionName, movementName = "BlindboxOpeningInput", "BlindboxOpeningMovement"
local function isGamepad(): boolean
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end
function Controller.create(focus: (boolean) -> (), report: (string) -> ()): Controller
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
		present = function(result, reduced, presentationRarity)
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
				Config.profile(presentationRarity or figure.rarity),
				Config.collection(figure.collection)
			local scope = Scope.create()
			local session: Session = {
				state = State.create(profile.timing, reduced, result.direct),
				scope = scope,
				render = nil,
				interact = nil,
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
				local view = View.create(gui, scope, result, profile)
				local cinematic =
					Cinematic.create(scope, gui, result, profile, collection, reduced, closeSession)
				local audio = Audio.create(scope)
				scope.add(function()
					if session.render then
						session.render:Disconnect()
						session.render = nil
					end
					ContextActionService:UnbindAction(actionName)
					ContextActionService:UnbindAction(movementName)
				end)
				local revealed, teaseIndex, breakIndex = false, 0, 0
				local diving, shimmer = false, false
				local flightResumed = false
				local spectral = profile.signature.spectralTiming
				local pendingCue: { beat: Config.TeaseBeat, at: number }? = nil
				local selectionPhase: State.Phase? = nil
				local function enterPhase()
					local phase: State.Phase = session.state.phase
					cinematic.enter(phase)
					if phase == "Arrival" then
						audio.play("entrance")
						audio.play(collection.ambience, true)
					elseif phase == "Charge" then
						audio.play("charge", true)
					elseif phase == "Shake" then
						audio.play("shake")
					elseif phase == "Await" or phase == "Result" then
						audio.stop()
					elseif phase == "Break" then
						audio.stop()
						audio.play("click")
					elseif phase == "Flight" then
						audio.play("flight", true)
						audio.play("acceleration")
					elseif phase == "RarityTease" and profile.signature.quietUntil > 0 then
						audio.stop(if spectral then nil else "flight")
					elseif phase == "Impact" then
						audio.stop()
						audio.play(profile.cues.impact)
					elseif phase == "Silhouette" then
						audio.stop()
						audio.play("silhouette")
					elseif phase == "Closing" then
						audio.stop()
						audio.play("close")
					end
					if (phase == "Reveal" or phase == "Result") and not revealed then
						revealed = true
						audio.play(profile.cues.reveal)
						if result.isNew then
							audio.play("discovery")
						end
					end
				end
				local function cues()
					local state = session.state
					if state.phase == "Break" then
						for i, cue in Config.breakCues do
							-- Reduced mode scales the same synchronized crack/lid/launch beats.
							local at = if reduced
								then cue.at * State.duration(state) / profile.timing.opening
								else cue.at
							if i > breakIndex and state.elapsed >= at then
								breakIndex = i
								audio.play(cue.cue)
							end
						end
					elseif state.phase == "RarityTease" then
						local _, index = Config.teaseBeat(profile, State.progress(state))
						for i = teaseIndex + 1, index do
							local beat = profile.tease[i]
							if beat.quiet then
								audio.stop()
							end
							cinematic.tease(beat)
							if spectral and not beat.quiet then
								pendingCue = {
									beat = beat,
									at = beat.at * State.duration(state) + spectral.bloomAt,
								}
							else
								if not beat.quiet then
									audio.play(profile.cues.transformation)
								end
								audio.play(beat.cue)
							end
						end
						teaseIndex = index
						if pendingCue and state.elapsed >= pendingCue.at then
							audio.play(profile.cues.transformation)
							audio.play(pendingCue.beat.cue)
							pendingCue = nil
						end
						if
							profile.signature.quietUntil > 0
							and not flightResumed
							and state.elapsed
								>= profile.flight.transition * profile.signature.quietUntil
						then
							flightResumed = true
							audio.play("flight", true)
						end
						if not diving and Flight.sample(state, profile).dive > 0 then
							diving = true
							audio.play("dive")
						end
					elseif
						state.phase == "Impact"
						and not shimmer
						and state.elapsed >= Config.impactCalmAt(profile)
					then
						shimmer = true
						audio.stop()
						audio.play("postImpactShimmer")
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
						if
							selectionPhase ~= session.state.phase
							and session.state.phase == "Await"
						then
							GuiService.SelectedObject = view.primary
						end
						selectionPhase = session.state.phase
						local current = GuiService.SelectedObject
						if
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
						-- Audio ages by wall-clock delta; animation advances one phase at a time after stalls.
						audio.update(
							delta,
							if session.state.phase == "Charge"
								then State.progress(session.state)
								elseif
									session.state.phase == "Flight"
									or session.state.phase == "RarityTease"
								then Flight.sample(session.state, profile).energy
								else 1
						)
						if State.advance(session.state, delta) then
							enterPhase()
						end
						if session.state.phase == "Done" then
							close()
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
				local function interact(skip: boolean)
					if active ~= session then
						return
					end
					safely(function()
						local changed = if skip
							then State.skip(session.state)
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
				connect(view.skip.Activated, function(input)
					activated(input, true)
				end)
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
			characterConnection:Disconnect()
			addedConnection:Disconnect()
			close()
			table.clear(seen)
			table.clear(receipts)
		end,
	}
end
return Controller

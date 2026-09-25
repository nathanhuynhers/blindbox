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
local Controller = {}
export type Controller = {
	present: (Result.Result, boolean) -> boolean,
	isActive: () -> boolean,
	cancel: () -> (),
	destroy: () -> (),
}
type Session = {
	state: State.State,
	gui: ScreenGui,
	view: View.View?,
	audio: Audio.Audio?,
	connections: { RBXScriptConnection },
	render: RBXScriptConnection?,
	selection: GuiObject?,
}

local actionName = "BlindboxOpeningInput"
local movementName = "BlindboxOpeningMovement"
local function isGamepad(): boolean
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

function Controller.create(focus: (boolean) -> (), report: (string) -> ()): Controller
	local active: Session? = nil
	local destroyed = false
	local lastRequest: string? = nil
	local function close()
		local session = active
		if not session then
			return
		end
		active = nil
		State.cancel(session.state)
		if session.render then
			session.render:Disconnect()
		end
		for _, connection in session.connections do
			connection:Disconnect()
		end
		ContextActionService:UnbindAction(actionName)
		ContextActionService:UnbindAction(movementName)
		if session.view then
			session.view.destroy()
		end
		if session.audio then
			session.audio.destroy()
		end
		session.gui:Destroy()
		focus(false)
		GuiService.SelectedObject = if session.selection and session.selection.Parent
			then session.selection
			else nil
	end
	local function fail(reason: unknown)
		close()
		warn("Opening presentation failed: " .. tostring(reason))
		report("Your figure is in your collection. The opening could not be displayed.")
	end
	local characterConnection = Players.LocalPlayer.CharacterRemoving:Connect(close)
	return {
		isActive = function(): boolean
			return active ~= nil
		end,
		cancel = close,
		present = function(result: Result.Result, reduced: boolean): boolean
			if destroyed or active or lastRequest == result.requestId then
				return false
			end
			local figure = Catalog.byId[result.figureId]
			if not figure then
				return false
			end
			local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if not playerGui then
				return false
			end
			lastRequest = result.requestId
			local profile = Config.profile(figure.rarity)
			local gui = Instance.new("ScreenGui")
			gui.Name = "BlindboxOpening"
			gui.ResetOnSpawn = false
			gui.DisplayOrder = 100
			gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
			gui.Parent = playerGui
			local session: Session = {
				state = State.create(profile.timing, reduced, result.direct),
				gui = gui,
				view = nil,
				audio = nil,
				connections = {},
				render = nil,
				selection = GuiService.SelectedObject,
			}
			active = session
			local ok, reason = pcall(function()
				focus(true)
				local view = View.create(gui, result, profile, reduced)
				session.view = view
				local audio = Audio.create()
				session.audio = audio
				local impacted = false
				local function enterPhase()
					local phase = session.state.phase
					if phase == "Enter" then
						audio.play(Config.sounds.entrance)
					elseif phase == "Shake" then
						audio.play(Config.sounds.shake)
					elseif phase == "Open" then
						audio.play(Config.sounds.open)
					elseif phase == "Silhouette" then
						audio.play(Config.sounds.buildup)
					end
					if (phase == "Reveal" or phase == "Result") and not impacted then
						impacted = true
						audio.play(Config.sounds.impact)
						audio.play(profile.sound)
						if result.isNew then
							audio.play(Config.sounds.discovery)
						end
					end
				end
				local function draw()
					if active ~= session then
						return
					end
					view.draw(session.state, isGamepad())
					if isGamepad() then
						local selected = if view.primary.Visible and view.primary.Selectable
							then view.primary
							elseif view.skip.Visible then view.skip
							else nil
						if GuiService.SelectedObject ~= selected then
							GuiService.SelectedObject = selected
						end
					end
				end
				local function tick(delta: number)
					if active ~= session then
						return
					end
					local success, problem = pcall(function()
						if State.advance(session.state, delta) then
							enterPhase()
						end
						if session.state.phase == "Done" then
							close()
							return true
						end
						draw()
						if not State.animated(session.state) and session.render then
							session.render:Disconnect()
							session.render = nil
						end
						return true
					end)
					if not success then
						fail(problem)
					end
				end
				local function wake()
					if State.animated(session.state) and not session.render then
						session.render = RunService.RenderStepped:Connect(tick)
					end
				end
				local function interact(skip: boolean)
					if active ~= session then
						return
					end
					local changed = if skip
						then State.skip(session.state)
						else State.activate(session.state)
					if changed then
						local success, problem = pcall(function()
							enterPhase()
							draw()
							wake()
						end)
						if not success then
							fail(problem)
						end
					end
				end
				local function activated(input: InputObject, skip: boolean)
					-- Gamepad A is owned by the action binding, not also GuiButton.Activated.
					if string.find(input.UserInputType.Name, "Gamepad", 1, true) == nil then
						interact(skip)
					end
				end
				table.insert(
					session.connections,
					view.primary.Activated:Connect(function(input: InputObject)
						activated(input, false)
					end)
				)
				table.insert(
					session.connections,
					view.hitTarget.Activated:Connect(function(input: InputObject)
						activated(input, false)
					end)
				)
				table.insert(
					session.connections,
					view.skip.Activated:Connect(function(input: InputObject)
						activated(input, true)
					end)
				)
				table.insert(
					session.connections,
					UserInputService.LastInputTypeChanged:Connect(draw)
				)
				table.insert(session.connections, view.resized:Connect(draw))
				table.insert(
					session.connections,
					gui.Destroying:Connect(function()
						if active == session then
							close()
						end
					end)
				)
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
					3000,
					Enum.KeyCode.ButtonA,
					Enum.KeyCode.ButtonB,
					Enum.KeyCode.ButtonX,
					Enum.KeyCode.Return
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
				enterPhase()
				draw()
				wake()
			end)
			if not ok then
				fail(reason)
				return false
			end
			return true
		end,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			characterConnection:Disconnect()
			close()
		end,
	}
end

return Controller

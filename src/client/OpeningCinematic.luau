--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local UserInputService = game:GetService("UserInputService")
local Config = require(script.Parent.OpeningConfig)
local State = require(script.Parent.OpeningState)
local Scope = require(script.Parent.OpeningScope)
local CameraOwner = require(script.Parent.OpeningCamera)
local Box = require(script.Parent.OpeningBox)
local Figure = require(script.Parent.OpeningFigure)
local Effects = require(script.Parent.OpeningEffects)
local Flight = require(script.Parent.OpeningFlight)
local Result = require(script.Parent.OpeningResult)
local Cinematic = {}
export type Cinematic = {
	draw: (State.State, number) -> (),
	enter: (State.Phase) -> (),
	tease: (Config.TeaseBeat) -> (),
	skip: () -> (),
	restore: () -> (),
}
local function smooth(p: number): number
	return p * p * (3 - 2 * p)
end
local function back(p: number): number
	local q = p - 1
	return 1 + 2.70158 * q ^ 3 + 1.70158 * q ^ 2
end
local function solid(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3
): Part
	local object = Instance.new("Part")
	object.Name, object.Size, object.Position, object.Color = name, size, position, color
	object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
	object.Material = Enum.Material.SmoothPlastic
	object.Parent = parent
	return object
end
function Cinematic.create(
	scope: Scope.Scope,
	_gui: ScreenGui,
	result: Result.Result,
	profile: Config.Profile,
	collection: Config.Collection,
	reduced: boolean,
	interrupted: () -> ()
): Cinematic
	local owner = CameraOwner.create(scope, interrupted)
	local camera = owner.camera
	local stage = Instance.new("Model")
	stage.Name = "BlindboxCinematic"
	stage:SetAttribute("RequestId", result.requestId)
	stage.Parent = workspace
	scope.add(function()
		stage:Destroy()
	end)
	local stageDestroyed = stage.Destroying:Connect(scope.guard(interrupted))
	scope.add(function()
		stageDestroyed:Disconnect()
	end)
	local hidden = Instance.new("Folder")
	hidden.Name = "HiddenCinematicAssets"
	-- A PlayerGui descendant is not inert storage for SurfaceGui/BillboardGui content.
	-- Keep unshown assets outside the DataModel, but explicitly owned on every exit.
	scope.add(function()
		hidden:Destroy()
	end)
	local origin, settings = Config.stage.origin, Config.stage
	local spectral = profile.signature.spectralTiming
	solid(
		stage,
		"Floor",
		origin - Vector3.new(0, 0.35, 0),
		Vector3.new(140, 0.5, 140),
		settings.floor
	)
	solid(
		stage,
		"Backdrop",
		origin + Vector3.new(0, 30, 45),
		Vector3.new(140, 90, 2),
		settings.background
	)
	solid(
		stage,
		"LeftWing",
		origin + Vector3.new(-65, 30, 0),
		Vector3.new(2, 90, 100),
		settings.background
	)
	solid(
		stage,
		"RightWing",
		origin + Vector3.new(65, 30, 0),
		Vector3.new(2, 90, 100),
		settings.background
	)
	solid(
		stage,
		"Canopy",
		origin + Vector3.new(0, 65, 0),
		Vector3.new(140, 2, 140),
		settings.background
	)
	local pedestal = solid(
		stage,
		"PorcelainPlinth",
		origin + Vector3.new(0, 0.38, 0),
		Vector3.new(0.65, 5.8, 5.8),
		Color3.fromRGB(170, 165, 152)
	)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.CFrame = CFrame.new(origin + Vector3.new(0, 0.38, 0))
		* CFrame.Angles(0, 0, math.pi / 2)
	local edge = solid(
		stage,
		"PlinthEdge",
		origin + Vector3.new(0, 0.74, 0),
		Vector3.new(0.08, 5.65, 5.65),
		Color3.fromRGB(230, 218, 192)
	)
	edge.Shape = Enum.PartType.Cylinder
	edge.CFrame = CFrame.new(edge.Position) * CFrame.Angles(0, 0, math.pi / 2)
	local studioLights: { PointLight } = {}
	for index, offset in { Vector3.new(-5, 9, -6), Vector3.new(5, 5, -2), Vector3.new(0, 7, 4) } do
		local mount =
			solid(stage, "StudioLight", origin + offset, Vector3.one * 0.1, Config.neutral)
		mount.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = if index == 2 then Color3.fromRGB(202, 217, 226) else Config.neutral
		light.Name = "OpeningStudioLight" .. index
		light.Range, light.Brightness, light.Shadows = Config.lighting.range, 0, index == 1
		light.Parent = mount
		table.insert(studioLights, light)
	end
	local lastPhase: State.Phase? = nil
	local boxScope = Scope.create()
	scope.add(boxScope.destroy)
	local box = if result.direct
		then nil
		else Box.create(hidden, Catalog.byId[result.figureId].collection, boxScope, function()
			return lastPhase == nil or lastPhase == "Enter"
		end)
	local function retireBoxPresentation()
		boxScope.destroy() -- cancels loading/watchers before destroying the complete wrapper
		box = nil
	end
	local figure = Figure.create(hidden, result.figureId)
	figure.appearance(0)
	local effects = Effects.create(
		stage,
		camera,
		scope,
		profile,
		collection,
		reduced,
		UserInputService.TouchEnabled
	)
	local time = 0
	local appearance = -1
	local basePosition = Vector3.new(0.8, 4.5, -settings.cameraDistance)
	local baseTarget = Vector3.new(0, settings.boxY, 0)
	local chargePosition = Vector3.new(0.55, 4.1, -settings.cameraDistance + 0.6)
	local pursuitPosition, pursuitTarget = chargePosition, baseTarget
	local pursuitFov = settings.chargeFov
	local function cameraFrame(
		position: Vector3,
		target: Vector3,
		fov: number,
		impulse: number,
		roll: number
	)
		local viewport = camera.ViewportSize
		local aspect = math.max(0.3, viewport.X / math.max(1, viewport.Y))
		-- Extra distance fits narrow portrait devices without shrinking landscape staging.
		local fit = math.max(1, settings.portraitFit / aspect)
		local adjusted = target + (position - target) * fit
		local cf = CFrame.lookAt(origin + adjusted, origin + target) * CFrame.Angles(0, 0, roll)
		if not reduced and impulse > 0 then
			local amount = profile.cameraShake * impulse
			cf *= CFrame.new(math.sin(time * 47) * amount, math.sin(time * 59) * amount * 0.65, 0) * CFrame.Angles(
				math.sin(time * 41) * amount * 0.12,
				0,
				0
			)
		end
		camera.CFrame, camera.Focus, camera.FieldOfView = cf, CFrame.new(origin + target), fov
	end
	return {
		restore = owner.restore,
		skip = effects.clear,
		tease = function(beat)
			if scope.isAlive() then
				effects.tease(beat)
			end
		end,
		enter = function(phase)
			if not scope.isAlive() or not State.isForward(lastPhase, phase) then
				return
			end
			lastPhase = phase
			local showing = phase == "Silhouette"
				or phase == "Reveal"
				or phase == "Result"
				or phase == "Closing"
			if showing or phase == "RarityTease" or phase == "Impact" or phase == "Done" then
				retireBoxPresentation()
			end
			figure.model.Parent = if showing then stage else hidden
			if box then
				box.model.Parent = if phase == "Enter" then hidden else stage
			end
			stage:SetAttribute("Phase", phase)
			effects.enter(phase)
		end,
		draw = function(state, delta)
			if not scope.isAlive() or state.phase ~= lastPhase then
				return
			end
			local phase: State.Phase = state.phase
			local p = State.progress(state)
			time += delta
			-- The UI is fully dark at this handoff; gameplay camera never teleports visibly.
			if phase == "Enter" and p < 0.5 then
				return
			end
			if phase == "Closing" and p >= 0.5 then
				effects.suspend()
				for _, light in studioLights do
					light.Enabled = false
				end
				owner.restore()
				return
			end
			if not owner.isOwned() then
				owner.take()
			end
			if box and phase == "Enter" then
				box.model.Parent = stage
			end
			local showing = phase == "Silhouette"
				or phase == "Reveal"
				or phase == "Result"
				or phase == "Closing"
			local lighting = Config.lightState(
				if phase == "Enter" then "Arrival" else phase,
				p,
				state.elapsed,
				profile
			)
			for index, light in studioLights do
				light.Enabled = true
				light.Brightness = lighting.studio * (if index == 1 then 3 / 5.8 else 1.4 / 5.8)
			end
			local float = if reduced then 0 else math.sin(time * 1.65) * 0.055
			local rise = if phase == "Enter" and not reduced
				then 1
				elseif phase == "Arrival" and not reduced then 1 - back(p)
				else 0
			local shake = if phase == "Shake" and not reduced then profile.shake * p * p else 0
			local rotation = if reduced then 0.2 else 0.2 + math.sin(time * 0.7) * 0.035
			local boxAt = CFrame.new(origin + Vector3.new(0, settings.boxY + float - rise * 4, 0))
				* CFrame.Angles(
					-0.045,
					rotation + rise * 0.35,
					math.sin(state.elapsed * profile.shakeFrequency * 2) * shake
				)
			local opening = if phase == "Break"
				then math.clamp((state.elapsed - 0.12) / (State.duration(state) - 0.12), 0, 1)
				elseif phase == "Flight" then 1 + p * 0.35
				else 0
			local compression = if phase == "Break"
				then math.sin(math.clamp(state.elapsed / 0.12, 0, 1) * math.pi) * 0.03
				else 0
			if box and box.model.Parent == stage then
				box.pose(
					boxAt,
					if reduced then opening * 0.25 else opening,
					if reduced then 0 else compression
				)
			end
			local compact = camera.ViewportSize.Y < 500
				and camera.ViewportSize.X > camera.ViewportSize.Y
			local shift = if compact then 2.4 else 0
			local finalTarget = Vector3.new(shift, if compact then 2 else 1.2, 0)
			local settled = phase == "Result" or phase == "Closing"
			local finalPosition = Vector3.new(
				shift + 0.3,
				3.5,
				-settings.resultDistance - (if settled then 0 else settings.revealPush)
			)
			local flight = Flight.sample(state, profile)
			local comet = flight.position
			local position, target, fov, impulse = basePosition, baseTarget, settings.fov, 0
			local roll = 0
			if phase == "Anticipation" then
				position = basePosition:Lerp(chargePosition, p * 0.3)
			elseif phase == "Charge" then
				position = basePosition:Lerp(chargePosition, 0.3 + smooth(p) * 0.7)
				fov = settings.fov + (settings.chargeFov - settings.fov) * smooth(p)
			elseif phase == "Shake" or phase == "Await" then
				position, fov = chargePosition, settings.chargeFov
				impulse = if phase == "Shake" then p * 0.12 else 0
			elseif phase == "Break" then
				local react = smooth(
					math.clamp(
						(state.elapsed - Config.flight.launchAt - Config.flight.acquireDelay)
							/ Config.flight.acquireDuration,
						0,
						1
					)
				)
				position = chargePosition:Lerp(comet + Config.flight.riseOffset, react)
				position =
					Vector3.new(position.X, math.max(chargePosition.Y, position.Y), position.Z)
				target = baseTarget:Lerp(comet + Config.flight.aimOffset, react)
				fov = settings.chargeFov + (Config.flight.fovStart - settings.chargeFov) * react
				impulse = math.sin(flight.launch * math.pi) * 0.5
			elseif phase == "Flight" then
				position = comet
					+ Config.flight.riseOffset:Lerp(Config.flight.holdOffset, smooth(p))
				target = comet + Config.flight.aimOffset
				fov = Config.flight.fovStart
					+ (profile.fovPeak - Config.flight.fovStart) * smooth(p)
				roll = math.sin(p * math.pi) * Config.flight.roll
			elseif phase == "RarityTease" then
				local settle = smooth(
					math.clamp(
						(flight.dive - Config.flight.cameraSettleAt)
							/ (1 - Config.flight.cameraSettleAt),
						0,
						1
					)
				)
				local offset =
					Config.flight.holdOffset:Lerp(Config.flight.diveOffset, smooth(flight.apex))
				local framing = if spectral
					then (profile.signature.cameraPull * flight.suspense - 0.3 * flight.recognition)
						* (1 - flight.apex)
					else profile.signature.cameraPull * flight.pulse
				offset += offset.Unit * framing
				position = (comet + offset):Lerp(finalPosition, settle)
				target = (comet + Config.flight.aimOffset):Lerp(finalTarget, settle)
				fov = (
					profile.fovPeak
					- profile.signature.holdFovDrop * flight.transition * (1 - flight.dive)
					+ Config.flight.fovDiveExtra * flight.dive
				)
						* (1 - settle)
					+ settings.resultFov * settle
				impulse = if spectral then 0 else flight.pulse * 0.25
				roll = -math.sin(flight.apex * math.pi) * Config.flight.roll
			elseif phase == "Impact" then
				position, target, fov = finalPosition, finalTarget, settings.resultFov
				local kick = math.clamp(
					(state.elapsed - Config.flight.impactKickAt) / Config.flight.impactShakeDuration,
					0,
					1
				)
				impulse = if state.elapsed >= Config.flight.impactKickAt
					then (1 - kick) ^ 3 * 1.5
					else 0
				fov -= math.sin(kick * math.pi) * Config.flight.impactFov
				if spectral then
					-- A single axial breath replaces lateral shake and ends before the halo settles.
					local response = math.sin(
						math.clamp(
							(state.elapsed - Config.flight.impactKickAt)
								/ (spectral.calmAt - Config.flight.impactKickAt),
							0,
							1
						) * math.pi
					)
					impulse = 0
					position += Vector3.new(0, 0, response * 0.12)
					fov = settings.resultFov - response * 1.2
				end
			elseif showing then
				target, position = finalTarget, finalPosition
				fov = settings.resultFov
				if phase == "Reveal" and not reduced then
					position += Vector3.new(0, 0, smooth(p) * settings.revealPush)
				end
				local pop = if phase == "Reveal" and not reduced
					then math.sin(p * math.pi) * 0.18
					else 0
				local turn = if reduced then 0 else math.sin(time * 0.34) * 0.14
				local composed = spectral ~= nil and phase == "Silhouette"
				if composed then
					turn, float = 0, 0
				elseif spectral and phase == "Reveal" then
					turn, float = turn * smooth(p), float * smooth(p)
				end
				figure.pose(
					CFrame.new(
						origin
							+ Vector3.new(
								0,
								0.8
									+ pop
									+ float * 0.4
									- (
										if phase == "Silhouette"
												and not reduced
												and not composed
											then (1 - smooth(p)) * 0.18
											else 0
									),
								0
							)
					) * CFrame.Angles(0, turn, 0)
				)
				local amount = if phase == "Silhouette"
					then 0
					elseif phase == "Reveal" then smooth(p)
					else 1
				if amount ~= appearance then
					appearance = amount
					figure.appearance(amount)
				end
			end
			if reduced then
				position, target, fov, impulse =
					Vector3.new(shift + 0.3, 3.8, -12),
					Vector3.new(shift, 1.8, 0),
					settings.reducedFov,
					0
				roll = 0
			elseif
				phase == "Break"
				or phase == "Flight"
				or phase == "RarityTease"
				or phase == "Impact"
			then
				-- Frame-rate-independent pursuit with a slight physical lag; no new render subscription.
				local gain = 1 - math.exp(-Config.flight.pursuitStrength * delta)
				pursuitPosition = pursuitPosition:Lerp(position, gain)
				pursuitTarget = pursuitTarget:Lerp(target, gain)
				pursuitFov += (fov - pursuitFov) * gain
				if spectral and phase == "Impact" then
					local settle = smooth(math.clamp(state.elapsed / spectral.calmAt, 0, 1))
					pursuitPosition = pursuitPosition:Lerp(position, settle)
					pursuitTarget = pursuitTarget:Lerp(target, settle)
					pursuitFov += (fov - pursuitFov) * settle
				end
				position, target, fov = pursuitPosition, pursuitTarget, pursuitFov
			else
				pursuitPosition, pursuitTarget, pursuitFov = position, target, fov
			end
			cameraFrame(position, target, fov, impulse, roll)
			effects.update(state, boxAt, origin + comet, time)
		end,
	}
end
return Cinematic

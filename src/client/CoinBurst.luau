--!strict
-- Client-only collect spectacle: flash, shockwave and sparkles at the figure, then spinning gold
-- coins fountain out and get magnetised into the player. Every part is local and self-destroys.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tweens = game:GetService("TweenService")
local Scope = require(script.Parent.UIScope)
local Burst = {}
local active: { [Scope.Scope]: boolean } = {}

local function owned(): Scope.Scope
	local scope = Scope.create()
	active[scope] = true
	scope.add(function()
		active[scope] = nil
	end)
	return scope
end

local function later(scope: Scope.Scope, seconds: number, callback: () -> ())
	local done = false
	local thread = task.delay(seconds, function()
		done = true
		callback()
	end)
	scope.add(function()
		if not done then
			task.cancel(thread)
		end
	end)
end

local gold = Color3.fromRGB(255, 196, 46)
local hot = Color3.fromRGB(255, 236, 150)
local gravity = Vector3.new(0, -70, 0)
local lifetime = 2.2 -- Hard cap; a coin that never reaches the player still disappears.

local folder: Folder? = nil
local function root(): Folder
	if not folder or not folder.Parent then
		local created = Instance.new("Folder")
		created.Name = "CoinBursts"
		created.Parent = workspace
		folder = created
	end
	return folder :: Folder
end

local function effect(scope: Scope.Scope, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Parent = root()
	scope.add(function()
		part:Destroy()
	end)
	return part
end

local function fade(
	scope: Scope.Scope,
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = Tweens:Create(instance, info, goal)
	scope.add(function()
		tween:Cancel()
	end)
	tween:Play()
end

local function sparkle(scope: Scope.Scope, at: Vector3, count: number, speed: number)
	local anchor = effect(scope, "Sparkle", Vector3.one * 0.2, CFrame.new(at))
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter") -- Default built-in sparkle texture.
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(hot, gold)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = anchor
	emitter:Emit(count)
	later(scope, 1, function()
		anchor:Destroy()
	end)
end

local function impact(scope: Scope.Scope, at: Vector3)
	-- Flat neon ring racing outward across the counter.
	local ring = effect(
		scope,
		"Shockwave",
		Vector3.new(0.1, 1, 1),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = gold
	ring.Transparency = 0.45
	fade(scope, ring, 0.45, { Size = Vector3.new(0.1, 10, 10), Transparency = 1 })
	-- Bright pulse that lights the figure and furniture, readable day or night.
	local flash = effect(scope, "Flash", Vector3.one * 0.2, CFrame.new(at + Vector3.new(0, 2, 0)))
	flash.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = hot
	light.Range = 10
	light.Brightness = 2
	light.Shadows = false
	light.Parent = flash
	fade(scope, light, 0.35, { Brightness = 0 })
	later(scope, 0.6, function()
		ring:Destroy()
		flash:Destroy()
	end)
	sparkle(scope, at + Vector3.new(0, 2.5, 0), 36, 16)
end

type Coin = { part: Part, velocity: Vector3, spin: number, homeAt: number, done: boolean }

local function coin(scope: Scope.Scope, at: Vector3, index: number, count: number): Coin
	local part = effect(scope, "Coin", Vector3.new(0.22, 1.15, 1.15), CFrame.new(at))
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0.25
	part.Color = gold
	-- Glowing comet tail; the coin spins about Y, so local Y stays roughly vertical.
	local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
	top.Position, bottom.Position = Vector3.new(0, 0.35, 0), Vector3.new(0, -0.35, 0)
	top.Parent, bottom.Parent = part, part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = top, bottom
	trail.Color = ColorSequence.new(hot, gold)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Lifetime = 0.22
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = part
	local angle = (index / count) * math.pi * 2 + math.random() * 0.5
	local out = 5 + math.random() * 5
	return {
		part = part,
		velocity = Vector3.new(
			math.cos(angle) * out,
			15 + math.random() * 8,
			math.sin(angle) * out
		),
		spin = (if math.random() < 0.5 then -1 else 1) * (14 + math.random() * 10),
		homeAt = 0.32 + index * 0.035,
		done = false,
	}
end

-- More Coins collected, more coins thrown: log-scaled so huge banks stay bounded.
function Burst.count(amount: number): number
	return math.clamp(math.floor(4 + math.log10(math.max(1, amount)) * 4), 5, 24)
end

-- Flash, shockwave and sparkles without coins: a figure was just put on Display.
function Burst.celebrate(origin: Vector3)
	local scope = owned()
	local ok, problem = pcall(function()
		impact(scope, origin)
		return nil
	end)
	if not ok then
		scope.destroy()
		warn(problem)
		return
	end
	later(scope, 1, scope.destroy)
end

-- landed runs once per coin that reaches the player (the HUD pill kick).
function Burst.play(
	origin: Vector3,
	amount: number,
	landed: () -> (),
	completed: () -> ()
): () -> ()
	local scope = owned()
	local finished = false
	local function complete()
		if finished then
			return
		end
		finished = true
		local ok, problem = pcall(function()
			completed()
			return nil
		end)
		if not ok then
			warn(problem)
		end
	end
	scope.add(complete)
	local ok, problem = pcall(function()
		impact(scope, origin)
		local count = Burst.count(amount)
		local coins: { Coin } = {}
		for index = 1, count do
			coins[index] = coin(scope, origin + Vector3.new(0, 2.5, 0), index, count)
		end
		local started = os.clock()
		local remaining = count
		local connection: RBXScriptConnection
		local function finish(entry: Coin, reached: boolean)
			if entry.done then
				return
			end
			entry.done = true
			remaining -= 1
			if reached then
				sparkle(scope, entry.part.Position, 6, 8)
				landed()
			end
			entry.part:Destroy()
			if remaining == 0 then
				connection:Disconnect()
				complete()
				-- Allow the final sparkle to fade, without keeping a frame listener alive.
				later(scope, 1, scope.destroy)
			end
		end
		connection = RunService.Heartbeat:Connect(function(delta: number)
			local stepped, failure = pcall(function()
				local age = os.clock() - started
				local character = Players.LocalPlayer.Character
				local target = if character
					then character:FindFirstChild("HumanoidRootPart")
					else nil
				local goal = if target and target:IsA("BasePart") then target.Position else nil
				for _, entry in coins do
					if entry.done then
						continue
					end
					local position = entry.part.Position
					if age > lifetime or (age > entry.homeAt and not goal) then
						finish(entry, false)
						continue
					end
					if age < entry.homeAt or not goal then
						entry.velocity += gravity * delta
					else
						-- Magnet: steer harder and faster the longer the coin has been homing.
						local offset = (goal :: Vector3) - position
						if offset.Magnitude < 1.6 then
							finish(entry, true)
							continue
						end
						local pull = math.min(1, (age - entry.homeAt) * 6)
						local speed = 30 + (age - entry.homeAt) * 90
						entry.velocity =
							entry.velocity:Lerp(offset.Unit * speed, math.min(1, pull * delta * 12))
					end
					-- Upright coin (cylinder axis horizontal) spinning about Y with a slight wobble.
					local spin = CFrame.Angles(0, age * entry.spin, math.sin(age * 9) * 0.35)
					entry.part.CFrame = CFrame.new(position + entry.velocity * delta) * spin
				end
			end)
			if not stepped then
				scope.destroy()
				warn(failure)
			end
		end)
		scope.add(function()
			connection:Disconnect()
		end)
	end)
	if not ok then
		scope.destroy()
		warn(problem)
	end
	return scope.destroy
end

function Burst.destroy()
	for scope in table.clone(active) do
		scope.destroy()
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
end
return Burst

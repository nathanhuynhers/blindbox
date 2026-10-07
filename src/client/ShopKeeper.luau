--!strict
-- Presentation only: each plot Shop's Peeka bobs slowly, waves once when the local owner steps
-- into Open Shop range, and dozes at night. Edits are local CFrame/Transparency changes that never
-- replicate. A half-second check finds nearby shopkeepers; the per-frame step is connected only
-- while one is close and Motion is on.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ShopKeeper = {}
ShopKeeper.style = table.freeze({
	check = 0.5,
	nearby = 40,
	waveRange = 12, -- the Open Shop prompt range
	bobHeight = 0.08,
	bobPeriod = 3.2,
	waveTime = 1.8,
	-- Right shoulder of the uploaded model in pivot space at scale 1, measured in Studio (the
	-- pivot is the bounding-box base, not the Blender origin); the stand-in carries its own.
	shoulder = Vector3.new(0.39, 0.88, -0.07),
	-- The arm holds the box forward: the wave lifts it up and rolls it out, then swings.
	raise = 1.35,
	roll = 0.6,
	swing = 0.25,
})
local style = ShopKeeper.style

type Keeper = {
	model: Model,
	rest: CFrame,
	arm: BasePart?,
	armOffset: CFrame,
	shoulder: CFrame,
	-- Open eyes (and their shine) with their replicated transparency, hidden while asleep.
	eyes: { [BasePart]: number },
	near: boolean,
	posed: boolean,
	asleep: boolean,
	waveStart: number?,
}

local function track(model: Model): Keeper
	local rest = model:GetPivot()
	local arm = model:FindFirstChild("PeekaShopkeeper_RightArm", true)
	local shoulder = model:GetAttribute("Shoulder")
	local entry: Keeper = {
		model = model,
		rest = rest,
		arm = if arm and arm:IsA("BasePart") then arm else nil,
		armOffset = CFrame.new(),
		shoulder = CFrame.new(
			if typeof(shoulder) == "Vector3" then shoulder else style.shoulder * model:GetScale()
		),
		eyes = {},
		near = false,
		posed = false,
		asleep = false,
		waveStart = nil,
	}
	if entry.arm then
		entry.armOffset = rest:ToObjectSpace(entry.arm.CFrame)
	end
	for _, part in model:GetDescendants() do
		if
			part:IsA("BasePart")
			and (part.Name == "PeekaShopkeeper_Eyes" or part.Name == "PeekaShopkeeper_EyeShine")
		then
			entry.eyes[part] = part.Transparency
		end
	end
	return entry
end

local function pose(entry: Keeper, at: CFrame, lift: number, swing: number)
	entry.model:PivotTo(at)
	local arm = entry.arm
	if arm then
		arm.CFrame = at
			* entry.shoulder
			* CFrame.Angles(0, 0, -lift * (style.roll + swing))
			* CFrame.Angles(lift * style.raise, 0, 0)
			* entry.shoulder:Inverse()
			* entry.armOffset
	end
end

local function setAsleep(entry: Keeper, asleep: boolean)
	if entry.asleep == asleep then
		return
	end
	entry.asleep = asleep
	for part, transparency in entry.eyes do
		part.Transparency = if asleep then 1 else transparency
	end
end

-- Raise, wave three times, lower: returns the lift (0-1) and the side-to-side swing.
local function wave(progress: number): (number, number)
	local lift = math.min(1, progress * 4, (1 - progress) * 4)
	return lift, style.swing * math.sin(progress * 6 * math.pi)
end

function ShopKeeper.create(motion: () -> boolean): { tick: () -> (), destroy: () -> () }
	local keepers: { [Model]: Keeper } = {}
	local step: RBXScriptConnection? = nil
	local inRange = false
	local alive = true

	local function release(entry: Keeper)
		if entry.model.Parent then
			if entry.posed then
				pose(entry, entry.rest, 0, 0)
			end
			setAsleep(entry, false)
		end
		keepers[entry.model] = nil
	end

	local function frame()
		local now = os.clock()
		local bob = math.sin(now * 2 * math.pi / style.bobPeriod) * style.bobHeight
		for _, entry in keepers do
			if entry.near then
				local lift, swing = 0, 0
				local start = entry.waveStart
				if start then
					local progress = (now - start) / style.waveTime
					if progress >= 1 then
						entry.waveStart = nil
					else
						lift, swing = wave(progress)
					end
				end
				pose(entry, entry.rest * CFrame.new(0, bob, 0), lift, swing)
				entry.posed = true
			end
		end
	end

	local function tick()
		if not alive then
			return
		end
		local player = Players.LocalPlayer
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local position = if root
				and root:IsA("BasePart")
				and humanoid
				and humanoid.Health > 0
			then root.Position
			else nil
		local moving = motion()
		local plots = workspace:FindFirstChild("PlayerPlots")
		local seen: { [Model]: boolean } = {}
		local ownInRange = false
		local animating = false
		for _, plot in if plots then plots:GetChildren() else {} do
			local fixture = plot:FindFirstChild("ShopFixture")
			local model = if fixture then fixture:FindFirstChild("Shopkeeper") else nil
			if not fixture or not model or not model:IsA("Model") then
				continue
			end
			local entry = keepers[model] or track(model)
			keepers[model] = entry
			seen[model] = true
			entry.near = moving
				and position ~= nil
				and (position - entry.rest.Position).Magnitude <= style.nearby
			local target = fixture:FindFirstChild("OpenShop")
			if
				position
				and plot.Name == tostring(player.UserId)
				and plot:GetAttribute("OwnerId") == player.UserId
				and target
				and target:IsA("BasePart")
				and (position - target.Position).Magnitude <= style.waveRange
			then
				ownInRange = true
				if not inRange and entry.near then
					entry.waveStart = os.clock()
				end
			end
			if not entry.near then
				entry.waveStart = nil
				if entry.posed then
					pose(entry, entry.rest, 0, 0)
					entry.posed = false
				end
			end
			-- Peeka dozes after dusk and wakes up for the wave.
			setAsleep(entry, fixture:GetAttribute("Night") == true and entry.waveStart == nil)
			animating = animating or entry.near
		end
		inRange = ownInRange
		for model, entry in keepers do
			if not seen[model] then
				release(entry)
			end
		end
		if animating and not step then
			step = RunService.RenderStepped:Connect(frame)
		elseif not animating and step then
			step:Disconnect()
			step = nil
		end
	end

	task.spawn(function()
		while alive do
			tick()
			task.wait(style.check)
		end
	end)

	return {
		tick = tick,
		destroy = function()
			alive = false
			if step then
				step:Disconnect()
				step = nil
			end
			for _, entry in keepers do
				release(entry)
			end
		end,
	}
end

return ShopKeeper

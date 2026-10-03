--!strict
-- Presentation only. Native ClickDetectors on the server own click/tap collection.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Prompts = game:GetService("ProximityPromptService")
local Scope = require(script.Parent.UIScope)
local UIState = require(script.Parent.UIState)
local Interaction = {}

local function ownPlot(): Instance?
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = if plots then plots:FindFirstChild(tostring(Players.LocalPlayer.UserId)) else nil
	return if plot and plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then plot else nil
end

local function promptTarget(name: string): BasePart?
	local plot = ownPlot()
	if not plot then
		return nil
	end
	local fixtureName, targetName
	if name == "ManageDisplayPrompt" then
		fixtureName, targetName = "DisplayFixture", "ManageDisplay"
	elseif name == "ManageShelvesPrompt" then
		fixtureName, targetName = "CollectionFixture", "ManageShelves"
	else
		return nil
	end
	local fixture = plot:FindFirstChild(fixtureName)
	local target = if fixture then fixture:FindFirstChild(targetName) else nil
	return if target and target:IsA("BasePart") then target else nil
end

function Interaction.create(
	openDisplay: () -> (),
	openShelves: (() -> ())?
): { update: (number?) -> (), destroy: () -> () }
	local scope = Scope.create()
	local function ownConnection(connection: RBXScriptConnection)
		scope.add(function()
			connection:Disconnect()
		end)
	end
	local touch = Input.TouchEnabled and not Input.MouseEnabled
	local total = 0
	local function update(banked: number?)
		total = banked or total
		for _, name in { "ManageDisplayPrompt", "ManageShelvesPrompt" } do
			local target = promptTarget(name)
			local prompt = if target then target:FindFirstChild(name) else nil
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = true -- Recover if the owner/fixture replicated after PromptShown.
			end
		end
		local plot = ownPlot()
		local fixture = if plot then plot:FindFirstChild("DisplayFixture") else nil
		local face = if fixture then fixture:FindFirstChild("CollectSignFace") else nil
		local sign = if face then face:FindFirstChild("CollectSign") else nil
		local label = if sign then sign:FindFirstChild("Instruction") else nil
		if label and label:IsA("TextLabel") then
			-- The owner's Display total shares the plaque instead of adding another sign.
			label.Text = string.format(
				"%s to Collect · %s Coins Ready",
				if touch then "Tap" else "Click",
				UIState.compact(total)
			)
		end
	end
	ownConnection(Input.LastInputTypeChanged:Connect(function(input: Enum.UserInputType)
		if input == Enum.UserInputType.Touch then
			touch = true
		elseif
			input == Enum.UserInputType.Keyboard or string.find(input.Name, "Mouse", 1, true)
		then
			touch = false
		end
		update()
	end))
	ownConnection(Prompts.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "ManageDisplayPrompt" or prompt.Name == "ManageShelvesPrompt" then
			if prompt.Parent ~= promptTarget(prompt.Name) then
				prompt.Enabled = false
			end
		end
	end))
	ownConnection(Prompts.PromptTriggered:Connect(function(prompt: ProximityPrompt, actor: Player)
		if actor ~= Players.LocalPlayer then
			return
		end
		local target = promptTarget(prompt.Name)
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			target
			and prompt.Parent == target
			and prompt.Enabled
			and root
			and root:IsA("BasePart")
			and humanoid
			and humanoid.Health > 0
			and (root.Position - target.Position).Magnitude <= prompt.MaxActivationDistance
		then
			if prompt.Name == "ManageDisplayPrompt" then
				openDisplay()
			elseif openShelves then
				openShelves()
			end
		end
	end))
	update()
	return { update = update, destroy = scope.destroy }
end
return Interaction

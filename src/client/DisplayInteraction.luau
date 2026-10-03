--!strict
-- Presentation only. Native ClickDetectors on the server own click/tap collection.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Prompts = game:GetService("ProximityPromptService")
local Scope = require(script.Parent.UIScope)
local Interaction = {}

local function ownFixture(): Instance?
	local plots = workspace:FindFirstChild("PlayerPlots")
	local plot = if plots then plots:FindFirstChild(tostring(Players.LocalPlayer.UserId)) else nil
	return if plot and plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId
		then plot:FindFirstChild("DisplayFixture")
		else nil
end

function Interaction.create(open: () -> ()): { update: () -> (), destroy: () -> () }
	local scope = Scope.create()
	local function ownConnection(connection: RBXScriptConnection)
		scope.add(function()
			connection:Disconnect()
		end)
	end
	local touch = Input.TouchEnabled and not Input.MouseEnabled
	local function update()
		local fixture = ownFixture()
		local manage = if fixture then fixture:FindFirstChild("ManageDisplay") else nil
		local prompt = if manage then manage:FindFirstChild("ManageDisplayPrompt") else nil
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = true -- Recover if the owner/fixture replicated after PromptShown.
		end
		local face = if fixture then fixture:FindFirstChild("CollectSignFace") else nil
		local sign = if face then face:FindFirstChild("CollectSign") else nil
		local label = if sign then sign:FindFirstChild("Instruction") else nil
		if label and label:IsA("TextLabel") then
			label.Text = if touch
				then "Tap to Collect · Each Figure"
				else "Click to Collect · Each Figure"
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
		if prompt.Name == "ManageDisplayPrompt" then
			local fixture = ownFixture()
			if not fixture or prompt.Parent ~= fixture:FindFirstChild("ManageDisplay") then
				prompt.Enabled = false
			end
		end
	end))
	ownConnection(Prompts.PromptTriggered:Connect(function(prompt: ProximityPrompt, actor: Player)
		if actor ~= Players.LocalPlayer then
			return
		end
		local fixture = ownFixture()
		local target = if fixture then fixture:FindFirstChild("ManageDisplay") else nil
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			target
			and target:IsA("BasePart")
			and prompt.Parent == target
			and prompt.Name == "ManageDisplayPrompt"
			and prompt.Enabled
			and root
			and root:IsA("BasePart")
			and humanoid
			and humanoid.Health > 0
			and (root.Position - target.Position).Magnitude <= prompt.MaxActivationDistance
		then
			open()
		end
	end))
	update()
	return { update = update, destroy = scope.destroy }
end
return Interaction

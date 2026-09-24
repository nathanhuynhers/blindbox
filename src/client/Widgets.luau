--!strict
local Widgets = {}
local ink = Color3.fromRGB(242, 239, 223)
function Widgets.corner(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end
function Widgets.label(parent: Instance, text: string, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.TextColor3 = ink
	label.TextSize = 16
	label.Font = Enum.Font.Gotham
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end
function Widgets.button(parent: Instance, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 46)
	button.BackgroundColor3 = Color3.fromRGB(53, 90, 88)
	button.TextColor3 = ink
	button.TextSize = 15
	button.Font = Enum.Font.GothamMedium
	button.TextWrapped = true
	button.Text = text
	button.Parent = parent
	Widgets.corner(button, 8)
	return button
end
function Widgets.portrait(parent: Instance, model: Model): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 2.4, -6), Vector3.new(0, 1.15, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport
	viewport.Parent = parent
	return viewport
end
return Widgets

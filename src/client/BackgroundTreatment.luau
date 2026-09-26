--!strict
local Lighting = game:GetService("Lighting")
local Scope = require(script.Parent.UIScope)

local BackgroundTreatment = {}
export type Options = { color: Color3, transparency: number, blur: number }
export type Treatment = { overlay: TextButton, set: (Options?) -> () }

-- The overlay sits below the interface. BlurEffect affects only the rendered 3D world.
function BackgroundTreatment.create(parent: Instance, scope: Scope.Scope): Treatment
	local overlay = Instance.new("TextButton")
	overlay.Name = "Backdrop"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Text = ""
	overlay.BorderSizePixel = 0
	overlay.Selectable = false
	overlay.Modal = true
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.Parent = parent

	local blur = Instance.new("BlurEffect")
	blur.Name = "InterfaceBackgroundBlur"
	blur.Enabled = false
	blur.Size = 0
	blur.Parent = Lighting

	local function set(options: Options?)
		overlay.Visible = options ~= nil
		blur.Enabled = options ~= nil and options.blur > 0
		if options then
			overlay.BackgroundColor3 = options.color
			overlay.BackgroundTransparency = options.transparency
			blur.Size = options.blur
		else
			blur.Size = 0
		end
	end

	scope.add(function()
		set(nil)
		blur:Destroy()
	end)
	return { overlay = overlay, set = set }
end

return BackgroundTreatment

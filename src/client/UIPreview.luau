--!strict
local FigureModel = require(game:GetService("ReplicatedStorage").Shared.FigureModel)
local Box = require(script.Parent.OpeningBox)
local Scope = require(script.Parent.UIScope)
local Preview = {}
export type Preview =
	{ frame: ViewportFrame, figure: (string?, boolean) -> (), box: (string) -> () }
-- Asset slot: one model per preview. Snapshot updates reuse it until identity changes.
function Preview.create(parent: Instance, scope: Scope.Scope): Preview
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Portrait"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(216, 215, 224)
	frame.LightColor = Color3.fromRGB(255, 246, 225)
	frame.LightDirection = Vector3.new(-1, -1, -2)
	frame.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = frame
	frame.CurrentCamera = camera
	local model: Model? = nil
	local key = ""
	local visible: boolean? = nil
	local colors: { [BasePart]: Color3 } = {}
	local extent = 1.7
	local function fit()
		local aspect = math.max(0.2, frame.AbsoluteSize.X / math.max(1, frame.AbsoluteSize.Y))
		local distance = extent / (math.tan(math.rad(17.5)) * math.min(1, aspect)) * 1.3
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.35, -distance), Vector3.zero)
	end
	local function replace(nextModel: Model?)
		if model then
			model:Destroy()
		end
		model = nextModel
		table.clear(colors)
		visible = nil
		if nextModel then
			local bounds, size = nextModel:GetBoundingBox()
			nextModel:PivotTo(CFrame.new(-bounds.Position) * nextModel:GetPivot())
			extent = math.max(size.X, size.Y, size.Z) * 0.5
			nextModel.Parent = frame
			for _, part in nextModel:GetDescendants() do
				if part:IsA("BasePart") then
					colors[part] = part.Color
				end
			end
		end
		fit()
	end
	scope.connect(frame:GetPropertyChangedSignal("AbsoluteSize"), fit)
	return {
		frame = frame,
		figure = function(id: string?, discovered: boolean)
			local nextKey = id or ""
			if nextKey ~= key then
				key = nextKey
				replace(if id and id ~= "" then FigureModel.create(id, CFrame.new()) else nil)
			end
			if visible ~= discovered then
				visible = discovered
				for part, color in colors do
					part.Color = if discovered then color else Color3.fromRGB(120, 114, 130)
				end
			end
		end,
		box = function(collection: string)
			if key == "box:" .. collection then
				return
			end
			key = "box:" .. collection
			local asset = Box.create(frame, collection)
			asset.pose(CFrame.Angles(-0.06, 0.24, 0), 0)
			replace(asset.model)
		end,
	}
end
return Preview

--!strict
-- Minimal instance/property-signal shim for exercising the actual CollectionAssets mount.
local Engine = {}
type Signal = {
	Connect: (Signal, (...unknown) -> ()) -> { Disconnect: () -> () },
	fire: () -> (),
}
type Node = {
	Name: string,
	Image: string,
	IsLoaded: boolean,
	Visible: boolean,
	BackgroundTransparency: number,
	Size: { number },
	Parent: Node?,
	ScaleType: string,
	SliceCenter: { number }?,
	GetPropertyChangedSignal: (Node, string) -> Signal,
}
Engine.nodes = {} :: { Node }
local function create(): Node
	local signals: { [string]: Signal } = {}
	local node: Node = {
		Name = "",
		Image = "",
		IsLoaded = false,
		Visible = true,
		BackgroundTransparency = 0,
		Size = {},
		ScaleType = "Stretch",
		GetPropertyChangedSignal = function(_self, property)
			if not signals[property] then
				local callbacks: { [number]: (...unknown) -> () } = {}
				local count = 0
				signals[property] = {
					Connect = function(_signal, callback)
						count += 1
						local index = count
						callbacks[index] = callback
						return {
							Disconnect = function()
								callbacks[index] = nil
							end,
						}
					end,
					fire = function()
						for _, callback in callbacks do
							callback()
						end
					end,
				}
			end
			return signals[property]
		end,
	}
	table.insert(Engine.nodes, node)
	return node
end
Engine.Instance = {
	new = function(_class: string): Node
		return create()
	end,
}
Engine.Widgets = {
	frame = function(parent: Node, name: string): Node
		local node = create()
		node.Parent, node.Name = parent, name
		return node
	end,
}
Engine.UDim2 = {
	fromScale = function(x: number, y: number)
		return { x, y }
	end,
}
Engine.Rect = {
	new = function(a: number, b: number, c: number, d: number)
		return { a, b, c, d }
	end,
}
Engine.Enum = { ScaleType = { Fit = "Fit", Stretch = "Stretch", Slice = "Slice" } }
return Engine

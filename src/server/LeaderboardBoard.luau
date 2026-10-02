--!strict
-- Physical two-sided leaderboard: native parts plus identical SurfaceGuis on both faces.
-- Presentation only; the Leaderboard service decides what to show.
local TownProps = require(script.Parent.TownProps)
local Style = require(script.Parent.TownStyle)

local colors, materials = Style.colors, Style.materials
local Board = {}
Board.style = table.freeze({
	postX = 8.3,
	post = 1.2,
	height = 18.5,
	panel = Vector3.new(15.5, 10.5, 0.8),
	panelBottom = 3.5,
	rows = 5,
	pages = 3,
	text = Color3.fromRGB(246, 239, 217),
	row = Color3.fromRGB(59, 91, 77),
	firstRow = Color3.fromRGB(110, 120, 82),
	dotOff = Color3.fromRGB(104, 128, 117),
})
local style = Board.style

export type Row = { frame: Frame, rank: TextLabel, name: TextLabel, value: TextLabel }
export type Face = { title: TextLabel, status: TextLabel, rows: { Row }, dots: { Frame } }
export type Board = { model: Model, panel: Part, header: Part, faces: { Face } }
export type Line = { name: string, value: string }

local function label(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	color: Color3
): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = color
	text.TextScaled = true
	text.Text = ""
	text.Parent = parent
	return text
end

local function corner(parent: Instance, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = parent
end

local function surface(part: Part, name: string, face: Enum.NormalId, canvas: Vector2): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvas
	gui.AlwaysOnTop = false
	-- Self-lit so the board stays readable at night.
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

local function buildFace(panel: Part, face: Enum.NormalId, side: string): Face
	local gui = surface(panel, "Board" .. side, face, Vector2.new(760, 525))
	local title =
		label(gui, "Title", UDim2.fromScale(0.05, 0.035), UDim2.fromScale(0.9, 0.13), colors.gold)
	local rows: { Row } = {}
	for index = 1, style.rows do
		local frame = Instance.new("Frame")
		frame.Name = "Row_" .. index
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = if index == 1 then style.firstRow else style.row
		frame.Position = UDim2.fromScale(0.05, 0.2 + (index - 1) * 0.128)
		frame.Size = UDim2.fromScale(0.9, 0.112)
		frame.Parent = gui
		corner(frame, 14)
		table.insert(rows, {
			frame = frame,
			rank = label(
				frame,
				"Rank",
				UDim2.fromScale(0.02, 0.12),
				UDim2.fromScale(0.09, 0.76),
				colors.gold
			),
			name = label(
				frame,
				"PlayerName",
				UDim2.fromScale(0.13, 0.15),
				UDim2.fromScale(0.55, 0.7),
				style.text
			),
			value = label(
				frame,
				"Value",
				UDim2.fromScale(0.7, 0.15),
				UDim2.fromScale(0.27, 0.7),
				style.text
			),
		})
		rows[index].rank.Text = tostring(index)
		rows[index].name.TextXAlignment = Enum.TextXAlignment.Left
		rows[index].value.TextXAlignment = Enum.TextXAlignment.Right
	end
	local status =
		label(gui, "Status", UDim2.fromScale(0.1, 0.845), UDim2.fromScale(0.8, 0.055), style.dotOff)
	local dots: { Frame } = {}
	for index = 1, style.pages do
		local dot = Instance.new("Frame")
		dot.Name = "PageDot_" .. index
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = style.dotOff
		dot.Size = UDim2.fromOffset(22, 22)
		dot.Position = UDim2.new(0.5, (index - (style.pages + 1) / 2) * 40 - 11, 0.925, 0)
		dot.Parent = gui
		corner(dot, 11)
		table.insert(dots, dot)
	end
	return { title = title, status = status, rows = rows, dots = dots }
end

-- `at` is the ground-level center; its -Z (Front face) looks toward the plaza center.
function Board.create(parent: Instance, at: CFrame): Board
	local model = Instance.new("Model")
	model.Name = "Leaderboard"
	for _, side in { -1, 1 } do
		local x = side * style.postX
		TownProps.part(
			model,
			"Footing",
			Vector3.new(1.8, 0.5, 1.8),
			at * CFrame.new(x, 0.25, 0),
			colors.stone,
			materials.stone
		)
		TownProps.part(
			model,
			"Post",
			Vector3.new(style.post, style.height - 0.5, style.post),
			at * CFrame.new(x, (style.height - 0.5) / 2, 0),
			colors.iron,
			materials.metal
		)
	end
	local panel = TownProps.part(
		model,
		"Panel",
		style.panel,
		at * CFrame.new(0, style.panelBottom + style.panel.Y / 2, 0),
		colors.board,
		materials.plastic
	)
	local header = TownProps.part(
		model,
		"Header",
		Vector3.new(16.6, 2.6, 1.2),
		at * CFrame.new(0, 15.5, 0),
		colors.gold,
		materials.plastic
	)
	TownProps.part(
		model,
		"Cap",
		Vector3.new(2 * style.postX + style.post + 0.8, 0.5, 2.2),
		at * CFrame.new(0, style.height - 0.25, 0),
		colors.iron,
		materials.metal
	)
	local faces: { Face } = {}
	local sides: { { name: string, face: Enum.NormalId } } = {
		{ name = "Front", face = Enum.NormalId.Front },
		{ name = "Back", face = Enum.NormalId.Back },
	}
	for _, entry in sides do
		local side, face = entry.name, entry.face
		table.insert(faces, buildFace(panel, face, side))
		local gui = surface(header, "Header" .. side, face, Vector2.new(830, 130))
		label(
			gui,
			"Title",
			UDim2.fromScale(0.04, 0.12),
			UDim2.fromScale(0.92, 0.76),
			colors.charcoal
		).Text =
			"TOWN LEADERBOARD"
	end
	model.Parent = parent
	return { model = model, panel = panel, header = header, faces = faces }
end

local function set(text: TextLabel, value: string)
	if text.Text ~= value then
		text.Text = value
	end
end

-- Writes only changed properties, so cycling pages replicates a handful of strings.
function Board.show(board: Board, page: number, title: string, lines: { Line }, status: string)
	for _, face in board.faces do
		-- Dots, rows, status, then title: every changed property is written in one non-yielding pass.
		for index, dot in face.dots do
			local color = if index == page then colors.gold else style.dotOff
			if dot.BackgroundColor3 ~= color then
				dot.BackgroundColor3 = color
			end
		end
		for index, row in face.rows do
			local line = lines[index]
			set(row.name, if line then line.name else "—")
			set(row.value, if line then line.value else "")
		end
		set(face.status, status)
		set(face.title, title)
	end
end

return Board

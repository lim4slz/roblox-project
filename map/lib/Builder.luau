--!nonstrict
-- Small helpers for building the map with Lune's Roblox library. Every map
-- object is a plain primitive (block, ball, cylinder, truss) to keep the
-- blocky LEGO look and stay cheap to render on phones.

local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local Builder = {}

Builder.Vector3 = Vector3
Builder.CFrame = CFrame
Builder.Color3 = Color3
Builder.Enum = Enum
Builder.Instance = Instance
Builder.roblox = roblox

-- Deterministic random numbers so every build produces the same map.
local seed = 1337
function Builder.random(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

function Builder.randomRange(low: number, high: number): number
	return low + (high - low) * Builder.random()
end

function Builder.rgb(r: number, g: number, b: number)
	return Color3.fromRGB(r, g, b)
end

-- Slightly varies a colour so walls look like real stacked bricks rather
-- than one flat slab.
function Builder.vary(color, amount: number)
	local shift = (Builder.random() * 2 - 1) * amount
	local function channel(value: number): number
		return math.clamp(value + shift, 0, 1)
	end
	return Color3.new(channel(color.R), channel(color.G), channel(color.B))
end

function Builder.folder(name: string, parent)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Builder.model(name: string, parent)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

type PartOptions = {
	name: string?,
	size: any,
	cframe: any?,
	position: any?,
	color: any?,
	material: any?,
	transparency: number?,
	canCollide: boolean?,
	canQuery: boolean?,
	canTouch: boolean?,
	castShadow: boolean?,
	studs: boolean?, -- studs on top, inlets underneath (default true)
	shape: any?,
	className: string?,
	parent: any?,
}

function Builder.part(options: PartOptions)
	local part = Instance.new(options.className or "Part")
	part.Name = options.name or "Part"
	part.Size = options.size
	if options.cframe then
		part.CFrame = options.cframe
	elseif options.position then
		part.CFrame = CFrame.new(options.position)
	end
	part.Color = options.color or Color3.fromRGB(200, 200, 200)
	part.Material = options.material or Enum.Material.Plastic
	part.Transparency = options.transparency or 0
	part.Anchored = true
	part.CanCollide = if options.canCollide == nil then true else options.canCollide
	if options.canQuery ~= nil then
		part.CanQuery = options.canQuery
	end
	if options.canTouch ~= nil then
		part.CanTouch = options.canTouch
	end
	if options.castShadow ~= nil then
		part.CastShadow = options.castShadow
	end
	if options.shape and options.className == nil then
		part.Shape = options.shape
	end
	local studs = options.studs ~= false and options.shape == nil and options.material == nil
	part.TopSurface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	part.BottomSurface = if studs then Enum.SurfaceType.Inlet else Enum.SurfaceType.Smooth
	part.Parent = options.parent
	return part
end

-- Box defined by its bottom-centre point, which is how level design thinks.
function Builder.block(name: string, size, bottomCenter, color, parent, extra: PartOptions?)
	local options: PartOptions = extra or ({} :: any)
	options.name = name
	options.size = size
	options.position = bottomCenter + Vector3.new(0, size.Y / 2, 0)
	options.color = color
	options.parent = parent
	return Builder.part(options)
end

-- Vertical cylinder (Roblox cylinders run along X, so we rotate them).
function Builder.pillar(name: string, diameter: number, height: number, bottomCenter, color, parent, material)
	return Builder.part({
		name = name,
		size = Vector3.new(height, diameter, diameter),
		cframe = CFrame.new(bottomCenter + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		shape = Enum.PartType.Cylinder,
		material = material or Enum.Material.SmoothPlastic,
		parent = parent,
	})
end

-- Flat disc lying on the ground (used for pads and rings).
function Builder.disc(name: string, diameter: number, thickness: number, center, color, parent, material)
	return Builder.part({
		name = name,
		size = Vector3.new(thickness, diameter, diameter),
		cframe = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		shape = Enum.PartType.Cylinder,
		material = material or Enum.Material.SmoothPlastic,
		parent = parent,
	})
end

-- A SurfaceGui sign with one line (or a few) of big friendly text.
function Builder.sign(name: string, size, cframe, text: string, textColor, backColor, parent)
	local board = Builder.part({
		name = name,
		size = size,
		cframe = cframe,
		color = backColor,
		material = Enum.Material.SmoothPlastic,
		parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = roblox.UDim2.new(0.92, 0, 0.84, 0)
	label.Position = roblox.UDim2.new(0.04, 0, 0.08, 0)
	label.BackgroundTransparency = 1
	label.FontFace = roblox.Font.fromEnum(Enum.Font.FredokaOne)
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	return board
end

-- Blocky tree: trunk plus two stacked leaf cubes.
function Builder.tree(name: string, base, scale: number, parent)
	local model = Builder.model(name, parent)
	local trunkHeight = 7 * scale
	Builder.block(
		"Trunk",
		Vector3.new(2, trunkHeight, 2) * scale,
		base,
		Builder.vary(Builder.rgb(133, 94, 66), 0.04),
		model
	)
	local leafColor = Builder.vary(Builder.rgb(74, 170, 74), 0.06)
	Builder.block("Leaves", Vector3.new(9, 6, 9) * scale, base + Vector3.new(0, trunkHeight - 1, 0), leafColor, model)
	Builder.block(
		"LeavesTop",
		Vector3.new(6, 4, 6) * scale,
		base + Vector3.new(0, trunkHeight + 5 * scale - 1, 0),
		Builder.vary(Builder.rgb(110, 200, 100), 0.05),
		model
	)
	return model
end

-- Floating blocky cloud; purely decorative so it ignores physics entirely.
function Builder.cloud(name: string, center, scale: number, parent)
	local model = Builder.model(name, parent)
	local pieces = {
		{ Vector3.new(16, 6, 10), Vector3.new(0, 0, 0) },
		{ Vector3.new(10, 6, 8), Vector3.new(9, 2, 1) },
		{ Vector3.new(10, 7, 9), Vector3.new(-8, 2, -1) },
		{ Vector3.new(8, 5, 7), Vector3.new(2, 5, 0) },
	}
	for index, piece in pieces do
		Builder.part({
			name = "Puff" .. index,
			size = piece[1] * scale,
			position = center + piece[2] * scale,
			color = Builder.rgb(255, 255, 255),
			material = Enum.Material.SmoothPlastic,
			transparency = 0.05,
			canCollide = false,
			canQuery = false,
			canTouch = false,
			castShadow = false,
			parent = model,
		})
	end
	return model
end

return Builder

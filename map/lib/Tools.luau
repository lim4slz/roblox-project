--!nonstrict
-- Tool models (stored in ServerStorage.Tools and handed out by the server).
-- Each is a few primitives welded to a Handle. With the default Grip the
-- handle sits in the palm and its -Z axis points forward, so blades and
-- barrels are built along -Z.

local Builder = require("./Builder")

local Vector3 = Builder.Vector3
local CFrame = Builder.CFrame
local Enum = Builder.Enum
local Instance = Builder.Instance
local rgb = Builder.rgb

local Tools = {}

local function newTool(name: string, tip: string, parent)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new()
	tool.Parent = parent
	return tool
end

-- Tool parts never collide (no tripping over your own sword) and weigh
-- nothing, so they don't affect movement.
local function toolPart(options)
	options.canCollide = false
	options.studs = false
	options.material = options.material or Enum.Material.SmoothPlastic
	local part = Builder.part(options)
	part.Anchored = false
	part.Massless = true
	return part
end

local function weldTo(handle, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end

local function buildBomb(parent)
	local tool = newTool("Bomb", "Hold to charge, release to throw", parent)
	local handle = toolPart({
		name = "Handle",
		size = Vector3.new(1.6, 1.6, 1.6),
		cframe = CFrame.new(),
		color = rgb(31, 31, 38),
		shape = Enum.PartType.Ball,
		parent = tool,
	})
	local band = toolPart({
		name = "Band",
		size = Vector3.new(0.5, 1.66, 1.66),
		cframe = CFrame.new(),
		color = rgb(250, 204, 21),
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Neon,
		parent = tool,
	})
	weldTo(handle, band)
	local fuse = toolPart({
		name = "Fuse",
		size = Vector3.new(0.3, 0.55, 0.3),
		cframe = CFrame.new(0, 0.95, 0),
		color = rgb(120, 85, 50),
		material = Enum.Material.Wood,
		parent = tool,
	})
	weldTo(handle, fuse)
	local spark = toolPart({
		name = "Spark",
		size = Vector3.new(0.35, 0.35, 0.35),
		cframe = CFrame.new(0, 1.3, 0),
		color = rgb(255, 220, 90),
		shape = Enum.PartType.Ball,
		material = Enum.Material.Neon,
		parent = tool,
	})
	weldTo(handle, spark)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 170, 80)
	light.Range = 6
	light.Brightness = 1.2
	light.Parent = spark
	return tool
end

local function buildSword(parent)
	local tool = newTool("Sword", "Click to slash, double-click to lunge", parent)
	local handle = toolPart({
		name = "Handle",
		size = Vector3.new(0.4, 0.4, 1.4),
		cframe = CFrame.new(),
		color = rgb(120, 80, 45),
		material = Enum.Material.Wood,
		parent = tool,
	})
	local pommel = toolPart({
		name = "Pommel",
		size = Vector3.new(0.6, 0.6, 0.6),
		cframe = CFrame.new(0, 0, 0.9),
		color = rgb(250, 204, 21),
		shape = Enum.PartType.Ball,
		parent = tool,
	})
	weldTo(handle, pommel)
	local guard = toolPart({
		name = "Guard",
		size = Vector3.new(0.4, 1.8, 0.4),
		cframe = CFrame.new(0, 0, -0.85),
		color = rgb(250, 204, 21),
		parent = tool,
	})
	weldTo(handle, guard)
	local blade = toolPart({
		name = "Blade",
		size = Vector3.new(0.25, 0.75, 4),
		cframe = CFrame.new(0, 0, -3.05),
		color = rgb(203, 213, 225),
		material = Enum.Material.Metal,
		parent = tool,
	})
	weldTo(handle, blade)
	local edge = toolPart({
		name = "Edge",
		size = Vector3.new(0.3, 0.2, 4),
		cframe = CFrame.new(0, 0.3, -3.05),
		color = rgb(241, 245, 249),
		material = Enum.Material.Neon,
		parent = tool,
	})
	edge.Transparency = 0.3
	weldTo(handle, edge)
	return tool
end

local function buildRocketLauncher(parent)
	local tool = newTool("RocketLauncher", "Click to fire a rocket", parent)
	tool.Grip = CFrame.new(0, -0.4, 0.4)
	local handle = toolPart({
		name = "Handle",
		size = Vector3.new(0.5, 1.2, 0.6),
		cframe = CFrame.new(),
		color = rgb(51, 65, 85),
		parent = tool,
	})
	local tube = toolPart({
		name = "Tube",
		size = Vector3.new(5, 1.1, 1.1),
		cframe = CFrame.new(0, 0.8, -1.2) * CFrame.Angles(0, math.rad(90), 0),
		color = rgb(74, 222, 128),
		shape = Enum.PartType.Cylinder,
		parent = tool,
	})
	weldTo(handle, tube)
	local muzzle = toolPart({
		name = "Muzzle",
		size = Vector3.new(0.4, 1.3, 1.3),
		cframe = CFrame.new(0, 0.8, -3.7) * CFrame.Angles(0, math.rad(90), 0),
		color = rgb(250, 204, 21),
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Neon,
		parent = tool,
	})
	weldTo(handle, muzzle)
	return tool
end

function Tools.build()
	local folder = Builder.folder("Tools", nil)
	buildBomb(folder)
	buildSword(folder)
	buildRocketLauncher(folder)
	return folder
end

return Tools

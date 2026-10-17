--!nonstrict
-- The lobby: a floating blocky island off to the side of the arena (you can
-- see the towers from it). It has a spawn pad, a giant status board, a
-- breakable practice wall with training dummies, and a rainbow parkour
-- spiral up to the "Sky Peak".

local Builder = require("./Builder")
local Bricks = require("./Bricks")

local Vector3 = Builder.Vector3
local CFrame = Builder.CFrame
local Enum = Builder.Enum
local Instance = Builder.Instance
local rgb = Builder.rgb

local Lobby = {}

local CENTER = Vector3.new(0, 220, -460)
local ISLAND_SIZE = 120

local GRASS = rgb(120, 205, 100)
local WOOD = rgb(133, 94, 66)
local INK = rgb(30, 41, 59)
local WHITE = rgb(255, 255, 255)
local GOLD = rgb(250, 204, 21)

local RAINBOW = {
	rgb(239, 68, 68),
	rgb(249, 115, 22),
	rgb(250, 204, 21),
	rgb(74, 222, 128),
	rgb(45, 212, 191),
	rgb(59, 130, 246),
	rgb(168, 85, 247),
	rgb(236, 72, 153),
}

local function at(x: number, y: number, z: number)
	return CENTER + Vector3.new(x, y, z)
end

-- A sign on two posts, turned to face `lookAt`.
local function postSign(name: string, base, size, lookAt, text: string, parent)
	local model = Builder.model(name, parent)
	local signCenter = base + Vector3.new(0, 4 + size.Y / 2, 0)
	local facing = CFrame.lookAt(signCenter, Vector3.new(lookAt.X, signCenter.Y, lookAt.Z))
	Builder.sign("Board", size, facing, text, WHITE, INK, model)
	for _, side in { -1, 1 } do
		local postPosition = (facing * CFrame.new(side * (size.X / 2 - 0.5), 0, 0.6)).Position
		Builder.block(
			"Post",
			Vector3.new(0.8, 4 + size.Y, 0.8),
			Vector3.new(postPosition.X, base.Y, postPosition.Z),
			WOOD,
			model
		)
	end
	return model
end

local function buildIsland(parent)
	local island = Builder.folder("Island", parent)
	Builder.block("Top", Vector3.new(ISLAND_SIZE, 4, ISLAND_SIZE), at(0, -4, 0), GRASS, island)
	-- Rocky underside that tapers to a point, like every good sky island.
	local layers = {
		{ 110, 6, rgb(146, 104, 64) },
		{ 92, 8, rgb(120, 84, 52) },
		{ 66, 10, rgb(100, 116, 139) },
		{ 40, 10, rgb(71, 85, 105) },
		{ 16, 8, rgb(51, 65, 85) },
	}
	local depth = 4
	for index, layer in layers do
		depth += layer[2]
		Builder.block(
			"Underside" .. index,
			Vector3.new(layer[1], layer[2], layer[1]),
			at(0, -depth, 0),
			layer[3],
			island
		)
	end
end

local function buildSpawn(parent)
	local spawn = Builder.part({
		name = "LobbySpawn",
		className = "SpawnLocation",
		size = Vector3.new(14, 1, 14),
		position = at(0, 0.5, 22),
		color = GOLD,
		parent = parent,
	})
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	-- Face the status board.
	spawn.CFrame = CFrame.lookAt(spawn.CFrame.Position, at(0, 0.5, -40))
	return spawn
end

-- The giant board; LobbyController draws live text onto it.
local function buildBoard(parent)
	local model = Builder.model("Billboard", parent)
	local board = Builder.part({
		name = "StatusBoard",
		size = Vector3.new(44, 20, 1),
		-- Rotated so its front face looks toward the spawn.
		cframe = CFrame.new(at(0, 14, -42)) * CFrame.Angles(0, math.pi, 0),
		color = INK,
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})
	board:SetAttribute("Note", "LobbyController draws the live match status on this board.")
	for _, x in { -23, 23 } do
		Builder.block("Post", Vector3.new(2, 25, 2), at(x, 0, -42), WOOD, model)
	end
	Builder.block("TopBeam", Vector3.new(50, 2, 3), at(0, 24, -42), GOLD, model)
	-- Team flags either side of the board.
	for index, color in { rgb(59, 130, 246), rgb(239, 68, 68) } do
		local x = if index == 1 then -30 else 30
		Builder.pillar("FlagPole", 0.6, 16, at(x, 0, -42), rgb(226, 232, 240), model)
		Builder.part({
			name = "Flag",
			size = Vector3.new(6, 4, 0.3),
			position = at(x + (if index == 1 then -3.3 else 3.3), 13.5, -42),
			color = color,
			material = Enum.Material.SmoothPlastic,
			parent = model,
		})
	end
end

local function buildDummy(name: string, base, facing, parent)
	local dummy = Builder.model(name, parent)
	local frame = CFrame.lookAt(base, base + facing)
	local burlap = rgb(214, 172, 120)
	local function piece(partName: string, size, offset, color)
		return Builder.part({
			name = partName,
			size = size,
			cframe = frame * CFrame.new(offset),
			color = color or burlap,
			parent = dummy,
		})
	end
	local root = piece("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	root.Transparency = 1
	root.CanCollide = false
	piece("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	piece("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0))
	piece("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0))
	piece("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0))
	piece("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0))
	piece("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0))
	-- Bullseye on the chest.
	Builder.part({
		name = "Target",
		size = Vector3.new(0.2, 1.4, 1.4),
		cframe = frame * CFrame.new(0, 3, -0.55) * CFrame.Angles(0, math.rad(90), 0),
		color = rgb(239, 68, 68),
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
		parent = dummy,
	})
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayName = "Training Dummy"
	humanoid.MaxHealth = 500
	humanoid.Health = 500
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = dummy
	dummy.PrimaryPart = root
	return dummy
end

local function buildPracticeArea(parent)
	local area = Builder.folder("PracticeArea", parent)

	local wall = Builder.model("PracticeWall", area)
	local bricks = Builder.folder("Bricks", wall)
	local wallColor = rgb(148, 163, 184)
	Bricks.straightWall(CFrame.new(at(-38, 0, -18)), 16, 4, function(course)
		return Builder.vary(if course % 2 == 0 then wallColor else rgb(203, 213, 225), 0.04)
	end, bricks)

	local dummies = Builder.folder("Dummies", area)
	buildDummy("TrainingDummy", at(-48, 0, -4), Vector3.new(0, 0, 1), dummies)
	buildDummy("TrainingDummy", at(-30, 0, -4), Vector3.new(0, 0, 1), dummies)

	postSign(
		"PracticeSign",
		at(-22, 0, -14),
		Vector3.new(10, 4, 0.5),
		at(0, 0, 22),
		"PRACTICE WALL\nBomb it - it rebuilds itself!",
		area
	)
end

local function buildParkour(parent)
	local course = Builder.folder("Parkour", parent)
	local pillarCenter = at(38, 0, -26)
	local peakHeight = 28

	Builder.block("Pillar", Vector3.new(6, peakHeight, 6), pillarCenter, rgb(100, 116, 139), course)
	Builder.block("SkyPeak", Vector3.new(12, 2, 12), pillarCenter + Vector3.new(0, peakHeight, 0), GOLD, course)
	local finish = Builder.part({
		name = "FinishPad",
		size = Vector3.new(7, 0.4, 7),
		position = pillarCenter + Vector3.new(0, peakHeight + 2.2, 0),
		color = rgb(255, 236, 140),
		material = Enum.Material.Neon,
		parent = course,
	})
	finish:SetAttribute("ParkourFinish", true)
	Builder.pillar("PeakFlagPole", 0.5, 9, pillarCenter + Vector3.new(4.5, peakHeight + 2, 4.5), WHITE, course)
	Builder.part({
		name = "PeakFlag",
		size = Vector3.new(4, 2.6, 0.3),
		position = pillarCenter + Vector3.new(6.7, peakHeight + 9.5, 4.5),
		color = rgb(236, 72, 153),
		material = Enum.Material.SmoothPlastic,
		parent = course,
	})

	-- Rainbow steps spiralling around the pillar, three studs higher each.
	local towardSpawn = at(0, 0, 22) - pillarCenter
	local startAngle = math.atan2(towardSpawn.Z, towardSpawn.X)
	local radius = 13
	for step = 1, 9 do
		local angle = startAngle - math.rad(42) * (step - 1)
		local top = 2 + 3 * (step - 1)
		local position = pillarCenter + Vector3.new(math.cos(angle) * radius, top - 1.5, math.sin(angle) * radius)
		Builder.block("Step" .. step, Vector3.new(5, 1.5, 5), position, RAINBOW[(step - 1) % #RAINBOW + 1], course)
	end

	postSign(
		"ParkourSign",
		pillarCenter + Vector3.new(-6, 0, 20),
		Vector3.new(10, 3.5, 0.5),
		at(0, 0, 22),
		"SKY PEAK PARKOUR\nReach the golden pad!",
		course
	)
end

local function buildDecor(parent)
	local decor = Builder.folder("Decor", parent)
	for _, spot in { { -50, 44 }, { 50, 44 }, { -52, -50 }, { 8, -54 }, { -10, 50 } } do
		Builder.tree("Tree", at(spot[1], 0, spot[2]), 0.9 + Builder.random() * 0.3, decor)
	end

	-- Lamp posts lining the spawn.
	for _, spot in { { -12, 12 }, { 12, 12 }, { -12, 32 }, { 12, 32 } } do
		Builder.block("LampPost", Vector3.new(0.8, 7, 0.8), at(spot[1], 0, spot[2]), INK, decor)
		local lamp = Builder.part({
			name = "Lamp",
			size = Vector3.new(1.6, 1.6, 1.6),
			position = at(spot[1], 7.8, spot[2]),
			color = rgb(255, 236, 170),
			material = Enum.Material.Neon,
			parent = decor,
		})
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 1
		light.Color = rgb(255, 220, 160)
		light.Parent = lamp
	end

	-- Benches facing the board.
	for _, x in { -14, 14 } do
		local bench = Builder.model("Bench", decor)
		Builder.block("Seat", Vector3.new(8, 0.6, 2.4), at(x, 1.6, 4), rgb(176, 128, 82), bench)
		for _, offset in { -3, 3 } do
			Builder.block("Leg", Vector3.new(0.6, 1.6, 2), at(x + offset, 0, 4), INK, bench)
		end
	end

	postSign(
		"HowToPlay",
		at(-24, 0, 28),
		Vector3.new(14, 6, 0.5),
		at(0, 0, 22),
		"HOW TO PLAY\nHold click to charge a bomb, release to throw.\nWreck the enemy tower, protect yours.\nStay inside the storm!",
		decor
	)

	-- A few crates by the practice wall for cover-jumping.
	for _, spot in { { -54, -20 }, { -54, -15.5 }, { -20, -24 } } do
		Builder.block(
			"Crate",
			Vector3.new(4, 4, 4),
			at(spot[1], 0, spot[2]),
			Builder.vary(rgb(160, 112, 66), 0.05),
			decor
		)
	end
end

function Lobby.build()
	local lobby = Builder.model("Lobby", nil)
	buildIsland(lobby)
	buildSpawn(lobby)
	buildBoard(lobby)
	buildPracticeArea(lobby)
	buildParkour(lobby)
	buildDecor(lobby)
	return lobby
end

Lobby.Center = CENTER

return Lobby

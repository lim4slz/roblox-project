--!nonstrict
-- The battle arena: a studded grass field with the two team towers at either
-- end, a raised centre plateau with power-up pads, and simple cover in
-- between (stepped hills, stone walls, crate stacks). Everything is mirrored
-- so neither side has an advantage.

local Builder = require("./Builder")
local Tower = require("./Tower")

local Vector3 = Builder.Vector3
local CFrame = Builder.CFrame
local Enum = Builder.Enum
local Instance = Builder.Instance
local rgb = Builder.rgb

local Arena = {}

local GROUND_SIZE = Vector3.new(380, 4, 280)
local TOWER_X = 80
local SPAWN_X = 122
local PLATEAU_HALF = 15
local PLATEAU_HEIGHT = 3

local GRASS = rgb(106, 190, 92)
local STONE = rgb(148, 163, 184)
local WOOD = rgb(160, 112, 66)
local DIRT = rgb(196, 164, 112)

type TeamSpec = {
	Name: string,
	Color: any,
	LightColor: any,
	DarkColor: any,
	BrickColor: string,
}

-- Calls `place` for a position and its mirror images so the map stays fair.
local function mirrored(x: number, z: number, place: (number, number) -> ())
	place(x, z)
	place(-x, z)
	if z ~= 0 then
		place(x, -z)
		place(-x, -z)
	end
end

local function buildGround(parent)
	local ground = Builder.folder("Ground", parent)
	Builder.part({
		name = "Grass",
		size = GROUND_SIZE,
		position = Vector3.new(0, -GROUND_SIZE.Y / 2, 0),
		color = GRASS,
		parent = ground,
	})
	-- A dirt path linking the two tower doors.
	Builder.part({
		name = "Path",
		size = Vector3.new(TOWER_X * 2 - 26, 0.2, 10),
		position = Vector3.new(0, 0.1, 0),
		color = DIRT,
		studs = false,
		material = Enum.Material.SmoothPlastic,
		parent = ground,
	})
end

local function buildPlateau(parent)
	local plateau = Builder.folder("Plateau", parent)
	Builder.block(
		"Top",
		Vector3.new(PLATEAU_HALF * 2, PLATEAU_HEIGHT, PLATEAU_HALF * 2),
		Vector3.new(0, 0, 0),
		rgb(226, 232, 240),
		plateau
	)
	-- One-stud steps on all four sides (no jumping needed).
	local directions = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	for _, direction in directions do
		local alongX = direction.X ~= 0
		for step = 1, PLATEAU_HEIGHT - 1 do
			local height = PLATEAU_HEIGHT - step
			local offset = PLATEAU_HALF + (step - 0.5) * 3
			local size = if alongX then Vector3.new(3, height, 12) else Vector3.new(12, height, 3)
			Builder.block("Step", size, direction * offset, rgb(203, 213, 225), plateau)
		end
	end
end

-- Power-up pads: a glowing ring the pickups hover above.
local function buildPads(parent)
	local pads = Builder.folder("PowerUpPads", parent)
	local positions = {
		Vector3.new(0, PLATEAU_HEIGHT, 0),
		Vector3.new(9, PLATEAU_HEIGHT, 9),
		Vector3.new(-9, PLATEAU_HEIGHT, 9),
		Vector3.new(9, PLATEAU_HEIGHT, -9),
		Vector3.new(-9, PLATEAU_HEIGHT, -9),
		Vector3.new(0, 0, 80),
		Vector3.new(0, 0, -80),
	}
	for index, position in positions do
		local pad = Builder.disc(
			"Pad" .. index,
			6,
			0.4,
			position + Vector3.new(0, 0.2, 0),
			rgb(250, 204, 21),
			pads,
			Enum.Material.Neon
		)
		Builder.disc("Inner", 4, 0.5, position + Vector3.new(0, 0.25, 0), rgb(255, 255, 255), pad)
	end
end

local function buildHill(name: string, center, parent)
	local hill = Builder.model(name, parent)
	local tiers = { Vector3.new(34, 2, 22), Vector3.new(24, 2, 15), Vector3.new(14, 2, 8) }
	for index, size in tiers do
		Builder.block(
			"Tier" .. index,
			size,
			center + Vector3.new(0, (index - 1) * 2, 0),
			Builder.vary(GRASS, 0.04),
			hill
		)
	end
end

local function buildCrate(base, parent)
	local crate = Builder.block("Crate", Vector3.new(4, 4, 4), base, Builder.vary(WOOD, 0.05), parent)
	-- Darker planks across the faces read as "crate" from far away.
	for _, z in { -2.05, 2.05 } do
		Builder.part({
			name = "Plank",
			size = Vector3.new(4.1, 0.6, 0.1),
			position = base + Vector3.new(0, 2, z),
			color = rgb(120, 80, 45),
			studs = false,
			canCollide = false,
			parent = crate,
		})
	end
	return crate
end

local function buildCover(parent)
	local cover = Builder.folder("Cover", parent)

	-- Stone walls to duck behind.
	local function wall(position, alongX: boolean)
		local size = if alongX then Vector3.new(14, 3, 2) else Vector3.new(2, 3, 14)
		Builder.block("StoneWall", size, position, Builder.vary(STONE, 0.04), cover)
	end
	mirrored(45, 26, function(x, z)
		wall(Vector3.new(x, 0, z), false)
	end)
	mirrored(28, 44, function(x, z)
		wall(Vector3.new(x, 0, z), true)
	end)
	mirrored(108, 42, function(x, z)
		wall(Vector3.new(x, 0, z), true)
	end)

	-- Crate stacks.
	mirrored(60, 46, function(x, z)
		buildCrate(Vector3.new(x, 0, z), cover)
		buildCrate(Vector3.new(x + 4.5, 0, z), cover)
		buildCrate(Vector3.new(x + 2, 4, z), cover)
	end)
	mirrored(24, 98, function(x, z)
		buildCrate(Vector3.new(x, 0, z), cover)
	end)
	mirrored(140, 70, function(x, z)
		buildCrate(Vector3.new(x, 0, z), cover)
		buildCrate(Vector3.new(x, 4, z), cover)
	end)

	-- Hills.
	mirrored(45, 88, function(x, z)
		buildHill("Hill", Vector3.new(x, 0, z), cover)
	end)

	-- Boulders for a bit of shape.
	mirrored(95, 110, function(x, z)
		Builder.part({
			name = "Boulder",
			size = Vector3.new(6, 5, 6),
			cframe = CFrame.new(x, 2, z) * CFrame.Angles(math.rad(12), math.rad(30), math.rad(8)),
			color = Builder.vary(rgb(120, 130, 145), 0.05),
			parent = cover,
		})
	end)
end

local function buildTrees(parent)
	local trees = Builder.folder("Trees", parent)
	local spots = {
		{ 165, 120 },
		{ 100, 126 },
		{ 40, 128 },
		{ 172, 40 },
		{ 175, -2 },
	}
	for _, spot in spots do
		mirrored(spot[1], spot[2], function(x, z)
			Builder.tree("Tree", Vector3.new(x, 0, z), 0.9 + Builder.random() * 0.4, trees)
		end)
	end
end

-- Low wooden fence around the edge plus invisible walls that keep players
-- (and bombs) in the arena.
local function buildBoundary(parent)
	local boundary = Builder.folder("Boundary", parent)
	local halfX, halfZ = GROUND_SIZE.X / 2 - 2, GROUND_SIZE.Z / 2 - 2
	local post = rgb(133, 94, 66)

	local function fenceLine(from, to)
		local length = (to - from).Magnitude
		local direction = (to - from).Unit
		local count = math.floor(length / 12)
		for index = 0, count do
			local position = from + direction * (index * length / count)
			Builder.block("FencePost", Vector3.new(1, 5, 1), position, post, boundary)
		end
		for _, height in { 2, 4 } do
			Builder.part({
				name = "FenceRail",
				size = Vector3.new(length, 0.5, 0.4),
				cframe = CFrame.lookAt((from + to) / 2 + Vector3.new(0, height, 0), to + Vector3.new(0, height, 0))
					* CFrame.Angles(0, math.rad(90), 0),
				color = rgb(176, 128, 82),
				studs = false,
				parent = boundary,
			})
		end
	end
	fenceLine(Vector3.new(-halfX, 0, -halfZ), Vector3.new(halfX, 0, -halfZ))
	fenceLine(Vector3.new(-halfX, 0, halfZ), Vector3.new(halfX, 0, halfZ))
	fenceLine(Vector3.new(-halfX, 0, -halfZ), Vector3.new(-halfX, 0, halfZ))
	fenceLine(Vector3.new(halfX, 0, -halfZ), Vector3.new(halfX, 0, halfZ))

	local wallHeight = 220
	local function invisibleWall(size, position)
		Builder.part({
			name = "InvisibleWall",
			size = size,
			position = position,
			transparency = 1,
			castShadow = false,
			studs = false,
			parent = boundary,
		})
	end
	invisibleWall(Vector3.new(GROUND_SIZE.X, wallHeight, 2), Vector3.new(0, wallHeight / 2, -halfZ - 1))
	invisibleWall(Vector3.new(GROUND_SIZE.X, wallHeight, 2), Vector3.new(0, wallHeight / 2, halfZ + 1))
	invisibleWall(Vector3.new(2, wallHeight, GROUND_SIZE.Z), Vector3.new(-halfX - 1, wallHeight / 2, 0))
	invisibleWall(Vector3.new(2, wallHeight, GROUND_SIZE.Z), Vector3.new(halfX + 1, wallHeight / 2, 0))
end

local function buildTeamBase(team: TeamSpec, side: number, spawns, decor)
	local spawnPosition = Vector3.new(SPAWN_X * side, 0, 0)
	local spawn = Builder.part({
		name = team.Name .. "Spawn",
		className = "SpawnLocation",
		size = Vector3.new(14, 1, 14),
		position = spawnPosition + Vector3.new(0, 0.5, 0),
		color = team.Color,
		parent = spawns,
	})
	spawn.Neutral = false
	spawn.TeamColor = Builder.roblox.BrickColor.new(team.BrickColor)
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 3
	-- Face the enemy so players spawn looking at the action.
	local spawnCenter = spawn.CFrame.Position
	spawn.CFrame = CFrame.lookAt(spawnCenter, Vector3.new(0, spawnCenter.Y, 0))

	-- Flags at the corners of the spawn pad.
	for _, z in { -9, 9 } do
		local base = spawnPosition + Vector3.new(4 * side, 0, z)
		Builder.pillar("BannerPole", 0.6, 12, base, rgb(226, 232, 240), decor)
		Builder.part({
			name = "Banner",
			size = Vector3.new(0.3, 4, 5),
			position = base + Vector3.new(0, 9.5, -math.sign(z) * 2.8),
			color = team.Color,
			material = Enum.Material.SmoothPlastic,
			parent = decor,
		})
	end
	-- A pair of lamps.
	for _, z in { -14, 14 } do
		local base = spawnPosition + Vector3.new(-6 * side, 0, z)
		Builder.block("LampPost", Vector3.new(1, 7, 1), base, rgb(51, 65, 85), decor)
		local lamp = Builder.part({
			name = "Lamp",
			size = Vector3.new(1.6, 1.6, 1.6),
			position = base + Vector3.new(0, 7.8, 0),
			color = team.LightColor,
			material = Enum.Material.Neon,
			parent = decor,
		})
		local light = Instance.new("PointLight")
		light.Color = team.LightColor
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = lamp
	end
end

-- Scenery outside the fence so the arena sits in a world, not a void:
-- rolling fields and a ring of big blocky hills fading into the haze.
local function buildBackdrop(parent)
	local backdrop = Builder.folder("Backdrop", parent)
	Builder.part({
		name = "Fields",
		size = Vector3.new(1600, 2, 1600),
		position = Vector3.new(0, -1.4, 0),
		color = rgb(96, 172, 84),
		studs = false,
		canQuery = false,
		parent = backdrop,
	})
	for index = 1, 12 do
		local angle = (index / 12) * math.pi * 2 + Builder.random() * 0.25
		local radius = 430 + Builder.random() * 260
		local base = Vector3.new(math.cos(angle) * radius, -0.4, math.sin(angle) * radius)
		local width = 90 + Builder.random() * 70
		local hill = Builder.model("DistantHill", backdrop)
		local height = 0
		for tier = 1, 3 do
			local tierHeight = 14 + Builder.random() * 18
			local tierWidth = width * (1 - (tier - 1) * 0.28)
			Builder.block(
				"Tier" .. tier,
				Vector3.new(tierWidth, tierHeight, tierWidth * 0.8),
				base + Vector3.new(0, height, 0),
				Builder.vary(rgb(84, 156, 78), 0.05),
				hill,
				{ studs = false, canQuery = false } :: any
			)
			height += tierHeight
		end
	end
end

local function buildClouds(parent)
	local clouds = Builder.folder("Clouds", parent)
	for index = 1, 14 do
		local angle = (index / 14) * math.pi * 2 + Builder.random() * 0.3
		local radius = 230 + Builder.random() * 110
		local center = Vector3.new(math.cos(angle) * radius, 150 + Builder.random() * 70, math.sin(angle) * radius)
		Builder.cloud("Cloud", center, 1 + Builder.random() * 0.8, clouds)
	end
end

function Arena.build(teams: { TeamSpec })
	local arena = Builder.model("Arena", nil)

	buildGround(arena)
	buildPlateau(arena)
	buildPads(arena)
	buildCover(arena)
	buildTrees(arena)
	buildBoundary(arena)
	buildBackdrop(arena)
	buildClouds(arena)

	local towers = Builder.folder("Towers", arena)
	local spawns = Builder.folder("Spawns", arena)
	local baseDecor = Builder.folder("BaseDecor", arena)
	local brickCounts = {}
	for index, team in teams do
		-- First team on the left (-X), second on the right (+X).
		local side = if index == 1 then -1 else 1
		local frame = CFrame.new(TOWER_X * side, 0, 0) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0)
		local _, count = Tower.build({
			name = team.Name .. "Tower",
			teamName = team.Name,
			frame = frame,
			color = team.Color,
			lightColor = team.LightColor,
			darkColor = team.DarkColor,
			parent = towers,
		})
		brickCounts[team.Name] = count
		buildTeamBase(team, side, spawns, baseDecor)
	end

	-- The storm closes in on this point.
	local zoneCenter = Builder.part({
		name = "ZoneCenter",
		size = Vector3.new(1, 1, 1),
		position = Vector3.new(0, 1, 0),
		transparency = 1,
		canCollide = false,
		canQuery = false,
		canTouch = false,
		studs = false,
		parent = arena,
	})
	zoneCenter:SetAttribute("Note", "The shrinking storm is centred here. Radii are set in Shared/Config.")

	return arena, brickCounts
end

return Arena

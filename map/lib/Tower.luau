--!nonstrict
-- Builds one team tower out of ~480 individual LEGO-style bricks.
--
-- Layout (local space, door facing +X toward the arena centre):
--   * 24x24 hollow square, 18 courses of 4x2x2 bricks in a running bond,
--     with interlocking corners like a real brick wall
--   * a 4-wide door at ground level and windows on every side
--   * a tiled roof with a hatch, a parapet and battlements on top
--   * a truss ladder inside, lanterns by the door and the team flag
--
-- Bricks go in Bricks/ (they count toward tower health); the ladder, flag and
-- lights go in Decor/ (they fall with the tower but don't count).

local Builder = require("./Builder")
local Bricks = require("./Bricks")

local Vector3 = Builder.Vector3
local CFrame = Builder.CFrame
local Enum = Builder.Enum

local Tower = {}

local HALF = 12 -- half the outer width
local THICK = 2 -- wall thickness
local LENGTH = 4 -- brick length
local HEIGHT = 2 -- brick (course) height
local COURSES = 18
local DOOR = { -2, 2 }
local DOOR_COURSES = 3
local WINDOW = { -2, 2 }
local WINDOW_COURSES = { [7] = true, [8] = true, [13] = true, [14] = true }

type TowerOptions = {
	name: string,
	teamName: string,
	frame: any, -- ground centre, rotated so local +X faces the arena centre
	color: any,
	lightColor: any,
	darkColor: any,
	parent: any,
}

local function holesFor(wall: string, course: number): { Bricks.Span }
	local holes = {}
	if wall == "East" and course < DOOR_COURSES then
		table.insert(holes, DOOR)
	end
	if WINDOW_COURSES[course] then
		table.insert(holes, WINDOW)
	end
	return holes
end

function Tower.build(options: TowerOptions)
	local model = Builder.model(options.name, options.parent)
	model:SetAttribute("Team", options.teamName)
	local bricksFolder = Builder.folder("Bricks", model)
	local decor = Builder.folder("Decor", model)
	local frame = options.frame

	local function courseColor(course: number)
		if course <= 1 then
			return Builder.vary(options.darkColor, 0.03)
		elseif course >= COURSES then
			return Builder.vary(options.lightColor, 0.03)
		end
		return Builder.vary(options.color, 0.045)
	end

	-- Walls, plus one extra course (the parapet) that sits on the roof.
	local roofTop = COURSES * HEIGHT + 1
	for course = 0, COURSES do
		local isParapet = course == COURSES
		local y = if isParapet then roofTop + HEIGHT / 2 else course * HEIGHT + HEIGHT / 2
		local even = course % 2 == 0
		-- Long walls swap every course so the corners interlock.
		local northSouthHalf = if even then HALF else HALF - THICK
		local eastWestHalf = if even then HALF - THICK else HALF

		for _, wall in { "North", "South" } do
			local z = if wall == "North" then -(HALF - THICK / 2) else HALF - THICK / 2
			local holes = if isParapet then {} else holesFor(wall, course)
			for _, span in Bricks.segments(-northSouthHalf, northSouthHalf, LENGTH, holes) do
				Bricks.place({
					frame = frame,
					localCenter = Vector3.new((span[1] + span[2]) / 2, y, z),
					size = Vector3.new(span[2] - span[1], HEIGHT, THICK),
					color = courseColor(course),
					grounded = course == 0,
					parent = bricksFolder,
				})
			end
		end
		for _, wall in { "West", "East" } do
			local x = if wall == "West" then -(HALF - THICK / 2) else HALF - THICK / 2
			local holes = if isParapet then {} else holesFor(wall, course)
			for _, span in Bricks.segments(-eastWestHalf, eastWestHalf, LENGTH, holes) do
				Bricks.place({
					frame = frame,
					localCenter = Vector3.new(x, y, (span[1] + span[2]) / 2),
					size = Vector3.new(THICK, HEIGHT, span[2] - span[1]),
					color = courseColor(course),
					grounded = course == 0,
					parent = bricksFolder,
				})
			end
		end
	end

	-- Roof tiles, leaving a hatch above the ladder.
	local roofY = COURSES * HEIGHT + 0.5
	local slate = Builder.rgb(71, 85, 105)
	for x = -HALF + 2, HALF - 2, 4 do
		for z = -HALF + 2, HALF - 2, 4 do
			local isHatch = x == -HALF + 2 and math.abs(z) == 2
			if not isHatch then
				Bricks.place({
					name = "RoofTile",
					frame = frame,
					localCenter = Vector3.new(x, roofY, z),
					size = Vector3.new(4, 1, 4),
					color = Builder.vary(slate, 0.03),
					parent = bricksFolder,
				})
			end
		end
	end

	-- Battlements.
	local merlonY = roofTop + HEIGHT + 1
	local merlonColor = Builder.rgb(241, 245, 249)
	local function merlon(x: number, z: number)
		Bricks.place({
			name = "Merlon",
			frame = frame,
			localCenter = Vector3.new(x, merlonY, z),
			size = Vector3.new(2, 2, 2),
			color = Builder.vary(merlonColor, 0.02),
			parent = bricksFolder,
		})
	end
	for _, x in { -11, -7, -3, 3, 7, 11 } do
		merlon(x, -11)
		merlon(x, 11)
	end
	for _, z in { -7, -3, 3, 7 } do
		merlon(-11, z)
		merlon(11, z)
	end

	-- Ladder up the inside of the back wall, through the hatch.
	local ladder = Builder.part({
		name = "Ladder",
		className = "TrussPart",
		size = Vector3.new(2, 38, 2),
		cframe = frame * CFrame.new(-(HALF - THICK) + 1, 19, 0),
		color = Builder.rgb(51, 65, 85),
		parent = decor,
	})
	ladder:SetAttribute("Grounded", false)
	-- It touches every course, so it must not act as a spine holding the
	-- tower up after the walls are blown through.
	ladder:SetAttribute("Supports", false)

	-- Team flag on the roof.
	local poleBase = Vector3.new(-6, roofTop, 7)
	Builder.part({
		name = "FlagPole",
		size = Vector3.new(14, 0.6, 0.6),
		cframe = frame * CFrame.new(poleBase + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Builder.rgb(226, 232, 240),
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.SmoothPlastic,
		parent = decor,
	})
	Builder.part({
		name = "Flag",
		size = Vector3.new(0.3, 4, 6.5),
		cframe = frame * CFrame.new(poleBase + Vector3.new(0, 11.5, -3.55)),
		color = options.color,
		material = Enum.Material.SmoothPlastic,
		parent = decor,
	})
	Builder.part({
		name = "FlagTop",
		size = Vector3.new(1.2, 1.2, 1.2),
		cframe = frame * CFrame.new(poleBase + Vector3.new(0, 14.4, 0)),
		color = Builder.rgb(250, 204, 21),
		shape = Enum.PartType.Ball,
		material = Enum.Material.Neon,
		parent = decor,
	})

	-- Lanterns either side of the door and a banner above it.
	for _, z in { -3.5, 3.5 } do
		local lantern = Builder.part({
			name = "Lantern",
			size = Vector3.new(1, 1.6, 1),
			cframe = frame * CFrame.new(HALF + 0.5, 5, z),
			color = Builder.rgb(255, 214, 140),
			material = Enum.Material.Neon,
			parent = decor,
		})
		local light = Builder.Instance.new("PointLight")
		light.Color = Builder.rgb(255, 200, 120)
		light.Range = 10
		light.Brightness = 1
		light.Parent = lantern
	end
	Builder.part({
		name = "Banner",
		size = Vector3.new(0.3, 6, 5),
		cframe = frame * CFrame.new(HALF + 0.15, 10, 0),
		color = Builder.rgb(241, 245, 249),
		material = Enum.Material.SmoothPlastic,
		parent = decor,
	})
	Builder.part({
		name = "BannerEmblem",
		size = Vector3.new(0.4, 2, 2),
		cframe = frame * CFrame.new(HALF + 0.2, 10.5, 0) * CFrame.Angles(math.rad(45), 0, 0),
		color = options.color,
		material = Enum.Material.Neon,
		parent = decor,
	})

	return model, #bricksFolder:GetChildren()
end

return Tower

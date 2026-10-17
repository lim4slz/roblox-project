--!nonstrict
-- Brick-laying for towers and walls: splits a wall course into bricks with a
-- running bond (each course shifted half a brick) and cuts clean holes for
-- doors and windows by trimming bricks rather than leaving ragged gaps.

local Builder = require("./Builder")

local Vector3 = Builder.Vector3
local CFrame = Builder.CFrame

local Bricks = {}

export type Span = { number }

-- Splits [from, to] into bricks of `length`. The brick grid starts `phase`
-- studs before `from`, so phase = length / 2 gives the offset course.
-- `holes` is a list of {start, finish} spans to leave open.
function Bricks.segments(from: number, to: number, length: number, holes: { Span }?, phase: number?): { Span }
	local result = {}
	local cursor = from - (phase or 0)
	while cursor < to - 1e-6 do
		local finish = cursor + length
		local pieces = { { math.max(cursor, from), math.min(finish, to) } }
		for _, hole in holes or {} do
			local kept = {}
			for _, piece in pieces do
				if hole[2] <= piece[1] or hole[1] >= piece[2] then
					table.insert(kept, piece)
				else
					if hole[1] > piece[1] then
						table.insert(kept, { piece[1], hole[1] })
					end
					if hole[2] < piece[2] then
						table.insert(kept, { hole[2], piece[2] })
					end
				end
			end
			pieces = kept
		end
		for _, piece in pieces do
			-- Slivers thinner than one stud would look like glitches.
			if piece[2] - piece[1] >= 0.99 then
				table.insert(result, piece)
			end
		end
		cursor = finish
	end
	return result
end

type BrickOptions = {
	frame: any, -- CFrame of the structure's ground centre
	localCenter: any,
	size: any,
	color: any,
	grounded: boolean?,
	parent: any,
	name: string?,
}

-- Places one brick in the structure's local space.
function Bricks.place(options: BrickOptions)
	local part = Builder.part({
		name = options.name or "Brick",
		size = options.size,
		cframe = options.frame * CFrame.new(options.localCenter),
		color = options.color,
		parent = options.parent,
	})
	if options.grounded then
		part:SetAttribute("Grounded", true)
	end
	return part
end

-- A straight free-standing wall along local X (used for the practice wall).
function Bricks.straightWall(frame, width: number, courses: number, colorFor: (number) -> any, parent)
	local brickLength, brickHeight, thickness = 4, 2, 2
	local count = 0
	for course = 0, courses - 1 do
		local phase = if course % 2 == 0 then 0 else brickLength / 2
		for _, span in Bricks.segments(-width / 2, width / 2, brickLength, nil, phase) do
			Bricks.place({
				frame = frame,
				localCenter = Vector3.new((span[1] + span[2]) / 2, course * brickHeight + brickHeight / 2, 0),
				size = Vector3.new(span[2] - span[1], brickHeight, thickness),
				color = colorFor(course),
				grounded = course == 0,
				parent = parent,
			})
			count += 1
		end
	end
	return count
end

return Bricks

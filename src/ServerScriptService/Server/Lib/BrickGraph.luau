--!strict
-- Pure data structure behind the collapsing towers.
--
-- Every brick is an axis-aligned box. Two bricks are "connected" when they
-- share a face (not just an edge or a corner). After bricks are removed, any
-- brick that can no longer reach a grounded brick through connected neighbours
-- has lost its support and should fall. This is what makes blowing out a
-- tower's base drop the whole top half, Doomspire style.
--
-- No Roblox types are used here so the logic can be unit-tested with Lune.

export type Vec3 = { x: number, y: number, z: number }

export type Box = {
	min: Vec3,
	max: Vec3,
	grounded: boolean,
	-- false for parts that hang off the structure but must never hold
	-- anything else up (e.g. the ladder that touches every course).
	conducts: boolean?,
}

export type BrickGraph = {
	count: number,
	neighbors: { { number } },
	grounded: { boolean },
	conducts: { boolean },
	alive: { boolean },
	aliveCount: number,
	remove: (self: BrickGraph, index: number) -> boolean,
	isAlive: (self: BrickGraph, index: number) -> boolean,
	findUnsupported: (self: BrickGraph) -> { number },
	components: (self: BrickGraph, indices: { number }) -> { { number } },
}

local BrickGraph = {}
BrickGraph.__index = BrickGraph

-- Gaps smaller than this still count as touching (floating point slop from
-- CFrame maths in Studio-built maps).
local TOUCH_TOLERANCE = 0.05
-- Two boxes must overlap by at least this much on two axes to share a face.
local FACE_OVERLAP = 0.2
-- Spatial hash cell size; about one brick.
local CELL_SIZE = 4

-- World-space axis-aligned bounds of a (possibly rotated) box. Takes the
-- CFrame and size by duck typing so it works with Lune's datatypes in tests.
function BrickGraph.boxFromCFrame(cframe: CFrame, size: Vector3, grounded: boolean, conducts: boolean?): Box
	local half = size / 2
	local right, up, look = cframe.RightVector, cframe.UpVector, cframe.LookVector
	local extentX = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z
	local extentY = math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z
	local extentZ = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	local p = cframe.Position
	return {
		min = { x = p.X - extentX, y = p.Y - extentY, z = p.Z - extentZ },
		max = { x = p.X + extentX, y = p.Y + extentY, z = p.Z + extentZ },
		grounded = grounded,
		conducts = conducts,
	}
end

local function overlap(minA: number, maxA: number, minB: number, maxB: number): number
	return math.min(maxA, maxB) - math.max(minA, minB)
end

local function sharesFace(a: Box, b: Box): boolean
	local ox = overlap(a.min.x, a.max.x, b.min.x, b.max.x)
	local oy = overlap(a.min.y, a.max.y, b.min.y, b.max.y)
	local oz = overlap(a.min.z, a.max.z, b.min.z, b.max.z)
	if ox < -TOUCH_TOLERANCE or oy < -TOUCH_TOLERANCE or oz < -TOUCH_TOLERANCE then
		return false
	end
	local solidAxes = 0
	if ox > FACE_OVERLAP then
		solidAxes += 1
	end
	if oy > FACE_OVERLAP then
		solidAxes += 1
	end
	if oz > FACE_OVERLAP then
		solidAxes += 1
	end
	return solidAxes >= 2
end

local function cellRange(low: number, high: number): (number, number)
	return math.floor((low - TOUCH_TOLERANCE) / CELL_SIZE), math.floor((high + TOUCH_TOLERANCE) / CELL_SIZE)
end

function BrickGraph.new(boxes: { Box }): BrickGraph
	local count = #boxes
	local neighbors: { { number } } = table.create(count)
	local grounded: { boolean } = table.create(count)
	local conducts: { boolean } = table.create(count)
	local alive: { boolean } = table.create(count)

	-- Bucket every box into the grid cells it covers so we only compare
	-- nearby pairs: O(n) instead of O(n^2) for a few hundred bricks.
	local cells: { [string]: { number } } = {}
	for index, box in boxes do
		neighbors[index] = {}
		grounded[index] = box.grounded
		conducts[index] = box.conducts ~= false
		alive[index] = true
		local x0, x1 = cellRange(box.min.x, box.max.x)
		local y0, y1 = cellRange(box.min.y, box.max.y)
		local z0, z1 = cellRange(box.min.z, box.max.z)
		for cx = x0, x1 do
			for cy = y0, y1 do
				for cz = z0, z1 do
					local key = cx .. "," .. cy .. "," .. cz
					local bucket = cells[key]
					if bucket then
						table.insert(bucket, index)
					else
						cells[key] = { index }
					end
				end
			end
		end
	end

	local seen: { [number]: { [number]: boolean } } = {}
	for _, bucket in cells do
		for i = 1, #bucket do
			local a = bucket[i]
			for j = i + 1, #bucket do
				local b = bucket[j]
				local low, high = math.min(a, b), math.max(a, b)
				local checked = seen[low]
				if not checked then
					checked = {}
					seen[low] = checked
				end
				if not checked[high] then
					checked[high] = true
					if sharesFace(boxes[low], boxes[high]) then
						table.insert(neighbors[low], high)
						table.insert(neighbors[high], low)
					end
				end
			end
		end
	end

	local self = setmetatable({
		count = count,
		neighbors = neighbors,
		grounded = grounded,
		conducts = conducts,
		alive = alive,
		aliveCount = count,
	}, BrickGraph)
	return (self :: any) :: BrickGraph
end

-- Marks a brick as gone. Returns false if it was already removed.
function BrickGraph.remove(self: BrickGraph, index: number): boolean
	if not self.alive[index] then
		return false
	end
	self.alive[index] = false
	self.aliveCount -= 1
	return true
end

function BrickGraph.isAlive(self: BrickGraph, index: number): boolean
	return self.alive[index] == true
end

-- Flood fill from every living grounded brick; whatever we can't reach is
-- floating and must fall.
function BrickGraph.findUnsupported(self: BrickGraph): { number }
	local reached: { boolean } = table.create(self.count, false)
	local stack: { number } = {}
	for index = 1, self.count do
		if self.alive[index] and self.grounded[index] then
			reached[index] = true
			table.insert(stack, index)
		end
	end
	while #stack > 0 do
		local current = table.remove(stack) :: number
		-- Non-conducting parts stay up if they touch something supported, but
		-- support doesn't flow onward through them.
		if self.conducts[current] then
			for _, neighbor in self.neighbors[current] do
				if self.alive[neighbor] and not reached[neighbor] then
					reached[neighbor] = true
					table.insert(stack, neighbor)
				end
			end
		end
	end

	local unsupported = {}
	for index = 1, self.count do
		if self.alive[index] and not reached[index] then
			table.insert(unsupported, index)
		end
	end
	return unsupported
end

-- Splits a set of bricks into connected clusters (each falls as one chunk).
function BrickGraph.components(self: BrickGraph, indices: { number }): { { number } }
	local inSet: { [number]: boolean } = {}
	for _, index in indices do
		inSet[index] = true
	end
	local visited: { [number]: boolean } = {}
	local result = {}
	for _, start in indices do
		if not visited[start] then
			local cluster = {}
			local stack = { start }
			visited[start] = true
			while #stack > 0 do
				local current = table.remove(stack) :: number
				table.insert(cluster, current)
				for _, neighbor in self.neighbors[current] do
					if inSet[neighbor] and not visited[neighbor] then
						visited[neighbor] = true
						table.insert(stack, neighbor)
					end
				end
			end
			table.insert(result, cluster)
		end
	end
	return result
end

return BrickGraph

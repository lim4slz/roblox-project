--[[
	Geometry helpers shared by the pet specs (box corners, lowest points, ...).
]]

local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

local PetGeometry = {}

function PetGeometry.corners(cframe, size)
	local result = {}
	local half = size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(result, cframe * Vector3.new(half.X * x, half.Y * y, half.Z * z))
			end
		end
	end
	return result
end

function PetGeometry.partIndex(parts, name)
	for index, def in parts do
		if def.name == name then
			return index
		end
	end
	error("no part " .. name)
end

-- Lowest Y of the given parts (all parts when `filter` is nil) for solved
-- CFrames of a rig built with `scale` (default 1).
function PetGeometry.lowest(parts, cframes, filter, scale)
	local lowest = math.huge
	for index, def in parts do
		if filter == nil or filter(def.name) then
			for _, corner in PetGeometry.corners(cframes[index], def.size * (scale or 1)) do
				lowest = math.min(lowest, corner.Y)
			end
		end
	end
	return lowest
end

-- Smallest Z (the front, pets face -Z) of a part.
function PetGeometry.frontZ(parts, cframes, name)
	local index = PetGeometry.partIndex(parts, name)
	local front = math.huge
	for _, corner in PetGeometry.corners(cframes[index], parts[index].size) do
		front = math.min(front, corner.Z)
	end
	return front
end

-- Corners of a part expressed in another part's space (to check "inside").
function PetGeometry.cornersIn(parts, cframes, name, otherName)
	local index = PetGeometry.partIndex(parts, name)
	local other = cframes[PetGeometry.partIndex(parts, otherName)]
	local result = {}
	for _, corner in PetGeometry.corners(cframes[index], parts[index].size) do
		table.insert(result, other:PointToObjectSpace(corner))
	end
	return result
end

-- True when every corner of `name` is inside the box of `otherName` (with a margin).
function PetGeometry.inside(parts, cframes, name, otherName, margin)
	local half = parts[PetGeometry.partIndex(parts, otherName)].size / 2 + Vector3.one * (margin or 0)
	for _, point in PetGeometry.cornersIn(parts, cframes, name, otherName) do
		if math.abs(point.X) > half.X or math.abs(point.Y) > half.Y or math.abs(point.Z) > half.Z then
			return false
		end
	end
	return true
end

-- Distance from a point to a polyline, measured on the ground plane.
function PetGeometry.flatDistanceToPolyline(point, polyline)
	local best = math.huge
	local p = Vector3.new(point.X, 0, point.Z)
	for index = 1, #polyline - 1 do
		local a = Vector3.new(polyline[index].X, 0, polyline[index].Z)
		local b = Vector3.new(polyline[index + 1].X, 0, polyline[index + 1].Z)
		local ab = b - a
		local t = if ab.Magnitude > 1e-9 then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
		best = math.min(best, (a + ab * t - p).Magnitude)
	end
	return best
end

return PetGeometry

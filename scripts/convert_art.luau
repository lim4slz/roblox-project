--[[
	Prints a pet from the artist's .rbxm in the pet's own frame, ready to turn
	into a <Pet>Model.luau: origin on the ground under the body (the tool's
	Handle), facing -Z, +X = the pet's right. Blocks are written with their
	simplest equivalent rotation (a box turned 90 or 180 degrees is the same box
	with its sizes swapped).

	  lune run scripts/convert_art -- <file.rbxm> <ToolName> [yaw degrees to undo]

	Each line: size(x, y, z) at(x, y, z, rx, ry, rz), the at() helper of the
	model files. "HANDLE" marks the handle. The yaw is the art's own turn
	around Y (look at the parts' rotations); the Dog needed 6.47, the Crab 1.606.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CFrame, Vector3, Enum = roblox.CFrame, roblox.Vector3, roblox.Enum

local args = table.clone(process.args)
if args[1] == "--" then
	table.remove(args, 1)
end
local path, toolName, yaw = args[1], args[2], tonumber(args[3]) or 0
assert(path and toolName, "usage: lune run scripts/convert_art -- <file.rbxm> <ToolName> [yaw]")

local tool
for _, root in roblox.deserializeModel(fs.readFile(path)) do
	tool = if root.Name == toolName then root else root:FindFirstChild(toolName, true)
	if tool then
		break
	end
end
assert(tool, "no " .. toolName .. " in " .. path)

local function corners(cframe, size)
	local out = {}
	local half = size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(out, cframe * Vector3.new(half.X * x, half.Y * y, half.Z * z))
			end
		end
	end
	return out
end

local parts = {}
for _, part in tool:GetDescendants() do
	if part:IsA("BasePart") then
		table.insert(parts, part)
	end
end
local handle = tool:FindFirstChild("Handle") or parts[1]

-- Turn everything about the handle, then find the ground and the middle.
local unyaw = CFrame.Angles(0, math.rad(-yaw), 0)
local pivot = CFrame.new(handle.CFrame.Position)
local turned = {}
local minY, minX, maxX = math.huge, math.huge, -math.huge
for _, part in parts do
	local cframe = unyaw * (pivot:Inverse() * part.CFrame)
	turned[part] = cframe
	for _, corner in corners(cframe, part.Size) do
		minY = math.min(minY, corner.Y)
		minX = math.min(minX, corner.X)
		maxX = math.max(maxX, corner.X)
	end
end
local origin = CFrame.new((minX + maxX) / 2, minY, 0)

-- Every way to map a box's axes onto itself (with its sizes following).
local axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
local mappings = {}
for i = 1, 3 do
	for j = 1, 3 do
		if j ~= i then
			for _, si in { 1, -1 } do
				for _, sj in { 1, -1 } do
					local x, y = axes[i] * si, axes[j] * sj
					table.insert(mappings, { x = x, y = y, z = x:Cross(y) })
				end
			end
		end
	end
end

local function angleOf(cframe)
	local _, angle = cframe:ToAxisAngle()
	return math.abs(angle)
end

local function number(n)
	local text = string.format("%.3f", n)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return if text == "-0" then "0" else text
end

local rows = {}
for _, part in parts do
	local cframe = origin:Inverse() * turned[part]
	local size = part.Size
	local isBlock = part:IsA("Part") and part.Shape == Enum.PartType.Block
	if isBlock then
		local best = angleOf(cframe)
		local bestCFrame, bestSize = cframe, size
		for _, mapping in mappings do
			local candidate = cframe * CFrame.fromMatrix(Vector3.zero, mapping.x, mapping.y, mapping.z)
			local angle = angleOf(candidate)
			if angle < best - 1e-6 then
				local function along(v)
					return math.abs(v.X) * size.X + math.abs(v.Y) * size.Y + math.abs(v.Z) * size.Z
				end
				best, bestCFrame = angle, candidate
				bestSize = Vector3.new(along(mapping.x), along(mapping.y), along(mapping.z))
			end
		end
		cframe, size = bestCFrame, bestSize
	end
	local rx, ry, rz = cframe:ToEulerAnglesXYZ()
	local color = part.Color
	local shape = if part:IsA("Part") then string.gsub(tostring(part.Shape), "Enum.PartType.", "") else part.ClassName
	table.insert(rows, {
		y = cframe.Position.Y,
		line = string.format(
			"%-6s %-8s rgb(%d,%d,%d) size(%s, %s, %s) at(%s, %s, %s, %s, %s, %s)",
			if part == handle then "HANDLE" else "",
			shape,
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5),
			number(size.X),
			number(size.Y),
			number(size.Z),
			number(cframe.Position.X),
			number(cframe.Position.Y),
			number(cframe.Position.Z),
			number(math.deg(rx)),
			number(math.deg(ry)),
			number(math.deg(rz))
		),
	})
end
table.sort(rows, function(a, b)
	return a.y > b.y
end)
print(string.format("-- %s: %d parts, facing -Z, +X = the pet's right, ground at y = 0", toolName, #parts))
for _, row in rows do
	print(row.line)
end

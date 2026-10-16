--[[
	Builds the MeltingR6 folder from src/MeltingR6Rig.server.luau and zips it into MeltingR6.zip:
	  MeltingR6/ServerScriptService/MeltingR6Rig.rbxm
	  MeltingR6/ServerScriptService/MeltingR6Rig.lua
	  MeltingR6/Test/MeltingR6_Test.rbxl

	  lune run scripts/build_melting
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local OUT = "MeltingR6"
local source = fs.readFile("src/MeltingR6Rig.server.luau")

local function newScript()
	local script = Instance.new("Script")
	script.Name = "MeltingR6Rig"
	script.Source = source
	return script
end

for _, dir in { OUT .. "/ServerScriptService", OUT .. "/Test" } do
	if not fs.isDir(dir) then
		fs.writeDir(dir)
	end
end

fs.writeFile(OUT .. "/ServerScriptService/MeltingR6Rig.rbxm", roblox.serializeModel({ newScript() }))
fs.writeFile(OUT .. "/ServerScriptService/MeltingR6Rig.lua", source)

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")

local floor = Instance.new("Part")
floor.Name = "Baseplate"
floor.Anchored = true
floor.Locked = true
floor.Size = Vector3.new(512, 16, 512)
floor.CFrame = CFrame.new(0, -8, 0)
floor.Color = Color3.fromRGB(91, 93, 105)
floor.Material = Enum.Material.Slate
floor.TopSurface = Enum.SurfaceType.Smooth
floor.BottomSurface = Enum.SurfaceType.Smooth
floor.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(0, 0.5, 20)
spawn.Color = Color3.fromRGB(163, 162, 165)
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Parent = workspace

newScript().Parent = game:GetService("ServerScriptService")

fs.writeFile(OUT .. "/Test/MeltingR6_Test.rbxl", roblox.serializePlace(game))

-- no timestamps in the zip: same files in, same zip out
local ZIP = [[
import os, sys, zipfile
folder, target = sys.argv[1], sys.argv[2]
paths = []
for root, dirs, files in os.walk(folder):
    dirs.sort()
    for name in sorted(files):
        paths.append(os.path.join(root, name))
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for path in paths:
        info = zipfile.ZipInfo(path, date_time=(2026, 1, 1, 0, 0, 0))
        info.external_attr = 0o644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        with open(path, "rb") as f:
            z.writestr(info, f.read())
print(len(paths), "files")
]]
if fs.isFile(OUT .. ".zip") then
	fs.removeFile(OUT .. ".zip")
end
local result = process.exec("python3", { "-I", "-c", ZIP, OUT, OUT .. ".zip" })
assert(result.ok, result.stderr)
print(OUT .. ".zip: " .. string.gsub(result.stdout, "%s+$", ""))

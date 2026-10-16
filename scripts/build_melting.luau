--[[
	Gera a pasta MeltingR6 a partir de src/MeltingR6Rig.server.luau:
	  MeltingR6/ServerScriptService/MeltingR6Rig.rbxm
	  MeltingR6/Teste/MeltingR6_Teste.rbxl

	  lune run scripts/build_melting
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local OUT = "MeltingR6"
local fonte = fs.readFile("src/MeltingR6Rig.server.luau")

local function novoScript()
	local script = Instance.new("Script")
	script.Name = "MeltingR6Rig"
	script.Source = fonte
	return script
end

for _, pasta in { OUT .. "/ServerScriptService", OUT .. "/Teste" } do
	if not fs.isDir(pasta) then
		fs.writeDir(pasta)
	end
end

fs.writeFile(OUT .. "/ServerScriptService/MeltingR6Rig.rbxm", roblox.serializeModel({ novoScript() }))

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")

local chao = Instance.new("Part")
chao.Name = "Baseplate"
chao.Anchored = true
chao.Locked = true
chao.Size = Vector3.new(512, 16, 512)
chao.CFrame = CFrame.new(0, -8, 0)
chao.Color = Color3.fromRGB(91, 93, 105)
chao.Material = Enum.Material.Slate
chao.TopSurface = Enum.SurfaceType.Smooth
chao.BottomSurface = Enum.SurfaceType.Smooth
chao.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(0, 0.5, 20)
spawn.Color = Color3.fromRGB(163, 162, 165)
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Parent = workspace

novoScript().Parent = game:GetService("ServerScriptService")

fs.writeFile(OUT .. "/Teste/MeltingR6_Teste.rbxl", roblox.serializePlace(game))
print("ok")

--[[
	Gera a pasta MeltingR6 a partir de src/MeltingR6Rig.server.luau e zipa tudo em MeltingR6.zip:
	  MeltingR6/ServerScriptService/MeltingR6Rig.rbxm
	  MeltingR6/ServerScriptService/MeltingR6Rig.lua
	  MeltingR6/Teste/MeltingR6_Teste.rbxl

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
fs.writeFile(OUT .. "/ServerScriptService/MeltingR6Rig.lua", fonte)

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

-- zip sem data nos arquivos: mesmo conteúdo, mesmo zip
local ZIP = [[
import os, sys, zipfile
pasta, destino = sys.argv[1], sys.argv[2]
arquivos = []
for raiz, dirs, nomes in os.walk(pasta):
    dirs.sort()
    for nome in sorted(nomes):
        arquivos.append(os.path.join(raiz, nome))
with zipfile.ZipFile(destino, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for caminho in arquivos:
        info = zipfile.ZipInfo(caminho, date_time=(2026, 1, 1, 0, 0, 0))
        info.external_attr = 0o644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        with open(caminho, "rb") as f:
            z.writestr(info, f.read())
print(len(arquivos), "arquivos")
]]
if fs.isFile(OUT .. ".zip") then
	fs.removeFile(OUT .. ".zip")
end
local r = process.exec("python3", { "-I", "-c", ZIP, OUT, OUT .. ".zip" })
assert(r.ok, r.stderr)
print(OUT .. ".zip: " .. string.gsub(r.stdout, "%s+$", ""))

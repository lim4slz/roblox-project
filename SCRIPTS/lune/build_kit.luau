--!strict
-- Monta o kit do Roblox a partir de ROBLOX/src e EXPORT/KeyframeSequences:
--   ROBLOX/build/EmberAbilities.rbxm       pastas pra arrastar pros serviços
--   ROBLOX/build/EmberAbilities_Test.rbxl  place pronto pra testar no Studio
--   lune run SCRIPTS/lune/build_kit.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3
local Enum = roblox.Enum

local ROOT = process.cwd
local SRC = ROOT .. "/ROBLOX/src"
local OUT = ROOT .. "/ROBLOX/build"

local function scriptFor(file: string, path: string): any
	local name, kind
	if string.match(file, "%.server%.luau$") then
		name, kind = string.gsub(file, "%.server%.luau$", ""), "Script"
	elseif string.match(file, "%.client%.luau$") then
		name, kind = string.gsub(file, "%.client%.luau$", ""), "LocalScript"
	else
		name, kind = string.gsub(file, "%.luau$", ""), "ModuleScript"
	end
	local s = Instance.new(kind)
	s.Name = name
	s.Source = fs.readFile(path)
	return s
end

-- mesmo mapeamento do Rojo: pasta vira Folder, pasta com init vira o script do init
local function build(path: string, name: string): any
	local entries = fs.readDir(path)
	table.sort(entries)
	local container: any = nil
	for _, e in entries do
		if string.match(e, "^init%.") then
			container = scriptFor(e, path .. "/" .. e)
			container.Name = name
		end
	end
	if container == nil then
		container = Instance.new("Folder")
		container.Name = name
	end
	for _, e in entries do
		local full = path .. "/" .. e
		if string.match(e, "^init%.") then
			continue
		elseif fs.isDir(full) then
			build(full, e).Parent = container
		elseif string.match(e, "%.luau$") then
			scriptFor(e, full).Parent = container
		end
	end
	return container
end

local function keyframeSequences(): any
	local folder = Instance.new("Folder")
	folder.Name = "KeyframeSequences"
	local dir = ROOT .. "/EXPORT/KeyframeSequences"
	if fs.isDir(dir) then
		local files = fs.readDir(dir)
		table.sort(files)
		for _, f in files do
			if string.match(f, "%.rbxm$") then
				for _, inst in roblox.deserializeModel(fs.readFile(dir .. "/" .. f)) do
					inst.Parent = folder
				end
			end
		end
	end
	return folder
end

local function ember(): any
	local e = build(SRC .. "/shared", "Ember")
	keyframeSequences().Parent = e
	return e
end

local function part(props: { [string]: any }): any
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- boneco R15 de teste montado com os mesmos dados do rig do Blender
local function dummy(name: string, position: any, withExtras: boolean?): any
	local meta = serde.decode("json", fs.readFile(ROOT .. "/CHARACTER/rig_meta_ember_r15.json"))
	local sizes = {
		HumanoidRootPart = Vector3.new(2, 2, 1), LowerTorso = Vector3.new(2, 0.4, 1), UpperTorso = Vector3.new(2, 1.6, 1),
		Head = Vector3.new(1.25, 1.25, 1.25), LeftUpperArm = Vector3.new(1, 1.17, 1), LeftLowerArm = Vector3.new(1, 1.05, 1),
		LeftHand = Vector3.new(1, 0.3, 1), RightUpperArm = Vector3.new(1, 1.17, 1), RightLowerArm = Vector3.new(1, 1.05, 1),
		RightHand = Vector3.new(1, 0.3, 1), LeftUpperLeg = Vector3.new(1, 1, 1), LeftLowerLeg = Vector3.new(1, 0.9, 1),
		LeftFoot = Vector3.new(1, 0.3, 1), RightUpperLeg = Vector3.new(1, 1, 1), RightLowerLeg = Vector3.new(1, 0.9, 1),
		RightFoot = Vector3.new(1, 0.3, 1),
	}
	if withExtras then
		sizes.EmberBlade = Vector3.new(0.14, 0.32, 5.2)
		sizes.Scarf1 = Vector3.new(0.72, 0.86, 0.08)
		sizes.Scarf2 = Vector3.new(0.68, 0.86, 0.08)
		sizes.Scarf3 = Vector3.new(0.62, 0.86, 0.08)
		sizes.Scarf4 = Vector3.new(0.54, 0.86, 0.08)
	end
	local model = Instance.new("Model")
	model.Name = name
	local base = CFrame.new(position)
	local parts = {}
	local function cf(t: { number }): any
		return CFrame.new(t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12])
	end
	local function walk(node: any, parentName: string?)
		local n = node.jname
		local size = sizes[n]
		if size then
			local p = Instance.new("Part")
			p.Name = n
			p.Size = size
			p.CFrame = base * cf(node.transform)
			p.Anchored = false
			p.CanCollide = n == "HumanoidRootPart"
			p.Transparency = if n == "HumanoidRootPart" then 1 else 0
			p.Color = if n == "Head" then Color3.fromRGB(200, 170, 140) else Color3.fromRGB(90, 96, 110)
			p.Parent = model
			parts[n] = p
			if parentName and parts[parentName] then
				local m = Instance.new("Motor6D")
				m.Name = node.jointName
				m.Part0 = parts[parentName]
				m.Part1 = p
				m.C0 = cf(node.jointtransform0)
				m.C1 = cf(node.jointtransform1)
				m.Parent = p
			end
			for _, c in node.children or {} do
				walk(c, n)
			end
		end
	end
	walk(meta.rig, nil)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	model.PrimaryPart = parts.HumanoidRootPart
	if withExtras then
		parts.HumanoidRootPart.Anchored = true
		local saves = Instance.new("ObjectValue")
		saves.Name = "AnimSaves"
		saves.Parent = model
		for _, kfs in keyframeSequences():GetChildren() do
			kfs.Parent = saves
		end
	end
	return model
end

local function testPlace(): any
	local game = Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local lighting = game:GetService("Lighting")
	local starterPlayer = game:GetService("StarterPlayer")

	lighting.ClockTime = 17.6
	lighting.Brightness = 1.4
	lighting.Ambient = Color3.fromRGB(40, 36, 52)
	lighting.OutdoorAmbient = Color3.fromRGB(90, 86, 110)
	lighting.Technology = Enum.Technology.Future
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Color = Color3.fromRGB(150, 140, 170)
	atmosphere.Decay = Color3.fromRGB(80, 70, 110)
	atmosphere.Parent = lighting

	starterPlayer.GameSettingsAvatar = Enum.GameAvatarType.R15
	starterPlayer.CharacterWalkSpeed = 16

	part({ Name = "Baseplate", Size = Vector3.new(1024, 16, 1024), CFrame = CFrame.new(0, -8, 0),
		Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 68, 76) }).Parent = workspace
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Neutral = true
	spawn.Parent = workspace
	for i, dist in { 18, 40, 70, 110 } do
		local a = math.rad(i * 70)
		local d = dummy(`Dummy{dist}`, Vector3.new(math.sin(a) * dist, 3.1, -math.cos(a) * dist))
		d.Parent = workspace
	end
	local rig = dummy("EmberRig", Vector3.new(-12, 3.1, 8), true)
	rig.Parent = workspace
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		part({ Name = "Pillar", Size = Vector3.new(4, 26, 4), CFrame = CFrame.new(math.cos(a) * 150, 13, math.sin(a) * 150),
			Material = Enum.Material.Basalt, Color = Color3.fromRGB(60, 58, 66) }).Parent = workspace
	end

	ember().Parent = game:GetService("ReplicatedStorage")
	build(SRC .. "/server", "EmberServer").Parent = game:GetService("ServerScriptService")
	build(SRC .. "/client", "EmberClient").Parent = starterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
		or (function()
			local sps = Instance.new("StarterPlayerScripts")
			sps.Parent = starterPlayer
			return sps
		end)()
	return game
end

local function kit(): any
	local root = Instance.new("Folder")
	root.Name = "EmberAbilities"
	local rs = Instance.new("Folder")
	rs.Name = "ReplicatedStorage"
	ember().Parent = rs
	rs.Parent = root
	local sss = Instance.new("Folder")
	sss.Name = "ServerScriptService"
	build(SRC .. "/server", "EmberServer").Parent = sss
	sss.Parent = root
	local sps = Instance.new("Folder")
	sps.Name = "StarterPlayerScripts"
	build(SRC .. "/client", "EmberClient").Parent = sps
	sps.Parent = root
	return root
end

fs.writeDir(OUT)
fs.writeFile(OUT .. "/EmberAbilities.rbxm", roblox.serializeModel({ kit() }, false))
fs.writeFile(OUT .. "/EmberAbilities_Test.rbxl", roblox.serializePlace(testPlace(), false))

-- relê e confere
local model = roblox.deserializeModel(fs.readFile(OUT .. "/EmberAbilities.rbxm"))[1]
local scripts, kfs = 0, 0
for _, d in model:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	elseif d.ClassName == "KeyframeSequence" then
		kfs += 1
	end
end
local place = roblox.deserializePlace(fs.readFile(OUT .. "/EmberAbilities_Test.rbxl"))
local ok = place:GetService("ReplicatedStorage"):FindFirstChild("Ember") ~= nil
	and place:GetService("ServerScriptService"):FindFirstChild("EmberServer") ~= nil
assert(ok, "place sem os scripts")
print(`kit: {scripts} scripts, {kfs} KeyframeSequence(s); place de teste ok`)

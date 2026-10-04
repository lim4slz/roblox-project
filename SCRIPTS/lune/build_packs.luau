--!strict
-- Monta a pasta que vai pro comprador em EXPORT/packs/ATOMIC_ECLIPSE/:
--   1_Animation_Only, 2_Animation_With_Sword, 3_Full_Ability, Demo, Preview e README.txt
-- Os scripts que vão na pasta saem com comentários e mensagens em inglês (ROBLOX/packs/english.luau).
-- Rode depois do build_kit.luau.
--   lune run SCRIPTS/lune/build_packs.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local luau = require("@lune/luau")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3
local ColorSequence = roblox.ColorSequence
local NumberSequence = roblox.NumberSequence
local Enum = roblox.Enum

local ROOT = process.cwd
local ANIM = "ANIM_01_ATOMIC_ECLIPSE"
local NAME = "AtomicEclipse"
local OUT = `{ROOT}/EXPORT/packs/ATOMIC_ECLIPSE`

local english = luau.load(fs.readFile(`{ROOT}/ROBLOX/packs/english.luau`))()

local R15 = {
	HumanoidRootPart = true, LowerTorso = true, UpperTorso = true, Head = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local function translate(source: string): string
	local out = {}
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		local indent, body = string.match(line, "^(%s*)(.-)%s*$")
		local en = english[body]
		table.insert(out, if en then indent .. en else line)
	end
	if out[#out] == "" then
		table.remove(out)
	end
	return table.concat(out, "\n")
end

local PORTUGUESE = { "[ãõçáéíóúâêôàÃÕÇÁÉÍÓÚÂÊÔ]", " não ", " pra ", " com ", " uma ", " quando ", " aqui ", " então " }

local function englishScripts(root: any): number
	local list = if root:IsA("LuaSourceContainer") then { root } else {}
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			table.insert(list, d)
		end
	end
	for _, s in list do
		s.Source = translate(s.Source)
		for _, pattern in PORTUGUESE do
			local at = string.find(s.Source, pattern)
			if at then
				local before = string.match(string.sub(s.Source, 1, at), "[^\n]*$") or ""
				local after = string.match(string.sub(s.Source, at + 1), "^[^\n]*") or ""
				error(`sobrou português em {s:GetFullName()}: {before}{after}`)
			end
		end
	end
	return #list
end

local function loadSequence(): any
	local kfs = roblox.deserializeModel(fs.readFile(`{ROOT}/EXPORT/KeyframeSequences/{ANIM}.rbxm`))[1]
	assert(kfs.ClassName == "KeyframeSequence", "o .rbxm da animação não tem KeyframeSequence")
	kfs.Name = "ATOMIC_ECLIPSE"
	return kfs
end

local function keepPoses(kfs: any, extra: { [string]: boolean })
	local drop = {}
	for _, d in kfs:GetDescendants() do
		if d.ClassName == "Pose" and not R15[d.Name] and not extra[d.Name] then
			table.insert(drop, d)
		end
	end
	for _, d in drop do
		d.Parent = nil
	end
end

local function part(name: string, size: any, color: any, material: any): any
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(a: any, b: any, offset: any)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = offset
	w.Parent = b
end

-- mesma espada do Rig.luau, montada uma vez só
local function sword(): any
	local length = 5.2
	local blade = part("EmberBlade", Vector3.new(0.14, 0.32, length), Color3.fromRGB(22, 18, 30), Enum.Material.Metal)

	local edge = part("Edge", Vector3.new(0.05, 0.1, length * 0.94), Color3.fromRGB(150, 70, 255), Enum.Material.Neon)
	edge.CastShadow = false
	edge.Parent = blade
	weld(blade, edge, CFrame.new(0, -0.32 / 2 + 0.03, -length * 0.03))

	local guard = part("Guard", Vector3.new(0.5, 0.5, 0.12), Color3.fromRGB(40, 32, 52), Enum.Material.Metal)
	guard.Parent = blade
	weld(blade, guard, CFrame.new(0, 0, length / 2 - 0.55))

	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, 0, -0.9)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = Vector3.new(0, 0, -2.5)
	a1.Parent = blade
	local trail = Instance.new("Trail")
	trail.Name = "BladeTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.22
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = false
	trail.Enabled = false
	trail.Color = ColorSequence.new(Color3.fromRGB(205, 160, 255), Color3.fromRGB(150, 70, 255))
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = blade

	local grip = Instance.new("Motor6D")
	grip.Name = "EmberBladeGrip"
	grip.Part1 = blade
	grip.C0 = CFrame.new(0, -0.029954, 0)
	grip.C1 = CFrame.new(0, 0, 2.1)
	grip.Parent = blade
	return blade
end

local function attachScript(): any
	local s = Instance.new("Script")
	s.Name = "AttachSword"
	s.Source = fs.readFile(`{ROOT}/ROBLOX/packs/AttachSword.server.luau`)
	sword().Parent = s
	return s
end

local function poseNames(kfs: any): { [string]: boolean }
	local names = {}
	for _, d in kfs:GetDescendants() do
		if d.ClassName == "Pose" then
			names[d.Name] = true
		end
	end
	return names
end

local function count(root: any, class: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d.ClassName == class then
			n += 1
		end
	end
	return n
end

local function write(dir: string, file: string, data: string)
	fs.writeDir(`{OUT}/{dir}`)
	fs.writeFile(`{OUT}/{dir}/{file}`, data)
end

if fs.isDir(OUT) then
	fs.removeDir(OUT)
end
fs.writeDir(OUT)

-- 1. só a animação
local plain = loadSequence()
keepPoses(plain, {})
write("1_Animation_Only", `{NAME}_Animation.rbxm`, roblox.serializeModel({ plain }, false))

-- 2. animação + espada, numa pasta só (o Lune quebra ao salvar lado a lado instância lida de arquivo e instância nova)
local swordPack = Instance.new("Folder")
swordPack.Name = "ATOMIC_ECLIPSE_Sword"
local withSword = loadSequence()
keepPoses(withSword, { EmberBlade = true })
withSword.Parent = swordPack
attachScript().Parent = swordPack
englishScripts(swordPack)
write("2_Animation_With_Sword", `{NAME}_Animation_Sword.rbxm`, roblox.serializeModel({ swordPack }, false))

-- 3. habilidade completa
local kitPath = `{ROOT}/ROBLOX/build/EmberAbilities.rbxm`
assert(fs.isFile(kitPath), "rode o build_kit.luau antes")
local kit = roblox.deserializeModel(fs.readFile(kitPath))[1]
local kitScripts = englishScripts(kit)
write("3_Full_Ability", `{NAME}_Full.rbxm`, roblox.serializeModel({ kit }, false))

-- demo
local place = roblox.deserializePlace(fs.readFile(`{ROOT}/ROBLOX/build/EmberAbilities_Test.rbxl`))
local rig = place:GetService("Workspace"):FindFirstChild("EmberRig")
if rig then
	rig.Name = "AnimationRig"
end
for _, service in place:GetChildren() do
	englishScripts(service)
end
write("Demo", `{NAME}_Demo.rbxl`, roblox.serializePlace(place, false))

-- vídeo e README
local video = `{ROOT}/REFERENCE/{ANIM}/{ANIM}_previs.mp4`
if fs.isFile(video) then
	write("Preview", `{NAME}_Preview.mp4`, fs.readFile(video))
end
fs.writeFile(`{OUT}/README.txt`, fs.readFile(`{ROOT}/ROBLOX/packs/README_ATOMIC_ECLIPSE.txt`))

-- relê tudo
local original = loadSequence()
local frames = #original:GetChildren()
local markers = count(original, "KeyframeMarker")

local a = roblox.deserializeModel(fs.readFile(`{OUT}/1_Animation_Only/{NAME}_Animation.rbxm`))
assert(#a == 1 and a[1].ClassName == "KeyframeSequence", "pacote só animação errado")
assert(#a[1]:GetChildren() == frames and count(a[1], "KeyframeMarker") == markers, "keyframes ou markers sumiram")
local joints = 0
for name in poseNames(a[1]) do
	assert(R15[name], `junta fora do R15 no pacote só animação: {name}`)
	joints += 1
end

local b = roblox.deserializeModel(fs.readFile(`{OUT}/2_Animation_With_Sword/{NAME}_Animation_Sword.rbxm`))
assert(#b == 1 and b[1].ClassName == "Folder", "pacote com espada devia ser uma pasta")
local seq, script
for _, inst in b[1]:GetChildren() do
	if inst.ClassName == "KeyframeSequence" then
		seq = inst
	elseif inst.ClassName == "Script" then
		script = inst
	end
end
assert(seq and script, "pacote com espada sem KeyframeSequence ou script")
assert(#seq:GetChildren() == frames and count(seq, "KeyframeMarker") == markers, "keyframes ou markers sumiram")
assert(poseNames(seq).EmberBlade, "pacote com espada sem a junta EmberBlade")
for name in poseNames(seq) do
	assert(R15[name] or name == "EmberBlade", `junta sobrando no pacote com espada: {name}`)
end
local blade = script:FindFirstChild("EmberBlade")
local grip = blade and blade:FindFirstChild("EmberBladeGrip")
assert(grip and grip.Part1 == blade, "Motor6D da espada não aponta pra lâmina")
for _, w in blade:GetDescendants() do
	if w.ClassName == "Weld" then
		assert(w.Part0 == blade and w.Part1 == w.Parent, "weld da espada solto")
	end
end

local c = roblox.deserializeModel(fs.readFile(`{OUT}/3_Full_Ability/{NAME}_Full.rbxm`))[1]
assert(count(c, "KeyframeSequence") >= 1, "pacote completo sem animação")
for _, pair in { { "ReplicatedStorage", "Ember" }, { "ServerScriptService", "EmberServer" }, { "StarterPlayerScripts", "EmberClient" } } do
	local folder = c:FindFirstChild(pair[1])
	assert(folder and folder:FindFirstChild(pair[2]), `pacote completo sem {pair[1]}/{pair[2]}`)
end

local d = roblox.deserializePlace(fs.readFile(`{OUT}/Demo/{NAME}_Demo.rbxl`))
assert(d:GetService("ReplicatedStorage"):FindFirstChild("Ember"), "demo sem Ember")
assert(d:GetService("ServerScriptService"):FindFirstChild("EmberServer"), "demo sem EmberServer")
assert(d:GetService("Workspace"):FindFirstChild("AnimationRig"), "demo sem AnimationRig")

print(`ATOMIC_ECLIPSE: {frames} keyframes, {markers} markers`)
print(`  1_Animation_Only        {joints} juntas do R15`)
print(`  2_Animation_With_Sword  espada + AttachSword ok`)
print(`  3_Full_Ability          {kitScripts} scripts em inglês`)
print(`  Demo                    place ok`)
print(`  Preview                 {if fs.isFile(video) then "copiado" else "ainda não existe"}`)

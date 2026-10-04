--!strict
-- Monta os pacotes de venda de uma habilidade em EXPORT/packs/<NOME>/:
--   <NOME>_Animation.rbxm        só a animação, juntas padrão do R15
--   <NOME>_Animation_Sword.rbxm  animação com a junta da espada + espada + script que encaixa
--   <NOME>_Full.rbxm             habilidade completa (cópia do kit)
-- Rode depois do build_kit.luau.
--   lune run SCRIPTS/lune/build_packs.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3
local ColorSequence = roblox.ColorSequence
local NumberSequence = roblox.NumberSequence
local Enum = roblox.Enum

local ROOT = process.cwd
local ANIM = "ANIM_01_ATOMIC_ECLIPSE"
local PACK = "ATOMIC_ECLIPSE"
local OUT = `{ROOT}/EXPORT/packs/{PACK}`

local R15 = {
	HumanoidRootPart = true, LowerTorso = true, UpperTorso = true, Head = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local function loadSequence(): any
	local kfs = roblox.deserializeModel(fs.readFile(`{ROOT}/EXPORT/KeyframeSequences/{ANIM}.rbxm`))[1]
	assert(kfs.ClassName == "KeyframeSequence", "o .rbxm da animação não tem KeyframeSequence")
	kfs.Name = PACK
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

fs.writeDir(OUT)

local plain = loadSequence()
keepPoses(plain, {})
fs.writeFile(`{OUT}/{PACK}_Animation.rbxm`, roblox.serializeModel({ plain }, false))

-- numa pasta só: o Lune quebra ao salvar lado a lado instância lida de arquivo e instância nova
local swordPack = Instance.new("Folder")
swordPack.Name = `{PACK}_Sword`
local withSword = loadSequence()
keepPoses(withSword, { EmberBlade = true })
withSword.Parent = swordPack
attachScript().Parent = swordPack
fs.writeFile(`{OUT}/{PACK}_Animation_Sword.rbxm`, roblox.serializeModel({ swordPack }, false))

local kit = `{ROOT}/ROBLOX/build/EmberAbilities.rbxm`
assert(fs.isFile(kit), "rode o build_kit.luau antes")
fs.writeFile(`{OUT}/{PACK}_Full.rbxm`, fs.readFile(kit))

fs.writeFile(`{OUT}/README.md`, fs.readFile(`{ROOT}/ROBLOX/packs/README_ATOMIC_ECLIPSE.md`))
local video = `{ROOT}/REFERENCE/{ANIM}/{ANIM}_previs.mp4`
if fs.isFile(video) then
	fs.writeFile(`{OUT}/{PACK}_preview.mp4`, fs.readFile(video))
end

-- relê tudo
local original = loadSequence()
local frames = #original:GetChildren()
local markers = count(original, "KeyframeMarker")

local a = roblox.deserializeModel(fs.readFile(`{OUT}/{PACK}_Animation.rbxm`))
assert(#a == 1 and a[1].ClassName == "KeyframeSequence", "pacote só animação errado")
assert(#a[1]:GetChildren() == frames and count(a[1], "KeyframeMarker") == markers, "keyframes ou markers sumiram")
for name in poseNames(a[1]) do
	assert(R15[name], `junta fora do R15 no pacote só animação: {name}`)
end

local b = roblox.deserializeModel(fs.readFile(`{OUT}/{PACK}_Animation_Sword.rbxm`))
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

local c = roblox.deserializeModel(fs.readFile(`{OUT}/{PACK}_Full.rbxm`))[1]
local scripts = 0
for _, d in c:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	end
end
assert(count(c, "KeyframeSequence") >= 1 and scripts > 0, "pacote completo vazio")

print(`{PACK}: {frames} keyframes, {markers} markers`)
local joints = 0
for _ in poseNames(a[1]) do
	joints += 1
end
print(`  _Animation        {joints} juntas do R15`)
print(`  _Animation_Sword  espada + AttachSword ok`)
print(`  _Full             {scripts} scripts`)
print(`  preview           {if fs.isFile(video) then "copiado" else "ainda não existe"}`)

-- Adiciona as partes extras (lâmina e cachecol) com os mesmos C0/C1 do rig do Blender.
-- Roda no servidor quando o personagem nasce.

local Palette = require(script.Parent.Palette)
local RigData = require(script.Parent.RigData)

local Rig = {}

Rig.Default = { "EmberBlade", "Scarf1", "Scarf2", "Scarf3", "Scarf4" }

local function basePart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function dressBlade(blade: Part, edge: Color3)
	blade.Material = Enum.Material.Metal
	blade.Color = Color3.fromRGB(22, 18, 30)
	local length = blade.Size.Z

	local glow = basePart("Edge", Vector3.new(0.05, 0.1, length * 0.94))
	glow.Material = Enum.Material.Neon
	glow.Color = edge
	glow.CastShadow = false
	glow.CFrame = blade.CFrame * CFrame.new(0, -blade.Size.Y / 2 + 0.03, -length * 0.03)
	glow.Parent = blade
	weld(blade, glow)

	local guard = basePart("Guard", Vector3.new(0.5, 0.5, 0.12))
	guard.Material = Enum.Material.Metal
	guard.Color = Color3.fromRGB(40, 32, 52)
	guard.CFrame = blade.CFrame * CFrame.new(0, 0, length / 2 - 0.55)
	guard.Parent = blade
	weld(blade, guard)

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
	trail.Color = ColorSequence.new(Palette.LILAC, Palette.VIOLET)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = blade
end

function Rig.augment(character: Model, include: { string }?)
	local wanted = {}
	for _, n in include or Rig.Default do
		wanted[n] = true
	end
	for _, def in RigData do
		if not wanted[def.name] or character:FindFirstChild(def.name) then
			continue
		end
		local parent = character:FindFirstChild(def.parent)
		if parent == nil or not parent:IsA("BasePart") then
			continue
		end
		local p = basePart(def.name, def.size)
		if string.find(def.name, "Blade") then
			p.CFrame = parent.CFrame * def.c0 * def.c1:Inverse()
			dressBlade(p, if def.name == "AzureBlade" then Palette.AZURE else Palette.VIOLET)
		else
			p.Material = Enum.Material.Fabric
			p.Color = Color3.fromRGB(96, 18, 32)
			p.CFrame = parent.CFrame * def.c0 * def.c1:Inverse()
		end
		p.Parent = character
		local m = Instance.new("Motor6D")
		m.Name = def.joint
		m.Part0 = parent
		m.Part1 = p
		m.C0 = def.c0
		m.C1 = def.c1
		m.Parent = p
	end
end

function Rig.setTrail(character: Model, on: boolean, colors: { Color3 }?)
	local blade = character:FindFirstChild("EmberBlade")
	local trail = blade and blade:FindFirstChild("BladeTrail")
	if trail and trail:IsA("Trail") then
		if colors and #colors >= 2 then
			trail.Color = ColorSequence.new(colors[1], colors[2])
		end
		trail.Enabled = on
	end
end

return Rig

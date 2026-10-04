local Workspace = game:GetService("Workspace")

local Anchors = require(script.Parent.Parent.Anchors)
local Util = require(script.Parent.Parent.Util)
local Pool = require(script.Parent.Pool)
local Ring = require(script.Parent.Ring)

local Specials = {}

local function beam(a0: Attachment, a1: Attachment, width: number, color: Color3): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.Segments = 1
	b.Width0 = width
	b.Width1 = width
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = 3
	b.Color = ColorSequence.new(color)
	b.Parent = a0
	return b
end

local function terrainAttachment(): Attachment
	local a = Instance.new("Attachment")
	a.Name = "EmberFX"
	a.Parent = Workspace.Terrain
	return a
end

local function fadeWindow(age: number, life: number, fadeIn: number, fadeOut: number): number
	if age < fadeIn then
		return age / fadeIn
	end
	if age > life - fadeOut then
		return math.max(0, (life - age) / fadeOut)
	end
	return 1
end

local function setTransparency(beams: { Beam }, t: number)
	local seq = NumberSequence.new(math.clamp(t, 0, 1))
	for _, b in beams do
		b.Transparency = seq
	end
end

local function base(layer, ctx, t0, anchor)
	return {
		layer = layer,
		ctx = ctx,
		anchor = layer.anchor or anchor,
		t0 = t0 + (layer.delay or 0),
		life = layer.duration or layer.lifetime or 2,
		cleanup = {},
	}
end

local function destroyAll(self)
	for _, inst in self.cleanup do
		if typeof(inst) == "Instance" then
			inst:Destroy()
		elseif type(inst) == "function" then
			inst()
		end
	end
	table.clear(self.cleanup)
end

-- Círculo mágico no chão --------------------------------------------------------
local Sigil = {}
Sigil.__index = Sigil

function Sigil.new(layer, ctx, t0, anchor)
	local self = setmetatable(base(layer, ctx, t0, anchor), Sigil)
	self.center = Anchors.position(ctx.character, self.anchor)
	self.center = Vector3.new(self.center.X, Anchors.ground(ctx.character) + 0.05, self.center.Z)
	self.implodeAt = layer.implode_at
	return self
end

function Sigil:build()
	local layer = self.layer
	local R = layer.radius or 8
	local color = Util.color(layer.color or "VIOLET", self.ctx.palette)
	local w = 0.16 * math.sqrt(R / 8)
	self.rings = {}
	for i = 1, layer.rings or 3 do
		local atts, beams = Ring.build(if R > 12 then 12 else 10)
		local radius = R * ({ 1, 0.86, 0.6, 0.45 })[i]
		for _, b in beams do
			b.Width0, b.Width1 = w * (i == 1 and 1.4 or 1), w * (i == 1 and 1.4 or 1)
			b.Color = ColorSequence.new(color)
		end
		table.insert(self.rings, { atts = atts, beams = beams, radius = radius, dir = if i % 2 == 0 then -1 else 1 })
		for _, a in atts do
			table.insert(self.cleanup, a)
		end
	end
	self.lines = {}
	local function line(r0, a0, r1, a1, width)
		local p, q = terrainAttachment(), terrainAttachment()
		local b = beam(p, q, width, color)
		table.insert(self.lines, { p = p, q = q, b = b, r0 = r0, a0 = a0, r1 = r1, a1 = a1 })
		table.insert(self.cleanup, p)
		table.insert(self.cleanup, q)
	end
	local spokes = layer.spokes or 12
	for i = 0, spokes - 1 do
		local a = i / spokes * math.pi * 2
		line(R * 0.6, a, R * 0.86, a, w * 0.8)
		line(R * 0.9, a + math.pi / spokes * 0.6, R * 0.97, a + math.pi / spokes * 1.4, w * 0.6)
	end
	for k = 0, 5 do
		local a, b = k / 6 * math.pi * 2, (k + 2) / 6 * math.pi * 2
		line(R * 0.58, a, R * 0.58, b, w * 0.9)
	end
	self.allBeams = {}
	for _, r in self.rings do
		for _, b in r.beams do
			table.insert(self.allBeams, b)
		end
	end
	for _, l in self.lines do
		table.insert(self.allBeams, l.b)
	end
end

function Sigil:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	local life = self.life
	local implodeAge = if self.implodeAt then self.implodeAt - self.t0 else nil
	local scale, alpha
	if implodeAge and age >= implodeAge then
		local k = (age - implodeAge) / 0.25
		if k >= 1 then
			self:destroy()
			return false
		end
		scale, alpha = 1 - k, 1
	else
		if age >= life then
			self:destroy()
			return false
		end
		local appear = math.min(1, age / 0.5)
		scale = 1 - (1 - appear) ^ 3
		alpha = fadeWindow(age, life, 0.5, 0.4)
	end
	if self.rings == nil then
		self:build()
	end
	local spin = math.rad((self.layer.spin or 20) * age)
	local frame = CFrame.new(self.center)
	for _, r in self.rings do
		Ring.place(r.atts, r.beams, frame, math.max(0.05, r.radius * scale), spin * r.dir)
	end
	for _, l in self.lines do
		local p = Vector3.new(math.cos(l.a0 + spin), 0, math.sin(l.a0 + spin)) * l.r0 * scale
		local q = Vector3.new(math.cos(l.a1 + spin), 0, math.sin(l.a1 + spin)) * l.r1 * scale
		l.p.WorldPosition = self.center + p
		l.q.WorldPosition = self.center + q
	end
	setTransparency(self.allBeams, 1 - 0.85 * alpha)
	return true
end

function Sigil:destroy()
	destroyAll(self)
end

-- Linhas de energia subindo pelo corpo -----------------------------------------
local Circuits = {}
Circuits.__index = Circuits

local PATHS = {
	{ "LeftFoot", "LeftLowerLeg", "LeftUpperLeg", "LowerTorso", "UpperTorso", "Head" },
	{ "RightFoot", "RightLowerLeg", "RightUpperLeg", "LowerTorso", "UpperTorso" },
	{ "LeftHand", "LeftLowerArm", "LeftUpperArm", "UpperTorso" },
	{ "RightHand", "RightLowerArm", "RightUpperArm", "UpperTorso" },
	{ "LowerTorso", "UpperTorso", "Head" },
	{ "LeftUpperLeg", "LowerTorso", "UpperTorso", "RightUpperArm" },
}

function Circuits.new(layer, ctx, t0, anchor)
	return setmetatable(base(layer, ctx, t0, anchor), Circuits)
end

function Circuits:build()
	local character = self.ctx.character
	local color = Util.color(self.layer.color or "VIOLET", self.ctx.palette)
	local rng = Random.new(self.ctx.seed)
	self.lines = {}
	for i = 1, math.min(self.layer.count or 6, #PATHS) do
		local side = if i % 2 == 0 then 1 else -1
		local atts = {}
		for _, name in PATHS[i] do
			local p = character:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				for k = 1, 2 do
					local a = Instance.new("Attachment")
					a.Name = "EmberCircuit"
					a.Position = Vector3.new(
						rng:NextNumber(-0.35, 0.35) * p.Size.X,
						(k == 1 and -0.4 or 0.4) * p.Size.Y,
						side * (p.Size.Z / 2 + 0.03)
					)
					a.Parent = p
					table.insert(atts, a)
					table.insert(self.cleanup, a)
				end
			end
		end
		local beams = {}
		for k = 1, #atts - 1 do
			table.insert(beams, beam(atts[k], atts[k + 1], 0.07, color))
		end
		table.insert(self.lines, { beams = beams, speed = rng:NextNumber(0.6, 1.1), phase = rng:NextNumber() })
	end
end

function Circuits:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	if age >= self.life then
		self:destroy()
		return false
	end
	if self.lines == nil then
		self:build()
	end
	local k = fadeWindow(age, self.life, 0.6, 0.3)
	for _, line in self.lines do
		local n = #line.beams
		local head = ((age * line.speed + line.phase) % 1.4) * n
		for i, b in line.beams do
			local d = head - i
			local lit = if d >= 0 and d < 3 then 1 - d / 3 else 0
			b.Transparency = NumberSequence.new(math.clamp(1 - k * (0.25 + 0.75 * lit), 0, 1))
		end
	end
	return true
end

function Circuits:destroy()
	destroyAll(self)
end

-- Fitas em hélice ao redor do corpo --------------------------------------------
local Helix = {}
Helix.__index = Helix

function Helix.new(layer, ctx, t0, anchor)
	return setmetatable(base(layer, ctx, t0, anchor), Helix)
end

function Helix:build()
	local color = Util.color(self.layer.color or "VIOLET", self.ctx.palette)
	local core = self.ctx.palette.CORE
	self.ribbons = {}
	for i = 1, self.layer.count or 3 do
		local a0, a1 = terrainAttachment(), terrainAttachment()
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Lifetime = 0.45
		t.LightEmission = 1
		t.LightInfluence = 0
		t.FaceCamera = true
		t.Color = ColorSequence.new(core, color)
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		t.Parent = a0
		table.insert(self.ribbons, { a0 = a0, a1 = a1, trail = t, phase = (i - 1) / (self.layer.count or 3) * math.pi * 2 })
		table.insert(self.cleanup, a0)
		table.insert(self.cleanup, a1)
	end
end

function Helix:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	if age >= self.life + 0.5 then
		self:destroy()
		return false
	end
	if self.ribbons == nil then
		self:build()
	end
	local character = self.ctx.character
	local feet = Anchors.ground(character)
	local center = Anchors.position(character, "root")
	local r = self.layer.radius or 3
	local h = self.layer.height or 7
	for _, rb in self.ribbons do
		local a = rb.phase + age * math.pi * 2 * 0.85
		local y = feet + h * (0.5 + 0.45 * math.sin(age * 1.7 + rb.phase))
		local p = Vector3.new(center.X + math.cos(a) * r, y, center.Z + math.sin(a) * r)
		rb.a0.WorldPosition = p + Vector3.new(0, 0.14, 0)
		rb.a1.WorldPosition = p - Vector3.new(0, 0.14, 0)
		rb.trail.Enabled = age < self.life
	end
	return true
end

function Helix:destroy()
	destroyAll(self)
end

-- Orbes orbitando o peito -------------------------------------------------------
local Orbs = {}
Orbs.__index = Orbs

function Orbs.new(layer, ctx, t0, anchor)
	return setmetatable(base(layer, ctx, t0, anchor), Orbs)
end

function Orbs:build()
	local color = Util.color(self.layer.color or "CORE", self.ctx.palette)
	self.items = {}
	local n = self.layer.count or 6
	for i = 1, n do
		local p = Pool.get("ball", "neon")
		p.Color = color
		p.Size = Vector3.one * 0.6
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.2, 0)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.2, 0)
		a1.Parent = p
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Lifetime = 0.3
		t.LightEmission = 1
		t.Color = ColorSequence.new(color, self.ctx.palette.VIOLET)
		t.Transparency = NumberSequence.new(0, 1)
		t.Parent = p
		table.insert(self.items, { part = p, extras = { a0, a1, t }, phase = (i - 1) / n * math.pi * 2, tilt = (i % 3 - 1) * 0.5 })
	end
	local holder = Instance.new("Attachment")
	holder.Parent = Workspace.Terrain
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1.5
	light.Color = self.ctx.palette.LILAC
	light.Parent = holder
	self.holder = holder
	table.insert(self.cleanup, holder)
end

function Orbs:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	if age >= self.life then
		self:destroy()
		return false
	end
	if self.items == nil then
		self:build()
	end
	local center = Anchors.position(self.ctx.character, self.anchor)
	local r = (self.layer.radius or 4) * math.min(1, age / 0.6)
	local k = fadeWindow(age, self.life, 0.4, 0.3)
	for _, it in self.items do
		local a = it.phase + age * 2.2
		local offset = CFrame.Angles(it.tilt, 0, it.tilt * 0.5):VectorToWorldSpace(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		it.part.Transparency = 1 - k
		Pool.move(it.part, CFrame.new(center + offset))
	end
	self.holder.WorldPosition = center
	return true
end

function Orbs:destroy()
	if self.items then
		for _, it in self.items do
			for _, e in it.extras do
				e:Destroy()
			end
			Pool.release(it.part)
		end
		self.items = nil
	end
	destroyAll(self)
end

-- Halo de eclipse atrás das costas -----------------------------------------------
local Halo = {}
Halo.__index = Halo

function Halo.new(layer, ctx, t0, anchor)
	return setmetatable(base(layer, ctx, t0, anchor), Halo)
end

function Halo:build()
	local palette = self.ctx.palette
	local color = Util.color(self.layer.color or "VIOLET", palette)
	self.inner = { Ring.build(12) }
	self.outer = { Ring.build(12) }
	Ring.style(self.inner[2], 0.35, palette.CORE, 0)
	Ring.style(self.outer[2], 0.12, color, 0.2)
	for _, a in self.inner[1] do
		table.insert(self.cleanup, a)
	end
	for _, a in self.outer[1] do
		table.insert(self.cleanup, a)
	end
	local disc = Pool.get("disc", "dark")
	disc.Color = palette.INK
	self.disc = disc
	table.insert(self.cleanup, function()
		Pool.release(disc)
	end)
	self.spikes = {}
	for i = 0, 11 do
		local p, q = terrainAttachment(), terrainAttachment()
		local b = beam(p, q, 0.1, color)
		b.Width1 = 0
		table.insert(self.spikes, { p = p, q = q, b = b, a = i / 12 * math.pi * 2 })
		table.insert(self.cleanup, p)
		table.insert(self.cleanup, q)
	end
end

function Halo:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	if age >= self.life then
		self:destroy()
		return false
	end
	if self.inner == nil then
		self:build()
	end
	local ut = Anchors.cframe(self.ctx.character, self.anchor)
	local center = ut:PointToWorldSpace(Vector3.new(0, 0.7, 1.3))
	local frame = CFrame.fromMatrix(center, ut.RightVector, ut.LookVector)
	local R = (self.layer.radius or 3.6) * (1 - (1 - math.min(1, age / 0.6)) ^ 3)
	local k = fadeWindow(age, self.life, 0.5, 0.25)
	Ring.place(self.inner[1], self.inner[2], frame, math.max(0.05, R), age * 0.6)
	Ring.place(self.outer[1], self.outer[2], frame, math.max(0.05, R * 1.25), -age * 0.9)
	setTransparency(self.inner[2], 1 - k)
	setTransparency(self.outer[2], 1 - 0.8 * k)
	local disc = self.disc :: BasePart
	disc.Size = Vector3.new(0.08, R * 1.9, R * 1.9)
	disc.Transparency = 1 - 0.9 * k
	Pool.move(disc, CFrame.fromMatrix(center, ut.LookVector, ut.UpVector))
	for _, s in self.spikes do
		local a = s.a + age * 0.35
		local dir = frame:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
		s.p.WorldPosition = center + dir * R * 1.05
		s.q.WorldPosition = center + dir * R * (1.4 + 0.08 * math.sin(age * 6 + s.a * 3))
		s.b.Transparency = NumberSequence.new(1 - 0.85 * k)
	end
	return true
end

function Halo:destroy()
	destroyAll(self)
end

-- O ponto da singularidade -------------------------------------------------------
local Point = {}
Point.__index = Point

function Point.new(layer, ctx, t0, anchor)
	return setmetatable(base(layer, ctx, t0, anchor), Point)
end

function Point:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	if age >= self.life then
		self:destroy()
		return false
	end
	if self.core == nil then
		self.core = Pool.get("ball", "neon")
		self.glow = Pool.get("ball", "neon")
		self.core.Color = self.ctx.palette.CORE
		self.glow.Color = self.ctx.palette.LILAC
		local light = Instance.new("PointLight")
		light.Range = 10
		light.Color = self.ctx.palette.CORE
		light.Parent = self.core
		self.light = light
		table.insert(self.cleanup, light)
	end
	local pos = Anchors.position(self.ctx.character, self.anchor)
	local beat = 0.5 + 0.5 * math.sin(age * 9)
	self.core.Size = Vector3.one * (0.28 + 0.06 * beat)
	self.glow.Size = Vector3.one * (1.2 + 0.4 * beat)
	self.glow.Transparency = 0.85
	self.light.Brightness = 2 + 2 * beat
	Pool.move(self.core, CFrame.new(pos))
	Pool.move(self.glow, CFrame.new(pos))
	return true
end

function Point:destroy()
	destroyAll(self)
	if self.core then
		Pool.release(self.core)
		Pool.release(self.glow)
		self.core = nil
	end
end

-- Highlight no personagem --------------------------------------------------------
local Glow = {}
Glow.__index = Glow

function Glow.new(layer, ctx, t0, anchor)
	return setmetatable(base(layer, ctx, t0, anchor), Glow)
end

function Glow:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	if age >= self.life then
		self:destroy()
		return false
	end
	if self.hl == nil then
		local hl = Instance.new("Highlight")
		hl.Adornee = self.ctx.character
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.FillColor = Util.color(self.layer.color or "VIOLET", self.ctx.palette)
		hl.OutlineColor = hl.FillColor
		hl.Parent = self.ctx.character
		self.hl = hl
		table.insert(self.cleanup, hl)
	end
	local k = fadeWindow(age, self.life, 0.3, 0.3)
	self.hl.FillTransparency = 1 - (self.layer.fill or 0.8) * 0.45 * k
	self.hl.OutlineTransparency = 1 - (1 - (self.layer.outline or 0)) * k
	return true
end

function Glow:destroy()
	destroyAll(self)
end

-- Lâmina some/volta ----------------------------------------------------------------
local Blade = {}
Blade.__index = Blade

function Blade.new(layer, ctx, t0, anchor)
	return setmetatable(base(layer, ctx, t0, anchor), Blade)
end

local function bladeParts(character: Model): { BasePart }
	local list = {}
	local blade = character:FindFirstChild("EmberBlade")
	if blade and blade:IsA("BasePart") then
		table.insert(list, blade)
		for _, d in blade:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	return list
end

function Blade:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	local fade = math.max(0.01, self.layer.fade or 0.3)
	local k = math.min(1, age / fade)
	for _, p in bladeParts(self.ctx.character) do
		local original = p:GetAttribute("EmberTransparency")
		if original == nil then
			original = p.Transparency
			p:SetAttribute("EmberTransparency", original)
		end
		if self.layer.visible then
			p.Transparency = 1 - (1 - original) * k
		else
			p.Transparency = original + (1 - original) * k
		end
	end
	return k < 1
end

function Blade:destroy() end

function Blade.restore(character: Model)
	for _, p in bladeParts(character) do
		local original = p:GetAttribute("EmberTransparency")
		if type(original) == "number" then
			p.Transparency = original
		end
	end
end

-- PointLight -----------------------------------------------------------------------
local Light = {}
Light.__index = Light

function Light.new(layer, ctx, t0, anchor)
	local self = setmetatable(base(layer, ctx, t0, anchor), Light)
	self.life = layer.lifetime or 0.5
	return self
end

function Light:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	if age >= self.life then
		self:destroy()
		return false
	end
	if self.holder == nil then
		local a = terrainAttachment()
		local l = Instance.new("PointLight")
		l.Range = math.min(60, self.layer.range or 16)
		l.Shadows = false
		l.Parent = a
		self.holder, self.light = a, l
		table.insert(self.cleanup, a)
	end
	local u = age / self.life
	self.holder.WorldPosition = Anchors.position(self.ctx.character, self.anchor) + Util.vec(self.layer.offset)
	self.light.Brightness = Util.curve(self.layer.brightness or { { 0, 1 }, { 1, 0 } }, u) * 3
	self.light.Color = Util.colorAt(self.layer.color or "VIOLET", u, self.ctx.palette)
	return true
end

function Light:destroy()
	destroyAll(self)
end

Specials.sigil = Sigil
Specials.circuits = Circuits
Specials.helix = Helix
Specials.orbs = Orbs
Specials.halo = Halo
Specials.point = Point
Specials.highlight = Glow
Specials.blade = Blade
Specials.light = Light

return Specials

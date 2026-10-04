local Anchors = require(script.Parent.Parent.Anchors)
local Util = require(script.Parent.Parent.Util)
local Pool = require(script.Parent.Pool)

-- um objeto só, parado no lugar (ou seguindo o anchor), tocando as curvas
local Animate = {}
Animate.__index = Animate

function Animate.new(layer, ctx, t0: number, anchor: string)
	local self = setmetatable({}, Animate)
	self.layer = layer
	self.ctx = ctx
	self.anchor = layer.anchor or anchor
	self.t0 = t0 + (layer.delay or 0)
	self.life = math.max(0.05, layer.lifetime or 1)
	self.loops = layer.loops or 1
	self.shape = layer.shape or "hiball"
	self.offset = Util.vec(layer.offset)
	self.follow = (layer.link or "follow") == "follow"
	self.fixed = Anchors.position(ctx.character, self.anchor)
	self.spin = Util.vec(layer.spin)
	self.tilt = Util.vec(layer.orient)
	self.drift = Util.vec(layer.drift)
	return self
end

function Animate:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	local total = self.life * self.loops
	if age >= total then
		self:destroy()
		return false
	end
	if self.part == nil then
		self.part = Pool.get(self.shape, self.layer.look or "neon")
	end
	local layer = self.layer
	local u = if self.loops > 1 then (age / self.life) % 1 else age / self.life
	local sx, sy, sz
	if layer.size_xyz then
		sx = Util.curve(layer.size_xyz[1], u)
		sy = Util.curve(layer.size_xyz[2], u)
		sz = Util.curve(layer.size_xyz[3], u)
	else
		local s = Util.curve(layer.size or 1, u)
		sx, sy, sz = s, s, s
	end
	local base = if self.follow then Anchors.position(self.ctx.character, self.anchor) else self.fixed
	local pos = base + self.offset + self.drift * age
	local rot = self.tilt + self.spin * age
	local cf = CFrame.new(pos) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	local size = Vector3.new(sx, sy, sz)
	if Pool.isCylinder(self.shape) then
		cf *= Pool.UPRIGHT
		size = Vector3.new(sy, sx, sz)
		if self.shape == "disc" then
			size = Vector3.new(math.max(0.05, sy * 0.05), sx, sz)
		end
	end
	local part = self.part :: BasePart
	part.Size = size
	part.Color = Util.colorAt(layer.color or "CORE", u, self.ctx.palette)
	part.Transparency = math.clamp(Util.curve(layer.transparency or 0, u), 0, 1)
	Pool.move(part, cf)
	return true
end

function Animate:destroy()
	if self.part then
		Pool.release(self.part)
		self.part = nil
	end
end

return Animate

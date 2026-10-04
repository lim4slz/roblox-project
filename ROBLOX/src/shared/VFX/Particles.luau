local Anchors = require(script.Parent.Parent.Anchors)
local Util = require(script.Parent.Parent.Util)
local Pool = require(script.Parent.Pool)

local Particles = {}
Particles.__index = Particles

Particles.alive = 0

local DIRS = {
	up = Vector3.yAxis,
	down = -Vector3.yAxis,
	forward = -Vector3.zAxis,
	back = Vector3.zAxis,
}

local function spawnTimes(layer, quality: number, rng: Random): { number }
	local times = {}
	local delay = layer.delay or 0
	local count = math.floor((layer.count or 0) * quality + 0.5)
	for _ = 1, count do
		table.insert(times, delay)
	end
	local rate, duration = (layer.rate or 0) * quality, layer.duration or 0
	if rate > 0 and duration > 0 then
		local n = math.floor(rate * duration)
		for i = 0, n - 1 do
			table.insert(times, delay + (i + rng:NextNumber()) / rate)
		end
	end
	table.sort(times)
	return times
end

local function spawnOffset(sp, rng: Random): (Vector3, Vector3?)
	if sp == nil then
		return Vector3.zero, nil
	end
	local shape = sp.shape or "point"
	local r = sp.radius or 0
	local r0, r1
	if type(r) == "table" then
		r0, r1 = r[1], r[2]
	elseif shape == "sphere" or shape == "disc" then
		r0, r1 = 0, r
	else
		r0, r1 = r, r
	end
	if shape == "box" then
		local b = sp.box or { 1, 1, 1 }
		return Vector3.new(rng:NextNumber(-0.5, 0.5) * b[1], rng:NextNumber(-0.5, 0.5) * b[2], rng:NextNumber(-0.5, 0.5) * b[3]), nil
	elseif shape == "sphere" or shape == "shell" then
		local d = Util.randomUnit(rng)
		if sp.upper then
			d = Vector3.new(d.X, math.abs(d.Y), d.Z)
		end
		local rad = if shape == "shell" then r1 else rng:NextNumber(r0, r1)
		return d * rad, d
	elseif shape == "vring" then
		local a = rng:NextNumber(0, math.pi * 2)
		local d = Vector3.new(math.cos(a), math.sin(a), 0)
		return d * rng:NextNumber(r0, r1), d
	elseif shape == "disc" or shape == "ring" then
		local a = rng:NextNumber(0, math.pi * 2)
		local rad = if shape == "disc" then math.sqrt(rng:NextNumber(r0 * r0, r1 * r1)) else rng:NextNumber(r0, r1)
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		return d * rad + Vector3.new(0, sp.height or 0, 0), d
	end
	return Vector3.zero, nil
end

local function direction(layer, off: Vector3, radial: Vector3?, rng: Random): Vector3
	local d = layer.dir or "up"
	local base: Vector3
	if d == "out" or d == "in" then
		local r = radial or (off.Magnitude > 1e-4 and off.Unit or Vector3.xAxis)
		if d == "in" then
			base = -r
		else
			local flat = Vector3.new(r.X, 0, r.Z)
			flat = flat.Magnitude > 1e-4 and flat.Unit or Vector3.xAxis
			local tilt = math.rad(layer.tilt or 0)
			base = flat * math.cos(tilt) + Vector3.yAxis * math.sin(tilt)
		end
	elseif d == "radial" then
		base = radial or (off.Magnitude > 1e-4 and off.Unit or Vector3.yAxis)
	elseif type(d) == "table" then
		base = Util.vec(d)
	else
		base = DIRS[d] or Vector3.yAxis
	end
	return Util.cone(base, layer.spread or 0, rng)
end

function Particles.new(layer, ctx, t0: number, anchor: string)
	local self = setmetatable({}, Particles)
	self.layer = layer
	self.ctx = ctx
	self.anchor = layer.anchor or anchor
	self.t0 = t0
	self.rng = Random.new(ctx.seed)
	self.times = spawnTimes(layer, ctx.quality, self.rng)
	self.next = 1
	self.list = {}
	self.shape = layer.shape or "ball"
	self.look = layer.look or "neon"
	self.aspect = Util.vec(layer.aspect, Vector3.one)
	self.accel = Util.vec(layer.accel)
	self.offset = Util.vec(layer.offset)
	self.drag = layer.drag or 0
	self.link = layer.link == "follow"
	self.orient = layer.rot or ((self.shape == "rock" or self.shape == "block") and "random" or "none")
	self.vref = math.max(1, Util.range(layer.speed, Random.new(1), 1))
	self.simulate = (layer.pull ~= nil and layer.pull > 0) or layer.ground ~= nil
	self.groundY = Anchors.ground(ctx.character)
	local life = layer.lifetime or 1
	self.maxLife = if type(life) == "table" then life[2] else life
	return self
end

function Particles:spawnOne(born: number)
	if Particles.alive >= self.ctx.maxParticles then
		return
	end
	local layer, rng, character = self.layer, self.rng, self.ctx.character
	local a0 = Anchors.position(character, self.anchor)
	local sp = layer.spawn
	local off, radial
	if sp and sp.shape == "segment" then
		local b0 = Anchors.position(character, sp.to)
		local j = sp.radius or 0
		off = (b0 - a0) * rng:NextNumber()
			+ Vector3.new(rng:NextNumber(-j, j), rng:NextNumber(-j, j), rng:NextNumber(-j, j))
	else
		off, radial = spawnOffset(sp, rng)
	end
	local p0 = a0 + self.offset + off
	if layer.snap == "ground" then
		p0 = Vector3.new(p0.X, self.groundY, p0.Z)
	end
	local v0 = direction(layer, off, radial, rng) * Util.range(layer.speed, rng, 0)
	local part = Pool.get(self.shape, self.look)
	Particles.alive += 1
	table.insert(self.list, {
		part = part,
		born = born,
		life = math.max(0.05, Util.range(layer.lifetime, rng, 1)),
		p0 = p0,
		v0 = v0,
		p = p0,
		v = v0,
		a0 = a0,
		env = rng:NextNumber(-1, 1) * (layer.env or 0),
		rot = rng:NextNumber(0, 360),
		spin = Util.range(layer.spin, rng, 0),
		last = born,
		settled = false,
	})
end

function Particles:integrate(q, now: number)
	local layer = self.layer
	local dt = math.clamp(now - q.last, 0, 0.1)
	q.last = now
	if dt <= 0 or q.settled then
		return
	end
	local a = self.accel
	local pull = layer.pull
	if pull and pull > 0 and (layer.pull_at == nil or now >= layer.pull_at) then
		local center = Anchors.position(self.ctx.character, layer.pull_to or self.anchor)
		local to = center - q.p
		if to.Magnitude > 1e-3 then
			a += to.Unit * pull * math.min(1, to.Magnitude)
			q.v *= 0.9
		end
	end
	q.v = q.v * math.exp(-self.drag * dt) + a * dt
	q.p += q.v * dt
	local g = layer.ground
	if g and q.p.Y < self.groundY then
		q.p = Vector3.new(q.p.X, self.groundY, q.p.Z)
		if math.abs(q.v.Y) < 6 then
			q.v = Vector3.new(q.v.X * 0.6, 0, q.v.Z * 0.6)
			if q.v.Magnitude < 1 then
				q.settled = true
			end
		else
			local b = Util.range(g.bounce, self.rng, 0.3)
			q.v = Vector3.new(q.v.X * 0.7, -q.v.Y * b, q.v.Z * 0.7)
		end
	end
end

function Particles:render(q, now: number, u: number)
	local layer = self.layer
	local age = now - q.born
	local pos, vel
	if self.simulate then
		self:integrate(q, now)
		pos, vel = q.p, q.v
	else
		local d = self.drag
		local travel = if d > 0 then q.v0 * ((1 - math.exp(-d * age)) / d) else q.v0 * age
		pos = q.p0 + travel + self.accel * (0.5 * age * age)
		vel = q.v0 * math.exp(-d * age) + self.accel * age
	end
	if self.link then
		pos += Anchors.position(self.ctx.character, self.anchor) - q.a0
	end
	local s = Util.curve(layer.size or 1, u, q.env)
	local size = self.aspect * s
	local sink = layer.ground and layer.ground.sink
	if sink and u > 1 - sink then
		pos -= Vector3.new(0, s * (u - (1 - sink)) / sink, 0)
	end
	local cf
	if self.orient == "velocity" and vel.Magnitude > 1e-3 then
		local stretch = 1 + (layer.stretch or 0) * math.min(3, vel.Magnitude / self.vref)
		size = Vector3.new(size.X, size.Y * stretch, size.Z)
		cf = Util.alongY(pos, vel)
	elseif self.orient == "random" then
		local ang = math.rad(q.rot + q.spin * age)
		cf = CFrame.new(pos) * CFrame.Angles(ang, ang * 0.7, ang * 1.3)
	else
		cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(q.spin * age), 0)
	end
	if Pool.isCylinder(self.shape) then
		cf *= Pool.UPRIGHT
		size = Vector3.new(size.Y, size.X, size.Z)
	end
	local part = q.part
	part.Size = size
	part.Color = Util.colorAt(layer.color or "CORE", u, self.ctx.palette)
	part.Transparency = math.clamp(Util.curve(layer.transparency or 0, u), 0, 1)
	Pool.move(part, cf)
end

function Particles:step(now: number): boolean
	while self.next <= #self.times and self.t0 + self.times[self.next] <= now do
		local born = self.t0 + self.times[self.next]
		-- quem entrou atrasado não precisa criar partícula que já teria morrido
		if now - born < self.maxLife then
			self:spawnOne(born)
		end
		self.next += 1
	end
	local list = self.list
	for i = #list, 1, -1 do
		local q = list[i]
		local u = (now - q.born) / q.life
		if u >= 1 then
			Pool.release(q.part)
			Particles.alive -= 1
			list[i] = list[#list]
			list[#list] = nil
		else
			self:render(q, now, math.max(u, 0))
		end
	end
	return self.next <= #self.times or #list > 0
end

function Particles:destroy()
	for _, q in self.list do
		Pool.release(q.part)
		Particles.alive -= 1
	end
	table.clear(self.list)
	self.next = #self.times + 1
end

return Particles

local Anchors = require(script.Parent.Parent.Anchors)
local Util = require(script.Parent.Parent.Util)
local Pool = require(script.Parent.Pool)

local Lightning = {}
Lightning.__index = Lightning

Lightning.segments = 0

local function boltPoints(a: Vector3, b: Vector3, segs: number, jitter: number, rng: Random): { Vector3 }
	local d = b - a
	local len = d.Magnitude
	if len < 1e-3 then
		return { a, b }
	end
	local side = d:Cross(math.abs(d.Unit.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis).Unit
	local side2 = d:Cross(side).Unit
	local pts = {}
	for i = 0, segs do
		local t = i / segs
		local q = a + d * t
		if i > 0 and i < segs then
			local amp = jitter * len / segs * 1.8 * math.sqrt(math.sin(math.pi * t))
			q += side * rng:NextNumber(-amp, amp) + side2 * rng:NextNumber(-amp, amp)
		end
		table.insert(pts, q)
	end
	return pts
end

function Lightning.new(layer, ctx, t0: number, anchor: string)
	local self = setmetatable({}, Lightning)
	self.layer = layer
	self.ctx = ctx
	self.anchor = layer.anchor or anchor
	self.t0 = t0
	self.rng = Random.new(ctx.seed)
	self.bolts = {}
	self.times = {}
	local delay = layer.delay or 0
	for _ = 1, math.floor((layer.count or 0) * ctx.quality + 0.5) do
		table.insert(self.times, delay)
	end
	local rate, duration = (layer.rate or 0) * ctx.quality, layer.duration or 0
	if rate > 0 and duration > 0 then
		for i = 0, math.floor(rate * duration) - 1 do
			table.insert(self.times, delay + (i + self.rng:NextNumber()) / rate)
		end
	end
	table.sort(self.times)
	self.next = 1
	self.groundY = Anchors.ground(ctx.character)
	return self
end

function Lightning:target(a: Vector3): Vector3
	local layer, rng = self.layer, self.rng
	local mode = layer.target or "around"
	local len = Util.range(layer.length, rng, 5)
	if mode == "ground" then
		local ang = rng:NextNumber(0, math.pi * 2)
		local dist = Util.range(layer.radius, rng, 6)
		return Vector3.new(a.X + math.cos(ang) * dist, self.groundY, a.Z + math.sin(ang) * dist)
	elseif mode == "anchor" then
		return Anchors.position(self.ctx.character, layer.to)
	elseif mode == "sky" then
		return a + Vector3.new(rng:NextNumber(-4, 4), len, rng:NextNumber(-4, 4))
	end
	return a + Util.randomUnit(rng) * len
end

function Lightning:release(bolt)
	for _, p in bolt.parts do
		Pool.release(p)
		Lightning.segments -= 1
	end
	table.clear(bolt.parts)
end

function Lightning:draw(bolt)
	self:release(bolt)
	local layer, rng = self.layer, self.rng
	local width = layer.width or 0.08
	local main = boltPoints(bolt.a, bolt.b, layer.segments or 9, layer.jitter or 0.7, rng)
	local paths = { { main, width } }
	for _ = 1, layer.forks or 2 do
		if rng:NextNumber() < (layer.fork_chance or 0.6) and #main > 3 then
			local i0 = rng:NextInteger(2, #main - 1)
			local dir = (main[#main] - main[1]).Unit
			local len = (main[#main] - main[1]).Magnitude * rng:NextNumber(0.2, 0.45)
			local tip = main[i0] + (dir + Util.randomUnit(rng) * 0.7).Unit * len
			table.insert(paths, { boltPoints(main[i0], tip, 5, 0.8, rng), width * 0.55 })
		end
	end
	local glow = Util.color(layer.color or "LILAC", self.ctx.palette)
	local core = Util.color(layer.core or "CORE", self.ctx.palette)
	for _, path in paths do
		local pts, w = path[1], path[2]
		for i = 1, #pts - 1 do
			if Lightning.segments >= self.ctx.maxSegments then
				return
			end
			local a, b = pts[i], pts[i + 1]
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt((a + b) / 2, b)
			for pass = 1, 2 do
				local p = Pool.get("block", "neon")
				local thick = if pass == 1 then w else w * 3
				p.Size = Vector3.new(thick, thick, len + thick * 0.5)
				p.Color = if pass == 1 then core else glow
				p.Transparency = if pass == 1 then 0 else 0.7
				Pool.move(p, cf)
				table.insert(bolt.parts, p)
				Lightning.segments += 1
			end
		end
	end
end

function Lightning:step(now: number): boolean
	local layer = self.layer
	while self.next <= #self.times and self.t0 + self.times[self.next] <= now do
		local born = self.t0 + self.times[self.next]
		self.next += 1
		if now - born > 0.5 then
			continue
		end
		local a = Anchors.position(self.ctx.character, self.anchor) + Util.vec(layer.offset)
		local b = self:target(a)
		if layer.reverse then
			a, b = b, a
		end
		table.insert(self.bolts, {
			a = a,
			b = b,
			born = born,
			life = math.max(0.03, Util.range(layer.lifetime, self.rng, 0.15)),
			nextDraw = born,
			parts = {},
		})
	end
	local flicker = layer.flicker or 0.05
	for i = #self.bolts, 1, -1 do
		local bolt = self.bolts[i]
		if now - bolt.born >= bolt.life then
			self:release(bolt)
			table.remove(self.bolts, i)
		elseif now >= bolt.nextDraw then
			bolt.nextDraw = now + flicker
			self:draw(bolt)
		end
	end
	return self.next <= #self.times or #self.bolts > 0
end

function Lightning:destroy()
	for _, bolt in self.bolts do
		self:release(bolt)
	end
	table.clear(self.bolts)
	self.next = #self.times + 1
end

return Lightning

local Workspace = game:GetService("Workspace")

local Anchors = require(script.Parent.Parent.Anchors)
local Util = require(script.Parent.Parent.Util)

-- Anel de Beams. Cada beam é um arco de Bézier entre dois attachments
-- (P1 = A0 + CurveSize0 * A0.X, P2 = A1 - CurveSize1 * A1.X); com o X do
-- attachment na tangente e CurveSize = 4/3 * tan(pi / 2N) * r o arco fica circular.
local Ring = {}
Ring.__index = Ring

function Ring.build(segments: number, parent: Instance?)
	local holder = parent or Workspace.Terrain
	local atts, beams = {}, {}
	for i = 1, segments do
		local a = Instance.new("Attachment")
		a.Name = "EmberRing"
		a.Parent = holder
		atts[i] = a
	end
	for i = 1, segments do
		local b = Instance.new("Beam")
		b.Attachment0 = atts[i]
		b.Attachment1 = atts[i % segments + 1]
		b.FaceCamera = true
		b.Segments = 12
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 3
		b.Parent = atts[i]
		beams[i] = b
	end
	return atts, beams
end

-- frame: CFrame do centro, círculo no plano XZ local
function Ring.place(atts: { Attachment }, beams: { Beam }, frame: CFrame, radius: number, angle: number?)
	local n = #atts
	local k = 4 / 3 * math.tan(math.pi / (2 * n)) * radius
	local a0 = angle or 0
	local up = frame.UpVector
	for i, att in atts do
		local th = a0 + (i - 1) / n * math.pi * 2
		local local_ = Vector3.new(math.cos(th) * radius, 0, math.sin(th) * radius)
		local tangent = frame:VectorToWorldSpace(Vector3.new(-math.sin(th), 0, math.cos(th)))
		att.WorldCFrame = CFrame.fromMatrix(frame:PointToWorldSpace(local_), tangent, up)
	end
	for _, b in beams do
		b.CurveSize0 = k
		b.CurveSize1 = k
	end
end

function Ring.style(beams: { Beam }, width: number, color: Color3, transparency: number)
	local seq = NumberSequence.new(transparency)
	local cs = ColorSequence.new(color)
	for _, b in beams do
		b.Width0 = width
		b.Width1 = width
		b.Color = cs
		b.Transparency = seq
	end
end

function Ring.new(layer, ctx, t0: number, anchor: string)
	local self = setmetatable({}, Ring)
	self.layer = layer
	self.ctx = ctx
	self.anchor = layer.anchor or anchor
	self.t0 = t0 + (layer.delay or 0)
	self.items = {}
	local count = layer.count or 1
	for j = 1, count do
		table.insert(self.items, { start = self.t0 + (j - 1) * (layer.stagger or 0) })
	end
	return self
end

function Ring:frameFor(item)
	local layer = self.layer
	local pos = Anchors.position(self.ctx.character, self.anchor) + Util.vec(layer.offset)
	local orient = layer.orient or "ground"
	if orient == "facing" then
		local cam = Workspace.CurrentCamera
		local look = cam and (cam.CFrame.Position - pos) or Vector3.zAxis
		-- plano do anel perpendicular à câmera: o Y local aponta pra câmera
		return Util.alongY(pos, look)
	elseif orient == "vertical" then
		return CFrame.new(pos) * CFrame.Angles(0, math.rad(layer.yaw or 0), 0) * CFrame.Angles(math.pi / 2, 0, 0)
	end
	return CFrame.new(pos) * CFrame.Angles(math.rad(layer.tiltx or 0), 0, math.rad(layer.tiltz or 0))
end

function Ring:step(now: number): boolean
	local layer = self.layer
	local life = math.max(0.05, layer.lifetime or 0.5)
	local alive = false
	for _, item in self.items do
		local age = now - item.start
		if age < 0 then
			alive = true
		elseif age >= life then
			if item.atts then
				for _, a in item.atts do
					a:Destroy()
				end
				item.atts = nil
			end
		else
			alive = true
			local u = age / life
			local radius = math.max(0.05, Util.curve(layer.radius or { { 0, 0.5 }, { 1, 6 } }, u))
			if item.atts == nil then
				local segs = if radius > 12 or Util.curve(layer.radius, 1) > 12 then 10 else 8
				item.atts, item.beams = Ring.build(segs)
				if layer.link ~= "follow" then
					item.frame = self:frameFor(item)
				end
			end
			local frame = if layer.link == "follow" or item.frame == nil then self:frameFor(item) else item.frame
			Ring.place(item.atts, item.beams, frame, radius, math.rad((layer.spin or 0) * age))
			Ring.style(
				item.beams,
				math.max(0.01, Util.curve(layer.width or 0.3, u)),
				Util.colorAt(layer.color or "CORE", u, self.ctx.palette),
				math.clamp(Util.curve(layer.transparency or { { 0, 0 }, { 1, 1 } }, u), 0, 1)
			)
		end
	end
	return alive
end

function Ring:destroy()
	for _, item in self.items do
		if item.atts then
			for _, a in item.atts do
				a:Destroy()
			end
			item.atts = nil
		end
	end
end

return Ring

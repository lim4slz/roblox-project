local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Anchors = require(script.Parent.Parent.Anchors)
local Config = require(script.Parent.Parent.Config)
local Util = require(script.Parent.Parent.Util)

local Screen = {}

local function distanceFactor(ctx, anchor: string): number
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return 1
	end
	local d = (cam.CFrame.Position - Anchors.position(ctx.character, anchor)).Magnitude
	return math.clamp(1 - d / Config.Quality.ScreenFalloff, 0, 1)
end

-- valor com rampa (lifetime), segura até `hold` e solta em `release` segundos
local function envelope(layer, age: number): (number, number)
	local life = math.max(0.01, layer.lifetime or 0.5)
	local hold = math.max(life, layer.hold or 0)
	local rel = layer.release or 0
	local u = math.min(age / life, 1)
	if age <= hold then
		return u, 1
	end
	if rel <= 0 then
		return u, 0
	end
	return u, math.max(0, 1 - (age - hold) / rel)
end

local ColorLayer = {}
ColorLayer.__index = ColorLayer

function ColorLayer.new(layer, ctx, t0: number, anchor: string)
	local self = setmetatable({ layer = layer, ctx = ctx, anchor = layer.anchor or anchor }, ColorLayer)
	self.t0 = t0 + (layer.delay or 0)
	return self
end

function ColorLayer:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	local layer = self.layer
	local u, k = envelope(layer, age)
	if k <= 0 then
		self:destroy()
		return false
	end
	if self.fx == nil then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "EmberScreen"
		cc.Parent = Lighting
		self.fx = cc
	end
	local f = k * distanceFactor(self.ctx, self.anchor)
	local cc = self.fx :: ColorCorrectionEffect
	cc.Brightness = Util.curve(layer.brightness or 0, u) * f
	cc.Saturation = Util.curve(layer.saturation or 0, u) * f
	cc.Contrast = Util.curve(layer.contrast or 0, u) * f
	if layer.tint then
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Util.colorAt(layer.tint, u, self.ctx.palette), f)
	end
	return true
end

function ColorLayer:destroy()
	if self.fx then
		self.fx:Destroy()
		self.fx = nil
	end
end

local flashGui: ScreenGui? = nil

local function gui(): ScreenGui?
	local player = Players.LocalPlayer
	if player == nil then
		return nil
	end
	if flashGui == nil or flashGui.Parent == nil then
		local g = Instance.new("ScreenGui")
		g.Name = "EmberFlash"
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.DisplayOrder = 50
		g.Parent = player:WaitForChild("PlayerGui")
		flashGui = g
	end
	return flashGui
end

local Flash = {}
Flash.__index = Flash

function Flash.new(layer, ctx, t0: number, anchor: string)
	local self = setmetatable({ layer = layer, ctx = ctx, anchor = layer.anchor or anchor }, Flash)
	self.t0 = t0 + (layer.delay or 0)
	return self
end

function Flash:step(now: number): boolean
	local age = now - self.t0
	if age < 0 then
		return true
	end
	local layer = self.layer
	local u, k = envelope(layer, age)
	if age > math.max(layer.lifetime or 0.3, layer.hold or 0) + (layer.release or 0) then
		self:destroy()
		return false
	end
	local a = math.clamp(Util.curve(layer.alpha or { { 0, 1 }, { 1, 0 } }, u) * k * distanceFactor(self.ctx, self.anchor), 0, 1)
	local mode = layer.mode or "white"
	if mode == "invert" then
		-- não existe inversão de cor no Roblox: vira um frame de impacto preto e branco estourado
		if self.cc == nil then
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "EmberImpact"
			cc.Parent = Lighting
			self.cc = cc
		end
		local cc = self.cc :: ColorCorrectionEffect
		cc.Saturation = -a
		cc.Contrast = 1.5 * a
		cc.Brightness = 0.1 * a
	else
		if self.frame == nil then
			local g = gui()
			if g == nil then
				return false
			end
			local f = Instance.new("Frame")
			f.Size = UDim2.fromScale(1, 1)
			f.BorderSizePixel = 0
			f.BackgroundColor3 = if mode == "black" then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
			f.Parent = g
			self.frame = f
		end
		(self.frame :: Frame).BackgroundTransparency = 1 - a
	end
	return true
end

function Flash:destroy()
	if self.frame then
		self.frame:Destroy()
		self.frame = nil
	end
	if self.cc then
		self.cc:Destroy()
		self.cc = nil
	end
end

local shakes: { [any]: boolean } = {}
local bound = false

local function shakeOffset(clock: number): CFrame
	local pos, rot = Vector3.zero, Vector3.zero
	for s in shakes do
		local life = math.max(0.01, s.layer.lifetime or 0.5)
		local age = clock - s.start
		if age >= 0 and age <= life then
			local amp = Util.curve(s.layer.amplitude or { { 0, 1 }, { 1, 0 } }, age / life) * s.factor
			local fq = s.layer.frequency or 14
			local rotAmp = math.rad(s.layer.rot or 0.6)
			pos += Vector3.new(
				math.noise(clock * fq, 0.31, s.seed),
				math.noise(clock * fq, 7.62, s.seed),
				math.noise(clock * fq, 13.9, s.seed)
			) * amp
			rot += Vector3.new(
				math.noise(clock * fq * 1.13, 21.4, s.seed),
				math.noise(clock * fq * 1.13, 29.8, s.seed),
				math.noise(clock * fq * 1.13, 37.1, s.seed)
			) * amp * rotAmp
		end
	end
	return CFrame.new(pos * 0.5) * CFrame.Angles(rot.X, rot.Y, rot.Z)
end

local function bind()
	if bound then
		return
	end
	bound = true
	RunService:BindToRenderStep("EmberShake", Enum.RenderPriority.Camera.Value + 1, function()
		local clock = os.clock()
		for s in shakes do
			if clock - s.start > (s.layer.lifetime or 0.5) then
				shakes[s] = nil
			end
		end
		if next(shakes) == nil then
			RunService:UnbindFromRenderStep("EmberShake")
			bound = false
			return
		end
		local cam = Workspace.CurrentCamera
		if cam then
			cam.CFrame *= shakeOffset(clock)
		end
	end)
end

local Shake = {}
Shake.__index = Shake

function Shake.new(layer, ctx, t0: number, anchor: string)
	local self = setmetatable({}, Shake)
	self.layer = layer
	self.ctx = ctx
	self.anchor = layer.anchor or anchor
	self.t0 = t0 + (layer.delay or 0)
	return self
end

function Shake:step(now: number): boolean
	if now < self.t0 then
		return true
	end
	if self.entry == nil then
		local factor = 1
		local fall = self.layer.falloff or 0
		local cam = Workspace.CurrentCamera
		if fall > 0 and cam then
			local d = (cam.CFrame.Position - Anchors.position(self.ctx.character, self.anchor)).Magnitude
			factor = math.clamp(1 - d / fall, 0, 1)
		end
		self.entry = { layer = self.layer, start = os.clock() - (now - self.t0), factor = factor, seed = self.ctx.seed % 997 }
		shakes[self.entry] = true
		bind()
	end
	return shakes[self.entry] == true
end

function Shake:destroy()
	if self.entry then
		shakes[self.entry] = nil
	end
end

local fovBase: number? = nil
local fovActive = 0

local Fov = {}
Fov.__index = Fov

function Fov.new(layer, ctx, t0: number, _anchor: string)
	return setmetatable({ layer = layer, ctx = ctx, t0 = t0 + (layer.delay or 0) }, Fov)
end

function Fov:step(now: number): boolean
	local cam = Workspace.CurrentCamera
	local age = now - self.t0
	if cam == nil or age < 0 then
		return true
	end
	local life = self.layer.lifetime or 0.8
	if not self.on then
		self.on = true
		fovActive += 1
		fovBase = fovBase or cam.FieldOfView
	end
	if age >= life then
		self:destroy()
		return false
	end
	local u = age / life
	local bump = if u < 0.15 then u / 0.15 else 1 - (u - 0.15) / 0.85
	cam.FieldOfView = (fovBase :: number) + (self.layer.delta or 10) * math.sin(bump * math.pi / 2)
	return true
end

function Fov:destroy()
	if self.on then
		self.on = false
		fovActive -= 1
		local cam = Workspace.CurrentCamera
		if fovActive <= 0 and cam and fovBase then
			cam.FieldOfView = fovBase
			fovBase = nil
		end
	end
end

Screen.ColorLayer = ColorLayer
Screen.Flash = Flash
Screen.Shake = Shake
Screen.Fov = Fov

return Screen

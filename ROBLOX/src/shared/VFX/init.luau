local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Palette = require(script.Parent.Palette)
local Animate = require(script.Animate)
local Lightning = require(script.Lightning)
local Particles = require(script.Particles)
local Pool = require(script.Pool)
local Ring = require(script.Ring)
local Screen = require(script.Screen)
local Specials = require(script.Specials)

local VFX = {}

local KINDS = {
	part = Particles,
	animate = Animate,
	distort = Animate,
	ring = Ring,
	lightning = Lightning,
	light = Specials.light,
	screen = Screen.ColorLayer,
	flash = Screen.Flash,
	shake = Screen.Shake,
	fov = Screen.Fov,
	highlight = Specials.highlight,
	sigil = Specials.sigil,
	circuits = Specials.circuits,
	helix = Specials.helix,
	orbs = Specials.orbs,
	halo = Specials.halo,
	point = Specials.point,
	blade = Specials.blade,
}

local TIER = { primary = 1, secondary = 2, tertiary = 3 }

function VFX.quality(): number
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	local n = if ok and level and level > 0 then level else 7
	return Config.Quality.ByLevel[math.clamp(n, 1, 10)]
end

-- distort vira uma esfera de vidro animada
local function prepare(layer)
	if layer.kind == "distort" and layer._ready == nil then
		layer._ready = true
		layer.shape = layer.shape or "hiball"
		layer.look = "glass"
		layer.link = layer.link or "world"
		if layer.radius then
			local size = {}
			for _, p in layer.radius do
				table.insert(size, { p[1], p[2] * 2 })
			end
			layer.size = size
		end
	end
	return layer
end

function VFX.allowed(tier: string?, quality: number): boolean
	local t = TIER[tier or "primary"] or 1
	if t == 3 and quality < Config.Quality.SkipTertiaryBelow then
		return false
	end
	if t == 2 and quality < Config.Quality.SkipSecondaryBelow then
		return false
	end
	return true
end

function VFX.spawn(layer, ctx, t0: number, anchor: string)
	local kind = KINDS[layer.kind]
	if kind == nil then
		return nil
	end
	ctx.seed = (ctx.seed or 1) + 7919
	return kind.new(prepare(layer), ctx, t0, anchor)
end

function VFX.context(cast, character: Model, quality: number)
	return {
		cast = cast,
		character = character,
		palette = Palette,
		quality = quality,
		seed = math.floor(os.clock() * 1000) % 100000,
		maxParticles = math.floor(Config.Quality.MaxParticles * math.max(quality, 0.3)),
		maxSegments = Config.Quality.MaxLightningSegments,
	}
end

local effects: { { effect: any, cast: any } } = {}
local connection: RBXScriptConnection? = nil

function VFX.track(effect, cast)
	table.insert(effects, { effect = effect, cast = cast })
	if connection == nil then
		connection = RunService.Heartbeat:Connect(function()
			for i = #effects, 1, -1 do
				local e = effects[i]
				local alive = e.cast.running and e.effect:step(e.cast:time())
				if not alive then
					e.effect:destroy()
					effects[i] = effects[#effects]
					effects[#effects] = nil
				end
			end
			Pool.flush()
			if #effects == 0 and connection then
				connection:Disconnect()
				connection = nil
			end
		end)
	end
end

function VFX.stopCast(cast)
	for i = #effects, 1, -1 do
		if effects[i].cast == cast then
			effects[i].effect:destroy()
			table.remove(effects, i)
		end
	end
	Pool.flush()
end

VFX.Ring = Ring
VFX.Pool = Pool
VFX.Specials = Specials

return VFX

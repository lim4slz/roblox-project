--!nocheck
-- Testes do runtime que dá pra rodar fora do Roblox.
--   lune run SCRIPTS/lune/test_runtime.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local ROOT = process.cwd
local SHARED = ROOT .. "/ROBLOX/src/shared"

local failures, passed = 0, 0
local function check(cond: boolean, msg: string)
	if cond then
		passed += 1
	else
		failures += 1
		print("FALHOU: " .. msg)
	end
end

-- Random do Roblox não existe no Lune: um substituto determinístico
local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (seed or 1) % 2147483647 }, Random)
end
function Random:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b)
	local r = self:_next()
	if a == nil then
		return r
	end
	return a + (b - a) * r
end
function Random:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end

local env = {
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	NumberSequence = roblox.NumberSequence,
	ColorSequence = roblox.ColorSequence,
	Random = Random,
	math = math,
	table = table,
	string = string,
	type = type,
	typeof = function(v)
		local t = typeof(v)
		return t
	end,
	setmetatable = setmetatable,
	pairs = pairs,
	ipairs = ipairs,
	tostring = tostring,
	tonumber = tonumber,
	print = print,
}

local function load(path: string, extra: { [string]: any }?)
	local e = table.clone(env)
	for k, v in extra or {} do
		e[k] = v
	end
	return luau.load(fs.readFile(path), { debugName = path, environment = e })()
end

-- Util ------------------------------------------------------------------------
local Util = load(SHARED .. "/Util.luau")
check(Util.curve(2, 0.3) == 2, "curve constante")
check(math.abs(Util.curve({ { 0, 0 }, { 1, 10 } }, 0.25) - 2.5) < 1e-9, "curve linear")
check(math.abs(Util.curve({ { 0, 1 }, { 0.5, 3 }, { 1, 0 } }, 0.75) - 1.5) < 1e-9, "curve 3 pontos")
check(Util.curve({ { 0, 1 }, { 1, 5 } }, -1) == 1 and Util.curve({ { 0, 1 }, { 1, 5 } }, 2) == 5, "curve fora do intervalo")
check(math.abs(Util.curve({ { 0, 2 }, { 1, 2 } }, 0.5, 0.25) - 2.5) < 1e-9, "curve com env")
local rng = Random.new(5)
for _ = 1, 50 do
	local v = Util.range({ 3, 7 }, rng)
	check(v >= 3 and v <= 7, "range dentro do intervalo")
end
local palette = load(SHARED .. "/Palette.luau")
local c = Util.colorAt({ { 0, "CORE" }, { 1, "VIOLET" } }, 0.5, palette)
local expect = palette.CORE:Lerp(palette.VIOLET, 0.5)
check(math.abs(c.R - expect.R) < 1e-6 and math.abs(c.B - expect.B) < 1e-6, "colorAt interpola")
for _ = 1, 200 do
	local d = Util.cone(roblox.Vector3.new(0, 1, 0), 30, rng)
	local ang = math.deg(math.acos(math.clamp(d.Y, -1, 1)))
	check(ang <= 30.01 and math.abs(d.Magnitude - 1) < 1e-6, "cone respeita o spread")
end
local up = Util.alongY(roblox.Vector3.new(1, 2, 3), roblox.Vector3.new(0, 0, -5))
check((up.UpVector - roblox.Vector3.new(0, 0, -1)).Magnitude < 1e-5, "alongY aponta o Y pra direção")
local vertical = Util.alongY(roblox.Vector3.zero, roblox.Vector3.new(0, 3, 0))
check((vertical.UpVector - roblox.Vector3.yAxis).Magnitude < 1e-5, "alongY vertical sem degenerar")

-- Arco de Bézier do Ring -----------------------------------------------------------
-- P1 = A0 + CurveSize0 * A0.X, P2 = A1 - CurveSize1 * A1.X (docs do Beam)
for _, n in { 8, 10, 12 } do
	local r = 50
	local k = 4 / 3 * math.tan(math.pi / (2 * n)) * r
	local worst = 0
	for i = 0, n - 1 do
		local a0 = i / n * math.pi * 2
		local a1 = (i + 1) / n * math.pi * 2
		local p0 = roblox.Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r)
		local p3 = roblox.Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r)
		local t0 = roblox.Vector3.new(-math.sin(a0), 0, math.cos(a0))
		local t1 = roblox.Vector3.new(-math.sin(a1), 0, math.cos(a1))
		local p1, p2 = p0 + t0 * k, p3 - t1 * k
		for s = 0, 20 do
			local u = s / 20
			local q = p0 * (1 - u) ^ 3 + p1 * 3 * u * (1 - u) ^ 2 + p2 * 3 * u * u * (1 - u) + p3 * u ^ 3
			worst = math.max(worst, math.abs(q.Magnitude - r) / r)
		end
	end
	check(worst < 0.0005, `anel com {n} beams fica circular (erro {worst})`)
end

-- RootMotion.sample ------------------------------------------------------------------
local RootMotion = load(SHARED .. "/RootMotion.luau")
local keys = { { 0, 0, 0, 0 }, { 1, 0, -2, 0 }, { 2, 1, -2, 90 } }
local x, z, yaw = RootMotion.sample(keys, 0.5)
check(x == 0 and math.abs(z + 1) < 1e-9 and yaw == 0, "root motion meio do primeiro trecho")
x, z, yaw = RootMotion.sample(keys, 1.5)
check(math.abs(x - 0.5) < 1e-9 and math.abs(yaw - 45) < 1e-9, "root motion segundo trecho")
x, z, yaw = RootMotion.sample(keys, 9)
check(x == 1 and z == -2 and yaw == 90, "root motion depois do fim")

-- dados das habilidades ----------------------------------------------------------------
local vfxSource = fs.readFile(SHARED .. "/VFX/init.luau")
local kinds = {}
for k in string.gmatch(vfxSource, "\n\t([%a_]+) = [%w%.]+,") do
	kinds[k] = true
end
local anchorsOk = {
	feet = true, chest = true, hands = true, root = true, character = true, blade_tip = true, blade_base = true,
	blade_mid = true, grip = true, Head = true, UpperTorso = true, LowerTorso = true, LeftHand = true,
	RightHand = true, LeftFoot = true, RightFoot = true, blade = true,
}
local function validAnchor(a)
	return a == nil or anchorsOk[a] or string.match(a, "^sky:%-?%d")
end
local timing = serde.decode("json", fs.readFile(ROOT .. "/ANIMATIONS/ANIM_01_ATOMIC_ECLIPSE/ANIM_01_ATOMIC_ECLIPSE_timing.json"))
for _, file in fs.readDir(SHARED .. "/Abilities") do
	if file == "init.luau" then
		continue
	end
	local data = load(SHARED .. "/Abilities/" .. file)
	local name = data.Name
	check(data.Duration >= 30, `{name}: dura pelo menos 30s`)
	check(math.abs(data.Duration - timing.duration_s) < 1e-6, `{name}: duração bate com o bake`)
	local last = -1
	local layerCount = 0
	for _, cue in data.Cues do
		check(cue.t >= last, `{name}: cues em ordem ({cue.marker})`)
		last = cue.t
		check(cue.t >= 0 and cue.t <= data.Duration, `{name}: cue dentro da duração ({cue.marker})`)
		check(validAnchor(cue.anchor), `{name}: anchor conhecido {tostring(cue.anchor)}`)
		if cue.fx == "emit" then
			for _, layer in cue.params.layers do
				layerCount += 1
				check(kinds[layer.kind] == true, `{name}: tipo de camada suportado {layer.kind}`)
				check(validAnchor(layer.anchor), `{name}: anchor de camada {tostring(layer.anchor)}`)
				for key, v in layer do
					if string.sub(key, 1, 5) == "color" and type(v) == "string" then
						check(palette[v] ~= nil, `{name}: cor {v} existe na paleta`)
					end
				end
				if layer.kind == "part" then
					check((layer.count or 0) > 0 or ((layer.rate or 0) > 0 and (layer.duration or 0) > 0),
						`{name}: emissor de partícula emite algo ({cue.marker})`)
				end
				local life = layer.lifetime or layer.duration
				if life then
					local maxLife = if type(life) == "table" then life[2] else life
					check(cue.t + (layer.delay or 0) + maxLife <= data.Duration + 9, `{name}: camada termina perto do fim ({cue.marker})`)
				end
			end
		else
			check(cue.fx == "trail", `{name}: fx fora de camada conhecido {cue.fx}`)
		end
	end
	local markerNames = {}
	for _, m in data.Markers do
		markerNames[m[2]] = true
	end
	for _, cue in data.Cues do
		check(markerNames[cue.marker] == true, `{name}: cue aponta pra marker existente {cue.marker}`)
	end
	for _, hit in data.Hits do
		check(hit.params.radius and hit.params.radius > 0, `{name}: hit com raio`)
		check(markerNames[hit.marker] == true, `{name}: hit aponta pra marker {hit.marker}`)
	end
	local prevT = -1
	for _, k in data.RootMotion do
		check(k[1] > prevT, `{name}: root motion em ordem`)
		prevT = k[1]
	end
	print(`{name}: {#data.Cues} cues, {layerCount} camadas, {#data.Hits} hits`)
end

-- KeyframeSequence exportado ---------------------------------------------------------------
local kfsPath = ROOT .. "/EXPORT/KeyframeSequences/ANIM_01_ATOMIC_ECLIPSE.rbxm"
local kfs = roblox.deserializeModel(fs.readFile(kfsPath))[1]
local list = kfs:GetChildren()
table.sort(list, function(a, b)
	return a.Time < b.Time
end)
check(math.abs(list[#list].Time - 32) < 1e-4, "KeyframeSequence tem 32s")
check(kfs.Loop == false, "KeyframeSequence sem loop")
local markers = 0
for _, kf in list do
	for _, d in kf:GetChildren() do
		if d.ClassName == "KeyframeMarker" then
			markers += 1
		end
	end
end
check(markers == #timing.markers, `KeyframeSequence com todos os markers ({markers})`)

print(`{passed} checagens ok, {failures} falhas`)
if failures > 0 then
	process.exit(1)
end

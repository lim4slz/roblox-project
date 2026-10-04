local Util = {}

export type Curve = number | { { number } }
export type Range = number | { number }

function Util.curve(c: Curve?, u: number, env: number?): number
	if c == nil then
		return 0
	end
	local scale = 1 + (env or 0)
	if type(c) == "number" then
		return c * scale
	end
	local pts = c :: { { number } }
	local first, last = pts[1], pts[#pts]
	if u <= first[1] then
		return first[2] * scale
	end
	if u >= last[1] then
		return last[2] * scale
	end
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if u >= a[1] and u <= b[1] then
			local k = (u - a[1]) / math.max(b[1] - a[1], 1e-6)
			return (a[2] + (b[2] - a[2]) * k) * scale
		end
	end
	return last[2] * scale
end

function Util.range(r: Range?, rng: Random, default: number?): number
	if r == nil then
		return default or 0
	end
	if type(r) == "number" then
		return r
	end
	local t = r :: { number }
	return t[1] + (t[2] - t[1]) * rng:NextNumber()
end

function Util.vec(t: { number }?, default: Vector3?): Vector3
	if t == nil then
		return default or Vector3.zero
	end
	return Vector3.new(t[1], t[2], t[3])
end

function Util.color(c: any, palette: { [string]: Color3 }): Color3
	if typeof(c) == "Color3" then
		return c
	end
	if type(c) == "string" then
		return palette[c] or Color3.new(1, 1, 1)
	end
	if type(c) == "table" and type(c[1]) == "number" and #c == 3 and c[1] > 1.001 then
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	return Color3.new(1, 1, 1)
end

-- aceita "NOME", {r,g,b} ou {{t, cor}, ...}
function Util.colorAt(seq: any, u: number, palette: { [string]: Color3 }): Color3
	if seq == nil then
		return Color3.new(1, 1, 1)
	end
	if type(seq) ~= "table" or type(seq[1]) == "number" then
		return Util.color(seq, palette)
	end
	local pts = seq :: { { any } }
	if u <= pts[1][1] then
		return Util.color(pts[1][2], palette)
	end
	if u >= pts[#pts][1] then
		return Util.color(pts[#pts][2], palette)
	end
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if u >= a[1] and u <= b[1] then
			local k = (u - a[1]) / math.max(b[1] - a[1], 1e-6)
			return Util.color(a[2], palette):Lerp(Util.color(b[2], palette), k)
		end
	end
	return Util.color(pts[#pts][2], palette)
end

function Util.randomUnit(rng: Random): Vector3
	local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	while v.Magnitude < 1e-3 or v.Magnitude > 1 do
		v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	end
	return v.Unit
end

function Util.cone(axis: Vector3, spreadDeg: number, rng: Random): Vector3
	local a = if axis.Magnitude > 1e-6 then axis.Unit else Vector3.yAxis
	if spreadDeg <= 0 then
		return a
	end
	local ortho = if math.abs(a.Y) < 0.99 then a:Cross(Vector3.yAxis).Unit else a:Cross(Vector3.xAxis).Unit
	local tilt = math.rad(rng:NextNumber(0, spreadDeg))
	local spin = rng:NextNumber(0, math.pi * 2)
	local v = CFrame.fromAxisAngle(ortho, tilt):VectorToWorldSpace(a)
	return CFrame.fromAxisAngle(a, spin):VectorToWorldSpace(v).Unit
end

-- Y do objeto apontando pra `dir`
function Util.alongY(pos: Vector3, dir: Vector3): CFrame
	if dir.Magnitude < 1e-6 then
		return CFrame.new(pos)
	end
	local y = dir.Unit
	local ref = if math.abs(y.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local x = ref:Cross(y).Unit
	return CFrame.fromMatrix(pos, x, y, x:Cross(y))
end

return Util

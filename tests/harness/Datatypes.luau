--[[
	Datatypes
	Roblox datatypes for the sandbox environment: everything Lune's roblox
	library implements, plus mocks of TweenInfo, Random, DateTime,
	RaycastParams and OverlapParams.
]]

local roblox = require("@lune/roblox")
local Registry = require("./Registry")

local Enum = roblox.Enum

local Datatypes = {}

local CFrameLib

local fields = setmetatable({}, { __mode = "k" })

local function readonlyProxy(typeName, data, methods)
	local proxy = Registry.proxy(typeName, function(mt)
		mt.__index = function(_, key)
			local method = methods and methods[key]
			if method then
				return method
			end
			local value = data[key]
			if value == nil and not (methods and methods.__allowNil) then
				error(tostring(key) .. " is not a valid member of " .. typeName, 2)
			end
			return value
		end
		mt.__newindex = function(_, key, value)
			if methods and methods.__writable and methods.__writable[key] then
				data[key] = value
				return
			end
			error(tostring(key) .. " cannot be assigned to", 2)
		end
		mt.__tostring = function()
			return typeName
		end
	end)
	fields[proxy] = data
	return proxy
end

function Datatypes.typeName(value)
	return Registry.typeName(value)
end

function Datatypes.tweenInfoFields(info)
	return fields[info]
end

local TweenInfo = {}
function TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
	return readonlyProxy("TweenInfo", {
		Time = time or 1,
		EasingStyle = easingStyle or Enum.EasingStyle.Quad,
		EasingDirection = easingDirection or Enum.EasingDirection.Out,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	})
end

local globalSeed = 1

local Random = {}
function Random.new(seed)
	local state = {}
	local initial = seed
	if initial == nil then
		globalSeed += 1
		initial = globalSeed * 7919
	end
	local x = math.floor(math.abs(initial)) % 4294967296
	-- splitmix-style scrambling so nearby seeds diverge
	x = bit32.bxor(x, 0x9E3779B9)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	if x == 0 then
		x = 2463534242
	end
	state.x = x

	local function nextU32()
		local v = state.x
		v = bit32.bxor(v, bit32.lshift(v, 13))
		v = bit32.bxor(v, bit32.rshift(v, 17))
		v = bit32.bxor(v, bit32.lshift(v, 5))
		state.x = v
		return v
	end

	local methods
	methods = {
		NextNumber = function(_, min, max)
			local unit = nextU32() / 4294967296
			if min == nil then
				return unit
			end
			return min + unit * (max - min)
		end,
		NextInteger = function(_, min, max)
			if type(min) ~= "number" or type(max) ~= "number" then
				error("NextInteger expects two numbers", 2)
			end
			min, max = math.floor(min), math.floor(max)
			if min > max then
				error("invalid argument #2 to 'NextInteger' (interval is empty)", 2)
			end
			return min + math.floor(nextU32() / 4294967296 * (max - min + 1))
		end,
		NextUnitVector = function()
			local theta = nextU32() / 4294967296 * math.pi * 2
			local z = nextU32() / 4294967296 * 2 - 1
			local r = math.sqrt(1 - z * z)
			return roblox.Vector3.new(r * math.cos(theta), r * math.sin(theta), z)
		end,
		Shuffle = function(_, list)
			for index = #list, 2, -1 do
				local other = 1 + math.floor(nextU32() / 4294967296 * index)
				list[index], list[other] = list[other], list[index]
			end
		end,
		Clone = function()
			local copy = Random.new(1)
			fields[copy].state.x = state.x
			return copy
		end,
	}
	return readonlyProxy("Random", { state = state }, methods)
end

function Datatypes.newDateTime(scheduler)
	local DateTime = {}
	local function make(millis)
		local seconds = millis // 1000
		local methods = {
			ToUniversalTime = function()
				local parts = os.date("!*t", seconds)
				return {
					Year = parts.year,
					Month = parts.month,
					Day = parts.day,
					Hour = parts.hour,
					Minute = parts.min,
					Second = parts.sec,
					Millisecond = millis % 1000,
				}
			end,
			ToIsoDate = function()
				return os.date("!%Y-%m-%dT%H:%M:%SZ", seconds)
			end,
			FormatUniversalTime = function(_, format)
				return os.date("!%Y-%m-%d %H:%M", seconds) .. " (" .. tostring(format) .. ")"
			end,
		}
		return readonlyProxy("DateTime", { UnixTimestamp = seconds, UnixTimestampMillis = millis }, methods)
	end
	function DateTime.now()
		return make(math.floor(scheduler:time() * 1000))
	end
	function DateTime.fromUnixTimestamp(seconds)
		return make(math.floor(seconds * 1000))
	end
	function DateTime.fromUnixTimestampMillis(millis)
		return make(math.floor(millis))
	end
	function DateTime.fromUniversalTime(year, month, day, hour, minute, second)
		local timestamp = os.time({
			year = year,
			month = month or 1,
			day = day or 1,
			hour = hour or 0,
			min = minute or 0,
			sec = second or 0,
			isdst = false,
		})
		return make(timestamp * 1000)
	end
	return table.freeze(DateTime)
end

local function paramsFactory(typeName)
	return {
		new = function()
			return readonlyProxy(typeName, {
				FilterDescendantsInstances = {},
				FilterType = Enum.RaycastFilterType.Exclude,
				IgnoreWater = false,
				CollisionGroup = "Default",
				RespectCanCollide = false,
				MaxParts = 0,
			}, {
				__writable = {
					FilterDescendantsInstances = true,
					FilterType = true,
					IgnoreWater = true,
					CollisionGroup = true,
					RespectCanCollide = true,
					MaxParts = true,
				},
				AddToFilter = function() end,
			})
		end,
	}
end

-- Lune's CFrame.lookAt (and CFrame.new(position, lookAt)) faces away from the
-- target along Z: towards -Z it returns a LookVector of +Z. Roblox faces the
-- target, so the sandbox gets a CFrame library with those two rebuilt on top
-- of CFrame.fromMatrix, which Lune gets right.
local function lookAt(at, target, up)
	local look = target - at
	if look.Magnitude < 1e-9 then
		return roblox.CFrame.new(at)
	end
	look = look.Unit
	local upVector = up or roblox.Vector3.yAxis
	local right = look:Cross(upVector)
	if right.Magnitude < 1e-6 then
		-- Looking straight along `up`: any right vector perpendicular to it works.
		right = look:Cross(roblox.Vector3.zAxis)
		if right.Magnitude < 1e-6 then
			right = look:Cross(roblox.Vector3.xAxis)
		end
	end
	right = right.Unit
	return roblox.CFrame.fromMatrix(at, right, right:Cross(look), -look)
end

CFrameLib = setmetatable({
	lookAt = lookAt,
	new = function(...)
		local first, second = ...
		if select("#", ...) == 2 and typeof(first) == "Vector3" and typeof(second) == "Vector3" then
			return lookAt(first, second)
		end
		return roblox.CFrame.new(...)
	end,
}, { __index = roblox.CFrame })

function Datatypes.globals(scheduler)
	return {
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		Vector3int16 = roblox.Vector3int16,
		Vector2int16 = roblox.Vector2int16,
		CFrame = CFrameLib,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		BrickColor = roblox.BrickColor,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Rect = roblox.Rect,
		Ray = roblox.Ray,
		Region3 = roblox.Region3,
		Region3int16 = roblox.Region3int16,
		Font = roblox.Font,
		Faces = roblox.Faces,
		Axes = roblox.Axes,
		PhysicalProperties = roblox.PhysicalProperties,
		Enum = roblox.Enum,
		TweenInfo = TweenInfo,
		Random = Random,
		DateTime = Datatypes.newDateTime(scheduler),
		RaycastParams = paramsFactory("RaycastParams"),
		OverlapParams = paramsFactory("OverlapParams"),
	}
end

Datatypes.Random = Random
Datatypes.TweenInfo = TweenInfo
Datatypes.CFrame = CFrameLib

return Datatypes

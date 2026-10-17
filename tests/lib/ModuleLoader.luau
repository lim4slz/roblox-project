--!nonstrict
-- Loads the game's ModuleScripts under Lune so pure logic can be unit tested
-- outside Roblox. It fakes just enough of the Roblox environment:
--   * `script` / `script.Parent.X` resolve to files under src/
--   * `require(script.Parent.X)` loads that file through this loader
--   * Roblox datatypes (Vector3, CFrame, Color3, ...) come from @lune/roblox
--   * `Random` is a tiny deterministic stand-in

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local ModuleLoader = {}

local cache: { [string]: any } = {}

-- Minimal Random replacement (Lune has no Random datatype).
local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	return setmetatable({ state = seed or 12345 }, Random)
end
function Random:NextNumber(low: number?, high: number?): number
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	local unit = self.state / 2147483648
	if low and high then
		return low + (high - low) * unit
	end
	return unit
end
function Random:NextInteger(low: number, high: number): number
	return math.floor(self:NextNumber(low, high + 1 - 1e-9))
end

local function resolve(path: string): string?
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	end
	if fs.isFile(path .. "/init.luau") then
		return path .. "/init.luau"
	end
	return nil
end

local makeNode

-- A proxy for a folder or module on disk that behaves like an Instance for
-- `.Parent` and `.ChildName` lookups.
function makeNode(path: string)
	return setmetatable({ __path = path }, {
		__index = function(self, key)
			if key == "Parent" then
				local parent = string.match(path, "^(.*)/[^/]+$")
				return makeNode(parent)
			end
			return makeNode(path .. "/" .. key)
		end,
	})
end

function ModuleLoader.load(modulePath: string): any
	local file = resolve(modulePath)
	assert(file, "Module not found: " .. modulePath)
	if cache[file] ~= nil then
		return cache[file]
	end

	local env = setmetatable({}, { __index = _G })
	env.script = makeNode(string.gsub(file, "%.luau$", ""))
	if string.match(file, "/init%.luau$") then
		env.script = makeNode(string.gsub(file, "/init%.luau$", ""))
	end
	env.require = function(target)
		if type(target) == "table" and rawget(target, "__path") then
			return ModuleLoader.load(rawget(target, "__path"))
		end
		error("Tests can only require modules via script paths, got " .. tostring(target))
	end
	for _, name in { "Vector3", "CFrame", "Color3", "BrickColor", "UDim", "UDim2", "Enum", "NumberRange" } do
		env[name] = roblox[name]
	end
	env.Random = Random

	local chunk = luau.load(fs.readFile(file), { debugName = file, environment = env })
	local result = chunk()
	cache[file] = result
	return result
end

ModuleLoader.Random = Random

return ModuleLoader

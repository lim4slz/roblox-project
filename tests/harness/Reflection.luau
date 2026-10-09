--[[
	Reflection
	Class metadata from the Roblox reflection database bundled with Lune
	(rbx-dom). Used to validate every property read/write made by game code:
	unknown members, wrong value types and writes to read-only properties fail
	exactly like they would in Roblox.
]]

local roblox = require("@lune/roblox")

local db = roblox.getReflectionDatabase()
local Enum = roblox.Enum

local Reflection = {}

local classCache = {}

local PRIMITIVES = {
	Bool = "boolean",
	String = "string",
	Content = "string",
	ContentId = "string",
	BinaryString = "string",
	SharedString = "string",
	Int32 = "number",
	Int64 = "number",
	Float32 = "number",
	Float64 = "number",
	Color3uint8 = "Color3",
}

local function enumName(datatype: string): string?
	return string.match(datatype, "^Enum%.(.+)$")
end

function Reflection.exists(className: string): boolean
	return db:GetClass(className) ~= nil
end

function Reflection.class(className: string)
	local cached = classCache[className]
	if cached then
		return cached
	end
	local def = db:GetClass(className)
	if not def then
		return nil
	end
	local chain = {}
	local props = {}
	local current = def
	while current do
		table.insert(chain, current.Name)
		for name, prop in current.Properties do
			if props[name] == nil then
				local tags = {}
				for _, tag in prop.Tags do
					tags[tag] = true
				end
				props[name] = {
					name = name,
					owner = current.Name,
					datatype = tostring(prop.Datatype),
					scriptability = tostring(prop.Scriptability),
					readOnly = tags.ReadOnly == true or tostring(prop.Scriptability) == "Read",
					deprecated = tags.Deprecated == true,
					hasDefault = false,
					default = nil,
				}
			end
		end
		current = current.Superclass and db:GetClass(current.Superclass) or nil
	end
	-- Defaults: the most specific class that defines a default wins.
	for index = #chain, 1, -1 do
		local classDef = db:GetClass(chain[index])
		for name, value in classDef.DefaultProperties do
			local prop = props[name]
			if prop then
				prop.default = value
				prop.hasDefault = true
			end
		end
	end
	local tags = {}
	for _, tag in def.Tags do
		tags[tag] = true
	end
	local info = {
		name = className,
		chain = chain,
		props = props,
		creatable = not tags.NotCreatable and not tags.Service,
		isService = tags.Service == true,
		tags = tags,
	}
	classCache[className] = info
	return info
end

function Reflection.isA(className: string, base: string): boolean
	local info = Reflection.class(className)
	if not info then
		return false
	end
	return table.find(info.chain, base) ~= nil
end

local function typeOf(value)
	return typeof(value)
end

-- Validates (and coerces, for enum names/values) a value for a property datatype.
-- Returns (ok, valueToStore, errorMessage)
function Reflection.coerce(datatype: string, value: any, isInstance: (any) -> boolean)
	local enumTypeName = enumName(datatype)
	if enumTypeName then
		local enumType = Enum[enumTypeName]
		if typeOf(value) == "EnumItem" then
			if tostring(value.EnumType) == tostring(enumType) then
				return true, value
			end
			return false, nil, string.format("expected Enum.%s, got %s", enumTypeName, tostring(value))
		elseif type(value) == "string" then
			local ok, item = pcall(function()
				return enumType[value]
			end)
			if ok and item then
				return true, item
			end
		elseif type(value) == "number" then
			for _, item in enumType:GetEnumItems() do
				if item.Value == value then
					return true, item
				end
			end
		end
		return false, nil, string.format("expected Enum.%s, got %s", enumTypeName, typeOf(value))
	end
	if datatype == "Ref" then
		if value == nil or isInstance(value) then
			return true, value
		end
		return false, nil, "expected Instance, got " .. typeOf(value)
	end
	if datatype == "OptionalCFrame" then
		if value == nil or typeOf(value) == "CFrame" then
			return true, value
		end
		return false, nil, "expected CFrame or nil"
	end
	if datatype == "PhysicalProperties" then
		if value == nil or typeOf(value) == "PhysicalProperties" then
			return true, value
		end
		return false, nil, "expected PhysicalProperties or nil"
	end
	local expected = PRIMITIVES[datatype] or datatype
	if expected == "number" then
		if type(value) == "number" then
			return true, value
		end
		return false, nil, "expected number, got " .. typeOf(value)
	end
	if typeOf(value) == expected then
		return true, value
	end
	-- Unknown / exotic datatypes are accepted as-is.
	local known = PRIMITIVES[datatype] ~= nil
		or roblox[datatype] ~= nil
		or datatype == "Vector3"
		or datatype == "CFrame"
	if not known then
		return true, value
	end
	return false, nil, string.format("expected %s, got %s", expected, typeOf(value))
end

Reflection.db = db

return Reflection

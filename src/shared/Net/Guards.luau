--!strict
--[[
	Guards
	Runtime validators for data arriving from clients. Everything a client sends
	is untrusted: wrong types, NaN/inf, huge strings, extra keys and nested
	tables are all rejected before any handler runs.

	A guard is a function (value) -> (ok, errorMessage?).
]]

export type Guard = (value: any) -> (boolean, string?)

local Guards = {}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Guards.boolean(): Guard
	return function(value)
		if type(value) == "boolean" then
			return true, nil
		end
		return false, "expected boolean"
	end
end

function Guards.number(min: number, max: number): Guard
	return function(value)
		if not isFiniteNumber(value) then
			return false, "expected finite number"
		end
		if value < min or value > max then
			return false, "number out of range"
		end
		return true, nil
	end
end

function Guards.integer(min: number, max: number): Guard
	return function(value)
		if not isFiniteNumber(value) or value % 1 ~= 0 then
			return false, "expected integer"
		end
		if value < min or value > max then
			return false, "integer out of range"
		end
		return true, nil
	end
end

function Guards.string(minLength: number, maxLength: number, pattern: string?): Guard
	return function(value)
		if type(value) ~= "string" then
			return false, "expected string"
		end
		if #value < minLength or #value > maxLength then
			return false, "string length out of range"
		end
		if not utf8.len(value) then
			return false, "invalid utf-8"
		end
		if pattern and not string.match(value, pattern) then
			return false, "string has invalid characters"
		end
		return true, nil
	end
end

--- Catalog-style identifier: letters, digits and underscores, 1-40 characters.
function Guards.id(): Guard
	return Guards.string(1, 40, "^[%w_]+$")
end

--- An identifier or the empty string (used for "unequip").
function Guards.idOrEmpty(): Guard
	local inner = Guards.id()
	return function(value)
		if value == "" then
			return true, nil
		end
		return inner(value)
	end
end

function Guards.oneOf(options: { string }): Guard
	local set: { [string]: boolean } = {}
	for _, option in options do
		set[option] = true
	end
	return function(value)
		if type(value) == "string" and set[value] then
			return true, nil
		end
		return false, "unexpected value"
	end
end

function Guards.optional(inner: Guard): Guard
	return function(value)
		if value == nil then
			return true, nil
		end
		return inner(value)
	end
end

--- Exact table shape: every listed field is validated and unknown keys are rejected.
function Guards.shape(fields: { [string]: Guard }): Guard
	return function(value)
		if type(value) ~= "table" then
			return false, "expected table"
		end
		if getmetatable(value) ~= nil then
			return false, "unexpected metatable"
		end
		for key in value do
			if type(key) ~= "string" or fields[key] == nil then
				return false, "unexpected key " .. tostring(key)
			end
		end
		for key, guard in fields do
			local ok, err = guard(value[key])
			if not ok then
				return false, key .. ": " .. (err or "invalid")
			end
		end
		return true, nil
	end
end

--- Rough serialized size of a payload, used to reject oversized requests early.
function Guards.approximateSize(value: any, depth: number?): number
	local level = depth or 0
	if level > 8 then
		return math.huge
	end
	local kind = type(value)
	if kind == "string" then
		return #value + 2
	elseif kind == "table" then
		local total = 2
		for key, child in value do
			total += Guards.approximateSize(key, level + 1) + Guards.approximateSize(child, level + 1) + 1
		end
		return total
	end
	return 8
end

return table.freeze(Guards)

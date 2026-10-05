--[[
	Serialize
	Copies values across a network or storage boundary and fails loudly where
	Roblox would silently lose data:
	  * remotes: functions, mixed tables, sparse arrays, non-string dictionary keys
	  * DataStores: all of the above plus Instances, userdata and NaN/inf
]]

local Registry = require("./Registry")

local Serialize = {}

local function classifyTable(t)
	local count = 0
	local maxIndex = 0
	local hasString = false
	local hasOther = false
	for key in t do
		count += 1
		local kind = type(key)
		if kind == "number" and key >= 1 and key % 1 == 0 then
			maxIndex = math.max(maxIndex, key)
		elseif kind == "string" then
			hasString = true
		else
			hasOther = true
		end
	end
	return count, maxIndex, hasString, hasOther
end

local function copy(value, path, mode, seen)
	local kind = type(value)
	if kind == "nil" or kind == "boolean" or kind == "string" then
		return value
	elseif kind == "number" then
		if mode == "datastore" and (value ~= value or value == math.huge or value == -math.huge) then
			error(string.format("%s: cannot store NaN/inf at %s", mode, path), 0)
		end
		return value
	elseif kind == "function" or kind == "thread" then
		error(string.format("%s: cannot send %s at %s", mode, kind, path), 0)
	elseif kind == "buffer" then
		return buffer.fromstring(buffer.tostring(value))
	elseif kind == "userdata" then
		local typeName = Registry.typeName(value)
		if typeName == "Instance" then
			if mode == "datastore" then
				error(string.format("datastore: cannot store Instance at %s", path), 0)
			end
			return value
		elseif typeName ~= nil then
			error(string.format("%s: cannot send %s at %s", mode, typeName, path), 0)
		end
		-- Roblox datatypes (Vector3, CFrame, ...) are immutable values.
		if mode == "datastore" then
			error(string.format("datastore: cannot store %s at %s (serialize it first)", typeof(value), path), 0)
		end
		return value
	elseif kind == "table" then
		if seen[value] then
			error(string.format("%s: cyclic table at %s", mode, path), 0)
		end
		seen[value] = true
		local count, maxIndex, hasString, hasOther = classifyTable(value)
		if hasOther then
			error(string.format("%s: table with non-string/non-integer keys at %s", mode, path), 0)
		end
		local result = {}
		if maxIndex > 0 then
			if hasString then
				error(string.format("%s: mixed array/dictionary table at %s (data would be lost)", mode, path), 0)
			end
			if maxIndex ~= count then
				error(string.format("%s: sparse array at %s (data after the first nil would be lost)", mode, path), 0)
			end
			for index = 1, maxIndex do
				result[index] = copy(value[index], path .. "[" .. index .. "]", mode, seen)
			end
		else
			for key, child in value do
				result[key] = copy(child, path .. "." .. tostring(key), mode, seen)
			end
		end
		seen[value] = nil
		return result
	end
	error(string.format("%s: unsupported value %s at %s", mode, kind, path), 0)
end

function Serialize.remote(value, path)
	return copy(value, path or "arg", "remote", {})
end

function Serialize.remoteArgs(args)
	local result = { n = args.n }
	for index = 1, args.n do
		result[index] = copy(args[index], "arg" .. index, "remote", {})
	end
	return result
end

function Serialize.datastore(value, path)
	return copy(value, path or "value", "datastore", {})
end

-- Approximate JSON size in characters (DataStore 4MB limit, MessagingService 1KB).
function Serialize.size(value): number
	local kind = type(value)
	if kind == "string" then
		return #value + 2
	elseif kind == "number" then
		return #tostring(value)
	elseif kind == "boolean" then
		return 5
	elseif kind == "table" then
		local total = 2
		for key, child in value do
			total += Serialize.size(key) + Serialize.size(child) + 2
		end
		return total
	end
	return 4
end

return Serialize

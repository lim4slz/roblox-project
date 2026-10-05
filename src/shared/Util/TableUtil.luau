--!strict
--[[
	TableUtil
	Small, dependency-free helpers for working with plain data tables
	(player data, catalog entries, network payloads).
]]

local TableUtil = {}

--- Deep copy of a plain data table. Metatables are not copied.
function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[TableUtil.deepCopy(key)] = TableUtil.deepCopy(child)
	end
	return (copy :: any) :: T
end

--- Structural equality for plain data (numbers, strings, booleans, nested tables).
function TableUtil.deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not TableUtil.deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

--- Fills missing string keys in `target` from `template` (recursively). Existing values win.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if type(key) == "string" then
			local current = target[key]
			if current == nil then
				target[key] = TableUtil.deepCopy(value)
			elseif type(current) == "table" and type(value) == "table" then
				TableUtil.reconcile(current, value)
			end
		end
	end
end

--- Number of entries in a dictionary-like table.
function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

--- Sorted list of the keys of a dictionary (string keys sort alphabetically).
function TableUtil.sortedKeys<K>(t: { [K]: any }): { K }
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys, function(a: any, b: any)
		return tostring(a) < tostring(b)
	end)
	return keys
end

--- Recursively freezes a table and all nested tables (catalog data must never be mutated).
function TableUtil.deepFreeze<T>(t: T): T
	if type(t) ~= "table" or table.isfrozen(t :: any) then
		return t
	end
	for _, value in t :: any do
		if type(value) == "table" then
			TableUtil.deepFreeze(value)
		end
	end
	return table.freeze(t :: any) :: any
end

--- Returns a new array with the elements of `list` for which `predicate` returns true.
function TableUtil.filter<T>(list: { T }, predicate: (T) -> boolean): { T }
	local result = {}
	for _, item in list do
		if predicate(item) then
			table.insert(result, item)
		end
	end
	return result
end

--- Returns a new array with `mapper` applied to every element of `list`.
function TableUtil.map<T, U>(list: { T }, mapper: (T) -> U): { U }
	local result = table.create(#list)
	for index, item in list do
		result[index] = mapper(item)
	end
	return result
end

return TableUtil

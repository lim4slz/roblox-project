--[[
	Expect
	Minimal Jest-style assertions: expect(value).toBe(x), .never.toBe(x), ...
]]

local function render(value, depth)
	depth = depth or 0
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) ~= "table" or depth > 3 then
		return tostring(value)
	end
	local parts = {}
	local count = 0
	for key, child in value do
		count += 1
		if count > 12 then
			table.insert(parts, "...")
			break
		end
		table.insert(parts, tostring(key) .. " = " .. render(child, depth + 1))
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
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

local function makeMatchers(actual, negate)
	local function check(passed, message)
		if negate then
			passed = not passed
			message = "NOT " .. message
		end
		if not passed then
			error("Expectation failed: " .. message, 3)
		end
	end
	local matchers = {}
	function matchers.toBe(expected)
		check(actual == expected, string.format("expected %s to be %s", render(actual), render(expected)))
	end
	function matchers.toEqual(expected)
		check(deepEqual(actual, expected), string.format("expected %s to deep-equal %s", render(actual), render(expected)))
	end
	function matchers.toBeTruthy()
		check(actual ~= nil and actual ~= false, string.format("expected %s to be truthy", render(actual)))
	end
	function matchers.toBeFalsy()
		check(actual == nil or actual == false, string.format("expected %s to be falsy", render(actual)))
	end
	function matchers.toBeNil()
		check(actual == nil, string.format("expected %s to be nil", render(actual)))
	end
	function matchers.toBeGreaterThan(n)
		check(type(actual) == "number" and actual > n, string.format("expected %s > %s", render(actual), render(n)))
	end
	function matchers.toBeGreaterThanOrEqual(n)
		check(type(actual) == "number" and actual >= n, string.format("expected %s >= %s", render(actual), render(n)))
	end
	function matchers.toBeLessThan(n)
		check(type(actual) == "number" and actual < n, string.format("expected %s < %s", render(actual), render(n)))
	end
	function matchers.toBeLessThanOrEqual(n)
		check(type(actual) == "number" and actual <= n, string.format("expected %s <= %s", render(actual), render(n)))
	end
	function matchers.toBeCloseTo(n, epsilon)
		check(
			type(actual) == "number" and math.abs(actual - n) <= (epsilon or 1e-6),
			string.format("expected %s to be close to %s", render(actual), render(n))
		)
	end
	function matchers.toContain(item)
		local found = false
		if type(actual) == "string" then
			found = string.find(actual, item, 1, true) ~= nil
		elseif type(actual) == "table" then
			for _, value in actual do
				if value == item then
					found = true
				end
			end
		end
		check(found, string.format("expected %s to contain %s", render(actual), render(item)))
	end
	function matchers.toMatch(pattern)
		check(type(actual) == "string" and string.match(actual, pattern) ~= nil, string.format("expected %s to match %s", render(actual), pattern))
	end
	function matchers.toHaveLength(n)
		local length = if type(actual) == "table" or type(actual) == "string" then #actual else -1
		check(length == n, string.format("expected length %d, got %d (%s)", n, length, render(actual)))
	end
	function matchers.toThrow(pattern)
		assert(type(actual) == "function", "toThrow expects a function")
		local ok, err = pcall(actual)
		local passed = not ok and (pattern == nil or string.find(tostring(err), pattern, 1, true) ~= nil)
		check(passed, string.format("expected function to throw%s (got %s)", if pattern then " '" .. pattern .. "'" else "", if ok then "no error" else tostring(err)))
	end
	return matchers
end

local function expect(actual)
	local matchers = makeMatchers(actual, false)
	matchers.never = makeMatchers(actual, true)
	return matchers
end

return {
	expect = expect,
	deepEqual = deepEqual,
	render = render,
}

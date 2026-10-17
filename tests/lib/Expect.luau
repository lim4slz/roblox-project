--!nonstrict
-- A deliberately tiny test harness: describe/it blocks and a few assertions.

local Expect = {}

local results = { passed = 0, failed = 0, failures = {} :: { string } }
local prefix = ""

function Expect.describe(name: string, body: () -> ())
	local previous = prefix
	prefix = previous .. name .. " > "
	body()
	prefix = previous
end

function Expect.it(name: string, body: () -> ())
	local ok, err = pcall(body)
	if ok then
		results.passed += 1
		print("  ok   " .. prefix .. name)
	else
		results.failed += 1
		table.insert(results.failures, prefix .. name .. "\n       " .. tostring(err))
		print("  FAIL " .. prefix .. name .. "\n       " .. tostring(err))
	end
end

function Expect.equal(actual, expected, message: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sexpected %s, got %s",
				if message then message .. ": " else "",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

function Expect.near(actual: number, expected: number, tolerance: number, message: string?)
	if math.abs(actual - expected) > tolerance then
		error(
			string.format(
				"%sexpected ~%s, got %s",
				if message then message .. ": " else "",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

function Expect.truthy(value, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function Expect.results()
	return results
end

return Expect

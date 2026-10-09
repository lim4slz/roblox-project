--[[
	TestRunner
	describe / it blocks with per-test isolation and a summary report.
	Spec files return function(t) ... end where `t` exposes describe, it,
	expect, beforeEach, afterEach and harness helpers.
]]

local Expect = require("./Expect")

local TestRunner = {}

function TestRunner.new(options)
	options = options or {}
	local runner = {
		filter = options.filter,
		results = {},
		stack = {},
		hooks = {},
		current = nil,
	}

	local api = {}
	api.expect = Expect.expect

	function api.describe(name, body)
		table.insert(runner.stack, name)
		table.insert(runner.hooks, { before = {}, after = {} })
		body()
		table.remove(runner.hooks)
		table.remove(runner.stack)
	end

	function api.beforeEach(fn)
		table.insert(runner.hooks[#runner.hooks].before, fn)
	end

	function api.afterEach(fn)
		table.insert(runner.hooks[#runner.hooks].after, fn)
	end

	function api.it(name, body)
		local fullName = table.concat(runner.stack, " > ") .. " > " .. name
		if runner.filter and not string.find(string.lower(fullName), string.lower(runner.filter), 1, true) then
			return
		end
		local hooks = {}
		for _, level in runner.hooks do
			table.insert(hooks, level)
		end
		local started = os.clock()
		local ok, err = xpcall(function()
			for _, level in hooks do
				for _, hook in level.before do
					hook()
				end
			end
			body()
		end, function(message)
			return debug.traceback(tostring(message), 2)
		end)
		for index = #hooks, 1, -1 do
			for _, hook in hooks[index].after do
				local hookOk, hookErr = pcall(hook)
				if not hookOk and ok then
					ok, err = false, tostring(hookErr)
				end
			end
		end
		local elapsed = os.clock() - started
		table.insert(runner.results, { name = fullName, ok = ok, err = err, elapsed = elapsed, file = runner.file })
		if ok then
			print(string.format("  \27[32m✓\27[0m %s \27[90m(%.0fms)\27[0m", fullName, elapsed * 1000))
		else
			print(string.format("  \27[31m✗ %s\27[0m\n%s", fullName, err))
		end
	end

	function api.skip(name)
		table.insert(runner.results, { name = table.concat(runner.stack, " > ") .. " > " .. name, ok = true, skipped = true })
	end

	runner.api = api

	function runner.runFile(path, spec, extras)
		runner.file = path
		for key, value in extras or {} do
			api[key] = value
		end
		print("\27[1m" .. path .. "\27[0m")
		local ok, err = xpcall(function()
			spec(api)
		end, function(message)
			return debug.traceback(tostring(message), 2)
		end)
		if not ok then
			table.insert(runner.results, { name = path .. " (load)", ok = false, err = err, file = path })
			print("  \27[31m✗ failed to run spec file\27[0m\n" .. err)
		end
	end

	function runner.summary()
		local passed, failed, skipped = 0, 0, 0
		for _, result in runner.results do
			if result.skipped then
				skipped += 1
			elseif result.ok then
				passed += 1
			else
				failed += 1
			end
		end
		return passed, failed, skipped
	end

	return runner
end

return TestRunner

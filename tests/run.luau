--[[
	Test entry point.

	  lune run tests/run                 -- build the place and run every spec
	  lune run tests/run -- unit         -- only specs whose path or test name matches "unit"
	  lune run tests/run -- --no-build   -- reuse build/test.rbxl

	Builds the place with Rojo (the exact file Studio would open), generates a
	sourcemap for readable stack traces, then runs tests/**/*.spec.luau.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local TestRunner = require("./harness/TestRunner")
local Runtime = require("./harness/Runtime")

local args = process.args
local filter = nil
local build = true
local verbose = false
for _, arg in args do
	if arg == "--no-build" then
		build = false
	elseif arg == "--verbose" then
		verbose = true
	elseif string.sub(arg, 1, 2) ~= "--" then
		filter = arg
	end
end

local function run(command, commandArgs)
	local result = process.exec(command, commandArgs)
	if not result.ok then
		print(result.stdout)
		print(result.stderr)
		error(command .. " failed")
	end
end

if build then
	if not fs.isDir("build") then
		fs.writeDir("build")
	end
	run("rojo", { "build", "default.project.json", "--output", "build/test.rbxl" })
	run("rojo", { "sourcemap", "default.project.json", "--output", "build/sourcemap.json" })
end

local specFiles = {}
local function collect(dir)
	if not fs.isDir(dir) then
		return
	end
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, entry in entries do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			collect(path)
		elseif string.match(entry, "%.spec%.luau$") then
			table.insert(specFiles, path)
		end
	end
end
collect("tests/unit")
collect("tests/integration")
collect("tests/e2e")

local runner = TestRunner.new({ filter = nil })
local started = os.clock()

for _, path in specFiles do
	local include = filter == nil or string.find(string.lower(path), string.lower(filter), 1, true) ~= nil
	if include then
		local relative = string.gsub(path, "^tests/", "")
		local modulePath = "./" .. string.gsub(relative, "%.luau$", "")
		local spec = require(modulePath)
		runner.runFile(path, spec, {
			Runtime = Runtime,
			newWorld = function(options)
				options = options or {}
				options.verbose = options.verbose or verbose
				return Runtime.new(options)
			end,
		})
	end
end

local passed, failed, skipped = runner.summary()
print(string.format(
	"\n\27[1m%d passed\27[0m, %s%d failed\27[0m, %d skipped in %.2fs",
	passed,
	if failed > 0 then "\27[31m" else "",
	failed,
	skipped,
	os.clock() - started
))
if failed > 0 then
	print("\nFailures:")
	for _, result in runner.results do
		if not result.ok then
			print("  - " .. result.name)
		end
	end
	process.exit(1)
end

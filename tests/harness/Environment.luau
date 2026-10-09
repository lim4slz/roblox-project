--[[
	Environment
	Builds the global environment for scripts running in a context.

	* task / os / tick / time use the virtual scheduler
	* print / warn go to the world log (tests can assert on them)
	* typeof understands mock Instances and signals
	* deprecated globals (wait, spawn, delay) are intentionally absent
	* every context has its own module cache, `shared` and `_G`, like separate VMs
]]

local luau = require("@lune/luau")
local Registry = require("./Registry")
local Instances = require("./Instances")
local Datatypes = require("./Datatypes")

local Environment = {}

local function mockTypeof(value)
	local name = Registry.typeName(value)
	if name then
		return name
	end
	return typeof(value)
end

local function packToString(...)
	local parts = {}
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		parts[index] = tostring(value)
	end
	return table.concat(parts, " ")
end

local function makeTask(scheduler, ctx)
	return table.freeze({
		spawn = function(fn, ...)
			return scheduler:spawn(fn, ...)
		end,
		defer = function(fn, ...)
			return scheduler:defer(fn, ...)
		end,
		delay = function(seconds, fn, ...)
			return scheduler:delay(seconds, fn, ...)
		end,
		wait = function(seconds)
			return scheduler:wait(seconds)
		end,
		cancel = function(thread)
			scheduler:cancel(thread)
		end,
		desynchronize = function()
			local current = scheduler:currentCtx()
			if not (current and current.actor) then
				error("task.desynchronize() can only be called from scripts that are descendants of an Actor", 2)
			end
			scheduler:setParallel(true)
		end,
		synchronize = function()
			scheduler:setParallel(false)
		end,
	})
end

local function makeCoroutine(scheduler)
	local wrapped = table.clone(coroutine)
	wrapped.create = function(fn)
		return scheduler:newThread(fn, scheduler:currentCtx())
	end
	wrapped.wrap = function(fn)
		local thread = scheduler:newThread(fn, scheduler:currentCtx())
		return function(...)
			local results = table.pack(coroutine.resume(thread, ...))
			if not results[1] then
				error(results[2], 2)
			end
			return table.unpack(results, 2, results.n)
		end
	end
	return table.freeze(wrapped)
end

function Environment.build(ctx, server, loader)
	local world = server.world
	local scheduler = world.scheduler

	local globals = {
		assert = assert,
		error = error,
		getmetatable = getmetatable,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		rawequal = rawequal,
		rawget = rawget,
		rawlen = rawlen,
		rawset = rawset,
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		xpcall = xpcall,
		newproxy = newproxy,
		gcinfo = gcinfo,
		unpack = table.unpack,
		string = string,
		table = table,
		math = math,
		bit32 = bit32,
		utf8 = utf8,
		buffer = buffer,
		vector = vector,
		coroutine = makeCoroutine(scheduler),
		debug = table.freeze({
			traceback = debug.traceback,
			info = debug.info,
			profilebegin = function() end,
			profileend = function() end,
			setmemorycategory = function() end,
			resetmemorycategory = function() end,
			getmemorycategory = function()
				return "Default"
			end,
		}),
		os = table.freeze({
			time = function(t)
				if t ~= nil then
					return os.time(t)
				end
				return math.floor(scheduler:time())
			end,
			clock = function()
				return scheduler.clock
			end,
			date = function(format, t)
				return os.date(format, t or math.floor(scheduler:time()))
			end,
			difftime = function(a, b)
				return a - (b or 0)
			end,
		}),
		tick = function()
			return scheduler:time()
		end,
		time = function()
			return scheduler.clock
		end,
		elapsedTime = function()
			return scheduler.clock
		end,
		print = function(...)
			world:log("print", scheduler:currentCtx(), packToString(...))
		end,
		warn = function(...)
			world:log("warn", scheduler:currentCtx(), packToString(...))
		end,
		typeof = mockTypeof,
		task = makeTask(scheduler, ctx),
		game = server.dataModel,
		workspace = server.services.Workspace,
		shared = ctx.shared,
		Instance = table.freeze({
			new = function(className, parent)
				local current = scheduler:currentCtx()
				if scheduler:isParallel() then
					error("Instance.new is not safe to call in parallel", 2)
				end
				local proxy = Instances.create(server, className, current)
				if parent ~= nil then
					proxy.Parent = parent
				end
				return proxy
			end,
		}),
		require = function(module)
			return loader.require(scheduler:currentCtx(), module)
		end,
		settings = function()
			return { Rendering = { QualityLevel = 10 } }
		end,
		UserSettings = function()
			return {
				GetService = function()
					return { SavedQualityLevel = 10 }
				end,
			}
		end,
	}
	for name, value in Datatypes.globals(scheduler) do
		globals[name] = value
	end
	globals._G = ctx._G
	return globals
end

-- Environment table for one script (its own `script` global).
function Environment.forScript(ctx, scriptProxy)
	return setmetatable({ script = scriptProxy }, { __index = ctx.globals })
end

function Environment.compile(source, debugName, env)
	return luau.load(source, {
		debugName = debugName,
		environment = env,
		injectGlobals = false,
	})
end

return Environment

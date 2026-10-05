--[[
	Scheduler
	Virtual-time implementation of Roblox's task scheduler.

	* Time only advances when the harness steps it, so tests that simulate
	  minutes of play (auto-saves, festivals, respawn timers) run instantly
	  and deterministically.
	* Every thread is tagged with the execution context (server or a specific
	  client) that created it. Signals, remotes and property overlays use this
	  to behave like separate Roblox peers.
	* Errors thrown inside spawned threads are recorded (like the Output window)
	  instead of crashing the test process.
]]

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new(options)
	options = options or {}
	local self = setmetatable({
		clock = 0, -- seconds since start (what os.clock() returns)
		epoch = options.epoch or 1790000000, -- unix time at clock 0
		frameIndex = 0,
		timers = {},
		deferred = {},
		threadCtx = setmetatable({}, { __mode = "k" }),
		threadParallel = setmetatable({}, { __mode = "k" }),
		errors = {},
		logs = {},
		seq = 0,
		mainCtx = nil,
		onError = nil,
		maxDeferredPerFlush = 200000,
	}, Scheduler)
	return self
end

function Scheduler:time(): number
	return self.epoch + self.clock
end

function Scheduler:currentCtx()
	local thread = coroutine.running()
	return self.threadCtx[thread] or self.mainCtx
end

function Scheduler:ctxOf(thread)
	return self.threadCtx[thread]
end

function Scheduler:setMainCtx(ctx)
	self.mainCtx = ctx
end

function Scheduler:register(thread, ctx, parallel)
	self.threadCtx[thread] = ctx
	if parallel then
		self.threadParallel[thread] = true
	end
	return thread
end

function Scheduler:isParallel(): boolean
	return self.threadParallel[coroutine.running()] == true
end

function Scheduler:setParallel(value: boolean)
	local thread = coroutine.running()
	self.threadParallel[thread] = value or nil
end

function Scheduler:newThread(fn, ctx, parallel)
	local thread = coroutine.create(fn)
	return self:register(thread, ctx or self:currentCtx(), parallel)
end

function Scheduler:reportError(thread, err)
	local ctx = self.threadCtx[thread]
	local trace = debug.traceback(thread, tostring(err))
	local entry = { ctx = ctx and ctx.id or "main", message = tostring(err), traceback = trace }
	table.insert(self.errors, entry)
	if self.onError then
		self.onError(entry)
	end
end

function Scheduler:resume(thread, ...)
	if coroutine.status(thread) ~= "suspended" then
		return
	end
	local ctx = self.threadCtx[thread]
	if ctx and ctx.dead then
		-- The peer that owned this thread disconnected or shut down.
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		self:reportError(thread, err)
	end
end

-- Runs `fn` (or resumes a thread) immediately in a new thread of `ctx`.
function Scheduler:spawnIn(ctx, fnOrThread, ...)
	local thread = fnOrThread
	if type(fnOrThread) == "function" then
		thread = self:newThread(fnOrThread, ctx)
	end
	self:resume(thread, ...)
	return thread
end

function Scheduler:spawn(fnOrThread, ...)
	return self:spawnIn(self:currentCtx(), fnOrThread, ...)
end

function Scheduler:deferIn(ctx, fnOrThread, args, parallel)
	local thread = fnOrThread
	if type(fnOrThread) == "function" then
		thread = self:newThread(fnOrThread, ctx, parallel)
	end
	table.insert(self.deferred, { thread = thread, args = args or { n = 0 } })
	return thread
end

function Scheduler:defer(fnOrThread, ...)
	return self:deferIn(self:currentCtx(), fnOrThread, table.pack(...))
end

function Scheduler:delay(seconds, fnOrThread, ...)
	local thread = fnOrThread
	if type(fnOrThread) == "function" then
		thread = self:newThread(fnOrThread, self:currentCtx())
	end
	self.seq += 1
	table.insert(self.timers, {
		at = self.clock + math.max(seconds or 0, 0),
		frame = self.frameIndex,
		seq = self.seq,
		thread = thread,
		args = table.pack(...),
		started = self.clock,
		isWait = false,
	})
	return thread
end

function Scheduler:wait(seconds)
	local thread = coroutine.running()
	assert(coroutine.isyieldable(), "task.wait called from a non-yieldable context")
	self.seq += 1
	table.insert(self.timers, {
		at = self.clock + math.max(seconds or 0, 0),
		frame = self.frameIndex,
		seq = self.seq,
		thread = thread,
		started = self.clock,
		isWait = true,
	})
	return coroutine.yield()
end

function Scheduler:cancel(thread)
	for index = #self.timers, 1, -1 do
		if self.timers[index].thread == thread then
			table.remove(self.timers, index)
		end
	end
	for index = #self.deferred, 1, -1 do
		if self.deferred[index].thread == thread then
			table.remove(self.deferred, index)
		end
	end
	if coroutine.status(thread) == "suspended" then
		coroutine.close(thread)
	end
end

function Scheduler:flushDeferred()
	local processed = 0
	while #self.deferred > 0 do
		local batch = self.deferred
		self.deferred = {}
		for _, entry in batch do
			processed += 1
			if processed > self.maxDeferredPerFlush then
				error("Scheduler: deferred thread flood (possible infinite task.defer loop)")
			end
			self:resume(entry.thread, table.unpack(entry.args, 1, entry.args.n))
		end
	end
end

function Scheduler:resumeTimers()
	local due = {}
	local remaining = {}
	for _, timer in self.timers do
		if timer.at <= self.clock and timer.frame < self.frameIndex then
			table.insert(due, timer)
		else
			table.insert(remaining, timer)
		end
	end
	self.timers = remaining
	table.sort(due, function(a, b)
		if a.at == b.at then
			return a.seq < b.seq
		end
		return a.at < b.at
	end)
	for _, timer in due do
		if timer.isWait then
			self:resume(timer.thread, self.clock - timer.started)
		else
			self:resume(timer.thread, table.unpack(timer.args, 1, timer.args.n))
		end
	end
end

-- Advances one frame. `hooks.preSimulation(dt)` and `hooks.heartbeat(dt)` fire engine events.
function Scheduler:step(dt, hooks)
	self.clock += dt
	self.frameIndex += 1
	if hooks and hooks.preSimulation then
		hooks.preSimulation(dt)
	end
	self:flushDeferred()
	self:resumeTimers()
	self:flushDeferred()
	if hooks and hooks.heartbeat then
		hooks.heartbeat(dt)
	end
	self:flushDeferred()
	if hooks and hooks.postFrame then
		hooks.postFrame(dt)
	end
	self:flushDeferred()
end

function Scheduler:pendingTimers(): number
	return #self.timers
end

return Scheduler

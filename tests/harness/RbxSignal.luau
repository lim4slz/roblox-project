--[[
	RbxSignal
	Mock of RBXScriptSignal / RBXScriptConnection.

	Each connection remembers the execution context (server/client) of the code
	that connected it. Firing can be filtered by context, which is how one
	shared instance tree behaves like separate peers (e.g. OnClientEvent only
	runs for the targeted player's client).

	Handlers run deferred by default, matching Workspace.SignalBehavior = Deferred.
]]

local Registry = require("./Registry")

local RbxSignal = {}

local function makeConnection(signalState, connection)
	return Registry.proxy("RBXScriptConnection", function(mt)
		mt.__index = function(_, key)
			if key == "Connected" then
				return connection.connected
			elseif key == "Disconnect" then
				return function()
					if connection.connected then
						connection.connected = false
						local index = table.find(signalState.connections, connection)
						if index then
							table.remove(signalState.connections, index)
						end
					end
				end
			end
			error(tostring(key) .. " is not a valid member of RBXScriptConnection", 2)
		end
		mt.__newindex = function()
			error("RBXScriptConnection is read-only", 2)
		end
		mt.__tostring = function()
			return "Connection"
		end
	end)
end

-- Creates a signal. `scheduler` drives handler threads. Returns (proxy, state).
function RbxSignal.new(scheduler, name: string, options)
	options = options or {}
	local state = {
		name = name,
		connections = {},
		scheduler = scheduler,
		immediate = options.immediate == true,
		-- Optional hook: called on Connect (used for remote event queues).
		onConnect = options.onConnect,
	}

	local function connect(fn, once, parallel)
		if type(fn) ~= "function" then
			error("Attempt to connect failed: Passed value is not a function", 3)
		end
		local connection = {
			fn = fn,
			ctx = scheduler:currentCtx(),
			connected = true,
			once = once,
			parallel = parallel,
		}
		table.insert(state.connections, connection)
		connection.proxy = makeConnection(state, connection)
		if state.onConnect then
			state.onConnect(connection)
		end
		return connection.proxy
	end

	local proxy = Registry.proxy("RBXScriptSignal", function(mt)
		mt.__index = function(_, key)
			if key == "Connect" then
				return function(_, fn)
					return connect(fn, false, false)
				end
			elseif key == "Once" then
				return function(_, fn)
					return connect(fn, true, false)
				end
			elseif key == "ConnectParallel" then
				return function(_, fn)
					local ctx = scheduler:currentCtx()
					if not (ctx and ctx.actor) then
						error("ConnectParallel can only be used from scripts that are descendants of an Actor", 2)
					end
					return connect(fn, false, true)
				end
			elseif key == "Wait" then
				return function()
					local thread = coroutine.running()
					connect(function(...)
						scheduler:resume(thread, ...)
					end, true, false)
					return coroutine.yield()
				end
			end
			error(tostring(key) .. " is not a valid member of RBXScriptSignal", 2)
		end
		mt.__tostring = function()
			return "Signal " .. name
		end
	end)
	state.proxy = proxy
	return proxy, state
end

-- Fires the signal. `filter(ctx)` decides which connections receive it.
function RbxSignal.fire(state, filter, ...)
	if #state.connections == 0 then
		return 0
	end
	local args = table.pack(...)
	local delivered = 0
	local snapshot = table.clone(state.connections)
	for _, connection in snapshot do
		if connection.connected and (filter == nil or filter(connection.ctx)) then
			delivered += 1
			if connection.once then
				connection.connected = false
				local index = table.find(state.connections, connection)
				if index then
					table.remove(state.connections, index)
				end
			end
			local ctx = connection.ctx
			local fn = connection.fn
			if state.immediate then
				local thread = state.scheduler:newThread(fn, ctx, connection.parallel)
				state.scheduler:resume(thread, table.unpack(args, 1, args.n))
			else
				state.scheduler:deferIn(ctx, fn, args, connection.parallel)
			end
		end
	end
	return delivered
end

function RbxSignal.disconnectAll(state)
	for _, connection in state.connections do
		connection.connected = false
	end
	table.clear(state.connections)
end

function RbxSignal.count(state, filter): number
	local n = 0
	for _, connection in state.connections do
		if filter == nil or filter(connection.ctx) then
			n += 1
		end
	end
	return n
end

return RbxSignal

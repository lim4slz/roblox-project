--[[
	RemoteEvent, UnreliableRemoteEvent, RemoteFunction, BindableEvent, BindableFunction.

	* FireServer/InvokeServer only work from client contexts, FireClient/InvokeClient
	  only from the server - like Roblox.
	* Arguments are deep-copied with Roblox's serialization limits (Serialize.remote),
	  and Instances the receiver cannot see arrive as nil.
	* Events fired before anyone listens are queued and delivered on Connect.
]]

local Instances = require("../Instances")
local RbxSignal = require("../RbxSignal")
local Serialize = require("../Serialize")

local states = Instances.state

local function ctxOf(st)
	return st.server.scheduler:currentCtx()
end

local function isClient(ctx)
	return ctx ~= nil and ctx.kind == "client"
end

-- Instances invisible to the receiver become nil.
local function forReceiver(args, receiverCtx)
	for index = 1, args.n do
		local value = args[index]
		local st = states(value)
		if st and not Instances.visible(st, receiverCtx) then
			args[index] = nil
		end
	end
	return args
end

local function eventState(st, name)
	return Instances.event(st, name).state
end

local function deliverToServer(st, playerProxy, args)
	local signal = eventState(st, "OnServerEvent")
	local delivered = RbxSignal.fire(signal, function(ctx)
		return ctx == nil or ctx.kind == "server"
	end, playerProxy, table.unpack(args, 1, args.n))
	if delivered == 0 then
		st.extra.serverQueue = st.extra.serverQueue or {}
		table.insert(st.extra.serverQueue, { player = playerProxy, args = args })
	end
	st.server.world.remoteLog:record("ToServer", st.name, args)
end

local function deliverToClient(st, clientCtx, args)
	local signal = eventState(st, "OnClientEvent")
	local delivered = RbxSignal.fire(signal, function(ctx)
		return ctx == clientCtx
	end, table.unpack(args, 1, args.n))
	if delivered == 0 then
		st.extra.clientQueues = st.extra.clientQueues or {}
		local queue = st.extra.clientQueues[clientCtx]
		if not queue then
			queue = {}
			st.extra.clientQueues[clientCtx] = queue
		end
		table.insert(queue, args)
		if #queue == 257 then
			st.server.log("warn", clientCtx, "Remote event invocation queue exhausted for " .. Instances.fullName(st))
		end
	end
	if clientCtx.onRemote then
		clientCtx.onRemote(st.name, args)
	end
end

local function remoteEventDef()
	return {
		methods = {
			FireServer = function(self, ...)
				local st = states(self)
				local ctx = ctxOf(st)
				if not isClient(ctx) then
					error("FireServer can only be called from the client", 2)
				end
				local args = forReceiver(Serialize.remoteArgs(table.pack(...)), st.server.serverCtx)
				st.server.scheduler:deferIn(ctx, function()
					deliverToServer(st, ctx.player, args)
				end)
			end,
			FireClient = function(self, player, ...)
				local st = states(self)
				local ctx = ctxOf(st)
				if isClient(ctx) then
					error("FireClient can only be called from the server", 2)
				end
				local playerState = states(player)
				if not playerState or playerState.className ~= "Player" then
					error("FireClient: player argument must be a Player object", 2)
				end
				local clientCtx = st.server.clientCtxFor(player)
				local args = Serialize.remoteArgs(table.pack(...))
				if clientCtx then
					forReceiver(args, clientCtx)
					deliverToClient(st, clientCtx, args)
				end
			end,
			FireAllClients = function(self, ...)
				local st = states(self)
				local ctx = ctxOf(st)
				if isClient(ctx) then
					error("FireAllClients can only be called from the server", 2)
				end
				local base = Serialize.remoteArgs(table.pack(...))
				for _, clientCtx in st.server.clientContexts() do
					local args = Serialize.remoteArgs(base)
					forReceiver(args, clientCtx)
					deliverToClient(st, clientCtx, args)
				end
			end,
		},
		events = {
			OnServerEvent = {
				onConnect = function(st, connection)
					local queue = st.extra.serverQueue
					if queue and #queue > 0 and (connection.ctx == nil or connection.ctx.kind == "server") then
						st.extra.serverQueue = nil
						for _, entry in queue do
							st.server.scheduler:deferIn(connection.ctx, connection.fn, table.pack(entry.player, table.unpack(entry.args, 1, entry.args.n)))
						end
					end
				end,
			},
			OnClientEvent = {
				onConnect = function(st, connection)
					local queues = st.extra.clientQueues
					local queue = queues and queues[connection.ctx]
					if queue and #queue > 0 then
						queues[connection.ctx] = nil
						for _, args in queue do
							st.server.scheduler:deferIn(connection.ctx, connection.fn, args)
						end
					end
				end,
			},
		},
	}
end

Instances.define("RemoteEvent", remoteEventDef())
Instances.define("UnreliableRemoteEvent", remoteEventDef())

local function callbackProp(name)
	return {
		get = function()
			error(name .. " is a callback member of RemoteFunction; you can only set the callback value, get is not available", 3)
		end,
		set = function(_, st, value)
			if value ~= nil and type(value) ~= "function" then
				error(name .. " must be set to a function", 3)
			end
			st.extra[name] = value
			-- Wake invocations that were waiting for a handler.
			local waiting = st.extra[name .. "Waiting"]
			if value and waiting then
				st.extra[name .. "Waiting"] = nil
				for _, resume in waiting do
					resume()
				end
			end
		end,
	}
end

local function invoke(st, handlerName, callerCtx, receiverCtx, prefixArgs, args)
	local scheduler = st.server.scheduler
	local caller = coroutine.running()
	local function run()
		local handler = st.extra[handlerName]
		scheduler:deferIn(receiverCtx, function()
			local packed = table.pack(pcall(handler, table.unpack(prefixArgs), table.unpack(args, 1, args.n)))
			if packed[1] then
				local ok, results = pcall(Serialize.remoteArgs, table.pack(table.unpack(packed, 2, packed.n)))
				if ok then
					forReceiver(results, callerCtx)
					scheduler:resume(caller, true, results)
				else
					scheduler:resume(caller, false, results)
				end
			else
				scheduler:resume(caller, false, packed[2])
			end
		end)
	end
	if st.extra[handlerName] then
		run()
	else
		st.extra[handlerName .. "Waiting"] = st.extra[handlerName .. "Waiting"] or {}
		table.insert(st.extra[handlerName .. "Waiting"], run)
	end
	local ok, results = coroutine.yield()
	if not ok then
		error(results, 0)
	end
	return table.unpack(results, 1, results.n)
end

Instances.define("RemoteFunction", {
	props = {
		OnServerInvoke = callbackProp("OnServerInvoke"),
		OnClientInvoke = callbackProp("OnClientInvoke"),
	},
	methods = {
		InvokeServer = function(self, ...)
			local st = states(self)
			local ctx = ctxOf(st)
			if not isClient(ctx) then
				error("InvokeServer can only be called from the client", 2)
			end
			local args = forReceiver(Serialize.remoteArgs(table.pack(...)), st.server.serverCtx)
			st.server.world.remoteLog:record("Invoke", st.name, args)
			return invoke(st, "OnServerInvoke", ctx, st.server.serverCtx, { ctx.player }, args)
		end,
		InvokeClient = function(self, player, ...)
			local st = states(self)
			local ctx = ctxOf(st)
			if isClient(ctx) then
				error("InvokeClient can only be called from the server", 2)
			end
			local clientCtx = st.server.clientCtxFor(player)
			if not clientCtx then
				error("InvokeClient: player is not connected", 2)
			end
			local args = forReceiver(Serialize.remoteArgs(table.pack(...)), clientCtx)
			return invoke(st, "OnClientInvoke", ctx, clientCtx, {}, args)
		end,
	},
})

Instances.define("BindableEvent", {
	methods = {
		Fire = function(self, ...)
			local st = states(self)
			local args = Serialize.remoteArgs(table.pack(...))
			RbxSignal.fire(eventState(st, "Event"), nil, table.unpack(args, 1, args.n))
		end,
	},
	events = { Event = true },
})

Instances.define("BindableFunction", {
	props = {
		OnInvoke = {
			get = function()
				error("OnInvoke is a callback member of BindableFunction; you can only set the callback value", 3)
			end,
			set = function(_, st, value)
				st.extra.OnInvoke = value
			end,
		},
	},
	methods = {
		Invoke = function(self, ...)
			local st = states(self)
			local handler = st.extra.OnInvoke
			if not handler then
				error("BindableFunction has no OnInvoke callback", 2)
			end
			return handler(...)
		end,
	},
})

return true

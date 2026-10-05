--!strict
--[[
	Signal
	Lightweight in-process event used for communication between modules that live
	in the same Luau VM (server services or client controllers).

	Every listener runs in its own thread via task.spawn, so a listener that yields
	or errors never blocks the code that fired the signal, nor other listeners.
	Listeners connected or disconnected while firing take effect from the next Fire.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, listener: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, listener: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	GetListenerCount: (self: Signal<T...>) -> number,
}

type ConnectionImpl = {
	Connected: boolean,
	_listener: (...any) -> (),
	_signal: SignalImpl,
	Disconnect: (self: ConnectionImpl) -> (),
}

type SignalImpl = {
	_connections: { ConnectionImpl },
}

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: ConnectionImpl)
	if not self.Connected then
		return
	end
	self.Connected = false
	local connections = self._signal._connections
	local index = table.find(connections, self)
	if index then
		table.remove(connections, index)
	end
end

local SignalClass = {}
SignalClass.__index = SignalClass

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local self: SignalImpl = { _connections = {} }
	return (setmetatable(self, SignalClass) :: any) :: Signal<T...>
end

function SignalClass.Connect(self: SignalImpl, listener: (...any) -> ()): Connection
	assert(type(listener) == "function", "Signal:Connect expects a function")
	local connection: ConnectionImpl = setmetatable({
		Connected = true,
		_listener = listener,
		_signal = self,
	}, Connection) :: any
	table.insert(self._connections, connection)
	return (connection :: any) :: Connection
end

function SignalClass.Once(self: SignalImpl, listener: (...any) -> ()): Connection
	local connection: Connection
	connection = SignalClass.Connect(self, function(...: any)
		connection:Disconnect()
		listener(...)
	end)
	return connection
end

function SignalClass.Wait(self: SignalImpl): ...any
	local thread = coroutine.running()
	SignalClass.Once(self, function(...: any)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function SignalClass.Fire(self: SignalImpl, ...: any)
	-- Snapshot so listeners may connect/disconnect safely while we iterate.
	local snapshot = table.clone(self._connections)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._listener, ...)
		end
	end
end

function SignalClass.DisconnectAll(self: SignalImpl)
	for _, connection in self._connections do
		connection.Connected = false
	end
	table.clear(self._connections)
end

function SignalClass.GetListenerCount(self: SignalImpl): number
	return #self._connections
end

return Signal

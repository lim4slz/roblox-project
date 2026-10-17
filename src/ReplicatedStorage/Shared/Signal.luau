--!nonstrict
-- Minimal in-process signal used for service-to-service and controller-to-
-- controller events. Handlers run in their own thread so one slow or erroring
-- listener can't stall the code that fired the signal.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { any } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(handler)
	local handlers = self._handlers
	local connection = { Connected = true }

	function connection.Disconnect(conn)
		if not conn.Connected then
			return
		end
		conn.Connected = false
		local index = table.find(handlers, conn)
		if index then
			table.remove(handlers, index)
		end
	end

	connection._handler = handler
	table.insert(handlers, connection)
	return connection
end

function Signal:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Iterate over a snapshot so handlers may disconnect themselves safely.
	for _, connection in table.clone(self._handlers) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in table.clone(self._handlers) do
		connection:Disconnect()
	end
end

return Signal

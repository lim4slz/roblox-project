--!strict
--[[
	Trove
	Collects things that must be cleaned up together (connections, instances,
	threads, callbacks) and releases them in reverse order with :Clean().
	Used by controllers/screens so that closing a UI or losing a character never
	leaks event connections.
]]

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, listener: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

type TroveImpl = {
	_items: { any },
	_cleaning: boolean,
}

local TroveClass = {}
TroveClass.__index = TroveClass

local function cleanItem(item: any)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

local Trove = {}

function Trove.new(): Trove
	local self: TroveImpl = { _items = {}, _cleaning = false }
	return (setmetatable(self, TroveClass) :: any) :: Trove
end

function TroveClass.Add(self: TroveImpl, item: any): any
	assert(not self._cleaning, "Cannot add to a Trove while it is cleaning")
	table.insert(self._items, item)
	return item
end

function TroveClass.Connect(self: TroveImpl, signal: RBXScriptSignal, listener: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(listener)
	TroveClass.Add(self, connection)
	return connection
end

function TroveClass.Clean(self: TroveImpl)
	if self._cleaning then
		return
	end
	self._cleaning = true
	local items = self._items
	for index = #items, 1, -1 do
		local item = items[index]
		items[index] = nil
		local ok, err = pcall(cleanItem :: (any) -> any, item)
		if not ok then
			warn("[Trove] cleanup error:", err)
		end
	end
	self._cleaning = false
end

TroveClass.Destroy = TroveClass.Clean

return Trove

--[[
	Registry
	Shared weak tables used across the harness:
	  typeNames[proxy] = "Instance" | "RBXScriptSignal" | ...  (for typeof)
	  states[proxy]    = internal state of a mock Instance
]]

local Registry = {
	typeNames = setmetatable({}, { __mode = "k" }),
	states = setmetatable({}, { __mode = "k" }),
}

-- Creates an opaque userdata whose metatable is configured by `configure`.
function Registry.proxy(typeName: string, configure: (mt: any) -> ())
	local proxy = newproxy(true)
	local mt = getmetatable(proxy)
	configure(mt)
	Registry.typeNames[proxy] = typeName
	return proxy
end

function Registry.typeName(value: any): string?
	return Registry.typeNames[value]
end

return Registry

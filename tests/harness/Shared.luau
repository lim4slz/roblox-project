--[[
	Loads ReplicatedStorage.Shared modules for unit tests (one cached world).
	Modules run in a server context of the harness so their instance-based
	requires and Roblox globals work exactly as in game.
]]

local Runtime = require("./Runtime")

local world, server

local Shared = {}

function Shared.world()
	if not world then
		world = Runtime.new()
		server = world:createServer()
	end
	return world, server
end

function Shared.require(path: string)
	local _, srv = Shared.world()
	return srv:requireAs(nil, "ReplicatedStorage.Shared." .. path)
end

-- Runs `fn` inside the server sandbox (Random, Vector3, ... available).
function Shared.run(fn)
	local w, srv = Shared.world()
	return w:runIn(srv.serverCtx, fn)
end

return Shared

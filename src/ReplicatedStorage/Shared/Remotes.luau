--!strict
-- Every RemoteEvent the game uses. The server creates them on boot; clients
-- wait for them. Keeping the list here means both sides agree on names, and a
-- quick read of this file tells you the whole client/server surface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENT_NAMES = {
	-- Client -> server requests (all validated server-side)
	"ThrowBomb", -- (aimDirection: Vector3, charge: number)
	"SwingSword", -- ()
	"FireRocket", -- (targetPosition: Vector3)
	"AdminCommand", -- (command: string, args: {any}?)
	"SetSpectatePreference", -- (wantsToSpectate: boolean)

	-- Server -> client(s)
	"Knockback", -- (velocity: Vector3) physics for the client-owned character
	"ExplosionFx", -- (position, radius, kind, bricksBroken)
	"StructureFx", -- (position, brickCount) big collapses
	"ActionFx", -- (player, action) arm animations: "Throw" | "Slash" | "Lunge" | "Fire"
	"Announce", -- (kind, payload) big centre-screen messages
	"Toast", -- (text, style) small notifications
	"KillFeed", -- (killerName?, victimName, how, killerTeam?, victimTeam?)
	"DamageFx", -- (amount, fromPosition?) red flash + direction hint
	"DamageNumber", -- (position, amount) floating numbers on training dummies
	"MatchResults", -- (results table)
	"FireworksBurst", -- (position, colorIndex)
	"AdminFeedback", -- (message, ok)
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local cache: { [string]: RemoteEvent } = {}

function Remotes.get(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end
	assert(table.find(EVENT_NAMES, name), "Unknown remote: " .. name)
	local remote = folder:WaitForChild(name) :: RemoteEvent
	cache[name] = remote
	return remote
end

return Remotes

--!strict
-- Server entry point. Services are initialised in dependency order (init wires
-- up events and finds map objects), then started (start kicks off loops).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create the shared state folder and remotes before any client asks for them.
require(ReplicatedStorage.Shared.GameState)
require(ReplicatedStorage.Shared.Remotes)

local Services = script.Parent.Services
local CollisionGroups = require(script.Parent.Lib.CollisionGroups)

local ScoreService = require(Services.ScoreService)
local TeamService = require(Services.TeamService)
local TowerService = require(Services.TowerService)
local WeaponService = require(Services.WeaponService)
local BombService = require(Services.BombService)
local PlayerService = require(Services.PlayerService)
local ZoneService = require(Services.ZoneService)
local EventService = require(Services.EventService)
local LobbyService = require(Services.LobbyService)
local MatchService = require(Services.MatchService)
local AdminService = require(Services.AdminService)

CollisionGroups.setup()

local ordered: { { name: string, module: any } } = {
	{ name = "ScoreService", module = ScoreService },
	{ name = "TeamService", module = TeamService },
	{ name = "TowerService", module = TowerService },
	{ name = "WeaponService", module = WeaponService },
	{ name = "BombService", module = BombService },
	{ name = "PlayerService", module = PlayerService },
	{ name = "ZoneService", module = ZoneService },
	{ name = "EventService", module = EventService },
	{ name = "LobbyService", module = LobbyService },
	{ name = "MatchService", module = MatchService },
	{ name = "AdminService", module = AdminService },
}

-- A broken map object shouldn't take the whole server down with it, so each
-- service starts in isolation and reports its own failure.
for _, entry in ordered do
	if entry.module.init then
		local ok, err = pcall(entry.module.init)
		if not ok then
			warn(`[Main] {entry.name}.init failed: {err}`)
		end
	end
end

for _, entry in ordered do
	if entry.module.start then
		local ok, err = pcall(entry.module.start)
		if not ok then
			warn(`[Main] {entry.name}.start failed: {err}`)
		end
	end
end

print("[Doomspire Brickbattle] Server ready.")

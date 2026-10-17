--!strict
-- Handles the shrinking safe zone (the "storm").
--
-- The radius itself comes from ZoneMath, a pure function of battle time that
-- clients evaluate too, so this service only has to: announce the phases, and
-- once a second hurt anyone standing outside. Checking once per second rather
-- than every frame is plenty for a damage-over-time effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ZoneMath = require(ReplicatedStorage.Shared.ZoneMath)
local CombatService = require(script.Parent.CombatService)

local ZoneService = {}

local TICK = 1

local running = false
local runToken = 0
local center = Vector3.zero

function ZoneService.init()
	local arena = workspace:FindFirstChild("Arena")
	local marker = arena and arena:FindFirstChild("ZoneCenter")
	if marker and marker:IsA("BasePart") then
		center = marker.Position
	else
		warn("[ZoneService] Workspace.Arena.ZoneCenter not found - using the world origin.")
	end
	GameState.set(GameState.Key.ZoneCenter, center)
	GameState.set(GameState.Key.ZoneActive, false)
	GameState.set(GameState.Key.ZoneTimeOffset, 0)
end

-- Battle time as the storm sees it (admins can fast-forward the storm).
local function stormElapsed(): number?
	local elapsed = GameState.battleElapsed()
	if not elapsed then
		return nil
	end
	return elapsed + (GameState.get(GameState.Key.ZoneTimeOffset) or 0)
end

function ZoneService.begin()
	runToken += 1
	local token = runToken
	running = true
	GameState.set(GameState.Key.ZoneTimeOffset, 0)
	GameState.set(GameState.Key.ZoneActive, false)

	task.spawn(function()
		local warned = false
		local lastStage = 0
		while running and runToken == token do
			local elapsed = stormElapsed()
			if elapsed then
				local sample = ZoneMath.sample(elapsed)
				GameState.set(GameState.Key.ZoneActive, sample.active)

				if not warned and elapsed >= Config.Zone.StartDelay - Config.Zone.WarningLead then
					warned = true
					Remotes.get("Announce"):FireAllClients("StormWarning", { seconds = Config.Zone.WarningLead })
				end
				if sample.active and sample.stage > lastStage then
					lastStage = sample.stage
					Remotes.get("Announce"):FireAllClients("StormShrinking", {
						stage = sample.stage,
						total = #Config.Zone.Radii - 1,
					})
				end

				if sample.active then
					for _, player in Players:GetPlayers() do
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						if player:GetAttribute("InMatch") and root and root:IsA("BasePart") then
							if ZoneMath.isOutside(root.Position, center, sample.radius) then
								CombatService.damagePlayer(player, sample.damagePerSecond * TICK, nil, nil, "Storm")
							end
						end
					end
				end
			end
			task.wait(TICK)
		end
	end)
end

function ZoneService.stop()
	running = false
	runToken += 1
	GameState.set(GameState.Key.ZoneActive, false)
	GameState.set(GameState.Key.ZoneTimeOffset, 0)
end

-- Admin: skip ahead so the next shrink starts right now.
function ZoneService.advance(): boolean
	local elapsed = stormElapsed()
	if not running or not elapsed then
		return false
	end
	local zone = Config.Zone
	local nextStart
	if elapsed < zone.StartDelay then
		nextStart = zone.StartDelay
	else
		local stage = math.floor((elapsed - zone.StartDelay) / zone.Interval) + 1
		if stage >= #zone.Radii - 1 then
			return false
		end
		nextStart = zone.StartDelay + stage * zone.Interval
	end
	GameState.set(
		GameState.Key.ZoneTimeOffset,
		(GameState.get(GameState.Key.ZoneTimeOffset) or 0) + (nextStart - elapsed)
	)
	return true
end

function ZoneService.center(): Vector3
	return center
end

return ZoneService

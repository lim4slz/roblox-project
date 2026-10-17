--!strict
-- Characters: where players spawn, what they carry, how fast they move, what
-- happens when they die (respawn timer or spectating), and the attributes the
-- client uses to know which mode it is in.
--
-- Player attributes owned here:
--   InMatch          on a team in the current match
--   Spectating       watching instead of playing (eliminated, late, opted out)
--   RespawnAt        server timestamp of a pending respawn (0 = none)
--   Frozen           can't move (Get Ready countdown)
--   WantsToSpectate  the player's own "sit the next match out" toggle

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local CollisionGroups = require(script.Parent.Parent.Lib.CollisionGroups)
local BombService = require(script.Parent.BombService)
local Rules = require(script.Parent.Rules)
local ScoreService = require(script.Parent.ScoreService)
local TeamService = require(script.Parent.TeamService)
local WeaponService = require(script.Parent.WeaponService)

local PlayerService = {}

-- (victim, killer?)
PlayerService.PlayerDied = Signal.new() :: Signal.Signal<Player, Player?>

local LOBBY_RESPAWN_DELAY = 2
local OUT_OF_BOUNDS_Y = -60

-- Roblox renamed LoadCharacter to LoadCharacterAsync. Use the new name when
-- this engine has it, the old one otherwise.
function PlayerService.loadCharacter(player: Player)
	if player.Parent ~= Players then
		return
	end
	local ok, method = pcall(function()
		return (player :: any).LoadCharacterAsync
	end)
	if ok and typeof(method) == "function" then
		method(player)
	else
		(player :: any):LoadCharacter()
	end
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function PlayerService.isAlive(player: Player): boolean
	local humanoid = humanoidOf(player)
	return humanoid ~= nil and humanoid.Health > 0
end

-- Applies walk speed / jump for the player's current state.
function PlayerService.applyMovement(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	if player:GetAttribute("Frozen") then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end
	local speed = Config.Player.WalkSpeed
	if (player:GetAttribute("SpeedBoostEndsAt") or 0) > GameState.now() then
		speed = Config.PowerUps.SpeedBoost.WalkSpeed
	end
	if player:GetAttribute("InMatch") then
		speed *= Rules.get("WalkSpeedMultiplier")
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = Config.Player.JumpPower
end

function PlayerService.setFrozen(player: Player, frozen: boolean)
	player:SetAttribute("Frozen", frozen)
	PlayerService.applyMovement(player)
end

local function resetMatchAttributes(player: Player)
	player:SetAttribute("InMatch", false)
	player:SetAttribute("Spectating", false)
	player:SetAttribute("RespawnAt", 0)
	player:SetAttribute("Frozen", false)
	player:SetAttribute("SpeedBoostEndsAt", 0)
	player:SetAttribute("PowerUp", "")
	player:SetAttribute("PowerUpEndsAt", 0)
	player:SetAttribute("PendingTeamSwap", nil)
end

function PlayerService.sendToLobby(player: Player)
	resetMatchAttributes(player)
	TeamService.clear(player)
	task.spawn(function()
		PlayerService.loadCharacter(player)
	end)
end

function PlayerService.sendToMatch(player: Player, frozen: boolean)
	player:SetAttribute("InMatch", true)
	player:SetAttribute("Spectating", false)
	player:SetAttribute("RespawnAt", 0)
	player:SetAttribute("Frozen", frozen)
	player:SetAttribute("JoinedMatchAt", GameState.now())
	task.spawn(function()
		PlayerService.loadCharacter(player)
	end)
end

-- Removes the character and switches the client to the spectator camera.
function PlayerService.makeSpectator(player: Player, keepTeam: boolean?)
	if not keepTeam then
		player:SetAttribute("InMatch", false)
		TeamService.clear(player)
	end
	player:SetAttribute("Spectating", true)
	player:SetAttribute("RespawnAt", 0)
	local character = player.Character
	if character then
		player.Character = nil
		character:Destroy()
	end
end

function PlayerService.participants(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InMatch") then
			table.insert(result, player)
		end
	end
	return result
end

function PlayerService.aliveCount(teamName: string): number
	local count = 0
	for _, player in TeamService.playersOn(teamName) do
		if PlayerService.isAlive(player) then
			count += 1
		end
	end
	return count
end

-- A team is still "in it" if anyone is alive or about to respawn.
function PlayerService.teamHasLife(teamName: string): boolean
	for _, player in TeamService.playersOn(teamName) do
		if PlayerService.isAlive(player) or (player:GetAttribute("RespawnAt") or 0) > 0 then
			return true
		end
	end
	return false
end

local function scheduleRespawn(player: Player)
	local delay = Config.Match.RespawnDelay
	local matchNumber = GameState.get(GameState.Key.MatchNumber)
	player:SetAttribute("RespawnAt", GameState.now() + delay)
	task.delay(delay, function()
		if player.Parent ~= Players then
			return
		end
		player:SetAttribute("RespawnAt", 0)
		local stillValid = GameState.get(GameState.Key.MatchNumber) == matchNumber
			and player:GetAttribute("InMatch")
			and GameState.phase() == GameState.Phase.Battle
		if not stillValid then
			return
		end
		local newTeam = TeamService.applyPendingSwap(player)
		if newTeam then
			Remotes.get("Toast"):FireClient(player, `Teams were uneven - you're now on {newTeam}!`, "info")
		end
		PlayerService.loadCharacter(player)
	end)
end

local function onDied(player: Player)
	local killer, assisters = ScoreService.onDeath(player)
	local how = player:GetAttribute("LastDamageKind")
	if typeof(how) ~= "string" then
		how = "Fall"
	end
	player:SetAttribute("LastDamageKind", nil)

	if player:GetAttribute("InMatch") and GameState.phase() == GameState.Phase.Battle then
		Remotes.get("KillFeed"):FireAllClients(
			if killer then killer.DisplayName else nil,
			player.DisplayName,
			how,
			if killer and killer.Team then killer.Team.Name else nil,
			if player.Team then player.Team.Name else nil
		)
		if killer then
			Remotes.get("Toast")
				:FireClient(killer, `Knocked out {player.DisplayName}!  +{Config.Scoring.Knockout}`, "knockout")
		end
		for _, assister in assisters do
			Remotes.get("Toast")
				:FireClient(assister, `Assist on {player.DisplayName}  +{Config.Scoring.Assist}`, "score")
		end
	end
	PlayerService.PlayerDied:Fire(player, killer)

	if not player:GetAttribute("InMatch") then
		-- Lobby (or reset button): straight back to the lobby.
		task.delay(LOBBY_RESPAWN_DELAY, function()
			if
				player.Parent == Players
				and not player:GetAttribute("InMatch")
				and not player:GetAttribute("Spectating")
			then
				PlayerService.loadCharacter(player)
			end
		end)
		return
	end

	local phase = GameState.phase()
	if phase == GameState.Phase.GetReady then
		task.delay(1, function()
			if player.Parent == Players and GameState.phase() == GameState.Phase.GetReady then
				PlayerService.loadCharacter(player)
			end
		end)
	elseif phase == GameState.Phase.Battle then
		if GameState.get(GameState.Key.SuddenDeath) then
			PlayerService.makeSpectator(player, true)
			Remotes.get("Toast"):FireClient(player, "Eliminated! Spectating until the round ends.", "warning")
		else
			scheduleRespawn(player)
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	CollisionGroups.assignCharacter(character)
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	PlayerService.applyMovement(player)

	humanoid.Died:Once(function()
		onDied(player)
	end)

	-- The backpack is rebuilt on every spawn, so the loadout is too.
	player:WaitForChild("Backpack", 10)
	WeaponService.giveLoadout(player)
	BombService.resetCharges(player)
end

-- Decides what a freshly joined player should be doing right now.
local function placeNewPlayer(player: Player)
	local phase = GameState.phase()
	local matchRunning = phase == GameState.Phase.GetReady or phase == GameState.Phase.Battle
	if not matchRunning then
		PlayerService.sendToLobby(player)
		return
	end
	if GameState.get(GameState.Key.SuddenDeath) or player:GetAttribute("WantsToSpectate") then
		PlayerService.makeSpectator(player)
		Remotes.get("Toast"):FireClient(player, "A match is in progress - spectating until the next round.", "info")
		return
	end
	local teamName = TeamService.assignLate(player)
	PlayerService.sendToMatch(player, phase == GameState.Phase.GetReady)
	Remotes.get("Toast"):FireClient(player, `Joined the match on {teamName} Team!`, "success")
end

function PlayerService.init()
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(function(player)
		resetMatchAttributes(player)
		player:SetAttribute("WantsToSpectate", false)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		placeNewPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if player:GetAttribute("InMatch") then
			-- Let the departure leave Players before recounting teams.
			task.defer(TeamService.rebalance)
		end
	end)

	Remotes.get("SetSpectatePreference").OnServerEvent:Connect(function(player, wantsToSpectate)
		if typeof(wantsToSpectate) == "boolean" then
			player:SetAttribute("WantsToSpectate", wantsToSpectate)
		end
	end)

	Rules.Changed:Connect(function()
		for _, player in Players:GetPlayers() do
			PlayerService.applyMovement(player)
		end
	end)

	-- Anyone who somehow leaves the arena floor is knocked out rather than
	-- falling forever.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = humanoidOf(player)
				if
					root
					and root:IsA("BasePart")
					and humanoid
					and humanoid.Health > 0
					and root.Position.Y < OUT_OF_BOUNDS_Y
				then
					player:SetAttribute("LastDamageKind", "Fall")
					humanoid.Health = 0
				end
			end
		end
	end)
end

-- Players already in the server when the scripts start (Studio Play Solo can
-- race us) still need placing.
function PlayerService.start()
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InMatch") == nil then
			resetMatchAttributes(player)
			player:SetAttribute("WantsToSpectate", false)
			player.CharacterAdded:Connect(function(character)
				onCharacterAdded(player, character)
			end)
			placeNewPlayer(player)
		end
	end
end

return PlayerService

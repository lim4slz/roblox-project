--!strict
-- The hidden admin panel. Only players listed in Config.AdminUserIds ever
-- receive the panel's GUI (it's cloned from ServerStorage straight into their
-- PlayerGui, so other clients never even download it), and every command is
-- re-checked here against the UserId before it runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BombService = require(script.Parent.BombService)
local EventService = require(script.Parent.EventService)
local LobbyService = require(script.Parent.LobbyService)
local MatchService = require(script.Parent.MatchService)
local TowerService = require(script.Parent.TowerService)
local WeaponService = require(script.Parent.WeaponService)
local ZoneService = require(script.Parent.ZoneService)

type Command = (admin: Player, args: { [string]: any }) -> (boolean, string)

local AdminService = {}

local COMMAND_COOLDOWN = 0.15
local lastCommandAt: { [Player]: number } = {}

function AdminService.isAdmin(player: Player): boolean
	if table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	-- Optional: let any tester use the panel in Studio local-server tests,
	-- where fake players get negative UserIds.
	return Config.AllowAdminPanelInStudio == true and RunService:IsStudio()
end

local function forEachCharacter(callback: (Player, Model) -> ())
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 then
			callback(player, character)
		end
	end
end

local function resolveTargets(admin: Player, target: any): { Player }
	if target == "all" then
		return Players:GetPlayers()
	end
	if typeof(target) == "number" then
		local player = Players:GetPlayerByUserId(target)
		return if player then { player } else {}
	end
	return { admin }
end

local COMMANDS: { [string]: Command } = {
	-- Match flow -----------------------------------------------------------
	StartMatch = function()
		if MatchService.forceStart() then
			return true, "Starting the match now!"
		end
		return false, "A match is already running."
	end,
	EndRound = function(_admin, args)
		local winner = if typeof(args.winner) == "string" then args.winner else nil
		if MatchService.endRound(winner) then
			return true, "Round ended."
		end
		return false, "No battle is running."
	end,
	AddTime = function()
		if MatchService.addTime(60) then
			return true, "+60 seconds on the clock."
		end
		return false, "No battle is running."
	end,
	Showdown = function()
		if MatchService.triggerShowdown() then
			return true, "Final Showdown triggered!"
		end
		return false, "Showdown unavailable right now."
	end,
	AdvanceStorm = function()
		if ZoneService.advance() then
			return true, "The storm shrinks now!"
		end
		return false, "The storm can't shrink any further right now."
	end,
	ResetTowers = function()
		TowerService.reset()
		return true, "Towers rebuilt."
	end,
	CollapseTower = function(_admin, args)
		local team = args.team
		if typeof(team) == "string" and TowerService.collapse(team) then
			return true, `{team} tower collapsed!`
		end
		return false, "Only works on a standing tower during battle."
	end,
	SetNextVariant = function(_admin, args)
		local variantId = args.variant
		if typeof(variantId) == "string" and MatchService.setNextVariant(variantId) then
			return true, `Next match mode: {variantId}`
		end
		return false, "Unknown mode."
	end,

	-- Fun ---------------------------------------------------------------------
	TriggerEvent = function(_admin, args)
		local eventId = args.event
		local ok = if eventId == "Random"
			then EventService.triggerRandom()
			else typeof(eventId) == "string" and EventService.trigger(eventId)
		if ok then
			return true, "Event started!"
		end
		return false, "Events only run during a battle."
	end,
	ToggleFireworks = function()
		local enabled = not GameState.get(GameState.Key.Fireworks)
		GameState.set(GameState.Key.Fireworks, enabled)
		return true, if enabled then "Fireworks on!" else "Fireworks off."
	end,
	BombsForAll = function()
		for _, player in Players:GetPlayers() do
			if player.Character then
				WeaponService.give(player, "Bomb")
				BombService.grantMega(player)
				BombService.grantCharges(player, 3)
				Remotes.get("Toast"):FireClient(player, "The admin gave everyone Mega Bombs!", "powerup")
			end
		end
		return true, "Everyone got 3 bombs (the first one Mega)."
	end,
	BombDrop = function(admin)
		local count = 0
		forEachCharacter(function(player: Player, character: Model)
			if player ~= admin then
				count += 1
				BombService.spawnBomb({
					position = character:GetPivot().Position + Vector3.new(0, 9, 0),
					velocity = Vector3.zero,
					owner = admin,
					kind = "Bomb",
				})
			end
		end)
		return true, `Dropped {count} bomb(s). Run!`
	end,
	HealAll = function()
		forEachCharacter(function(_player: Player, character: Model)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
		return true, "Everyone is back to full health."
	end,

	-- Players -------------------------------------------------------------------
	GiveWeapon = function(admin, args)
		local toolName = args.tool
		if typeof(toolName) ~= "string" or not table.find(WeaponService.ToolNames, toolName) then
			return false, "Unknown weapon."
		end
		local given = 0
		for _, player in resolveTargets(admin, args.target) do
			if player.Character and WeaponService.give(player, toolName) then
				given += 1
			end
		end
		return given > 0, `Gave {toolName} to {given} player(s).`
	end,
	GodMode = function(admin)
		local enabled = not admin:GetAttribute("GodMode")
		admin:SetAttribute("GodMode", enabled)
		return true, if enabled then "God mode ON." else "God mode OFF."
	end,
	TeleportArena = function(admin)
		local character = admin.Character
		if not character then
			return false, "You need a character first."
		end
		character:PivotTo(CFrame.new(ZoneService.center() + Vector3.new(0, 12, 0)))
		return true, "Teleported to the arena."
	end,
	TeleportLobby = function(admin)
		local character = admin.Character
		if not character then
			return false, "You need a character first."
		end
		character:PivotTo(LobbyService.spawnCFrame())
		return true, "Teleported to the lobby."
	end,
}

local function installPanel(player: Player)
	if not AdminService.isAdmin(player) then
		return
	end
	player:SetAttribute("IsAdmin", true)
	local template = ServerStorage:FindFirstChild("AdminPanel")
	if not template then
		warn("[AdminService] ServerStorage.AdminPanel is missing.")
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", 30)
	if playerGui and not playerGui:FindFirstChild("AdminPanel") then
		template:Clone().Parent = playerGui
	end
end

function AdminService.init()
	Players.PlayerAdded:Connect(installPanel)
	for _, player in Players:GetPlayers() do
		task.spawn(installPanel, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCommandAt[player] = nil
	end)

	local feedback = Remotes.get("AdminFeedback")
	Remotes.get("AdminCommand").OnServerEvent:Connect(function(player, commandName, args)
		if not AdminService.isAdmin(player) then
			return
		end
		local now = os.clock()
		if now - (lastCommandAt[player] or 0) < COMMAND_COOLDOWN then
			return
		end
		lastCommandAt[player] = now

		local command = if typeof(commandName) == "string" then COMMANDS[commandName] else nil
		if not command then
			feedback:FireClient(player, "Unknown command.", false)
			return
		end
		local ok, result, message = pcall(command, player, if typeof(args) == "table" then args else {})
		if not ok then
			warn("[AdminService] " .. tostring(result))
			feedback:FireClient(player, "That command failed - check the server output.", false)
			return
		end
		feedback:FireClient(player, message, result)
	end)
end

return AdminService

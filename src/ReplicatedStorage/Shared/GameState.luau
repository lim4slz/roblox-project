--!strict
-- Match state shared between server and clients.
--
-- The server writes plain values as attributes on ReplicatedStorage.GameState;
-- attributes replicate on their own, so clients simply read them and listen for
-- changes. Timers are stored as absolute server timestamps (from
-- workspace:GetServerTimeNow()) so every client can count down smoothly without
-- the server sending a packet every second.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "GameState"

local GameState = {}

GameState.Phase = {
	Waiting = "Waiting", -- not enough players yet
	Intermission = "Intermission", -- lobby countdown running
	GetReady = "GetReady", -- players in the arena, frozen, 10s countdown
	Battle = "Battle",
	Results = "Results",
}

-- Attribute names, kept in one table so a typo is a type error rather than a
-- silently missing value.
GameState.Key = {
	Phase = "Phase",
	PhaseEndsAt = "PhaseEndsAt",
	BattleStartedAt = "BattleStartedAt",
	BattleEndsAt = "BattleEndsAt",
	Variant = "Variant",
	NextVariant = "NextVariant",
	PlayersInLobby = "PlayersInLobby",
	PlayersNeeded = "PlayersNeeded",
	Showdown = "Showdown",
	SuddenDeath = "SuddenDeath",
	Winner = "Winner",
	LastWinner = "LastWinner",
	ZoneActive = "ZoneActive",
	ZoneCenter = "ZoneCenter",
	-- Seconds the admin has fast-forwarded the storm by.
	ZoneTimeOffset = "ZoneTimeOffset",
	Event = "Event",
	EventEndsAt = "EventEndsAt",
	Fireworks = "Fireworks",
	MatchNumber = "MatchNumber",
}

-- Per-team values are stored as "<Key>_<TeamName>", e.g. "TowerHealth_Blue".
GameState.TeamKey = {
	TowerHealth = "TowerHealth",
	Alive = "Alive",
	Players = "Players",
	Score = "Score",
}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function GameState.get(key: string): any
	return folder:GetAttribute(key)
end

function GameState.set(key: string, value: any)
	folder:SetAttribute(key, value)
end

function GameState.teamKey(key: string, teamName: string): string
	return key .. "_" .. teamName
end

function GameState.getTeam(key: string, teamName: string): any
	return folder:GetAttribute(GameState.teamKey(key, teamName))
end

function GameState.setTeam(key: string, teamName: string, value: any)
	folder:SetAttribute(GameState.teamKey(key, teamName), value)
end

function GameState.changed(key: string): RBXScriptSignal
	return folder:GetAttributeChangedSignal(key)
end

-- Calls `callback` now with the current value and again on every change.
function GameState.observe(key: string, callback: (any) -> ()): RBXScriptConnection
	task.spawn(callback, folder:GetAttribute(key))
	return folder:GetAttributeChangedSignal(key):Connect(function()
		callback(folder:GetAttribute(key))
	end)
end

-- Fires for any attribute change; handy for UI that depends on many fields.
function GameState.anyChanged(): RBXScriptSignal
	return folder.AttributeChanged
end

function GameState.now(): number
	return workspace:GetServerTimeNow()
end

function GameState.phase(): string
	local phase = folder:GetAttribute(GameState.Key.Phase)
	return if typeof(phase) == "string" then phase else GameState.Phase.Waiting
end

function GameState.isInMatchPhase(): boolean
	local phase = GameState.phase()
	return phase == GameState.Phase.GetReady or phase == GameState.Phase.Battle
end

-- Seconds until the current phase ends (never negative).
function GameState.phaseTimeLeft(): number
	local endsAt = folder:GetAttribute(GameState.Key.PhaseEndsAt)
	if typeof(endsAt) ~= "number" then
		return 0
	end
	return math.max(0, endsAt - GameState.now())
end

-- Seconds since "Battle Begins!", or nil outside a battle.
function GameState.battleElapsed(): number?
	local startedAt = folder:GetAttribute(GameState.Key.BattleStartedAt)
	if typeof(startedAt) ~= "number" or GameState.phase() ~= GameState.Phase.Battle then
		return nil
	end
	return GameState.now() - startedAt
end

return GameState

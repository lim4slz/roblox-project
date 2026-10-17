--!strict
-- The game loop: Lobby -> Get Ready -> Battle -> Results -> Lobby, forever.
--
-- Every other service is driven from here. Each phase writes its name and end
-- time into GameState, and clients render whatever phase they see; no phase
-- needs its own remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local Variants = require(ReplicatedStorage.Shared.Variants)
local BombService = require(script.Parent.BombService)
local EventService = require(script.Parent.EventService)
local PlayerService = require(script.Parent.PlayerService)
local Rules = require(script.Parent.Rules)
local ScoreService = require(script.Parent.ScoreService)
local TeamService = require(script.Parent.TeamService)
local TowerService = require(script.Parent.TowerService)
local WeaponService = require(script.Parent.WeaponService)
local ZoneService = require(script.Parent.ZoneService)

export type MatchOutcome = {
	winner: string, -- team name or "Draw"
	reason: string,
}

local MatchService = {}

local Phase = GameState.Phase
local Key = GameState.Key
local TeamKey = GameState.TeamKey

local LOOP_TICK = 0.2

local forceStartRequested = false
local pendingOutcome: MatchOutcome? = nil
local destroyedTower: { team: string, attacker: Player? }? = nil
local nextVariantOverride: string? = nil
local lastVariantId: string? = nil
local matchNumber = 0

local function setPhase(phase: string, duration: number?)
	GameState.set(Key.PhaseEndsAt, if duration then GameState.now() + duration else 0)
	GameState.set(Key.Phase, phase)
end

local function minimumPlayers(): number
	if RunService:IsStudio() and Config.Match.AllowSoloInStudio then
		return 1
	end
	return Config.Match.MinPlayers
end

-- Players who will be put on a team when the next match starts.
local function eligiblePlayers(): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("WantsToSpectate") then
			table.insert(result, player)
		end
	end
	return result
end

local function announce(kind: string, payload: { [string]: any }?)
	Remotes.get("Announce"):FireAllClients(kind, payload or {})
end

----------------------------------------------------------------------------
-- Lobby
----------------------------------------------------------------------------

local function pickVariant()
	local variant = if nextVariantOverride then Variants.get(nextVariantOverride) else Variants.roll(nil, lastVariantId)
	GameState.set(Key.NextVariant, variant.Id)
	return variant
end

local function runLobby()
	setPhase(Phase.Waiting)
	local variant = pickVariant()

	while true do
		-- The admin may change the next variant while we wait.
		if nextVariantOverride and nextVariantOverride ~= variant.Id then
			variant = pickVariant()
		end

		local count = #eligiblePlayers()
		local needed = minimumPlayers()
		GameState.set(Key.PlayersInLobby, count)
		GameState.set(Key.PlayersNeeded, needed)

		if forceStartRequested and count >= 1 then
			break
		end

		if count >= needed then
			if GameState.phase() ~= Phase.Intermission then
				setPhase(Phase.Intermission, Config.Match.LobbyCountdown)
			end
			local timeLeft = GameState.phaseTimeLeft()
			if count >= Config.Match.QuickStartPlayers and timeLeft > Config.Match.QuickStartCountdown then
				GameState.set(Key.PhaseEndsAt, GameState.now() + Config.Match.QuickStartCountdown)
			end
			if timeLeft <= 0 then
				break
			end
		elseif GameState.phase() ~= Phase.Waiting then
			-- Someone left and we no longer have enough players.
			setPhase(Phase.Waiting)
		end
		task.wait(LOOP_TICK)
	end

	forceStartRequested = false
	nextVariantOverride = nil
	return variant
end

----------------------------------------------------------------------------
-- Match helpers
----------------------------------------------------------------------------

local function publishTeamCounts()
	for _, info in TeamInfo.all() do
		GameState.setTeam(TeamKey.Players, info.Name, #TeamService.playersOn(info.Name))
		GameState.setTeam(TeamKey.Alive, info.Name, PlayerService.aliveCount(info.Name))
		local score = ScoreService.teamTotals(info.Name)
		GameState.setTeam(TeamKey.Score, info.Name, score)
	end
end

local function rosterSnapshot(): { [string]: { string } }
	local rosters = {}
	for _, info in TeamInfo.all() do
		local names = {}
		for _, player in TeamService.playersOn(info.Name) do
			table.insert(names, player.DisplayName)
		end
		rosters[info.Name] = names
	end
	return rosters
end

-- Time-up tiebreakers: tower health, then knockouts, then score.
local function decideByStandings(): MatchOutcome
	local teams = TeamInfo.all()
	local a, b = teams[1].Name, teams[2].Name
	local healthA, healthB = TowerService.health(a), TowerService.health(b)
	if math.abs(healthA - healthB) > 0.005 then
		return {
			winner = if healthA > healthB then a else b,
			reason = "Time's up! Their tower was standing tallest.",
		}
	end
	local scoreA, kosA = ScoreService.teamTotals(a)
	local scoreB, kosB = ScoreService.teamTotals(b)
	if kosA ~= kosB then
		return { winner = if kosA > kosB then a else b, reason = "Time's up! Towers tied - decided by knockouts." }
	end
	if scoreA ~= scoreB then
		return { winner = if scoreA > scoreB then a else b, reason = "Time's up! Decided by total score." }
	end
	return { winner = "Draw", reason = "Time's up! Perfectly matched - it's a draw." }
end

local function towerHealthOf(teamName: string): number
	return TowerService.health(teamName)
end

-- Flips into the Final Showdown: tense music, no more respawns.
local function checkShowdown(startedWithCount: number)
	if GameState.get(Key.Showdown) then
		return
	end
	local timeLeft = GameState.phaseTimeLeft()
	local lowestTower = 1
	for _, info in TeamInfo.all() do
		lowestTower = math.min(lowestTower, TowerService.health(info.Name))
	end
	local remaining = #PlayerService.participants()
	local fewPlayersLeft = startedWithCount > Config.Match.ShowdownAlivePlayers
		and remaining <= Config.Match.ShowdownAlivePlayers

	if
		timeLeft <= Config.Match.ShowdownTimeLeft
		or lowestTower <= Config.Match.ShowdownTowerHealth
		or fewPlayersLeft
	then
		GameState.set(Key.Showdown, true)
		GameState.set(Key.SuddenDeath, true)
		announce("Showdown", { timeLeft = timeLeft })
	end
end

-- Returns an outcome once the match is decided, nil while it's still going.
local function checkForOutcome(bothTeamsStarted: boolean): MatchOutcome?
	if pendingOutcome then
		return pendingOutcome
	end

	if destroyedTower then
		local loser = destroyedTower.team
		local winner = TeamInfo.opponentOf(loser)
		return {
			winner = if winner then winner.Name else "Draw",
			reason = `{loser} Team's tower has fallen!`,
		}
	end

	if GameState.phaseTimeLeft() <= 0 then
		return decideByStandings()
	end

	-- Solo/one-sided test matches can only end by tower or timer.
	if not bothTeamsStarted then
		return nil
	end

	for _, info in TeamInfo.all() do
		local opponent = TeamInfo.opponentOf(info.Name)
		if opponent then
			if #TeamService.playersOn(info.Name) == 0 then
				return { winner = opponent.Name, reason = `{info.Name} Team left the battle.` }
			end
			if GameState.get(Key.SuddenDeath) and not PlayerService.teamHasLife(info.Name) then
				return { winner = opponent.Name, reason = `{info.Name} Team was wiped out!` }
			end
		end
	end
	return nil
end

----------------------------------------------------------------------------
-- Match
----------------------------------------------------------------------------

local function resetArena()
	BombService.clearAll()
	WeaponService.clearProjectiles()
	EventService.stop()
	ZoneService.stop()
	local debris = workspace:FindFirstChild("Debris")
	if debris then
		debris:ClearAllChildren()
	end
	TowerService.reset()
end

local function runMatch(variant: Variants.Variant)
	matchNumber += 1
	GameState.set(Key.MatchNumber, matchNumber)
	lastVariantId = variant.Id
	GameState.set(Key.Variant, variant.Id)
	GameState.set(Key.Showdown, false)
	GameState.set(Key.SuddenDeath, false)
	GameState.set(Key.Winner, "")
	pendingOutcome = nil
	destroyedTower = nil

	resetArena()
	Rules.setVariant(variant.Id)
	ScoreService.resetMatch()

	-- Teams
	local participants = eligiblePlayers()
	TeamService.assignAll(participants)
	for _, player in Players:GetPlayers() do
		if table.find(participants, player) then
			PlayerService.sendToMatch(player, true)
		else
			PlayerService.makeSpectator(player)
		end
	end
	publishTeamCounts()

	local bothTeamsStarted = true
	for _, info in TeamInfo.all() do
		if #TeamService.playersOn(info.Name) == 0 then
			bothTeamsStarted = false
		end
	end

	-- Get Ready: everyone frozen at their base while the countdown runs.
	setPhase(Phase.GetReady, Config.Match.GetReadyDuration)
	announce("GetReady", {
		variant = variant.Id,
		variantName = variant.Name,
		variantDescription = variant.Description,
		rosters = rosterSnapshot(),
		duration = Config.Match.GetReadyDuration,
	})
	while GameState.phaseTimeLeft() > 0 do
		if pendingOutcome then
			break
		end
		task.wait(LOOP_TICK)
	end

	-- Battle! (skipped if the admin ended the round during the countdown)
	local startedAt = GameState.now()
	if not pendingOutcome then
		GameState.set(Key.BattleStartedAt, startedAt)
		GameState.set(Key.BattleEndsAt, startedAt + Config.Match.BattleDuration)
		setPhase(Phase.Battle, Config.Match.BattleDuration)
		for _, player in PlayerService.participants() do
			PlayerService.setFrozen(player, false)
		end
		announce("BattleBegins")
		ZoneService.begin()
		EventService.begin()
	end

	local startedWithCount = #participants
	local outcome: MatchOutcome? = nil
	while not outcome do
		publishTeamCounts()
		checkShowdown(startedWithCount)
		outcome = checkForOutcome(bothTeamsStarted)
		if not outcome then
			task.wait(LOOP_TICK)
		end
	end
	assert(outcome)

	-- Results
	ZoneService.stop()
	EventService.stop()
	if destroyedTower and destroyedTower.attacker and destroyedTower.attacker.Parent == Players then
		ScoreService.addTowerKill(destroyedTower.attacker)
	end
	if outcome.winner ~= "Draw" then
		ScoreService.awardWin(outcome.winner)
	end
	GameState.set(Key.Winner, outcome.winner)
	GameState.set(Key.LastWinner, outcome.winner)
	setPhase(Phase.Results, Config.Match.ResultsDuration)

	local teams, mvp = ScoreService.buildTeamResults(towerHealthOf)
	Remotes.get("MatchResults"):FireAllClients({
		winner = outcome.winner,
		reason = outcome.reason,
		variant = variant.Name,
		duration = GameState.now() - startedAt,
		teams = teams,
		mvp = mvp,
	})
	task.wait(Config.Match.ResultsDuration)
end

-- Puts the world back to lobby state, whether the match ended cleanly or not.
local function cleanup()
	Rules.reset()
	resetArena()
	GameState.set(Key.Showdown, false)
	GameState.set(Key.SuddenDeath, false)
	GameState.set(Key.Event, "")
	GameState.set(Key.Fireworks, false)
	TeamService.clearAll()
	for _, player in Players:GetPlayers() do
		PlayerService.sendToLobby(player)
	end
	for _, info in TeamInfo.all() do
		GameState.setTeam(TeamKey.Alive, info.Name, 0)
		GameState.setTeam(TeamKey.Players, info.Name, 0)
		GameState.setTeam(TeamKey.Score, info.Name, 0)
	end
end

----------------------------------------------------------------------------
-- Public API (used by AdminService)
----------------------------------------------------------------------------

function MatchService.init()
	GameState.set(Key.Phase, Phase.Waiting)
	GameState.set(Key.Event, "")
	GameState.set(Key.Fireworks, false)
	GameState.set(Key.LastWinner, "")

	Rules.Changed:Connect(function()
		workspace.Gravity = Rules.get("Gravity")
	end)

	TowerService.TowerDestroyed:Connect(function(teamName, attacker)
		if GameState.phase() == Phase.Battle and not destroyedTower then
			destroyedTower = { team = teamName, attacker = attacker }
			announce("TowerDestroyed", {
				team = teamName,
				by = if attacker then attacker.DisplayName else nil,
			})
		end
	end)
end

function MatchService.start()
	task.spawn(function()
		while true do
			local variant = runLobby()
			-- A bug in one match must never stop the server from hosting more.
			local ok, err = pcall(function()
				runMatch(variant)
			end)
			if not ok then
				warn("[MatchService] Match aborted: " .. tostring(err))
			end
			cleanup()
		end
	end)
end

function MatchService.forceStart(): boolean
	local phase = GameState.phase()
	if phase ~= Phase.Waiting and phase ~= Phase.Intermission then
		return false
	end
	forceStartRequested = true
	return true
end

-- Ends the current battle. With no winner given, standings decide.
function MatchService.endRound(winner: string?, reason: string?): boolean
	local phase = GameState.phase()
	if phase ~= Phase.Battle and phase ~= Phase.GetReady then
		return false
	end
	local outcome: MatchOutcome = if winner
		then { winner = winner, reason = reason or "Ended by the admin." }
		else decideByStandings()
	if not winner then
		outcome.reason = "Ended early by the admin. " .. outcome.reason
	end
	pendingOutcome = outcome
	return true
end

function MatchService.addTime(seconds: number): boolean
	if GameState.phase() ~= Phase.Battle then
		return false
	end
	local endsAt = (GameState.get(Key.PhaseEndsAt) or GameState.now()) + seconds
	GameState.set(Key.PhaseEndsAt, endsAt)
	GameState.set(Key.BattleEndsAt, endsAt)
	return true
end

function MatchService.triggerShowdown(): boolean
	if GameState.phase() ~= Phase.Battle or GameState.get(Key.Showdown) then
		return false
	end
	GameState.set(Key.Showdown, true)
	GameState.set(Key.SuddenDeath, true)
	announce("Showdown", { timeLeft = GameState.phaseTimeLeft() })
	return true
end

function MatchService.setNextVariant(variantId: string): boolean
	if Variants.get(variantId).Id ~= variantId then
		return false
	end
	nextVariantOverride = variantId
	return true
end

return MatchService

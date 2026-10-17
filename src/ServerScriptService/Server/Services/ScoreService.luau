--!strict
-- Tracks per-match stats (score, knockouts, assists, bricks) and the session
-- leaderboard. Also owns damage attribution: whoever hurt a player most
-- recently gets the knockout, and anyone else who chipped in gets an assist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)

export type PlayerStats = {
	Score: number,
	KOs: number,
	Assists: number,
	Deaths: number,
	Bricks: number,
	Team: string?,
	Name: string,
	UserId: number,
}

type DamageRecord = { attacker: Player, amount: number, at: number }

local ScoreService = {}

local matchStats: { [Player]: PlayerStats } = {}
-- victim -> list of recent hits
local damageLog: { [Player]: { DamageRecord } } = {}
-- Stats of players who left mid-match, so the results screen stays honest.
local departedStats: { PlayerStats } = {}

local function leaderstat(player: Player, name: string): IntValue?
	local folder = player:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		return value
	end
	return nil
end

local function statsFor(player: Player): PlayerStats
	local stats = matchStats[player]
	if not stats then
		stats = {
			Score = 0,
			KOs = 0,
			Assists = 0,
			Deaths = 0,
			Bricks = 0,
			Team = if player.Team then player.Team.Name else nil,
			Name = player.DisplayName,
			UserId = player.UserId,
		}
		matchStats[player] = stats
	end
	return stats
end

local function syncLeaderstats(player: Player)
	local stats = statsFor(player)
	local score = leaderstat(player, "Score")
	local kos = leaderstat(player, "KOs")
	if score then
		score.Value = stats.Score
	end
	if kos then
		kos.Value = stats.KOs
	end
	player:SetAttribute("MatchScore", stats.Score)
end

local function addScore(player: Player, amount: number)
	local stats = statsFor(player)
	stats.Score += amount
	syncLeaderstats(player)
end

function ScoreService.init()
	local function setup(player: Player)
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		for _, name in { "Score", "KOs", "Wins" } do
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = folder
		end
		folder.Parent = player
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local stats = matchStats[player]
		if stats and GameState.isInMatchPhase() then
			table.insert(departedStats, stats)
		end
		matchStats[player] = nil
		damageLog[player] = nil
	end)
end

function ScoreService.resetMatch()
	table.clear(matchStats)
	table.clear(damageLog)
	table.clear(departedStats)
	for _, player in Players:GetPlayers() do
		statsFor(player)
		syncLeaderstats(player)
	end
end

-- Called when a player joins a team, so their stats carry the right team.
function ScoreService.setTeam(player: Player, teamName: string?)
	statsFor(player).Team = teamName
end

function ScoreService.recordDamage(victim: Player, attacker: Player?, amount: number)
	if not attacker or attacker == victim or amount <= 0 then
		return
	end
	local log = damageLog[victim]
	if not log then
		log = {}
		damageLog[victim] = log
	end
	table.insert(log, { attacker = attacker, amount = amount, at = os.clock() })
end

-- Resolves a death into (killer, assisters) and hands out points.
function ScoreService.onDeath(victim: Player): (Player?, { Player })
	local stats = statsFor(victim)
	stats.Deaths += 1

	local log = damageLog[victim] or {}
	damageLog[victim] = nil
	local now = os.clock()
	local window = Config.Scoring.AssistWindow

	local killer: Player? = nil
	local totals: { [Player]: number } = {}
	for index = #log, 1, -1 do
		local record = log[index]
		if now - record.at <= window and record.attacker.Parent == Players then
			if not killer then
				killer = record.attacker
			end
			totals[record.attacker] = (totals[record.attacker] or 0) + record.amount
		end
	end

	-- No knockout credit for taking out a teammate.
	if killer and killer.Team and victim.Team and killer.Team == victim.Team then
		killer = nil
	end

	local assisters: { Player } = {}
	if killer then
		local killerStats = statsFor(killer)
		killerStats.KOs += 1
		addScore(killer, Config.Scoring.Knockout)
		for attacker, total in totals do
			if attacker ~= killer and total >= Config.Scoring.AssistMinimumDamage and attacker.Team ~= victim.Team then
				statsFor(attacker).Assists += 1
				addScore(attacker, Config.Scoring.Assist)
				table.insert(assisters, attacker)
			end
		end
	end
	syncLeaderstats(victim)
	return killer, assisters
end

function ScoreService.addBricks(player: Player, count: number)
	if count <= 0 then
		return
	end
	statsFor(player).Bricks += count
	addScore(player, count * Config.Scoring.EnemyBrick)
end

function ScoreService.addTowerKill(player: Player)
	addScore(player, Config.Scoring.TowerDestroyed)
end

function ScoreService.awardWin(teamName: string)
	for _, player in Players:GetPlayers() do
		if player.Team and player.Team.Name == teamName then
			addScore(player, Config.Scoring.WinBonus)
			local wins = leaderstat(player, "Wins")
			if wins then
				wins.Value += 1
			end
		end
	end
end

function ScoreService.stats(player: Player): PlayerStats
	return statsFor(player)
end

-- Used to seed team balancing: strong players get spread across teams.
function ScoreService.sessionStrength(player: Player): number
	local wins = leaderstat(player, "Wins")
	local score = leaderstat(player, "Score")
	return (if wins then wins.Value * 300 else 0) + (if score then score.Value else 0)
end

function ScoreService.teamTotals(teamName: string): (number, number)
	local score, kos = 0, 0
	for _, stats in matchStats do
		if stats.Team == teamName then
			score += stats.Score
			kos += stats.KOs
		end
	end
	for _, stats in departedStats do
		if stats.Team == teamName then
			score += stats.Score
			kos += stats.KOs
		end
	end
	return score, kos
end

-- Everything the results screen needs, grouped by team, best first.
function ScoreService.buildTeamResults(towerHealthOf: (string) -> number): ({ any }, PlayerStats?)
	local all: { PlayerStats } = {}
	for _, stats in matchStats do
		if stats.Team then
			table.insert(all, stats)
		end
	end
	for _, stats in departedStats do
		table.insert(all, stats)
	end
	table.sort(all, function(a, b)
		return a.Score > b.Score
	end)

	local teams = {}
	for _, info in TeamInfo.all() do
		local roster = {}
		for _, stats in all do
			if stats.Team == info.Name then
				table.insert(roster, table.clone(stats))
			end
		end
		local score, kos = ScoreService.teamTotals(info.Name)
		table.insert(teams, {
			name = info.Name,
			score = score,
			kos = kos,
			towerHealth = towerHealthOf(info.Name),
			players = roster,
		})
	end
	local mvp = if all[1] and all[1].Score > 0 then table.clone(all[1]) else nil
	return teams, mvp
end

return ScoreService

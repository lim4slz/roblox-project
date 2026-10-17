--!strict
-- Team creation, fair assignment at match start, late joiners, and keeping
-- teams even when people leave mid-match.

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local ScoreService = require(script.Parent.ScoreService)

local TeamService = {}

local teamObjects: { [string]: Team } = {}

function TeamService.init()
	for _, info in TeamInfo.all() do
		local team = Teams:FindFirstChild(info.Name)
		if not (team and team:IsA("Team")) then
			local created = Instance.new("Team")
			created.Name = info.Name
			created.Parent = Teams
			team = created
		end
		assert(team and team:IsA("Team"))
		team.TeamColor = info.BrickColor
		team.AutoAssignable = false
		teamObjects[info.Name] = team
	end
end

function TeamService.getTeam(teamName: string): Team
	return teamObjects[teamName]
end

function TeamService.playersOn(teamName: string): { Player }
	local result = {}
	for _, player in Players:GetPlayers() do
		if player.Team and player.Team.Name == teamName and player:GetAttribute("InMatch") then
			table.insert(result, player)
		end
	end
	return result
end

function TeamService.counts(): { [string]: number }
	local counts = {}
	for _, info in TeamInfo.all() do
		counts[info.Name] = #TeamService.playersOn(info.Name)
	end
	return counts
end

local function setTeam(player: Player, teamName: string?)
	if teamName then
		player.Neutral = false
		player.Team = teamObjects[teamName]
	else
		player.Team = nil :: any
		player.Neutral = true
	end
	ScoreService.setTeam(player, teamName)
end

-- Snake draft by session strength (A B B A A B ...) so the two strongest
-- players never start on the same side.
function TeamService.assignAll(players: { Player })
	local ordered = table.clone(players)
	local random = Random.new()
	-- Shuffle first so equal-strength players land on random sides.
	for index = #ordered, 2, -1 do
		local swap = random:NextInteger(1, index)
		ordered[index], ordered[swap] = ordered[swap], ordered[index]
	end
	table.sort(ordered, function(a, b)
		return ScoreService.sessionStrength(a) > ScoreService.sessionStrength(b)
	end)

	local teamList = TeamInfo.all()
	local teamCount = #teamList
	-- Randomise which team picks first so Blue isn't always favoured.
	local offset = random:NextInteger(0, teamCount - 1)
	for index, player in ordered do
		local round = (index - 1) // teamCount
		local slot = (index - 1) % teamCount
		if round % 2 == 1 then
			slot = teamCount - 1 - slot
		end
		local info = teamList[(slot + offset) % teamCount + 1]
		setTeam(player, info.Name)
	end
end

-- Smallest team, ties broken by lower total score.
function TeamService.smallestTeam(): string
	local counts = TeamService.counts()
	local best: string? = nil
	for _, info in TeamInfo.all() do
		if best == nil then
			best = info.Name
		else
			local current = best :: string
			local count, bestCount = counts[info.Name], counts[current]
			if count < bestCount then
				best = info.Name
			elseif count == bestCount then
				local score = ScoreService.teamTotals(info.Name)
				local bestScore = ScoreService.teamTotals(current)
				if score < bestScore then
					best = info.Name
				end
			end
		end
	end
	return best or TeamInfo.all()[1].Name
end

function TeamService.assignLate(player: Player): string
	local teamName = TeamService.smallestTeam()
	setTeam(player, teamName)
	return teamName
end

function TeamService.clear(player: Player)
	setTeam(player, nil)
end

function TeamService.clearAll()
	for _, player in Players:GetPlayers() do
		setTeam(player, nil)
		player:SetAttribute("PendingTeamSwap", nil)
	end
end

-- If one team is now two or more players bigger, flag someone to switch
-- sides. The swap happens at their next respawn so nobody is yanked out of
-- a fight mid-swing.
function TeamService.rebalance()
	local counts = TeamService.counts()
	local largest, smallest
	for name, count in counts do
		if not largest or count > counts[largest] then
			largest = name
		end
		if not smallest or count < counts[smallest] then
			smallest = name
		end
	end
	if not largest or not smallest or counts[largest] - counts[smallest] < 2 then
		return
	end

	-- Prefer someone already waiting to respawn, otherwise the latest joiner
	-- (they have the least invested in their current side).
	local candidates = TeamService.playersOn(largest)
	table.sort(candidates, function(a, b)
		local aWaiting = (a:GetAttribute("RespawnAt") or 0) > 0
		local bWaiting = (b:GetAttribute("RespawnAt") or 0) > 0
		if aWaiting ~= bWaiting then
			return aWaiting
		end
		return (a:GetAttribute("JoinedMatchAt") or 0) > (b:GetAttribute("JoinedMatchAt") or 0)
	end)
	for _, candidate in candidates do
		if not candidate:GetAttribute("PendingTeamSwap") then
			candidate:SetAttribute("PendingTeamSwap", smallest)
			return
		end
	end
end

-- Applies a pending balance swap. Returns the new team name if one happened.
function TeamService.applyPendingSwap(player: Player): string?
	local target = player:GetAttribute("PendingTeamSwap")
	if typeof(target) ~= "string" then
		return nil
	end
	player:SetAttribute("PendingTeamSwap", nil)
	setTeam(player, target)
	return target
end

return TeamService

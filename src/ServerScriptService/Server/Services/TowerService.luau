--!strict
-- Owns the team towers: health tracking, the defeat collapse, and restoring
-- them between rounds. Other breakable structures (the lobby practice wall)
-- register here too so a single explosion call can hit everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local BrickStructure = require(script.Parent.Parent.Lib.BrickStructure)
local ScoreService = require(script.Parent.ScoreService)

local TowerService = {}

-- (teamName, finalAttacker?)
TowerService.TowerDestroyed = Signal.new() :: Signal.Signal<string, Player?>

local towersFolder: Instance? = nil
local templates: { [string]: Model } = {}
local towers: { [string]: BrickStructure.BrickStructure } = {}
local extraStructures: { BrickStructure.BrickStructure } = {}
local lastAttackWarning: { [string]: number } = {}

local ATTACK_WARNING_COOLDOWN = 10

local function normalizedHealth(structure: BrickStructure.BrickStructure): number
	if structure.Destroyed then
		return 0
	end
	local defeat = Config.Tower.DefeatFraction
	return math.clamp((structure:health() - defeat) / (1 - defeat), 0, 1)
end

-- Bounding-box centre: works whether or not the model has a pivot set.
local function centerOf(model: Model): Vector3
	local boxCFrame = model:GetBoundingBox()
	return boxCFrame.Position
end

local function warnDefenders(teamName: string)
	local now = os.clock()
	if now - (lastAttackWarning[teamName] or 0) < ATTACK_WARNING_COOLDOWN then
		return
	end
	lastAttackWarning[teamName] = now
	local toast = Remotes.get("Toast")
	for _, player in Players:GetPlayers() do
		if player.Team and player.Team.Name == teamName and player:GetAttribute("InMatch") then
			toast:FireClient(player, "Your tower is under attack!", "warning")
		end
	end
end

local function onBricksLost(
	teamName: string,
	structure: BrickStructure.BrickStructure,
	count: number,
	attacker: Player?
)
	GameState.setTeam(GameState.TeamKey.TowerHealth, teamName, normalizedHealth(structure))
	-- The final collapse fires one last BricksLost; it isn't worth extra points.
	if structure.Destroyed then
		return
	end

	if attacker and attacker.Team and attacker.Team.Name ~= teamName then
		ScoreService.addBricks(attacker, count)
		warnDefenders(teamName)
	end

	if structure:health() <= Config.Tower.DefeatFraction then
		local position = centerOf(structure.Model)
		structure:collapseAll()
		GameState.setTeam(GameState.TeamKey.TowerHealth, teamName, 0)
		Remotes.get("StructureFx"):FireAllClients(position + Vector3.new(0, 20, 0), 200)
		TowerService.TowerDestroyed:Fire(teamName, structure.LastAttacker)
	end
end

function TowerService.init()
	local arena = workspace:FindFirstChild("Arena")
	towersFolder = arena and arena:FindFirstChild("Towers")
	if not towersFolder then
		warn("[TowerService] Workspace.Arena.Towers is missing - towers are disabled.")
		return
	end

	-- Keep pristine copies before anything can be damaged.
	local storage = Instance.new("Folder")
	storage.Name = "TowerTemplates"
	storage.Parent = ServerStorage
	for _, model in (towersFolder :: Instance):GetChildren() do
		local teamName = model:GetAttribute("Team")
		if model:IsA("Model") and typeof(teamName) == "string" then
			local template = model:Clone()
			template.Parent = storage
			templates[teamName] = template
		end
	end
	TowerService.reset()
end

-- Rebuilds every tower from its template.
function TowerService.reset()
	for _, structure in towers do
		structure:destroy()
	end
	table.clear(towers)
	table.clear(lastAttackWarning)

	local folder = towersFolder
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Team") ~= nil then
			child:Destroy()
		end
	end
	for teamName, template in templates do
		local model = template:Clone()
		model.Parent = folder
		local structure = BrickStructure.new(model, teamName)
		structure.BricksLost:Connect(function(count, attacker)
			onBricksLost(teamName, structure, count, attacker)
		end)
		towers[teamName] = structure
		GameState.setTeam(GameState.TeamKey.TowerHealth, teamName, 1)
	end
end

function TowerService.registerStructure(structure: BrickStructure.BrickStructure)
	table.insert(extraStructures, structure)
end

function TowerService.unregisterStructure(structure: BrickStructure.BrickStructure)
	local index = table.find(extraStructures, structure)
	if index then
		table.remove(extraStructures, index)
	end
end

-- Breaks bricks around an explosion. Towers only take damage mid-battle.
-- Returns the number of bricks that came loose.
function TowerService.breakAt(position: Vector3, radius: number, attacker: Player?): number
	local total = 0
	local collapsedTotal = 0
	if GameState.phase() == GameState.Phase.Battle then
		for _, structure in towers do
			local blasted, collapsed = structure:breakInRadius(position, radius, attacker)
			total += blasted + collapsed
			collapsedTotal += collapsed
		end
	end
	for _, structure in extraStructures do
		local blasted, collapsed = structure:breakInRadius(position, radius, attacker)
		total += blasted + collapsed
		collapsedTotal += collapsed
	end
	if collapsedTotal >= 12 then
		Remotes.get("StructureFx"):FireAllClients(position, collapsedTotal)
	end
	return total
end

function TowerService.health(teamName: string): number
	local structure = towers[teamName]
	return if structure then normalizedHealth(structure) else 0
end

function TowerService.isDestroyed(teamName: string): boolean
	local structure = towers[teamName]
	return structure ~= nil and structure.Destroyed
end

function TowerService.position(teamName: string): Vector3?
	local structure = towers[teamName]
	if structure and structure.Model.Parent then
		return centerOf(structure.Model)
	end
	local template = templates[teamName]
	return if template then centerOf(template) else nil
end

-- Admin/testing helper: brings a tower straight down.
function TowerService.collapse(teamName: string): boolean
	local structure = towers[teamName]
	if not structure or structure.Destroyed or GameState.phase() ~= GameState.Phase.Battle then
		return false
	end
	local position = centerOf(structure.Model)
	structure:collapseAll()
	GameState.setTeam(GameState.TeamKey.TowerHealth, teamName, 0)
	Remotes.get("StructureFx"):FireAllClients(position + Vector3.new(0, 20, 0), 200)
	TowerService.TowerDestroyed:Fire(teamName, nil)
	return true
end

return TowerService

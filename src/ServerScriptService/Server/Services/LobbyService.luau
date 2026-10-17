--!strict
-- The sky-island lobby: a breakable practice wall that rebuilds itself,
-- training dummies that show damage numbers, and a safety net that catches
-- anyone who falls off the island.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BrickStructure = require(script.Parent.Parent.Lib.BrickStructure)
local TowerService = require(script.Parent.TowerService)

local LobbyService = {}

local DUMMY_TAG = "TrainingDummy"
local DUMMY_RESPAWN_DELAY = 3
local DUMMY_REGEN_DELAY = 4

local lobby: Instance? = nil
local spawnPart: BasePart? = nil

local wallTemplate: Model? = nil
local wallParent: Instance? = nil
local wall: BrickStructure.BrickStructure? = nil
local lastWallHitAt = 0

-- The spot players are returned to.
function LobbyService.spawnCFrame(): CFrame
	if spawnPart then
		return spawnPart.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 50, 0)
end

local function buildWall()
	if wall then
		TowerService.unregisterStructure(wall)
		wall:destroy()
		wall = nil
	end
	if not wallTemplate or not wallParent then
		return
	end
	local model = wallTemplate:Clone()
	model.Parent = wallParent
	local structure = BrickStructure.new(model, nil)
	structure.BricksLost:Connect(function()
		lastWallHitAt = os.clock()
	end)
	TowerService.registerStructure(structure)
	wall = structure
end

local function setupDummy(dummy: Model, template: Model, parent: Instance)
	CollectionService:AddTag(dummy, DUMMY_TAG)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = Config.Lobby.DummyMaxHealth
	humanoid.Health = Config.Lobby.DummyMaxHealth

	local lastHitAt = 0
	humanoid.HealthChanged:Connect(function(health)
		if health < humanoid.MaxHealth then
			lastHitAt = os.clock()
		end
	end)

	-- Heal back to full after a short break so the numbers stay readable.
	task.spawn(function()
		while dummy.Parent and humanoid.Health > 0 do
			task.wait(1)
			if humanoid.Health < humanoid.MaxHealth and os.clock() - lastHitAt > DUMMY_REGEN_DELAY then
				humanoid.Health = humanoid.MaxHealth
			end
		end
	end)

	humanoid.Died:Once(function()
		task.delay(DUMMY_RESPAWN_DELAY, function()
			dummy:Destroy()
			local fresh = template:Clone()
			fresh.Parent = parent
			setupDummy(fresh, template, parent)
		end)
	end)
end

function LobbyService.init()
	lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		warn("[LobbyService] Workspace.Lobby is missing.")
		return
	end
	local root = lobby :: Instance

	local spawn = root:FindFirstChild("LobbySpawn", true)
	if spawn and spawn:IsA("BasePart") then
		spawnPart = spawn
	end

	local wallModel = root:FindFirstChild("PracticeWall", true)
	if wallModel and wallModel:IsA("Model") then
		wallParent = wallModel.Parent
		wallTemplate = wallModel:Clone()
		wallModel:Destroy()
		buildWall()
	end

	local dummies = root:FindFirstChild("Dummies", true)
	if dummies then
		local templateFolder = Instance.new("Folder")
		templateFolder.Name = "DummyTemplates"
		templateFolder.Parent = ServerStorage
		for _, dummy in dummies:GetChildren() do
			if dummy:IsA("Model") then
				local template = dummy:Clone()
				template.Parent = templateFolder
				setupDummy(dummy, template, dummies)
			end
		end
	end
end

function LobbyService.start()
	-- Rebuild the practice wall a few seconds after people stop hitting it.
	task.spawn(function()
		while true do
			task.wait(1)
			local current = wall
			if
				current
				and current:health() < 1
				and os.clock() - lastWallHitAt > Config.Lobby.PracticeWallRegenDelay
			then
				buildWall()
			end
		end
	end)

	-- Catch players who walk (or get blasted) off the island.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local spawnLocation = spawnPart
			if spawnLocation then
				local floorY = spawnLocation.Position.Y
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local rootPart = character and character:FindFirstChild("HumanoidRootPart")
					if
						character
						and rootPart
						and rootPart:IsA("BasePart")
						and not player:GetAttribute("InMatch")
						and rootPart.Position.Y < floorY - Config.Lobby.VoidDepth
					then
						rootPart.AssemblyLinearVelocity = Vector3.zero
						character:PivotTo(LobbyService.spawnCFrame())
					end
				end
			end
		end
	end)
end

return LobbyService

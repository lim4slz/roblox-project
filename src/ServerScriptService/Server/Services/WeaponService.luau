--!strict
-- Hands out tools and runs the melee sword and the (admin-only) rocket
-- launcher. Tool models live in ServerStorage.Tools; all input arrives through
-- remotes and is validated here before anything happens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local CombatService = require(script.Parent.CombatService)

local WeaponService = {}

WeaponService.ToolNames = { "Bomb", "Sword", "RocketLauncher" }

type SwordState = { lastSwing: number, lastWasLunge: boolean }

local toolsFolder: Instance? = nil
local swordStates: { [Player]: SwordState } = {}
local rocketCooldowns: { [Player]: number } = {}
local rocketsFolder: Folder

local function aliveCharacter(player: Player): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return character, humanoid
	end
	return nil, nil
end

local function isFiniteVector(vector: any): boolean
	if typeof(vector) ~= "Vector3" then
		return false
	end
	local magnitude = vector.Magnitude
	return magnitude == magnitude and magnitude < math.huge
end

-- The Tool the player is currently holding, if it has this name.
function WeaponService.equipped(player: Player, toolName: string): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild(toolName)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

local function findOwnedTool(player: Player, toolName: string): Tool?
	local equipped = WeaponService.equipped(player, toolName)
	if equipped then
		return equipped
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local stored = backpack and backpack:FindFirstChild(toolName)
	if stored and stored:IsA("Tool") then
		return stored
	end
	return nil
end

function WeaponService.give(player: Player, toolName: string): Tool?
	local existing = findOwnedTool(player, toolName)
	if existing then
		return existing
	end
	local template = toolsFolder and toolsFolder:FindFirstChild(toolName)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not template or not template:IsA("Tool") or not backpack then
		warn(`[WeaponService] Can't give {toolName} to {player.Name}`)
		return nil
	end
	local tool = template:Clone()
	tool.Parent = backpack
	return tool
end

function WeaponService.giveLoadout(player: Player)
	WeaponService.give(player, "Bomb")
	WeaponService.give(player, "Sword")
end

function WeaponService.clear(player: Player)
	for _, toolName in WeaponService.ToolNames do
		local tool = findOwnedTool(player, toolName)
		if tool then
			tool:Destroy()
		end
	end
end

-- Hides the bomb in the player's hand while it reloads (everyone sees it).
function WeaponService.setBombVisible(player: Player, visible: boolean)
	local tool = findOwnedTool(player, "Bomb")
	if not tool then
		return
	end
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") then
			local base = descendant:GetAttribute("BaseTransparency")
			if typeof(base) ~= "number" then
				base = descendant.Transparency
				descendant:SetAttribute("BaseTransparency", base)
			end
			descendant.Transparency = if visible then base :: number else 1
		elseif descendant:IsA("Light") then
			descendant.Enabled = visible
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = visible
		end
	end
end

----------------------------------------------------------------------------
-- Sword
----------------------------------------------------------------------------

local function onSwing(player: Player)
	if not WeaponService.equipped(player, "Sword") then
		return
	end
	local character = aliveCharacter(player)
	if not character then
		return
	end

	local sword = Config.Sword
	local now = os.clock()
	local state = swordStates[player]
	if not state then
		state = { lastSwing = 0, lastWasLunge = false }
		swordStates[player] = state
	end

	local sinceLast = now - state.lastSwing
	-- A quick second click becomes a lunge, but lunges can't chain.
	local isLunge = sinceLast <= sword.LungeWindow and sinceLast >= 0.08 and not state.lastWasLunge
	if not isLunge and sinceLast < sword.Cooldown then
		return
	end
	state.lastSwing = now
	state.lastWasLunge = isLunge

	Remotes.get("ActionFx"):FireAllClients(player, if isLunge then "Lunge" else "Slash")
	if isLunge then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			CombatService.knockback(player, root.CFrame.LookVector * 38 + Vector3.new(0, 12, 0))
		end
	end

	-- Tiny delay so the hit lands with the swing animation, not before it.
	task.delay(0.08, function()
		if player.Parent then
			CombatService.meleeSweep(
				player,
				sword.Range,
				if isLunge then sword.LungeDamage else sword.Damage,
				if isLunge then sword.LungeKnockback else sword.Knockback,
				"Sword"
			)
		end
	end)
end

----------------------------------------------------------------------------
-- Rocket launcher (classic Brickbattle, handed out from the admin panel)
----------------------------------------------------------------------------

local function launchRocket(player: Player, origin: Vector3, direction: Vector3)
	local rocketConfig = Config.Rocket
	local teamColor = TeamInfo.colorOf(if player.Team then player.Team.Name else nil)

	local rocket = Instance.new("Part")
	rocket.Name = "Rocket"
	rocket.Size = Vector3.new(0.8, 0.8, 3)
	rocket.Color = teamColor
	rocket.Material = Enum.Material.SmoothPlastic
	rocket.Anchored = true
	rocket.CanCollide = false
	rocket.CanQuery = false
	rocket.CanTouch = false
	rocket.CFrame = CFrame.lookAt(origin, origin + direction)

	local nose = Instance.new("Part")
	nose.Name = "Nose"
	nose.Size = Vector3.new(0.6, 0.6, 0.6)
	nose.Color = Color3.fromRGB(255, 214, 102)
	nose.Material = Enum.Material.Neon
	nose.Anchored = true
	nose.CanCollide = false
	nose.CanQuery = false
	nose.CanTouch = false
	nose.CFrame = rocket.CFrame * CFrame.new(0, 0, -1.7)
	nose.Parent = rocket

	local tailAttachment0 = Instance.new("Attachment")
	tailAttachment0.Position = Vector3.new(0, 0.3, 1.5)
	tailAttachment0.Parent = rocket
	local tailAttachment1 = Instance.new("Attachment")
	tailAttachment1.Position = Vector3.new(0, -0.3, 1.5)
	tailAttachment1.Parent = rocket
	local trail = Instance.new("Trail")
	trail.Attachment0 = tailAttachment0
	trail.Attachment1 = tailAttachment1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), teamColor)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.8
	trail.Parent = rocket

	rocket.Parent = rocketsFolder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { rocketsFolder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _, name in { "Debris", "Bombs", "ClientEffects" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	params.FilterDescendantsInstances = ignore

	local position: Vector3 = origin
	local travelled: number = 0
	local connection: RBXScriptConnection
	local function detonate(at: Vector3)
		connection:Disconnect()
		rocket:Destroy()
		CombatService.explode({
			position = at,
			radius = rocketConfig.BlastRadius,
			brickRadius = rocketConfig.BrickRadius,
			maxDamage = rocketConfig.MaxDamage,
			minDamage = rocketConfig.MinDamage,
			knockback = rocketConfig.Knockback,
			attacker = if player.Parent then player else nil,
			kind = "Rocket",
		})
	end

	-- Stepped manually with raycasts: deterministic, never tunnels through
	-- thin walls, and costs nothing when no rockets are in flight.
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		local step = direction * rocketConfig.Speed * deltaTime
		local hit = workspace:Raycast(position, step, params)
		if hit then
			detonate(hit.Position)
			return
		end
		position += step
		travelled += deltaTime
		rocket.CFrame = CFrame.lookAt(position, position + direction)
		nose.CFrame = rocket.CFrame * CFrame.new(0, 0, -1.7)
		if travelled >= rocketConfig.Lifetime then
			detonate(position)
		end
	end)
end

local function onFireRocket(player: Player, target: any)
	if not isFiniteVector(target) or not WeaponService.equipped(player, "RocketLauncher") then
		return
	end
	local character = aliveCharacter(player)
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local now = os.clock()
	if now - (rocketCooldowns[player] or 0) < Config.Rocket.Cooldown then
		return
	end
	rocketCooldowns[player] = now

	local direction = (target :: Vector3) - head.Position
	if direction.Magnitude < 1 then
		return
	end
	direction = direction.Unit
	Remotes.get("ActionFx"):FireAllClients(player, "Fire")
	launchRocket(player, head.Position + direction * 3, direction)
end

function WeaponService.init()
	toolsFolder = ServerStorage:FindFirstChild("Tools")
	if not toolsFolder then
		warn("[WeaponService] ServerStorage.Tools is missing - players won't get weapons.")
	end

	rocketsFolder = Instance.new("Folder")
	rocketsFolder.Name = "Rockets"
	rocketsFolder.Parent = workspace

	Remotes.get("SwingSword").OnServerEvent:Connect(onSwing)
	Remotes.get("FireRocket").OnServerEvent:Connect(onFireRocket)
	Players.PlayerRemoving:Connect(function(player)
		swordStates[player] = nil
		rocketCooldowns[player] = nil
	end)
end

function WeaponService.clearProjectiles()
	rocketsFolder:ClearAllChildren()
end

return WeaponService

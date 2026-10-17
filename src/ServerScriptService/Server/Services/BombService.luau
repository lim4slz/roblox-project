--!strict
-- The bomb: Doomspire's signature weapon. Hold to charge, release to lob a
-- bouncing bomb with a short fuse. Each player carries one bomb; a fresh one
-- appears in their hand after a short reload.
--
-- Bomb state lives in player attributes so the client HUD can show it without
-- any extra remotes:
--   BombCharges       bombs ready to throw
--   BombReloadEndsAt  server timestamp when the next bomb is ready (0 = none)
--   MegaBomb          the next throw is a Mega Bomb

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioLibrary = require(ReplicatedStorage.Shared.AudioLibrary)
local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local Trajectory = require(ReplicatedStorage.Shared.Trajectory)
local CollisionGroups = require(script.Parent.Parent.Lib.CollisionGroups)
local CombatService = require(script.Parent.CombatService)
local Rules = require(script.Parent.Rules)
local WeaponService = require(script.Parent.WeaponService)

export type BombOptions = {
	position: Vector3,
	velocity: Vector3,
	owner: Player?,
	mega: boolean?,
	kind: string, -- "Bomb" | "Mega" | "Rain"
	fuse: number?,
}

local BombService = {}

local LIVE_BOMB_TAG = "LiveBomb"

local bombsFolder: Folder
local lastThrowAt: { [Player]: number } = {}
-- Bumped whenever a reload is scheduled or cancelled, so stale reloads no-op.
local reloadTokens: { [Player]: number } = {}

local function throwingAllowed(): boolean
	-- Practice throws in the lobby are fine; nobody throws while frozen in
	-- Get Ready or while the results screen is up.
	local phase = GameState.phase()
	return phase == GameState.Phase.Battle or phase == GameState.Phase.Waiting or phase == GameState.Phase.Intermission
end

local function setCharges(player: Player, charges: number)
	player:SetAttribute("BombCharges", charges)
	WeaponService.setBombVisible(player, charges > 0)
end

local function scheduleReload(player: Player)
	local token = (reloadTokens[player] or 0) + 1
	reloadTokens[player] = token
	local reloadTime = Rules.reloadTime()
	player:SetAttribute("BombReloadEndsAt", GameState.now() + reloadTime)
	task.delay(reloadTime, function()
		if reloadTokens[player] ~= token or player.Parent ~= Players then
			return
		end
		player:SetAttribute("BombReloadEndsAt", 0)
		setCharges(player, 1)
	end)
end

function BombService.charges(player: Player): number
	local charges = player:GetAttribute("BombCharges")
	return if typeof(charges) == "number" then charges else 0
end

function BombService.resetCharges(player: Player)
	reloadTokens[player] = (reloadTokens[player] or 0) + 1
	player:SetAttribute("BombReloadEndsAt", 0)
	player:SetAttribute("MegaBomb", false)
	setCharges(player, 1)
end

-- Triple Bomb power-up: several throws in a row with no reload in between.
function BombService.grantCharges(player: Player, charges: number)
	reloadTokens[player] = (reloadTokens[player] or 0) + 1
	player:SetAttribute("BombReloadEndsAt", 0)
	setCharges(player, math.max(charges, BombService.charges(player)))
end

function BombService.grantMega(player: Player)
	player:SetAttribute("MegaBomb", true)
	if BombService.charges(player) < 1 then
		BombService.grantCharges(player, 1)
	end
end

local function weld(part: BasePart, to: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = to
	constraint.Part1 = part
	constraint.Parent = part
end

local function decorPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Builds the physical bomb: a black ball with a team-coloured band, a fuse
-- and a spark. The ticking and blinking are done client-side (see VfxController)
-- from the ExplodesAt attribute, which keeps network traffic near zero.
local function buildBomb(options: BombOptions, fuse: number): Part
	local teamName = if options.owner and options.owner.Team then options.owner.Team.Name else nil
	local size = Config.Bomb.Size * (if options.mega then 1.5 else 1)
	local bandColor = if options.kind == "Rain" then Color3.fromRGB(251, 146, 60) else TeamInfo.colorOf(teamName)

	local bomb = Instance.new("Part")
	bomb.Name = if options.mega then "MegaBomb" else "Bomb"
	bomb.Shape = Enum.PartType.Ball
	bomb.Size = Vector3.one * size
	bomb.Color = Color3.fromRGB(31, 31, 38)
	bomb.Material = Enum.Material.SmoothPlastic
	bomb.TopSurface = Enum.SurfaceType.Smooth
	bomb.BottomSurface = Enum.SurfaceType.Smooth
	bomb.CustomPhysicalProperties = PhysicalProperties.new(2, 0.5, Config.Bomb.Elasticity, 1, 1)
	bomb.CollisionGroup = CollisionGroups.Bombs
	bomb.CanQuery = false
	bomb.CFrame = CFrame.new(options.position)

	local band = decorPart("Band", Vector3.new(size * 0.32, size * 1.04, size * 1.04), bandColor, Enum.Material.Neon)
	band.Shape = Enum.PartType.Cylinder
	band.CFrame = bomb.CFrame
	band.Parent = bomb
	weld(band, bomb)

	local fuseCap = decorPart(
		"Fuse",
		Vector3.new(size * 0.18, size * 0.35, size * 0.18),
		Color3.fromRGB(120, 85, 50),
		Enum.Material.Wood
	)
	fuseCap.CFrame = bomb.CFrame * CFrame.new(0, size * 0.6, 0)
	fuseCap.Parent = bomb
	weld(fuseCap, bomb)

	local spark = decorPart("Spark", Vector3.one * size * 0.22, Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
	spark.Shape = Enum.PartType.Ball
	spark.CFrame = bomb.CFrame * CFrame.new(0, size * 0.8, 0)
	spark.Parent = bomb
	weld(spark, bomb)

	local light = Instance.new("PointLight")
	light.Name = "FuseLight"
	light.Color = Color3.fromRGB(255, 80, 60)
	light.Range = 8
	light.Brightness = 2
	light.Parent = spark

	-- Bounce sound is played from the server so everyone hears it in 3D.
	local spec = AudioLibrary.Sfx.Bounce
	local bounce = Instance.new("Sound")
	bounce.Name = "Bounce"
	bounce.SoundId = AudioLibrary.assetUri(spec.Id)
	bounce.Volume = spec.Volume
	if spec.RollOff then
		bounce.RollOffMinDistance = spec.RollOff[1]
		bounce.RollOffMaxDistance = spec.RollOff[2]
	end
	bounce.Parent = bomb

	bomb:SetAttribute("ExplodesAt", GameState.now() + fuse)
	bomb:SetAttribute("Fuse", fuse)
	bomb:SetAttribute("Mega", options.mega == true)
	bomb:SetAttribute("Team", teamName)
	CollectionService:AddTag(bomb, LIVE_BOMB_TAG)
	return bomb
end

local function detonate(bomb: BasePart, options: BombOptions)
	if not bomb.Parent then
		return
	end
	local position = bomb.Position
	bomb:Destroy()

	local scale = if options.mega then Config.Bomb.MegaMultiplier else 1
	local owner = options.owner
	CombatService.explode({
		position = position,
		radius = Rules.blastRadius(Config.Bomb.BlastRadius) * scale,
		brickRadius = Rules.blastRadius(Config.Bomb.BrickRadius) * scale,
		maxDamage = Config.Bomb.MaxDamage,
		minDamage = Config.Bomb.MinDamage,
		knockback = Config.Bomb.Knockback * (if options.mega then 1.3 else 1),
		attacker = if owner and owner.Parent == Players then owner else nil,
		kind = options.kind,
	})
end

function BombService.spawnBomb(options: BombOptions): BasePart
	local fuse = options.fuse or (Rules.get("FuseTime") + (if options.mega then 0.4 else 0))
	local bomb = buildBomb(options, fuse)

	local lastBounce = 0
	bomb.Touched:Connect(function(hit)
		local now = os.clock()
		if now - lastBounce < 0.18 or hit:IsDescendantOf(bomb) then
			return
		end
		if bomb.AssemblyLinearVelocity.Magnitude > 12 then
			lastBounce = now
			local sound = bomb:FindFirstChild("Bounce")
			if sound and sound:IsA("Sound") then
				sound.PlaybackSpeed = 0.9 + math.random() * 0.25
				sound:Play()
			end
		end
	end)

	bomb.Parent = bombsFolder
	pcall(function()
		bomb:SetNetworkOwner(nil)
	end)
	bomb.AssemblyLinearVelocity = options.velocity
	bomb.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))

	task.delay(fuse, detonate, bomb, options)
	return bomb
end

local function onThrow(player: Player, aim: any, charge: any)
	if typeof(aim) ~= "Vector3" or typeof(charge) ~= "number" then
		return
	end
	-- Reject NaN/inf and zero-length aims from tampered clients.
	local magnitude = aim.Magnitude
	if magnitude ~= magnitude or magnitude < 0.01 or magnitude > 10 or charge ~= charge then
		return
	end
	if not throwingAllowed() or player:GetAttribute("Frozen") then
		return
	end
	if not WeaponService.equipped(player, "Bomb") then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not humanoid
		or humanoid.Health <= 0
		or not head
		or not head:IsA("BasePart")
		or not root
		or not root:IsA("BasePart")
	then
		return
	end

	local now = os.clock()
	if now - (lastThrowAt[player] or 0) < Config.Bomb.ThrowCooldown then
		return
	end
	local charges = BombService.charges(player)
	if charges < 1 then
		return
	end
	lastThrowAt[player] = now

	local mega = player:GetAttribute("MegaBomb") == true
	if mega then
		player:SetAttribute("MegaBomb", false)
	end
	setCharges(player, charges - 1)
	if charges - 1 <= 0 then
		scheduleReload(player)
	end

	local origin, velocity =
		Trajectory.launch(head.Position, aim.Unit, math.clamp(charge, 0, 1), root.AssemblyLinearVelocity)
	-- Never spawn the bomb on the far side of a wall you're hugging.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Model, bombsFolder }
	local reach = origin - head.Position
	local blocked = workspace:Raycast(head.Position, reach, params)
	if blocked then
		origin = blocked.Position - reach.Unit * (Config.Bomb.Size * 0.6)
	end

	BombService.spawnBomb({
		position = origin,
		velocity = velocity,
		owner = player,
		mega = mega,
		kind = if mega then "Mega" else "Bomb",
	})
	Remotes.get("ActionFx"):FireAllClients(player, "Throw")
end

function BombService.init()
	bombsFolder = Instance.new("Folder")
	bombsFolder.Name = "Bombs"
	bombsFolder.Parent = workspace

	Remotes.get("ThrowBomb").OnServerEvent:Connect(onThrow)
	Players.PlayerRemoving:Connect(function(player)
		lastThrowAt[player] = nil
		reloadTokens[player] = nil
	end)
end

function BombService.clearAll()
	bombsFolder:ClearAllChildren()
end

return BombService

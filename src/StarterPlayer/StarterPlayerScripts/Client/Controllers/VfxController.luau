--!strict
-- All the client-side juice: explosions, tower collapses, blinking bomb fuses,
-- spinning power-ups, damage numbers and blocky fireworks.
--
-- Everything is built from plain parts (no textures or meshes) to match the
-- blocky art style and to stay cheap on phones: an explosion is a flash, a
-- shockwave ring, a dozen tumbling cubes and a few puffs of "smoke" cubes.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundPlayer = require(ReplicatedStorage.Shared.SoundPlayer)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local EffectParts = require(script.Parent.Parent.Lib.EffectParts)
local CameraController = require(script.Parent.CameraController)

local VfxController = {}

local player = Players.LocalPlayer

local EXPLOSION_COLORS: { [string]: Color3 } = {
	Bomb = Color3.fromRGB(255, 190, 70),
	Mega = Color3.fromRGB(255, 96, 64),
	Rocket = Color3.fromRGB(255, 226, 120),
	Rain = Color3.fromRGB(251, 146, 60),
}
local DEBRIS_PALETTE = {
	Color3.fromRGB(71, 85, 105),
	Color3.fromRGB(100, 116, 139),
	Color3.fromRGB(251, 146, 60),
	Color3.fromRGB(250, 204, 21),
	Color3.fromRGB(30, 41, 59),
}
local FIREWORK_COLORS = {
	Color3.fromRGB(239, 68, 68),
	Color3.fromRGB(59, 130, 246),
	Color3.fromRGB(250, 204, 21),
	Color3.fromRGB(74, 222, 128),
	Color3.fromRGB(236, 72, 153),
	Color3.fromRGB(45, 212, 191),
}

local function tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local created = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	created:Play()
	return created
end

-- Shrinks a part to nothing then removes it (nicer than popping out).
local function fadeAway(part: BasePart, delay: number, duration: number)
	task.delay(delay, function()
		if part.Parent then
			tween(part, duration, { Size = Vector3.one * 0.05, Transparency = 1 })
			Debris:AddItem(part, duration + 0.05)
		end
	end)
end

local function shakeFrom(position: Vector3, strength: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	local maxDistance = Config.Camera.ShakeMaxDistance * math.max(1, strength)
	if distance < maxDistance then
		CameraController.shake(Config.Camera.ShakeIntensity * strength * (1 - distance / maxDistance))
	end
end

local function flashLight(position: Vector3, color: Color3, range: number, duration: number)
	local holder = Instance.new("Attachment")
	holder.Parent = workspace.Terrain
	holder.WorldPosition = position
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range, 60)
	light.Brightness = 6
	light.Shadows = false
	light.Parent = holder
	tween(light, duration, { Brightness = 0 })
	Debris:AddItem(holder, duration + 0.1)
end

----------------------------------------------------------------------------
-- Explosions
----------------------------------------------------------------------------

function VfxController.explosion(position: Vector3, radius: number, kind: string, bricksBroken: number)
	local color = EXPLOSION_COLORS[kind] or EXPLOSION_COLORS.Bomb
	local scale = radius / Config.Bomb.BlastRadius

	-- 1. Bright core flash.
	local flash = EffectParts.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = CFrame.new(position),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.05,
	})
	tween(flash, 0.22, { Size = Vector3.one * radius * 1.7, Transparency = 1 })
	Debris:AddItem(flash, 0.3)

	-- 2. Blocky inner burst: a rotated cube that punches out and vanishes.
	local burst = EffectParts.part({
		Size = Vector3.one * 2,
		CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3),
		Color = Color3.fromRGB(255, 245, 210),
		Material = Enum.Material.Neon,
		Transparency = 0,
	})
	tween(burst, 0.18, { Size = Vector3.one * radius, Transparency = 1 })
	Debris:AddItem(burst, 0.25)

	-- 3. Shockwave ring hugging the ground.
	local ring = EffectParts.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius, radius),
		CFrame = CFrame.new(position - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	tween(ring, 0.4, { Size = Vector3.new(0.1, radius * 2.8, radius * 2.8), Transparency = 1 })
	Debris:AddItem(ring, 0.45)

	-- 4. Tumbling debris cubes.
	local pieces = math.floor(9 + 5 * scale)
	for _ = 1, pieces do
		local direction = Vector3.new(math.random() * 2 - 1, math.random() * 0.9 + 0.35, math.random() * 2 - 1).Unit
		local cube = EffectParts.debris(
			position + direction * 1.5,
			0.4 + math.random() * 0.7,
			DEBRIS_PALETTE[math.random(1, #DEBRIS_PALETTE)],
			direction * (30 + math.random() * 30) * math.sqrt(scale)
		)
		fadeAway(cube, 1 + math.random() * 0.6, 0.35)
	end

	-- 5. A few puffs of smoke (grey cubes that swell, drift up and fade).
	for _ = 1, 4 do
		local offset = Vector3.new(math.random() * 2 - 1, math.random() * 0.6, math.random() * 2 - 1) * radius * 0.35
		local puff = EffectParts.part({
			Size = Vector3.one * (1.5 + math.random()),
			CFrame = CFrame.new(position + offset) * CFrame.Angles(math.random() * 3, math.random() * 3, 0),
			Color = Color3.fromRGB(148, 163, 184),
			Transparency = 0.25,
		})
		tween(puff, 1.1 + math.random() * 0.4, {
			Size = Vector3.one * radius * (0.45 + math.random() * 0.25),
			CFrame = puff.CFrame + Vector3.new(0, 3 + math.random() * 3, 0),
			Transparency = 1,
		}, Enum.EasingStyle.Sine)
		Debris:AddItem(puff, 1.6)
	end

	flashLight(position, color, radius * 3, 0.35)
	SoundPlayer.playAt("Explosion", position, {
		pitchJitter = 0.08,
		pitch = if kind == "Mega" then 0.8 else 1,
	})
	if bricksBroken > 0 then
		SoundPlayer.playAt("BrickCrumble", position, { pitchJitter = 0.1 })
	end
	shakeFrom(position, scale)
end

function VfxController.structureCollapse(position: Vector3, brickCount: number)
	SoundPlayer.playAt("TowerCollapse", position, { pitchJitter = 0.05, pitch = 0.75 })
	SoundPlayer.playAt("BrickCrumble", position, { pitch = 0.8 })
	-- Big lazy dust cloud.
	local puffs = math.clamp(math.floor(brickCount / 10), 4, 12)
	for _ = 1, puffs do
		local offset = Vector3.new(math.random() * 2 - 1, math.random() - 0.3, math.random() * 2 - 1) * 14
		local puff = EffectParts.part({
			Size = Vector3.one * (4 + math.random() * 3),
			CFrame = CFrame.new(position + offset) * CFrame.Angles(math.random() * 3, math.random() * 3, 0),
			Color = Color3.fromRGB(203, 213, 225),
			Transparency = 0.3,
		})
		tween(puff, 2.5 + math.random(), {
			Size = Vector3.one * (12 + math.random() * 8),
			CFrame = puff.CFrame + Vector3.new(0, 6, 0),
			Transparency = 1,
		}, Enum.EasingStyle.Sine)
		Debris:AddItem(puff, 4)
	end
	shakeFrom(position, 1.6)
end

----------------------------------------------------------------------------
-- Live bombs: blink faster and tick as the fuse runs out
----------------------------------------------------------------------------

type LiveBomb = { part: BasePart, nextBlinkAt: number, lit: boolean }
local liveBombs: { [BasePart]: LiveBomb } = {}

local function trackBomb(instance: Instance)
	if instance:IsA("BasePart") then
		liveBombs[instance] = { part = instance, nextBlinkAt = 0, lit = false }
	end
end

local function updateBombs()
	local now = GameState.now()
	local clock = os.clock()
	for part, bomb in liveBombs do
		if not part.Parent then
			liveBombs[part] = nil
			continue
		end
		local explodesAt = part:GetAttribute("ExplodesAt")
		local remaining = if typeof(explodesAt) == "number" then explodesAt - now else 1
		if clock >= bomb.nextBlinkAt then
			bomb.lit = not bomb.lit
			local period = math.clamp(remaining * 0.16, 0.05, 0.35)
			bomb.nextBlinkAt = clock + period
			local spark = part:FindFirstChild("Spark")
			if spark and spark:IsA("BasePart") then
				spark.Color = if bomb.lit then Color3.fromRGB(255, 70, 50) else Color3.fromRGB(255, 220, 90)
				local light = spark:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = if bomb.lit then 4 else 0.5
				end
			end
			if bomb.lit and period > 0.06 then
				SoundPlayer.playAt(
					"FuseTick",
					part.Position,
					{ pitch = 1 + (1 - math.clamp(remaining / 3, 0, 1)) * 0.6 }
				)
			end
		end
	end
end

----------------------------------------------------------------------------
-- Power-ups: spin and bob locally (the server copy stays still)
----------------------------------------------------------------------------

local spinning: { [BasePart]: CFrame } = {}

local function trackPowerUp(instance: Instance)
	if instance:IsA("BasePart") then
		spinning[instance] = CFrame.new(instance.Position)
	end
end

local function updatePowerUps()
	local t = os.clock()
	for part, base in spinning do
		if not part.Parent then
			spinning[part] = nil
			continue
		end
		local cframe = base * CFrame.new(0, math.sin(t * 2.5) * 0.4, 0) * CFrame.Angles(t * 1.3, t * 2, t * 0.7)
		part.CFrame = cframe
		local core = part:FindFirstChild("Core")
		if core and core:IsA("BasePart") then
			core.CFrame = base * CFrame.new(0, math.sin(t * 2.5) * 0.4, 0) * CFrame.Angles(-t * 2, t, 0)
		end
	end
end

----------------------------------------------------------------------------
-- Floating damage numbers (training dummies)
----------------------------------------------------------------------------

function VfxController.damageNumber(position: Vector3, amount: number)
	local holder = Instance.new("Attachment")
	holder.Parent = workspace.Terrain
	holder.WorldPosition = position + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 50)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	billboard.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "-" .. tostring(amount)
	label.TextColor3 = if amount >= 60 then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(255, 230, 120)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	tween(billboard, 1, { StudsOffsetWorldSpace = Vector3.new(0, 4, 0) })
	tween(label, 1, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(holder, 1.1)
end

----------------------------------------------------------------------------
-- Fireworks (admin toggle, and over the winners' tower at the end)
----------------------------------------------------------------------------

local function towerCenter(teamName: string): Vector3?
	local arena = workspace:FindFirstChild("Arena")
	local towers = arena and arena:FindFirstChild("Towers")
	if not towers then
		return nil
	end
	for _, model in towers:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Team") == teamName and #model:GetChildren() > 0 then
			local ok, boxCFrame = pcall(function()
				return (model:GetBoundingBox())
			end)
			if ok then
				return boxCFrame.Position
			end
		end
	end
	return nil
end

function VfxController.firework(origin: Vector3, color: Color3?)
	local burstColor = color or FIREWORK_COLORS[math.random(1, #FIREWORK_COLORS)]
	local height = 45 + math.random() * 25
	local rocket = EffectParts.part({
		Size = Vector3.new(0.6, 1.4, 0.6),
		CFrame = CFrame.new(origin),
		Color = burstColor,
		Material = Enum.Material.Neon,
	})
	local rise = 0.9 + math.random() * 0.3
	tween(
		rocket,
		rise,
		{ CFrame = CFrame.new(origin + Vector3.new(math.random(-6, 6), height, math.random(-6, 6))) },
		Enum.EasingStyle.Sine
	)
	task.delay(rise, function()
		local burstAt = rocket.Position
		rocket:Destroy()
		flashLight(burstAt, burstColor, 50, 0.6)
		if math.random() < 0.5 then
			SoundPlayer.playAt("Fireworks", burstAt, { pitchJitter = 0.1 })
		end
		for _ = 1, 18 do
			local direction = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
			if direction.Magnitude < 0.05 then
				continue
			end
			local spark = EffectParts.part({
				Size = Vector3.one * 0.7,
				CFrame = CFrame.new(burstAt),
				Color = if math.random() < 0.3 then Color3.new(1, 1, 1) else burstColor,
				Material = Enum.Material.Neon,
			})
			local target = burstAt + direction.Unit * (14 + math.random() * 8) - Vector3.new(0, 6, 0)
			tween(
				spark,
				1.4,
				{ CFrame = CFrame.new(target), Size = Vector3.one * 0.1, Transparency = 1 },
				Enum.EasingStyle.Quint
			)
			Debris:AddItem(spark, 1.5)
		end
	end)
end

local function fireworksWanted(): (boolean, Vector3?, Color3?)
	local winner = GameState.get(GameState.Key.Winner)
	if GameState.phase() == GameState.Phase.Results and typeof(winner) == "string" and TeamInfo.get(winner) then
		return true, towerCenter(winner) or GameState.get(GameState.Key.ZoneCenter), TeamInfo.colorOf(winner)
	end
	if GameState.get(GameState.Key.Fireworks) then
		local center = GameState.get(GameState.Key.ZoneCenter)
		-- Show them wherever the local player is: arena or lobby.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and not player:GetAttribute("InMatch") then
			center = root.Position + Vector3.new(0, -5, -30)
		end
		return true, if typeof(center) == "Vector3" then center else Vector3.zero, nil
	end
	return false, nil, nil
end

----------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------

function VfxController.start()
	Remotes.get("ExplosionFx").OnClientEvent:Connect(VfxController.explosion)
	Remotes.get("StructureFx").OnClientEvent:Connect(VfxController.structureCollapse)
	Remotes.get("DamageNumber").OnClientEvent:Connect(VfxController.damageNumber)

	for _, bomb in CollectionService:GetTagged("LiveBomb") do
		trackBomb(bomb)
	end
	CollectionService:GetInstanceAddedSignal("LiveBomb"):Connect(trackBomb)
	for _, pickup in CollectionService:GetTagged("PowerUp") do
		trackPowerUp(pickup)
	end
	CollectionService:GetInstanceAddedSignal("PowerUp"):Connect(trackPowerUp)

	RunService.Heartbeat:Connect(function()
		updateBombs()
		updatePowerUps()
	end)

	task.spawn(function()
		while true do
			local wanted, center, color = fireworksWanted()
			if wanted and center then
				local spread = Vector3.new(math.random(-30, 30), 0, math.random(-30, 30))
				VfxController.firework(center + spread, color)
				task.wait(0.35 + math.random() * 0.4)
			else
				task.wait(0.5)
			end
		end
	end)
end

return VfxController

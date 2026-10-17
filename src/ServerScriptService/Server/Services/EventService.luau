--!strict
-- Keeps matches unpredictable: timed random events (Bomb Rain, Low Gravity,
-- ...) and power-up pickups that pop up on the pads around the centre plateau.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ZoneMath = require(ReplicatedStorage.Shared.ZoneMath)
local BombService = require(script.Parent.BombService)
local PlayerService = require(script.Parent.PlayerService)
local Rules = require(script.Parent.Rules)

type EventDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Duration: number,
	Start: () -> (),
	Stop: (() -> ())?,
}

type PowerUpDefinition = {
	Id: string,
	Label: string,
	Color: Color3,
	Message: string,
	Apply: (player: Player, character: Model) -> (),
}

local EventService = {}

local POWER_UP_TAG = "PowerUp"
local BOMB_RAIN_HEIGHT = 140
local BOMB_RAIN_INTERVAL = 0.45

local running = false
local runToken = 0
local activeEvent: EventDefinition? = nil
local activeEventToken = 0
local lastEventId: string? = nil

local pads: { BasePart } = {}
local occupiedPads: { [BasePart]: Instance } = {}
local pickupsFolder: Folder

----------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------

-- A random point on the arena floor inside the current safe zone.
local function randomArenaPoint(random: Random): Vector3
	local center = GameState.get(GameState.Key.ZoneCenter) or Vector3.zero
	local radius = 140
	local elapsed = GameState.battleElapsed()
	if elapsed then
		local sample = ZoneMath.sample(elapsed + (GameState.get(GameState.Key.ZoneTimeOffset) or 0))
		if sample.active then
			radius = math.min(radius, sample.radius)
		end
	end
	local angle = random:NextNumber(0, math.pi * 2)
	local distance = radius * math.sqrt(random:NextNumber())
	return center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local bombRainToken = 0

local function startBombRain()
	bombRainToken += 1
	local token = bombRainToken
	local random = Random.new()
	task.spawn(function()
		while bombRainToken == token do
			local landing = randomArenaPoint(random)
			BombService.spawnBomb({
				position = landing + Vector3.new(0, BOMB_RAIN_HEIGHT, 0),
				velocity = Vector3.new(random:NextNumber(-6, 6), -30, random:NextNumber(-6, 6)),
				owner = nil,
				kind = "Rain",
				fuse = 3.4,
			})
			task.wait(BOMB_RAIN_INTERVAL)
		end
	end)
end

local function stopBombRain()
	bombRainToken += 1
end

local function overlayEvent(id: string, modifiers: { [string]: number }): (() -> (), () -> ())
	return function()
		Rules.pushOverlay("event:" .. id, modifiers)
	end, function()
		Rules.popOverlay("event:" .. id)
	end
end

local spawnPowerUp: () -> boolean

local function spawnSupplyDrop()
	for _ = 1, 3 do
		spawnPowerUp()
	end
end

local lowGravityStart, lowGravityStop = overlayEvent("LowGravity", { Gravity = 75 })
local speedStart, speedStop = overlayEvent("SpeedRush", { WalkSpeedMultiplier = 1.5 })
local megaStart, megaStop = overlayEvent("MegaMadness", { BlastRadiusMultiplier = 1.5 })

EventService.Events = {
	{
		Id = "BombRain",
		Name = "Bomb Rain",
		Description = "Take cover! Bombs are falling from the sky!",
		Duration = 10,
		Start = startBombRain,
		Stop = stopBombRain,
	},
	{
		Id = "LowGravity",
		Name = "Low Gravity",
		Description = "Moon jumps for everyone!",
		Duration = 20,
		Start = lowGravityStart,
		Stop = lowGravityStop,
	},
	{
		Id = "SpeedRush",
		Name = "Speed Rush",
		Description = "Everyone runs 50% faster!",
		Duration = 15,
		Start = speedStart,
		Stop = speedStop,
	},
	{
		Id = "MegaMadness",
		Name = "Mega Madness",
		Description = "Every blast is 50% bigger!",
		Duration = 20,
		Start = megaStart,
		Stop = megaStop,
	},
	{
		Id = "SupplyDrop",
		Name = "Supply Drop",
		Description = "Fresh power-ups just landed!",
		Duration = 0,
		Start = spawnSupplyDrop,
	},
} :: { EventDefinition }

local function findEvent(id: string): EventDefinition?
	for _, event in EventService.Events do
		if event.Id == id then
			return event
		end
	end
	return nil
end

function EventService.stopActive()
	local event = activeEvent
	if not event then
		return
	end
	activeEvent = nil
	activeEventToken += 1
	if event.Stop then
		event.Stop()
	end
	GameState.set(GameState.Key.Event, "")
	GameState.set(GameState.Key.EventEndsAt, 0)
end

function EventService.trigger(id: string): boolean
	local event = findEvent(id)
	if not event or GameState.phase() ~= GameState.Phase.Battle then
		return false
	end
	EventService.stopActive()
	lastEventId = id

	Remotes.get("Announce"):FireAllClients("Event", {
		id = event.Id,
		name = event.Name,
		description = event.Description,
		duration = event.Duration,
	})
	event.Start()

	if event.Duration > 0 then
		activeEvent = event
		activeEventToken += 1
		local token = activeEventToken
		GameState.set(GameState.Key.Event, event.Name)
		GameState.set(GameState.Key.EventEndsAt, GameState.now() + event.Duration)
		task.delay(event.Duration, function()
			if activeEventToken == token then
				EventService.stopActive()
			end
		end)
	end
	return true
end

function EventService.triggerRandom(): boolean
	local choices = {}
	for _, event in EventService.Events do
		if event.Id ~= lastEventId then
			table.insert(choices, event.Id)
		end
	end
	return EventService.trigger(choices[math.random(1, #choices)])
end

----------------------------------------------------------------------------
-- Power-ups
----------------------------------------------------------------------------

local function grantShield(character: Model, duration: number)
	local existing = character:FindFirstChild("PowerUpShield")
	if existing then
		existing:Destroy()
	end
	local shield = Instance.new("ForceField")
	shield.Name = "PowerUpShield"
	shield.Parent = character
	task.delay(duration, function()
		if shield.Parent then
			shield:Destroy()
		end
	end)
end

local function setPowerUpChip(player: Player, label: string, duration: number)
	player:SetAttribute("PowerUp", label)
	player:SetAttribute("PowerUpEndsAt", GameState.now() + duration)
end

EventService.PowerUps = {
	{
		Id = "MegaBomb",
		Label = "MEGA BOMB",
		Color = Color3.fromRGB(239, 68, 68),
		Message = "Mega Bomb ready - your next throw is huge!",
		Apply = function(player)
			BombService.grantMega(player)
		end,
	},
	{
		Id = "TripleBomb",
		Label = "TRIPLE BOMB",
		Color = Color3.fromRGB(251, 146, 60),
		Message = "Triple Bomb - three throws, no reload!",
		Apply = function(player)
			BombService.grantCharges(player, Config.PowerUps.TripleBomb.Charges)
		end,
	},
	{
		Id = "Speed",
		Label = "SPEED",
		Color = Color3.fromRGB(56, 189, 248),
		Message = "Speed boost!",
		Apply = function(player)
			local duration = Config.PowerUps.SpeedBoost.Duration
			player:SetAttribute("SpeedBoostEndsAt", GameState.now() + duration)
			setPowerUpChip(player, "SPEED", duration)
			PlayerService.applyMovement(player)
			task.delay(duration + 0.05, function()
				if player.Parent then
					PlayerService.applyMovement(player)
				end
			end)
		end,
	},
	{
		Id = "Shield",
		Label = "SHIELD",
		Color = Color3.fromRGB(250, 204, 21),
		Message = "Shield up - you're invincible for a few seconds!",
		Apply = function(player, character)
			local duration = Config.PowerUps.Shield.Duration
			grantShield(character, duration)
			setPowerUpChip(player, "SHIELD", duration)
		end,
	},
	{
		Id = "Heal",
		Label = "+50 HEALTH",
		Color = Color3.fromRGB(74, 222, 128),
		Message = "Patched up! +50 health",
		Apply = function(_player, character)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.PowerUps.Heal.Amount)
			end
		end,
	},
} :: { PowerUpDefinition }

local function buildPickup(definition: PowerUpDefinition, position: Vector3): Part
	local pickup = Instance.new("Part")
	pickup.Name = "PowerUp_" .. definition.Id
	pickup.Size = Vector3.new(2.4, 2.4, 2.4)
	pickup.Color = definition.Color
	pickup.Material = Enum.Material.Neon
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.CanQuery = false
	pickup.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(45), math.rad(45), 0)

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.3, 1.3, 1.3)
	core.Color = Color3.new(1, 1, 1)
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CFrame = pickup.CFrame
	core.Parent = pickup

	local light = Instance.new("PointLight")
	light.Color = definition.Color
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = pickup

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = pickup
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = definition.Label
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = definition.Color
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	pickup:SetAttribute("Label", definition.Label)
	CollectionService:AddTag(pickup, POWER_UP_TAG)
	return pickup
end

function spawnPowerUp(): boolean
	local free = {}
	for _, pad in pads do
		if not occupiedPads[pad] then
			table.insert(free, pad)
		end
	end
	if #free == 0 then
		return false
	end
	local pad = free[math.random(1, #free)]
	local definition = EventService.PowerUps[math.random(1, #EventService.PowerUps)]
	local pickup = buildPickup(definition, pad.Position + Vector3.new(0, 3.2, 0))
	occupiedPads[pad] = pickup

	local claimed = false
	pickup.Touched:Connect(function(hit)
		if claimed then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			not player
			or not character
			or not humanoid
			or humanoid.Health <= 0
			or not player:GetAttribute("InMatch")
		then
			return
		end
		claimed = true
		definition.Apply(player, character)
		Remotes.get("Toast"):FireClient(player, definition.Message, "powerup")
		pickup:Destroy()
	end)
	pickup.Destroying:Connect(function()
		if occupiedPads[pad] == pickup then
			occupiedPads[pad] = nil
		end
	end)

	pickup.Parent = pickupsFolder
	task.delay(Config.PowerUps.Lifetime, function()
		if pickup.Parent then
			pickup:Destroy()
		end
	end)
	return true
end

EventService.spawnPowerUp = spawnPowerUp

local function activePickupCount(): number
	local count = 0
	for _ in occupiedPads do
		count += 1
	end
	return count
end

----------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------

function EventService.init()
	pickupsFolder = Instance.new("Folder")
	pickupsFolder.Name = "PowerUps"
	pickupsFolder.Parent = workspace

	local arena = workspace:FindFirstChild("Arena")
	local padFolder = arena and arena:FindFirstChild("PowerUpPads")
	if padFolder then
		for _, pad in padFolder:GetChildren() do
			if pad:IsA("BasePart") then
				table.insert(pads, pad)
			end
		end
	end
	if #pads == 0 then
		warn("[EventService] No Workspace.Arena.PowerUpPads found - power-ups disabled.")
	end
end

function EventService.begin()
	running = true
	runToken += 1
	local token = runToken
	lastEventId = nil

	task.spawn(function()
		local random = Random.new()
		local nextEventAt = Config.Events.FirstEventAt
		local nextPowerUpAt = Config.PowerUps.FirstSpawnAt
		while running and runToken == token do
			local elapsed = GameState.battleElapsed()
			if elapsed then
				local timeLeft = GameState.phaseTimeLeft()
				if elapsed >= nextEventAt and not activeEvent and timeLeft > Config.Events.QuietFinalSeconds then
					EventService.triggerRandom()
					local jitter = Config.Events.IntervalJitter
					nextEventAt = elapsed + Rules.get("EventInterval") + random:NextNumber(-jitter, jitter)
				end
				if elapsed >= nextPowerUpAt then
					if activePickupCount() < Config.PowerUps.MaxActive then
						spawnPowerUp()
					end
					nextPowerUpAt = elapsed + Config.PowerUps.SpawnInterval
				end
			end
			task.wait(0.5)
		end
	end)
end

function EventService.stop()
	running = false
	runToken += 1
	EventService.stopActive()
	pickupsFolder:ClearAllChildren()
	table.clear(occupiedPads)
end

return EventService

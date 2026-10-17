--!strict
-- The in-match HUD. Deliberately minimal: a timer flanked by the two tower
-- health bars, a crosshair (with a charge meter while winding up a throw),
-- bomb status, health and score. Everything else is an occasional overlay
-- (event chip, storm warning, damage flash) that only appears when relevant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundPlayer = require(ReplicatedStorage.Shared.SoundPlayer)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local UIKit = require(ReplicatedStorage.Shared.UIKit)
local CameraController = require(script.Parent.CameraController)
local WeaponController = require(script.Parent.WeaponController)
local ZoneController = require(script.Parent.ZoneController)

local HudController = {}

local Theme = UIKit.Theme
local player = Players.LocalPlayer

type TowerPanel = {
	frame: Frame,
	update: (health: number, alive: number, total: number) -> (),
}

type Vignette = {
	frame: Frame,
	setStrength: (strength: number, duration: number?) -> (),
}

local screen: ScreenGui
local root: Frame
local timerLabel: TextLabel
local statusLabel: TextLabel
local eventChip: Frame
local crosshair: Frame
local chargeBar: UIKit.Bar
local weaponLabel: TextLabel
local weaponHint: TextLabel
local reloadBar: UIKit.Bar
local weaponPanel: Frame
local powerUpChip: Frame
local healthBar: UIKit.Bar
local healthLabel: TextLabel
local healthPanel: Frame
local scoreLabel: TextLabel
local stormWarning: TextLabel
local damageVignette: Vignette
local stormVignette: Vignette
local towerPanels: { [string]: TowerPanel } = {}

local reloadTotal = Config.Bomb.ReloadTime
local lastTickSecond = -1
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

----------------------------------------------------------------------------
-- Builders
----------------------------------------------------------------------------

-- One function builds both tower panels; `mirrored` flips the layout so the
-- two bars drain toward the timer in the middle.
local function createTowerPanel(info: TeamInfo.TeamInfo, mirrored: boolean, layoutOrder: number): TowerPanel
	local panel = UIKit.panel({
		Name = info.Name .. "Tower",
		Size = UDim2.fromOffset(270, 70),
		StrokeColor = info.Color,
		StrokeTransparency = 0.1,
		LayoutOrder = layoutOrder,
	})
	local alignment = if mirrored then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left

	UIKit.label({
		Name = "TeamName",
		Text = string.upper(info.DisplayName),
		TextSize = 20,
		TextColor3 = info.LightColor,
		TextXAlignment = alignment,
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 6),
		Parent = panel,
	})
	local bar = UIKit.bar({
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 32),
		Color = info.Color,
		FromRight = mirrored,
		Parent = panel,
	})
	local info2 = UIKit.label({
		Name = "Info",
		Text = "TOWER 100%",
		TextSize = 14,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = alignment,
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 50),
		Parent = panel,
	})

	local lastHealth = 1
	local function update(health: number, alive: number, total: number)
		if math.abs(health - lastHealth) > 0.001 then
			if health < lastHealth then
				UIKit.pop(panel, 0.06)
			end
			lastHealth = health
			bar.set(health)
			bar.setColor(if health <= Config.Match.ShowdownTowerHealth then Theme.Danger else info.Color)
		end
		local status = if health <= 0 then "TOWER DESTROYED" else "TOWER " .. Format.percent(health)
		info2.Text = string.format("%s   ·   %d/%d ALIVE", status, alive, total)
	end
	bar.set(1, true)
	return { frame = panel, update = update }
end

-- Four edge gradients that fade toward the middle of the screen.
local function createVignette(color: Color3, parent: Instance): Vignette
	local container = UIKit.new("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = parent,
	})
	local edges = {
		{ size = UDim2.fromScale(1, 0.25), position = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, 0.25), position = UDim2.fromScale(0, 0.75), rotation = -90 },
		{ size = UDim2.fromScale(0.2, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(0.2, 1), position = UDim2.fromScale(0.8, 0), rotation = 180 },
	}
	local frames: { Frame } = {}
	for _, edge in edges do
		local frame = UIKit.new("Frame", {
			Size = edge.size,
			Position = edge.position,
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = container,
		})
		UIKit.new("UIGradient", {
			Rotation = edge.rotation,
			Transparency = NumberSequence.new(0, 1),
			Parent = frame,
		})
		table.insert(frames, frame)
	end
	local function setStrength(strength: number, duration: number?)
		for _, frame in frames do
			UIKit.tween(frame, duration or 0.2, { BackgroundTransparency = 1 - math.clamp(strength, 0, 1) })
		end
	end
	return { frame = container, setStrength = setStrength }
end

local function build()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	screen = UIKit.screen("Hud", 5)
	root = UIKit.new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})

	damageVignette = createVignette(Color3.fromRGB(220, 38, 38), root)
	stormVignette = createVignette(Theme.Storm, root)

	local inset = UIKit.topInset()

	-- Top bar: [Blue] [Timer] [Red]
	local topBar = UIKit.new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, inset + 6),
		Size = UDim2.fromOffset(800, 74),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = topBar

	local teams = TeamInfo.all()
	for index, info in teams do
		local panel = createTowerPanel(info, index > 1, if index == 1 then 1 else 3)
		panel.frame.Parent = topBar
		towerPanels[info.Name] = panel
	end

	local timerPanel = UIKit.panel({
		Name = "Timer",
		Size = UDim2.fromOffset(170, 70),
		StrokeColor = Theme.Accent,
		StrokeTransparency = 0.2,
		LayoutOrder = 2,
		Parent = topBar,
	})
	timerLabel = UIKit.label({
		Name = "Time",
		Text = "5:00",
		TextSize = 36,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 4),
		Parent = timerPanel,
	})
	statusLabel = UIKit.label({
		Name = "Status",
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, -10, 0, 18),
		Position = UDim2.fromOffset(5, 46),
		Parent = timerPanel,
	})

	eventChip = UIKit.pill({
		Name = "EventChip",
		Size = UDim2.fromOffset(300, 32),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, inset + 88),
		StrokeColor = Theme.Accent,
		Visible = false,
	})
	eventChip.Parent = root

	stormWarning = UIKit.label({
		Name = "StormWarning",
		Text = "OUTSIDE THE SAFE ZONE - GET TO THE CENTRE!",
		TextSize = 22,
		TextColor3 = Color3.fromRGB(233, 213, 255),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, inset + 128),
		Size = UDim2.fromOffset(700, 30),
		Visible = false,
		Parent = root,
	})

	-- Crosshair: a dot and four ticks, plus the throw charge meter.
	crosshair = UIKit.new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local dot = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(5, 5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = crosshair,
	})
	UIKit.corner(UDim.new(1, 0)).Parent = dot
	UIKit.stroke(Theme.Ink, 1, 0.3).Parent = dot
	for _, tick in
		{
			{ UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(2, 7) },
			{ UDim2.new(0.5, 0, 1, -7), UDim2.fromOffset(2, 7) },
			{ UDim2.new(0, 0, 0.5, 0), UDim2.fromOffset(7, 2) },
			{ UDim2.new(1, -7, 0.5, 0), UDim2.fromOffset(7, 2) },
		}
	do
		local bar = UIKit.new("Frame", {
			Position = tick[1],
			Size = tick[2],
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Parent = crosshair,
		})
		UIKit.stroke(Theme.Ink, 1, 0.4).Parent = bar
	end
	chargeBar = UIKit.bar({
		Name = "Charge",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 26),
		Size = UDim2.fromOffset(110, 10),
		Color = Theme.Accent,
		Parent = root,
	})
	chargeBar.Frame.Visible = false

	-- Bottom centre: bomb / weapon status.
	weaponPanel = UIKit.panel({
		Name = "Weapon",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(320, 58),
		StrokeColor = Theme.Accent,
		StrokeTransparency = 0.3,
		Parent = root,
	})
	weaponLabel = UIKit.label({
		Name = "Status",
		Text = "BOMB READY",
		TextSize = 22,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 4),
		Parent = weaponPanel,
	})
	weaponHint = UIKit.label({
		Name = "Hint",
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.TextMuted,
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.fromOffset(10, 32),
		Parent = weaponPanel,
	})
	reloadBar = UIKit.bar({
		Name = "Reload",
		Size = UDim2.new(1, -40, 0, 6),
		Position = UDim2.fromOffset(20, 50),
		Color = Theme.Teal,
		Parent = weaponPanel,
	})
	reloadBar.Frame.Visible = false

	powerUpChip = UIKit.pill({
		Name = "PowerUp",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -126),
		Size = UDim2.fromOffset(220, 30),
		StrokeColor = Theme.Accent,
		Visible = false,
	})
	powerUpChip.Parent = root

	-- Health sits centred above the weapon panel, clear of the mobile
	-- thumbstick (bottom left) and jump button (bottom right).
	healthPanel = UIKit.panel({
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -88),
		Size = UDim2.fromOffset(320, 30),
		Parent = root,
	})
	healthLabel = UIKit.label({
		Text = "100",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(50, 30),
		Position = UDim2.fromOffset(12, 0),
		Parent = healthPanel,
	})
	healthBar = UIKit.bar({
		Size = UDim2.new(1, -70, 0, 12),
		Position = UDim2.fromOffset(58, 9),
		Color = Theme.Success,
		Parent = healthPanel,
	})

	-- Top right: your score.
	local scorePanel = UIKit.panel({
		Name = "Score",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, inset + 8),
		Size = UDim2.fromOffset(210, 40),
		StrokeColor = Theme.Accent,
		StrokeTransparency = 0.4,
		Parent = root,
	})
	scoreLabel = UIKit.label({
		Text = "SCORE 0   ·   KO 0",
		TextSize = 17,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Parent = scorePanel,
	})
end

----------------------------------------------------------------------------
-- Updates
----------------------------------------------------------------------------

local function aliveHumanoid(): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function statusText(): (string, Color3)
	local phase = GameState.phase()
	if phase == GameState.Phase.GetReady then
		return "GET READY", Theme.Accent
	end
	if GameState.get(GameState.Key.Showdown) then
		return "FINAL SHOWDOWN", Theme.Danger
	end
	local sample = ZoneController.sample()
	local elapsed = GameState.battleElapsed() or 0
	if not sample or not sample.active then
		return "STORM IN " .. Format.clock(Config.Zone.StartDelay - elapsed), Theme.Teal
	end
	if sample.shrinking then
		return "STORM CLOSING IN!", Theme.Storm
	end
	if sample.nextChangeIn then
		return "STORM SHRINKS IN " .. Format.clock(sample.nextChangeIn), Color3.fromRGB(216, 180, 254)
	end
	return "STORM AT FULL STRENGTH", Theme.Storm
end

local function updateTimer()
	local phase = GameState.phase()
	local timeLeft = if phase == GameState.Phase.GetReady
		then Config.Match.BattleDuration
		else GameState.phaseTimeLeft()
	timerLabel.Text = Format.clock(timeLeft)

	local finalStretch = phase == GameState.Phase.Battle and timeLeft <= Config.Match.FinalCountdown and timeLeft > 0
	timerLabel.TextColor3 = if finalStretch then Theme.Danger else Theme.Text
	if finalStretch then
		local second = math.ceil(timeLeft)
		if second ~= lastTickSecond then
			lastTickSecond = second
			UIKit.pop(timerLabel, 0.12)
			SoundPlayer.play("Countdown", {
				volume = if second <= 5 then 0.6 else 0.3,
				pitch = if second <= 5 then 1.35 else 0.9,
			})
		end
	end

	local text, color = statusText()
	statusLabel.Text = text
	statusLabel.TextColor3 = color
end

local function updateTowers()
	for name, panel in towerPanels do
		local health = GameState.getTeam(GameState.TeamKey.TowerHealth, name)
		local alive = GameState.getTeam(GameState.TeamKey.Alive, name)
		local total = GameState.getTeam(GameState.TeamKey.Players, name)
		panel.update(
			if typeof(health) == "number" then health else 1,
			if typeof(alive) == "number" then alive else 0,
			if typeof(total) == "number" then total else 0
		)
	end
end

local function updateEventChip()
	local eventName = GameState.get(GameState.Key.Event)
	local endsAt = GameState.get(GameState.Key.EventEndsAt)
	local active = typeof(eventName) == "string" and eventName ~= "" and typeof(endsAt) == "number"
	eventChip.Visible = active
	if active then
		local label = eventChip:FindFirstChild("Text") :: TextLabel
		label.Text = string.format("%s   %s", string.upper(eventName), Format.clock(endsAt - GameState.now()))
	end
end

local function updateWeapon()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local charges = player:GetAttribute("BombCharges")
	charges = if typeof(charges) == "number" then charges else 0
	local mega = player:GetAttribute("MegaBomb") == true
	local reloadEndsAt = player:GetAttribute("BombReloadEndsAt")
	local reloading = typeof(reloadEndsAt) == "number" and reloadEndsAt > GameState.now()

	local holdVerb = if isTouch then "Hold" else "Hold click"
	if tool and tool.Name == "Sword" then
		weaponLabel.Text = "SWORD"
		weaponHint.Text = if isTouch
			then "Tap to slash · double-tap to lunge"
			else "Click to slash · double-click to lunge"
		weaponLabel.TextColor3 = Theme.Text
	elseif tool and tool.Name == "RocketLauncher" then
		weaponLabel.Text = "ROCKET LAUNCHER"
		weaponHint.Text = if isTouch then "Tap where you want it to land" else "Click to fire"
		weaponLabel.TextColor3 = Theme.Accent
	elseif reloading then
		weaponLabel.Text = "NEW BOMB IN " .. string.format("%.1fs", reloadEndsAt - GameState.now())
		weaponLabel.TextColor3 = Theme.TextMuted
		weaponHint.Text = "Switch to your sword while you wait"
	else
		local name = if mega then "MEGA BOMB READY" else "BOMB READY"
		weaponLabel.Text = if charges > 1 then string.format("%s  x%d", name, charges) else name
		weaponLabel.TextColor3 = if mega then Theme.Danger else Theme.Accent
		weaponHint.Text = if tool and tool.Name == "Bomb"
			then holdVerb .. " to charge · release to throw"
			else "Equip your bomb (1) to throw"
	end

	reloadBar.Frame.Visible = reloading and not (tool and tool.Name ~= "Bomb")
	if reloading then
		reloadBar.set(1 - (reloadEndsAt - GameState.now()) / math.max(0.1, reloadTotal), true)
	end

	local powerUp = player:GetAttribute("PowerUp")
	local powerUpEndsAt = player:GetAttribute("PowerUpEndsAt")
	local hasPowerUp = typeof(powerUp) == "string"
		and powerUp ~= ""
		and typeof(powerUpEndsAt) == "number"
		and powerUpEndsAt > GameState.now()
	powerUpChip.Visible = hasPowerUp
	if hasPowerUp then
		local label = powerUpChip:FindFirstChild("Text") :: TextLabel
		label.Text = string.format("%s   %s", powerUp, Format.clock(powerUpEndsAt - GameState.now()))
	end
end

local function updateScore()
	local score = player:GetAttribute("MatchScore")
	local leaderstats = player:FindFirstChild("leaderstats")
	local kos = leaderstats and leaderstats:FindFirstChild("KOs")
	scoreLabel.Text = string.format(
		"SCORE %s   ·   KO %d",
		Format.thousands(if typeof(score) == "number" then score else 0),
		if kos and kos:IsA("IntValue") then kos.Value else 0
	)
end

local function updateHealth()
	local humanoid = aliveHumanoid()
	local health = if humanoid then humanoid.Health / humanoid.MaxHealth else 0
	healthBar.set(health)
	healthBar.setColor(Theme.Danger:Lerp(Theme.Success, math.clamp(health * 1.4 - 0.2, 0, 1)))
	healthLabel.Text = tostring(if humanoid then math.ceil(humanoid.Health) else 0)
end

local function updateVisibility()
	local inMatchPhase = GameState.isInMatchPhase()
	local playing = player:GetAttribute("InMatch") == true and aliveHumanoid() ~= nil
	local watching = player:GetAttribute("Spectating") == true or player:GetAttribute("InMatch") == true
	root.Visible = inMatchPhase and watching

	crosshair.Visible = playing and CameraController.isLocked()
	weaponPanel.Visible = playing
	healthPanel.Visible = playing
	if not playing then
		powerUpChip.Visible = false
		chargeBar.Frame.Visible = false
	end

	local outside = playing and ZoneController.isOutside()
	stormWarning.Visible = outside
	if outside then
		stormWarning.TextTransparency = 0.25 + math.sin(os.clock() * 6) * 0.25
	end
end

----------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------

function HudController.init()
	build()
end

function HudController.start()
	local accumulator = 0
	local wasOutside = false
	RunService.RenderStepped:Connect(function(deltaTime)
		updateVisibility()
		if not root.Visible then
			return
		end

		-- Charge meter every frame so it feels responsive.
		local charge = WeaponController.getCharge()
		chargeBar.Frame.Visible = charge ~= nil and crosshair.Visible
		if charge then
			chargeBar.set(charge, true)
			chargeBar.setColor(Theme.Accent:Lerp(Theme.Danger, charge))
		end

		local outside = ZoneController.isOutside()
		if outside ~= wasOutside then
			wasOutside = outside
			stormVignette.setStrength(if outside then 0.55 else 0, 0.5)
		end

		-- Text only needs ~10 updates a second.
		accumulator += deltaTime
		if accumulator >= 0.1 then
			accumulator = 0
			updateTimer()
			updateTowers()
			updateEventChip()
			updateWeapon()
			updateScore()
			updateHealth()
		end
	end)

	player:GetAttributeChangedSignal("BombReloadEndsAt"):Connect(function()
		local endsAt = player:GetAttribute("BombReloadEndsAt")
		if typeof(endsAt) == "number" and endsAt > GameState.now() then
			reloadTotal = endsAt - GameState.now()
		end
	end)

	Remotes.get("DamageFx").OnClientEvent:Connect(function(amount: number, sourcePosition: Vector3?)
		damageVignette.setStrength(math.clamp(amount / 60, 0.25, 0.8), 0.05)
		task.delay(0.12, function()
			damageVignette.setStrength(0, 0.5)
		end)
		if sourcePosition == nil and ZoneController.isOutside() then
			SoundPlayer.play("ZoneZap", { pitchJitter = 0.1 })
		else
			SoundPlayer.play("Hit", { pitchJitter = 0.1, volume = 0.35 })
		end
	end)

	GameState.changed(GameState.Key.Phase):Connect(function()
		lastTickSecond = -1
	end)
end

return HudController

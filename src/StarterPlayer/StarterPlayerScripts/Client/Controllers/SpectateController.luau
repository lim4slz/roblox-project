--!strict
-- Spectator mode for anyone without a character mid-match: knocked out in
-- the Final Showdown, joined too late, sitting a round out, or simply waiting
-- out a respawn timer. Follow any living player in third person, or switch to
-- a free-flying camera (keyboard and mouse).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameState = require(ReplicatedStorage.Shared.GameState)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local UIKit = require(ReplicatedStorage.Shared.UIKit)

local SpectateController = {}

local Theme = UIKit.Theme
local player = Players.LocalPlayer

local FREE_CAM_SPEED = 55
local FREE_CAM_FAST = 2.5
local ORBIT_RADIUS = 170
local ORBIT_HEIGHT = 90

local active = false
local freeCam = false
local targetIndex = 1
local targetPlayer: Player? = nil
local freeCamCFrame = CFrame.new(0, 80, 160)
local freeYaw, freePitch = 0, -0.35

local bar: Frame
local nameLabel: TextLabel
local respawnLabel: TextLabel
local freeCamButton: TextButton

local function aliveCharacter(target: Player): Model?
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return character
	end
	return nil
end

local function ownCharacterAlive(): boolean
	return aliveCharacter(player) ~= nil
end

-- Living match players we can follow. Team-mates first if we're on a team.
local function candidates(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("InMatch") and aliveCharacter(other) then
			table.insert(list, other)
		end
	end
	local myTeam = player.Team
	table.sort(list, function(a, b)
		local aMine = myTeam ~= nil and a.Team == myTeam
		local bMine = myTeam ~= nil and b.Team == myTeam
		if aMine ~= bMine then
			return aMine
		end
		return a.UserId < b.UserId
	end)
	return list
end

local function shouldSpectate(): boolean
	local phase = GameState.phase()
	if phase ~= GameState.Phase.GetReady and phase ~= GameState.Phase.Battle and phase ~= GameState.Phase.Results then
		return false
	end
	if player:GetAttribute("Spectating") then
		return true
	end
	return player:GetAttribute("InMatch") == true and not ownCharacterAlive()
end

local function cycle(step: number)
	local list = candidates()
	if #list == 0 then
		targetPlayer = nil
		return
	end
	targetIndex = ((targetIndex - 1 + step) % #list) + 1
	targetPlayer = list[targetIndex]
	freeCam = false
end

local function setFreeCam(enabled: boolean)
	freeCam = enabled
	local camera = workspace.CurrentCamera
	if enabled then
		freeCamCFrame = camera.CFrame
		local _, yaw, _ = camera.CFrame:ToOrientation()
		freeYaw = yaw
		freePitch = -0.3
	end
	freeCamButton.Text = if enabled then "FOLLOW PLAYERS" else "FREE CAM [F]"
end

local function setActive(value: boolean)
	if value == active then
		return
	end
	active = value
	bar.Visible = value
	local camera = workspace.CurrentCamera
	if value then
		targetPlayer = nil
		cycle(0)
	else
		freeCam = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function updateFreeCam(deltaTime: number)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	-- Hold right mouse to look around.
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		local delta = UserInputService:GetMouseDelta()
		freeYaw -= delta.X * 0.004
		freePitch = math.clamp(freePitch - delta.Y * 0.004, -1.4, 1.4)
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	local move = Vector3.zero
	local keys: { [Enum.KeyCode]: Vector3 } = {
		[Enum.KeyCode.W] = Vector3.new(0, 0, -1),
		[Enum.KeyCode.S] = Vector3.new(0, 0, 1),
		[Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
		[Enum.KeyCode.D] = Vector3.new(1, 0, 0),
		[Enum.KeyCode.E] = Vector3.new(0, 1, 0),
		[Enum.KeyCode.Q] = Vector3.new(0, -1, 0),
	}
	for key, direction in keys do
		if UserInputService:IsKeyDown(key) then
			move += direction
		end
	end
	local speed = FREE_CAM_SPEED * (if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then FREE_CAM_FAST else 1)
	local rotation = CFrame.fromOrientation(freePitch, freeYaw, 0)
	local position = freeCamCFrame.Position
	if move.Magnitude > 0 then
		position += rotation:VectorToWorldSpace(move.Unit) * speed * deltaTime
	end
	freeCamCFrame = CFrame.new(position) * rotation
	camera.CFrame = freeCamCFrame
end

-- Slow orbit over the arena when there's nobody left to watch.
local function updateOrbit()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local centerValue = GameState.get(GameState.Key.ZoneCenter)
	local center = if typeof(centerValue) == "Vector3" then centerValue else Vector3.zero
	local angle = os.clock() * 0.08
	local eye = center + Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
	camera.CFrame = CFrame.lookAt(eye, center + Vector3.new(0, 15, 0))
end

local function update(deltaTime: number)
	setActive(shouldSpectate())
	if not active then
		return
	end

	local respawnAt = player:GetAttribute("RespawnAt")
	local waiting = typeof(respawnAt) == "number" and respawnAt > GameState.now()
	respawnLabel.Visible = waiting
	if waiting then
		respawnLabel.Text = string.format("RESPAWNING IN %d", math.ceil(respawnAt - GameState.now()))
	end

	if freeCam then
		nameLabel.Text = "FREE CAM  ·  WASD + Q/E  ·  hold right mouse to look"
		nameLabel.TextColor3 = Theme.Text
		updateFreeCam(deltaTime)
		return
	end

	if not targetPlayer or not aliveCharacter(targetPlayer) then
		cycle(0)
	end
	local target = targetPlayer
	local character = target and aliveCharacter(target)
	if not target or not character then
		nameLabel.Text = "Watching the arena"
		nameLabel.TextColor3 = Theme.TextMuted
		updateOrbit()
		return
	end

	local camera = workspace.CurrentCamera
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if camera.CameraType ~= Enum.CameraType.Custom then
		camera.CameraType = Enum.CameraType.Custom
	end
	if humanoid and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
	local info = TeamInfo.ofPlayer(target)
	nameLabel.Text = "SPECTATING  " .. target.DisplayName
	nameLabel.TextColor3 = if info then info.LightColor else Theme.Text
end

function SpectateController.init()
	local screen = UIKit.screen("Spectate", 15)
	bar = UIKit.panel({
		Name = "SpectateBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(640, 64),
		StrokeColor = Theme.Teal,
		StrokeTransparency = 0.2,
		Visible = false,
		Parent = screen,
	})
	UIKit.button({
		Text = "<",
		Size = UDim2.fromOffset(48, 44),
		Position = UDim2.fromOffset(10, 10),
		Color = Theme.Teal,
	}, function()
		cycle(-1)
	end).Parent =
		bar
	nameLabel = UIKit.label({
		Text = "",
		TextSize = 20,
		Size = UDim2.new(1, -300, 1, 0),
		Position = UDim2.fromOffset(66, 0),
		Parent = bar,
	})
	UIKit.button({
		Text = ">",
		Size = UDim2.fromOffset(48, 44),
		Position = UDim2.new(1, -234, 0, 10),
		Color = Theme.Teal,
	}, function()
		cycle(1)
	end).Parent =
		bar
	freeCamButton = UIKit.button({
		Text = "FREE CAM [F]",
		Size = UDim2.fromOffset(170, 44),
		Position = UDim2.new(1, -180, 0, 10),
		TextSize = 16,
	}, function()
		setFreeCam(not freeCam)
	end)
	freeCamButton.Parent = bar
	-- Free cam needs a keyboard; touch players just cycle between players.
	freeCamButton.Visible = UserInputService.KeyboardEnabled

	respawnLabel = UIKit.label({
		Name = "Respawn",
		Text = "",
		TextSize = 42,
		TextColor3 = Theme.Accent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(600, 60),
		StrokeThickness = 3,
		Visible = false,
		Parent = screen,
	})
end

function SpectateController.start()
	RunService:BindToRenderStep("DoomspireSpectate", Enum.RenderPriority.Camera.Value + 2, update)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not active then
			return
		end
		if input.KeyCode == Enum.KeyCode.F and UserInputService.KeyboardEnabled then
			setFreeCam(not freeCam)
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.ButtonR1 then
			cycle(1)
		elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.ButtonL1 then
			cycle(-1)
		end
	end)
end

return SpectateController

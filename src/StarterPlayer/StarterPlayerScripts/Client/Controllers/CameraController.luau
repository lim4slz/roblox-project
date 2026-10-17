--!strict
-- First-person lock during the match, free camera everywhere else, plus the
-- small camera shake that sells nearby explosions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)

local CameraController = {}

local player = Players.LocalPlayer

local ARM_PARTS = {
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"Right Arm",
	"Left Arm",
}

local shakeStrength = 0
local locked = false

local function aliveHumanoid(): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Should the camera be locked to first person right now?
function CameraController.shouldLock(): boolean
	return Config.Camera.LockFirstPersonInBattle
		and GameState.isInMatchPhase()
		and player:GetAttribute("InMatch") == true
		and not player:GetAttribute("Spectating")
		and aliveHumanoid() ~= nil
end

function CameraController.isLocked(): boolean
	return locked
end

-- Adds trauma; it decays on its own. 1 is a big, close explosion.
function CameraController.shake(amount: number)
	shakeStrength = math.clamp(shakeStrength + amount, 0, 1.5)
end

local function setLocked(shouldLock: boolean)
	if shouldLock == locked then
		return
	end
	locked = shouldLock
	if shouldLock then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 40
		-- Pop the camera back out of the head instead of staying zoomed in.
		player.CameraMinZoomDistance = 10
		task.delay(0.1, function()
			player.CameraMinZoomDistance = 0.5
		end)
	end
end

local function showArms()
	local character = player.Character
	if not character then
		return
	end
	for _, name in ARM_PARTS do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
		end
	end
end

local function update(deltaTime: number)
	setLocked(CameraController.shouldLock())

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	if locked and Config.Camera.ShowArmsInFirstPerson then
		showArms()
	end

	if shakeStrength > 0.001 then
		-- Squared trauma feels punchier at the start and settles smoothly.
		local intensity = shakeStrength * shakeStrength
		local time = os.clock() * 28
		local pitch = math.noise(time, 0.3) * intensity * 0.06
		local yaw = math.noise(time, 7.1) * intensity * 0.06
		local roll = math.noise(time, 13.7) * intensity * 0.04
		camera.CFrame *= CFrame.Angles(pitch, yaw, roll)
		shakeStrength = math.max(0, shakeStrength - deltaTime * 1.8)
	end
end

function CameraController.start()
	player.CameraMaxZoomDistance = 40
	-- Run right after Roblox's own camera so our shake and arm tweaks stick.
	RunService:BindToRenderStep("DoomspireCamera", Enum.RenderPriority.Camera.Value + 1, update)
end

return CameraController

--!strict
-- Draws the storm: a ring of shimmering force-field panels that closes in on
-- the centre, and a purple tint while you're caught outside it.
--
-- A ring of thin panels (rather than one big cylinder) is used because a
-- solid part can't be seen from the inside, and players inside the safe zone
-- are exactly the ones who need to see the wall coming.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local ZoneMath = require(ReplicatedStorage.Shared.ZoneMath)
local EffectParts = require(script.Parent.Parent.Lib.EffectParts)

local ZoneController = {}

local PANEL_COUNT = 64
local STORM_COLOR = Color3.fromRGB(168, 85, 247)

local player = Players.LocalPlayer
local panels: { Part } = {}
local wallVisible = false
local outside = false
local tint: ColorCorrectionEffect

local currentSample: ZoneMath.ZoneSample? = nil
-- Only re-layout the ring when the radius actually moves.
local laidOutRadius = -1

function ZoneController.sample(): ZoneMath.ZoneSample?
	return currentSample
end

function ZoneController.isOutside(): boolean
	return outside
end

local function buildPanels()
	local folder = Instance.new("Folder")
	folder.Name = "StormWall"
	folder.Parent = EffectParts.folder()
	for index = 1, PANEL_COUNT do
		panels[index] = EffectParts.part({
			Name = "StormPanel",
			Size = Vector3.new(4, Config.Zone.WallHeight, 0.5),
			Color = STORM_COLOR,
			Material = Enum.Material.ForceField,
			Transparency = 1,
			Parent = folder,
		})
	end
end

local function setWallVisible(visible: boolean)
	if visible == wallVisible then
		return
	end
	wallVisible = visible
	for _, panel in panels do
		panel.Transparency = if visible then 0.15 else 1
	end
end

local function layoutPanels(center: Vector3, radius: number)
	local height = Config.Zone.WallHeight
	local width = (2 * math.pi * radius / PANEL_COUNT) * 1.04
	local y = center.Y + height / 2 - 12
	for index, panel in panels do
		local angle = (index / PANEL_COUNT) * math.pi * 2
		local position = Vector3.new(center.X + math.cos(angle) * radius, y, center.Z + math.sin(angle) * radius)
		panel.Size = Vector3.new(width, height, 0.5)
		panel.CFrame = CFrame.lookAt(position, Vector3.new(center.X, y, center.Z))
	end
end

local function setOutside(value: boolean)
	if value == outside then
		return
	end
	outside = value
	TweenService:Create(tint, TweenInfo.new(0.6), {
		TintColor = if value then Color3.fromRGB(226, 200, 255) else Color3.new(1, 1, 1),
		Saturation = if value then -0.35 else 0,
		Contrast = if value then 0.1 else 0,
	}):Play()
end

local function update()
	local elapsed = GameState.battleElapsed()
	if not elapsed then
		currentSample = nil
		setWallVisible(false)
		setOutside(false)
		return
	end
	local offset = GameState.get(GameState.Key.ZoneTimeOffset)
	local sample = ZoneMath.sample(elapsed + (if typeof(offset) == "number" then offset else 0))
	currentSample = sample
	if not sample.active then
		setWallVisible(false)
		setOutside(false)
		return
	end

	local centerValue = GameState.get(GameState.Key.ZoneCenter)
	local center = if typeof(centerValue) == "Vector3" then centerValue else Vector3.zero
	setWallVisible(true)
	if math.abs(sample.radius - laidOutRadius) > 0.02 then
		laidOutRadius = sample.radius
		layoutPanels(center, sample.radius)
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local isOut = root ~= nil
		and root:IsA("BasePart")
		and player:GetAttribute("InMatch") == true
		and ZoneMath.isOutside(root.Position, center, sample.radius)
	setOutside(isOut)
end

function ZoneController.start()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "StormTint"
	tint.Parent = Lighting
	buildPanels()
	RunService.Heartbeat:Connect(update)
end

return ZoneController

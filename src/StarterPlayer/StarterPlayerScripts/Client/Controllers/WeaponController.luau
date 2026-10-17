--!strict
-- Weapon input and feel on the client: charge-and-release bomb throws with a
-- live aiming arc, sword swings, rocket shots, arm animations for everyone,
-- and applying knockback to our own character.
--
-- The server decides what actually happens; this controller just makes it
-- feel instant (local arm swing and sound before the server echoes back).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundPlayer = require(ReplicatedStorage.Shared.SoundPlayer)
local TeamInfo = require(ReplicatedStorage.Shared.TeamInfo)
local Trajectory = require(ReplicatedStorage.Shared.Trajectory)
local ArmAnimator = require(script.Parent.Parent.Lib.ArmAnimator)
local EffectParts = require(script.Parent.Parent.Lib.EffectParts)

local WeaponController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local ARC_DOTS = 22
local ARC_STEP = 0.06

local chargeStartedAt: number? = nil
local arcDots: { Part } = {}
-- Raycasting as a bomb means the arc passes through characters and debris
-- exactly like the real bomb will.
local arcParams = RaycastParams.new()
arcParams.CollisionGroup = "Bombs"

local lastLocalSwing = 0

local function rootAndHead(): (BasePart?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if root and root:IsA("BasePart") and head and head:IsA("BasePart") then
		return root, head
	end
	return nil, nil
end

-- Where the player is aiming: the crosshair in first person, the tapped point
-- on touch screens (Mouse.Hit follows the last touch).
local function aimDirection(): Vector3
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local target = mouse.Hit.Position
	local direction = target - origin
	if direction.Magnitude < 1 then
		return camera.CFrame.LookVector
	end
	return direction.Unit
end

local function chargeFraction(): number
	if not chargeStartedAt then
		return 0
	end
	return math.clamp((os.clock() - chargeStartedAt) / Config.Bomb.ChargeTime, 0, 1)
end

function WeaponController.getCharge(): number?
	return if chargeStartedAt then chargeFraction() else nil
end

local function bombCharges(): number
	local charges = player:GetAttribute("BombCharges")
	return if typeof(charges) == "number" then charges else 0
end

----------------------------------------------------------------------------
-- Aiming arc
----------------------------------------------------------------------------

local function ensureArc()
	if #arcDots > 0 then
		return
	end
	for index = 1, ARC_DOTS do
		arcDots[index] = EffectParts.part({
			Name = "AimDot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.35,
			Material = Enum.Material.Neon,
			Transparency = 1,
		})
	end
end

local function hideArc()
	for _, dot in arcDots do
		dot.Transparency = 1
	end
end

local function updateArc()
	local root, head = rootAndHead()
	if not chargeStartedAt or not root or not head then
		hideArc()
		return
	end
	ensureArc()
	local charge = chargeFraction()
	local origin, velocity = Trajectory.launch(head.Position, aimDirection(), charge, root.AssemblyLinearVelocity)
	local points = Trajectory.samplePoints(origin, velocity, workspace.Gravity, ARC_DOTS, ARC_STEP)

	local color = if player:GetAttribute("MegaBomb")
		then Color3.fromRGB(255, 90, 90)
		else TeamInfo.colorOf(if player.Team then player.Team.Name else nil):Lerp(Color3.new(1, 1, 1), 0.35)
	local previous = origin
	for index = 1, ARC_DOTS do
		local dot = arcDots[index]
		local point = points[index]
		local hit = workspace:Raycast(previous, point - previous, arcParams)
		if hit then
			point = hit.Position
		end
		dot.Position = point
		dot.Color = color
		-- Fade the tail so the arc reads as "this way" rather than a wall; the
		-- landing spot gets a bigger marker.
		dot.Transparency = 0.15 + (index / ARC_DOTS) * 0.6
		dot.Size = Vector3.one * (if hit then 0.9 else 0.35)
		previous = point
		if hit then
			for rest = index + 1, ARC_DOTS do
				arcDots[rest].Transparency = 1
			end
			break
		end
	end
end

----------------------------------------------------------------------------
-- Tools
----------------------------------------------------------------------------

local function canAct(): boolean
	if player:GetAttribute("Frozen") then
		return false
	end
	local phase = GameState.phase()
	return phase ~= GameState.Phase.GetReady and phase ~= GameState.Phase.Results
end

local function throwBomb()
	if not chargeStartedAt then
		return
	end
	local charge = chargeFraction()
	chargeStartedAt = nil
	hideArc()
	if not canAct() or bombCharges() < 1 then
		return
	end
	Remotes.get("ThrowBomb"):FireServer(aimDirection(), charge)
	-- Play our own swing immediately; the server's echo is skipped for us.
	ArmAnimator.play(player.Character, "Throw")
	local _, head = rootAndHead()
	if head then
		SoundPlayer.playAt("Throw", head.Position, { pitchJitter = 0.1 })
	end
end

local function bindBomb(tool: Tool)
	tool.Activated:Connect(function()
		if canAct() and bombCharges() >= 1 then
			chargeStartedAt = os.clock()
		end
	end)
	tool.Deactivated:Connect(throwBomb)
	tool.Unequipped:Connect(function()
		chargeStartedAt = nil
		hideArc()
	end)
end

local function bindSword(tool: Tool)
	tool.Activated:Connect(function()
		if not canAct() then
			return
		end
		local now = os.clock()
		local sinceLast = now - lastLocalSwing
		local isLunge = sinceLast <= Config.Sword.LungeWindow and sinceLast >= 0.08
		lastLocalSwing = now
		Remotes.get("SwingSword"):FireServer()
		ArmAnimator.play(player.Character, if isLunge then "Lunge" else "Slash")
	end)
end

local function bindRocket(tool: Tool)
	tool.Activated:Connect(function()
		if canAct() then
			Remotes.get("FireRocket"):FireServer(mouse.Hit.Position)
			ArmAnimator.play(player.Character, "Fire")
		end
	end)
end

local BINDERS: { [string]: (Tool) -> () } = {
	Bomb = bindBomb,
	Sword = bindSword,
	RocketLauncher = bindRocket,
}

-- Tools are cloned fresh on every spawn, so bind whenever one shows up.
local function watchContainer(container: Instance)
	local function onChild(child: Instance)
		if child:IsA("Tool") and not child:GetAttribute("_bound") then
			local binder = BINDERS[child.Name]
			if binder then
				child:SetAttribute("_bound", true)
				binder(child)
			end
		end
	end
	for _, child in container:GetChildren() do
		onChild(child)
	end
	container.ChildAdded:Connect(onChild)
end

----------------------------------------------------------------------------
-- Server echoes
----------------------------------------------------------------------------

local ACTION_SOUNDS = {
	Throw = "Throw",
	Slash = "SwordSlash",
	Lunge = "SwordLunge",
	Fire = "RocketFire",
}

local function onActionFx(actor: Player, action: string)
	if actor == player then
		-- Our own arm already moved locally; the sword/rocket sounds are
		-- still played here so they match the server's timing.
		if action ~= "Throw" then
			local _, head = rootAndHead()
			local soundName = ACTION_SOUNDS[action]
			if head and soundName then
				SoundPlayer.playAt(soundName, head.Position, { pitchJitter = 0.06 })
			end
		end
		return
	end
	local character = actor.Character
	ArmAnimator.play(character, action)
	local head = character and character:FindFirstChild("Head")
	local soundName = ACTION_SOUNDS[action]
	if head and head:IsA("BasePart") and soundName then
		SoundPlayer.playAt(soundName, head.Position, { pitchJitter = 0.06 })
	end
end

-- The server can't push a client-owned character, so it asks us to.
local function onKnockback(velocity: Vector3)
	local root = rootAndHead()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if velocity.Magnitude > 25 then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	root.AssemblyLinearVelocity += velocity
end

function WeaponController.start()
	local function onCharacter(character: Model)
		chargeStartedAt = nil
		watchContainer(character)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	-- Tools sitting in the backpack get bound too, so the first click works.
	task.spawn(function()
		local backpack = player:WaitForChild("Backpack")
		watchContainer(backpack)
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				watchContainer(child)
			end
		end)
	end)

	Remotes.get("ActionFx").OnClientEvent:Connect(onActionFx)
	Remotes.get("Knockback").OnClientEvent:Connect(onKnockback)

	RunService.RenderStepped:Connect(function()
		if chargeStartedAt then
			updateArc()
		end
	end)
end

return WeaponController

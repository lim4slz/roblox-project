--!strict
-- Damage, knockback and explosions. Every weapon funnels through here, so the
-- rules about who can hurt whom (teams, phases, the peaceful lobby, god mode)
-- live in exactly one place.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(script.Parent.Rules)
local ScoreService = require(script.Parent.ScoreService)
local TowerService = require(script.Parent.TowerService)

export type ExplosionSpec = {
	position: Vector3,
	radius: number,
	brickRadius: number,
	maxDamage: number,
	minDamage: number,
	knockback: number,
	attacker: Player?,
	kind: string, -- "Bomb" | "Mega" | "Rocket" | "Rain"
}

local CombatService = {}

local DUMMY_TAG = "TrainingDummy"

local function rootOf(character: Model?): BasePart?
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(character: Model?): Humanoid?
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- True when `attacker` is allowed to hurt `victim` right now.
function CombatService.canDamage(attacker: Player?, victim: Player): boolean
	if GameState.phase() ~= GameState.Phase.Battle then
		return false
	end
	if not victim:GetAttribute("InMatch") or victim:GetAttribute("GodMode") then
		return false
	end
	if attacker and attacker ~= victim then
		if not attacker:GetAttribute("InMatch") then
			return false
		end
		-- No friendly fire: team-mates only get knocked around.
		if attacker.Team and attacker.Team == victim.Team then
			return false
		end
	end
	return true
end

-- Applies damage to a player and records who did it. `how` feeds the kill feed.
function CombatService.damagePlayer(
	victim: Player,
	amount: number,
	attacker: Player?,
	sourcePosition: Vector3?,
	how: string
)
	if amount <= 0 or not CombatService.canDamage(attacker, victim) then
		return
	end
	local humanoid = humanoidOf(victim.Character)
	if not humanoid then
		return
	end
	-- ForceFields (spawn protection, Shield power-up) block everything.
	if victim.Character and victim.Character:FindFirstChildOfClass("ForceField") then
		return
	end
	local finalAmount = math.floor(amount + 0.5)
	ScoreService.recordDamage(victim, attacker, finalAmount)
	victim:SetAttribute("LastDamageKind", if attacker == victim then "Self" else how)
	humanoid:TakeDamage(finalAmount)
	Remotes.get("DamageFx"):FireClient(victim, finalAmount, sourcePosition)
end

-- Knockback must be applied by the client that owns the character's physics,
-- so we send the impulse to that client.
function CombatService.knockback(player: Player, velocity: Vector3)
	if velocity.Magnitude < 1 then
		return
	end
	if not player:GetAttribute("InMatch") then
		velocity *= Config.Lobby.KnockbackScale
	end
	Remotes.get("Knockback"):FireClient(player, velocity)
end

local function damageDummy(model: Model, amount: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local rounded = math.floor(amount + 0.5)
	humanoid:TakeDamage(rounded)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if root then
		Remotes.get("DamageNumber"):FireAllClients(root.Position + Vector3.new(0, 3, 0), rounded)
	end
end

-- Damage at the centre of a blast, fading to minDamage at the edge.
local function falloff(spec: ExplosionSpec, distance: number): (number, number)
	local t = math.clamp(distance / spec.radius, 0, 1)
	local damage = spec.maxDamage + (spec.minDamage - spec.maxDamage) * t
	local push = spec.knockback * (1 - t * 0.6)
	return damage, push
end

function CombatService.explode(spec: ExplosionSpec)
	local attacker = spec.attacker
	local damageMultiplier = Rules.get("DamageMultiplier")

	local bricks = TowerService.breakAt(spec.position, spec.brickRadius, attacker)

	for _, player in Players:GetPlayers() do
		local root = rootOf(player.Character)
		if root then
			local offset = root.Position - spec.position
			local distance = offset.Magnitude
			if distance <= spec.radius + 1.5 then
				local damage, push = falloff(spec, distance)
				if player == attacker then
					damage *= Config.Bomb.SelfDamageMultiplier
				end
				CombatService.damagePlayer(player, damage * damageMultiplier, attacker, spec.position, spec.kind)
				local direction = if distance > 0.1 then offset.Unit else Vector3.new(0, 1, 0)
				CombatService.knockback(player, (direction + Vector3.new(0, 0.7, 0)).Unit * push)
			end
		end
	end

	for _, dummy in CollectionService:GetTagged(DUMMY_TAG) do
		if dummy:IsA("Model") then
			local root = dummy.PrimaryPart
			if root and (root.Position - spec.position).Magnitude <= spec.radius + 2 then
				local damage = falloff(spec, (root.Position - spec.position).Magnitude)
				damageDummy(dummy, damage)
			end
		end
	end

	Remotes.get("ExplosionFx"):FireAllClients(spec.position, spec.radius, spec.kind, bricks)
end

-- Melee hit test: everything inside a box in front of the attacker.
function CombatService.meleeSweep(attacker: Player, range: number, damage: number, push: number, how: string): number
	local character = attacker.Character
	local root = rootOf(character)
	if not character or not root then
		return 0
	end
	local boxCFrame = root.CFrame * CFrame.new(0, 0, -range / 2)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { character }
	local debrisFolder = workspace:FindFirstChild("Debris")
	if debrisFolder then
		table.insert(ignore, debrisFolder)
	end
	params.FilterDescendantsInstances = ignore

	local hitModels: { [Model]: boolean } = {}
	local hits = 0
	for _, part in workspace:GetPartBoundsInBox(boxCFrame, Vector3.new(5, 6, range), params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not hitModels[model] then
			hitModels[model] = true
			local victim = Players:GetPlayerFromCharacter(model)
			if victim and humanoidOf(model) then
				hits += 1
				CombatService.damagePlayer(victim, damage * Rules.get("DamageMultiplier"), attacker, root.Position, how)
				local away = (model:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
				local direction = if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector
				CombatService.knockback(victim, (direction + Vector3.new(0, 0.5, 0)).Unit * push)
			elseif CollectionService:HasTag(model, DUMMY_TAG) then
				hits += 1
				damageDummy(model, damage)
			end
		end
	end
	return hits
end

return CombatService

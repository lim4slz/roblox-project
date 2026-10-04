local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ember = ReplicatedStorage:WaitForChild("Ember")
local Anchors = require(Ember.Anchors)
local Config = require(Ember.Config)

local Hits = {}

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude

local function knockback(root: BasePart, velocity: Vector3)
	local att = Instance.new("Attachment")
	att.Name = "EmberKnockback"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = velocity
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = att
	Debris:AddItem(att, 0.22)
end

function Hits.apply(player: Player, character: Model, abilityName: string, hit)
	local p = hit.params
	local center = Anchors.position(character, hit.anchor or "feet")
	local radius = p.radius or 10
	overlap.FilterDescendantsInstances = if Config.Damage.HitCaster then {} else { character }
	local seen: { [Humanoid]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInRadius(center, radius, overlap) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or seen[humanoid] or humanoid.Health <= 0 then
			continue
		end
		seen[humanoid] = true
		local root = (model :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
		local dist = if root then (root.Position - center).Magnitude else radius
		local falloff = 1 - math.clamp(dist / radius, 0, 1) * 0.6
		local damage = (p.damage or 0) * Config.Damage.Multiplier * falloff
		if damage > 0 then
			humanoid:TakeDamage(damage)
			if Config.OnHit then
				Config.OnHit(player, humanoid, abilityName, hit.marker, damage)
			end
		end
		if root and (p.knockback or 0) > 0 then
			local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
			local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
			knockback(root, dir * p.knockback * falloff + Vector3.new(0, p.lift or 0, 0))
		end
	end
end

function Hits.schedule(player: Player, character: Model, abilityName: string, ability, isActive: () -> boolean)
	if not Config.Damage.Enabled then
		return
	end
	for _, hit in ability.Hits or {} do
		task.delay(hit.t, function()
			if isActive() and character.Parent then
				Hits.apply(player, character, abilityName, hit)
			end
		end)
	end
end


return Hits

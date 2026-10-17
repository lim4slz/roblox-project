--!strict
-- Helpers for client-only effect parts (explosion flashes, debris cubes,
-- storm panels...). They live in a local folder that never replicates and are
-- excluded from collisions with players and from raycasts.

local EffectParts = {}

local folder: Folder? = nil

function EffectParts.folder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "ClientEffects"
	created.Parent = workspace
	folder = created
	return created
end

-- An anchored, non-colliding, non-queryable part: the default for visuals.
function EffectParts.part(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent or EffectParts.folder()
	return part
end

-- A physics cube that tumbles away (debris, confetti). Collides with the
-- world but not with characters.
function EffectParts.debris(
	position: Vector3,
	size: number,
	color: Color3,
	velocity: Vector3,
	material: Enum.Material?
): Part
	local cube = EffectParts.part({
		Size = Vector3.one * size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
	})
	cube.CollisionGroup = "Debris"
	cube.CanCollide = true
	cube.Anchored = false
	cube.AssemblyLinearVelocity = velocity
	cube.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
	return cube
end

return EffectParts

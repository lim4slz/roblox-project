--!strict
-- Bomb launch maths shared by the server (which spawns the real bomb) and the
-- client (which draws the aiming arc). Sharing it guarantees the preview
-- matches the throw.

local Config = require(script.Parent.Config)

local Trajectory = {}

-- Turns a 0..1 charge into launch speed. Quick taps still get a usable lob.
function Trajectory.speedForCharge(charge: number): number
	local bomb = Config.Bomb
	local eased = 1 - (1 - math.clamp(charge, 0, 1)) ^ 2
	return bomb.MinThrowSpeed + (bomb.MaxThrowSpeed - bomb.MinThrowSpeed) * eased
end

-- Where the bomb appears and how fast it leaves the hand.
function Trajectory.launch(
	headPosition: Vector3,
	aimDirection: Vector3,
	charge: number,
	carrierVelocity: Vector3?
): (Vector3, Vector3)
	local bomb = Config.Bomb
	local direction = if aimDirection.Magnitude > 1e-3 then aimDirection.Unit else Vector3.new(0, 0, -1)
	local speed = Trajectory.speedForCharge(charge)
	local origin = headPosition + direction * 2 + Vector3.new(0, -0.3, 0)
	local inherited = (carrierVelocity or Vector3.zero) * bomb.InheritVelocity
	local velocity = direction * speed + Vector3.new(0, speed * bomb.UpwardBias, 0) + inherited
	return origin, velocity
end

-- Samples points along the ballistic arc (no bounces) for the aim preview.
function Trajectory.samplePoints(
	origin: Vector3,
	velocity: Vector3,
	gravity: number,
	count: number,
	timeStep: number
): { Vector3 }
	local points = table.create(count)
	local gravityVector = Vector3.new(0, -gravity, 0)
	for index = 1, count do
		local t = index * timeStep
		points[index] = origin + velocity * t + gravityVector * (0.5 * t * t)
	end
	return points
end

return Trajectory

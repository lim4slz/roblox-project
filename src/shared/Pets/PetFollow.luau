--!strict
--[[
	PetFollow
	Moves a pet after its owner: it trails a little behind and to the side,
	walks to keep up, runs when it falls behind, stops once it has arrived and
	then turns to look at its owner. Pure math (positions in, positions out) so
	it can be unit tested; the caller supplies the ground height.

	  local follow = PetFollow.new(spawnPosition, yaw)
	  PetFollow.step(follow, ownerRootCFrame, groundY, dt)
	  local cframe = PetFollow.cframe(follow) -- ground point, facing the pet's heading
]]

export type State = {
	position: Vector3, -- point on the ground under the pet
	velocity: Vector3, -- horizontal, studs/s
	speed: number,
	yaw: number, -- heading in radians (0 faces -Z)
}

local OFFSET_RIGHT = 2.6 -- studs to the owner's right
local OFFSET_BACK = 3.4 -- studs behind the owner
local ARRIVE_RADIUS = 0.8 -- close enough to the spot: stop
-- Desired speed per stud of distance to the spot. Keeping up with a walking
-- owner (16 studs/s) takes ~4.5 studs of lag; falling further behind means running.
local GAIN = 3.6
local MAX_SPEED = 30
local ACCELERATION = 40
local BRAKING = 60
local TURN_SPEED = math.rad(540)
local FACE_MOVEMENT_SPEED = 2 -- above this the pet faces where it goes
local FACE_OWNER_SPEED = 0.6 -- below this it turns to look at its owner
local SNAP_DISTANCE = 80 -- teleport when the owner got this far (respawn, teleport)
local GROUND_SNAP = 6 -- height jumps above this are not smoothed

local PetFollow = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function turnTowards(current: number, target: number, maxStep: number): number
	local delta = (target - current + math.pi) % (2 * math.pi) - math.pi
	return current + math.clamp(delta, -maxStep, maxStep)
end

-- Where the pet wants to be for an owner standing at `owner`.
function PetFollow.goal(owner: CFrame): Vector3
	local forward = flat(owner.LookVector)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	return owner.Position + right * OFFSET_RIGHT - forward * OFFSET_BACK
end

function PetFollow.new(position: Vector3, yaw: number?): State
	return { position = position, velocity = Vector3.zero, speed = 0, yaw = yaw or 0 }
end

function PetFollow.step(state: State, owner: CFrame, groundY: number, dt: number)
	if dt <= 0 then
		return
	end
	local goal = PetFollow.goal(owner)
	local toGoal = flat(goal - state.position)
	local distance = toGoal.Magnitude
	if distance > SNAP_DISTANCE then
		state.position = Vector3.new(goal.X, groundY, goal.Z)
		state.velocity = Vector3.zero
		state.speed = 0
		state.yaw = yawOf(flat(owner.LookVector))
		return
	end

	local desiredSpeed = math.clamp((distance - ARRIVE_RADIUS) * GAIN, 0, MAX_SPEED)
	local desired = if distance > 1e-4 then toGoal.Unit * desiredSpeed else Vector3.zero
	local change = desired - state.velocity
	local limit = (if desiredSpeed < state.speed then BRAKING else ACCELERATION) * dt
	if change.Magnitude > limit then
		change = change.Unit * limit
	end
	local velocity = state.velocity + change
	local position = state.position + velocity * dt
	local y = position.Y
	if math.abs(groundY - y) > GROUND_SNAP then
		y = groundY
	else
		y += (groundY - y) * (1 - math.exp(-18 * dt))
	end
	state.position = Vector3.new(position.X, y, position.Z)
	state.velocity = velocity
	state.speed = velocity.Magnitude

	local toOwner = flat(owner.Position - state.position)
	if state.speed > FACE_MOVEMENT_SPEED then
		state.yaw = turnTowards(state.yaw, yawOf(velocity), TURN_SPEED * dt)
	elseif state.speed < FACE_OWNER_SPEED and toOwner.Magnitude > 1 then
		state.yaw = turnTowards(state.yaw, yawOf(toOwner), TURN_SPEED * 0.5 * dt)
	end
end

function PetFollow.cframe(state: State): CFrame
	return CFrame.new(state.position) * CFrame.Angles(0, state.yaw, 0)
end

return table.freeze(PetFollow)

--!strict
--[[
	SnakeAnimation
	Procedural slithering for the snake pet. The head goes where the follow
	logic takes it, weaving left and right as it travels, and leaves a trail on
	the ground. Every body segment lies on that trail, so the whole body slides
	through the same S-shaped path like a real snake, and it follows stairs and
	slopes the head went over. The segments stay rigidly connected: each joint
	sits exactly one segment away from the previous one, towards its spot on
	the trail.

	On top of that, cartoon life: the head rises a little and looks around when
	the snake stops, the tongue flicks in and out every second or two, and now
	and then it rears up and HISSES (mouth open, fangs, angry brows, tongue
	going wild, a little quiver).

	Pure math (no Instances), deterministic for a seed:

	  local anim = SnakeAnimation.new(seed, every, scale)
	  anim:reset(root)                          -- body laid out straight behind `root`
	  local hisses = anim:step(dt, root, speed) -- root: ground point under the head, facing its heading
	  local pose, pinned = anim:pose()          -- rig:solve(CFrame.identity, pose, out, pinned)

	`pinned` holds world pivots for the spine bones; `pose` the local
	transforms of the bones inside the head. Both tables are reused between
	frames.
]]

local SnakeModel = require(script.Parent.SnakeModel)

export type Gait = "Idle" | "Walk" | "Run"

export type SnakeAnimation = {
	reset: (self: SnakeAnimation, root: CFrame) -> (),
	step: (self: SnakeAnimation, dt: number, root: CFrame, speed: number) -> number,
	pose: (self: SnakeAnimation) -> ({ [string]: CFrame }, { [string]: CFrame }),
	hiss: (self: SnakeAnimation) -> (),
	gait: (self: SnakeAnimation) -> Gait,
	isHissing: (self: SnakeAnimation) -> boolean,
	joints: (self: SnakeAnimation) -> { Vector3 },
	trail: (self: SnakeAnimation) -> { Vector3 },
}

local TAU = 2 * math.pi
local rad = math.rad
local sin, cos = math.sin, math.cos
local UP = Vector3.yAxis

local JOINTS = SnakeModel.Joints
local SPINE = SnakeModel.Spine
local NECK = JOINTS[2] -- where the head meets the body

-- Speeds (studs/s) where the gaits blend, same as the other pets.
local MOVE_START, MOVE_FULL = 0.6, 2.5
local RUN_START, RUN_FULL = 17.5, 21

-- The S-curve: the head weaves this far to each side, once per wavelength of
-- travel. Amplitude changes are spread over a few studs of travel so a snake
-- that stops never slides sideways.
local WALK_AMPLITUDE, RUN_AMPLITUDE = 0.55, 0.75
local WALK_WAVELENGTH, RUN_WAVELENGTH = 6.5, 8
local AMPLITUDE_TRAVEL = 2

local TRAIL_STEP = 0.25 -- studs between trail points
local TRAIL_SPARE = 2 -- trail kept beyond the tip of the tail
local TELEPORT = 12 -- a jump this big in one step lays the body out again

-- How high the front of the body rises (studs) and over how much body.
local IDLE_LIFT, WALK_LIFT, RUN_LIFT, HISS_LIFT = 0.42, 0.2, 0.06, 1.9
local RISE_LENGTH, HISS_RISE_LENGTH = 3.2, 4.6
local LOOK_LIMIT = rad(55)

-- Random HISSes: the first one soon after spawning, then `every` seconds
-- after the previous one ended.
local FIRST_HISS_MIN, FIRST_HISS_MAX = 2, 4
local EVERY = { 5, 10 }
local HISS_LENGTH = 1.5
local MOUTH_OPEN_FROM, MOUTH_OPEN_TO = 0.1, 1.2

local FLICK_MIN, FLICK_MAX = 0.9, 2.8
local FLICK_LENGTH = 0.5

type Impl = {
	_rng: Random,
	_every: { number },
	_scale: number,
	_joints: { number }, -- scaled distances along the body
	_time: number,
	_move: number,
	_run: number,
	_rootPosition: Vector3,
	_look: Vector3,
	_side: Vector3,
	_head: Vector3, -- ground point under the head
	_phase: number,
	_amplitude: number,
	_trail: { Vector3 }, -- oldest first
	_hissStart: number,
	_nextHiss: number,
	_started: number, -- hisses started since the last step
	_flickStart: number,
	_nextFlick: number,
	_pose: { [string]: CFrame },
	_pinned: { [string]: CFrame },
	_points: { Vector3 }, -- scratch: trail point per joint
	_forward: { Vector3 }, -- scratch: trail direction (towards the head) per joint
	_spine: { Vector3 }, -- solved joint positions
}

local AnimationClass = {}
AnimationClass.__index = AnimationClass

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatUnit(vector: Vector3, fallback: Vector3): Vector3
	local f = flat(vector)
	return if f.Magnitude > 1e-4 then f.Unit else fallback
end

-- 0 -> 1 with a little overshoot, then holds, then eases back to 0.
local function rearCurve(age: number): number
	if age < 0 or age >= HISS_LENGTH then
		return 0
	elseif age < 0.25 then
		local u = age / 0.25 - 1
		return 1 + 2.2 * u * u * u + 1.2 * u * u
	elseif age < 1.15 then
		return 1
	end
	return 1 - smoothstep(1.15, HISS_LENGTH, age)
end

local SnakeAnimation = {}

SnakeAnimation.HissLength = HISS_LENGTH
SnakeAnimation.Every = table.freeze(EVERY)

function SnakeAnimation.new(seed: number?, every: { number }?, scale: number?): SnakeAnimation
	local rng = if seed then Random.new(seed) else Random.new()
	local s = scale or 1
	local interval = every or EVERY
	local joints = {}
	for index, distance in JOINTS do
		joints[index] = distance * s
	end
	local self: Impl = {
		_rng = rng,
		_every = interval,
		_scale = s,
		_joints = joints,
		_time = 0,
		_move = 0,
		_run = 0,
		_rootPosition = Vector3.zero,
		_look = Vector3.new(0, 0, -1),
		_side = Vector3.xAxis,
		_head = Vector3.zero,
		_phase = 0,
		_amplitude = 0,
		_trail = {},
		_hissStart = -math.huge,
		_started = 0,
		_nextHiss = if interval[1] < math.huge
			then rng:NextNumber(math.min(FIRST_HISS_MIN, interval[1]), math.min(FIRST_HISS_MAX, interval[2]))
			else math.huge,
		_flickStart = -math.huge,
		_nextFlick = rng:NextNumber(0.3, FLICK_MAX),
		_pose = {},
		_pinned = {},
		_points = {},
		_forward = {},
		_spine = {},
	}
	local animation = (setmetatable(self, AnimationClass) :: any) :: SnakeAnimation
	animation:reset(CFrame.identity)
	return animation
end

function AnimationClass.reset(self: Impl, root: CFrame)
	local look = flatUnit(root.LookVector, Vector3.new(0, 0, -1))
	local position = root.Position
	self._look = look
	self._side = look:Cross(UP)
	self._rootPosition = position
	self._head = position
	self._phase = 0
	self._amplitude = 0
	local length = (SnakeModel.Length + TRAIL_SPARE) * self._scale
	self._trail = { position - look * length, position }
end

function AnimationClass.hiss(self: Impl)
	if self._time - self._hissStart >= HISS_LENGTH then
		self._hissStart = self._time
		self._started += 1
		local every = self._every
		self._nextHiss = if every[1] < math.huge
			then self._time + HISS_LENGTH + self._rng:NextNumber(every[1], every[2])
			else math.huge
	end
end

local function recordTrail(self: Impl)
	local trail = self._trail
	local head = self._head
	if (head - trail[#trail]).Magnitude < TRAIL_STEP * self._scale then
		return
	end
	table.insert(trail, head)
	-- Forget the trail beyond the tip of the tail.
	local needed = (SnakeModel.Length + TRAIL_SPARE) * self._scale
	local total = (head - trail[#trail]).Magnitude
	for index = #trail, 2, -1 do
		total += (trail[index] - trail[index - 1]).Magnitude
		if total >= needed then
			local drop = index - 2
			if drop > 0 then
				table.move(trail, drop + 1, #trail, 1)
				for _ = 1, drop do
					trail[#trail] = nil
				end
			end
			return
		end
	end
end

-- Returns how many hisses started since the last step (play the sound/bubble for each).
function AnimationClass.step(self: Impl, dt: number, root: CFrame, speed: number): number
	dt = math.clamp(dt, 0, 0.25)
	self._time += dt
	local now = self._time
	local s = self._scale
	local relative = speed / s

	local follow = 1 - math.exp(-10 * dt)
	self._move += (smoothstep(MOVE_START, MOVE_FULL, relative) - self._move) * follow
	self._run += (smoothstep(RUN_START, RUN_FULL, relative) - self._run) * follow

	local position = root.Position
	local moved = flat(position - self._rootPosition).Magnitude
	if moved > TELEPORT * s then
		AnimationClass.reset(self, root)
	else
		self._rootPosition = position
		self._look = flatUnit(root.LookVector, self._look)
		-- The weave turns with the heading, spread over the first stud of
		-- travel so a snake setting off in a new direction does not jump.
		self._side += (self._look:Cross(UP) - self._side) * (1 - math.exp(-moved / s))
		local run = self._run
		local amplitude = lerp(WALK_AMPLITUDE, RUN_AMPLITUDE, run) * s
		local wavelength = lerp(WALK_WAVELENGTH, RUN_WAVELENGTH, run) * s
		self._amplitude += (amplitude - self._amplitude) * (1 - math.exp(-moved / (AMPLITUDE_TRAVEL * s)))
		self._phase = (self._phase + TAU * moved / wavelength) % TAU
		self._head = position + self._side * (self._amplitude * sin(self._phase))
		recordTrail(self)
	end

	if now >= self._nextHiss and now - self._hissStart >= HISS_LENGTH then
		AnimationClass.hiss(self)
	end
	local started = self._started
	self._started = 0

	if now >= self._nextFlick and now - self._flickStart >= FLICK_LENGTH then
		self._flickStart = now
		-- Sometimes a quick double flick.
		local gap = if self._rng:NextNumber() < 0.3 then 0.12 else self._rng:NextNumber(FLICK_MIN, FLICK_MAX)
		self._nextFlick = now + FLICK_LENGTH + gap
	end
	return started
end

function AnimationClass.gait(self: Impl): Gait
	if self._move < 0.5 then
		return "Idle"
	end
	return if self._run < 0.5 then "Walk" else "Run"
end

function AnimationClass.isHissing(self: Impl): boolean
	return self._time - self._hissStart < HISS_LENGTH
end

-- Points on the trail (and the trail direction there, towards the head) at
-- each joint's distance behind the head. Past the end of the trail the body
-- carries on straight.
local function sampleTrail(self: Impl)
	local trail = self._trail
	local joints = self._joints
	local points, forward = self._points, self._forward
	local previous = self._head
	local index = #trail
	local walked = 0
	local back = -self._look
	for k, distance in joints do
		while true do
			if index < 1 then
				points[k] = previous + back * (distance - walked)
				forward[k] = -back
				break
			end
			local point = trail[index]
			local segment = point - previous
			local length = segment.Magnitude
			if length < 1e-6 then
				index -= 1
				continue
			end
			if walked + length >= distance then
				points[k] = previous + segment * ((distance - walked) / length)
				forward[k] = -segment / length
				break
			end
			walked += length
			previous = point
			back = segment / length
			index -= 1
		end
	end
end

local function lookAlong(position: Vector3, forward: Vector3, fallbackUp: Vector3): CFrame
	local unit = forward.Unit
	if math.abs(unit.Y) > 0.98 then
		return CFrame.lookAt(position, position + unit, fallbackUp)
	end
	return CFrame.lookAt(position, position + unit)
end

local function signedYaw(from: Vector3, to: Vector3): number
	local a, b = flatUnit(from, Vector3.new(0, 0, -1)), flatUnit(to, Vector3.new(0, 0, -1))
	return math.atan2(a:Cross(b).Y, a:Dot(b))
end

function AnimationClass.pose(self: Impl): ({ [string]: CFrame }, { [string]: CFrame })
	local t = self._time
	local s = self._scale
	local move, run = self._move, self._run
	local idleW = 1 - move
	local walkW = move * (1 - run)
	local runW = move * run

	local hissAge = t - self._hissStart
	local rear = rearCurve(hissAge)
	local open = if hissAge >= MOUTH_OPEN_FROM and hissAge < MOUTH_OPEN_TO then 1 else 0

	-- How high the front of the body is lifted.
	local base = idleW * (IDLE_LIFT + 0.04 * sin(TAU * 0.35 * t)) + walkW * WALK_LIFT + runW * RUN_LIFT
	local lift = lerp(base, HISS_LIFT, rear) * s
	local riseEnd = (NECK + lerp(RISE_LENGTH, HISS_RISE_LENGTH, rear)) * s
	local neck = NECK * s
	local spineHeight = SnakeModel.SpineHeight * s

	sampleTrail(self)
	local points, forward, spine, joints = self._points, self._forward, self._spine, self._joints
	for k, distance in joints do
		local target = points[k] + UP * (spineHeight + lift * (1 - smoothstep(neck, riseEnd, distance)))
		-- Idle: a slow ripple runs down the neck.
		local sway = idleW * 0.16 * sin(TAU * 0.45 * t - 1.3 * distance / s) * (1 - smoothstep(0, 4.5 * s, distance))
		if sway ~= 0 then
			target += forward[k]:Cross(UP) * (sway * s)
		end
		if k == 1 then
			spine[k] = target
		else
			local previous = spine[k - 1]
			local toTarget = target - previous
			local direction = if toTarget.Magnitude > 1e-6 then toTarget.Unit else -forward[k]
			local joint = previous + direction * (distance - joints[k - 1])
			-- Over a sharp step the chain can overshoot downwards: never let a
			-- joint sink into the ground under it (the blocks just overlap).
			local floor = points[k].Y + spineHeight
			spine[k] = if joint.Y < floor then Vector3.new(joint.X, floor, joint.Z) else joint
		end
	end

	-- The head turns (about the neck) towards where the snake is heading or,
	-- standing, towards its owner; it rises when hissing and looks around.
	local neckToHead = spine[1] - spine[2]
	local yaw = math.clamp(signedYaw(neckToHead, self._look), -LOOK_LIMIT, LOOK_LIMIT) * (idleW + 0.45 * move)
		+ idleW * rad(12) * sin(TAU * 0.17 * t + 1.1)
	local pitch = idleW * rad(4) * sin(TAU * 0.6 * t) + rad(22) * rear
	local roll = idleW * rad(8) * sin(TAU * 0.3 * t)
	if open == 1 then
		yaw += rad(3) * sin(TAU * 21 * t)
		roll += rad(2.5) * sin(TAU * 17 * t)
	end
	local right = flatUnit(neckToHead, -self._look):Cross(UP)
	local turned = CFrame.fromAxisAngle(UP, yaw) * (CFrame.fromAxisAngle(right, pitch) * neckToHead)
	spine[1] = spine[2] + turned

	local pinned = self._pinned
	pinned[SPINE[1]] = lookAlong(spine[1], turned, UP) * CFrame.Angles(0, 0, roll)
	for bone = 2, #SPINE do
		pinned[SPINE[bone]] = lookAlong(spine[bone], spine[bone] - spine[bone + 1], forward[bone])
	end

	-- Tongue: flicks in and out (fluttering), goes wild while hissing.
	local extension, waggle = 0, 0
	if rear > 0 then
		extension = math.max(smoothstep(0, 0.08, hissAge) * (1 - smoothstep(1.3, HISS_LENGTH, hissAge)), 0)
		waggle = rad(26) * sin(TAU * 13 * t)
	end
	local flickAge = t - self._flickStart
	if flickAge < FLICK_LENGTH then
		local out = smoothstep(0, 0.07, flickAge) * (1 - smoothstep(0.4, FLICK_LENGTH, flickAge))
		if out > extension then
			extension = out * (0.82 + 0.18 * cos(TAU * 11 * flickAge))
			waggle = rad(20) * sin(TAU * 11 * flickAge)
		end
	end
	local pose = self._pose
	pose.Tongue = CFrame.new(SnakeModel.TongueInOffset * (1 - extension)) * CFrame.Angles(waggle * extension, 0, 0)
	pose.Mouth = CFrame.new(SnakeModel.MouthOpenOffset * open)
	pose.BrowL = CFrame.new(-SnakeModel.BrowOut * open, 0, 0)
	pose.BrowR = CFrame.new(SnakeModel.BrowOut * open, 0, 0)
	return pose, pinned
end

-- Joint positions (head center to tail tip) as of the last `pose`.
function AnimationClass.joints(self: Impl): { Vector3 }
	return self._spine
end

-- The ground trail the body follows, oldest point first (the head is not in it).
function AnimationClass.trail(self: Impl): { Vector3 }
	return self._trail
end

return table.freeze(SnakeAnimation)

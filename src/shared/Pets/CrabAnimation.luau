--!strict
--[[
	CrabAnimation
	Procedural cartoon animation for the crab pet. Standing, it breathes, its
	two eye stalks look around on their own (not always the same way), it
	blinks, sometimes winks, opens and closes a pincer and taps a foot.
	Moving, it does what crabs do: turns its side to where it is going and
	scuttles sideways on quick little steps, the shell rocking, claws up.
	Hurrying makes the steps faster and the shell lower. Now and then it
	SNAPs: claws up high, three quick snaps of both pincers with a hop on
	each, eyes popped up and mouth open.

	Pure math, no Instances, so it is deterministic and testable:

	  local anim = CrabAnimation.new(seed, every) -- every = { min, max } seconds between snaps (math.huge = never)
	  local snaps = anim:step(dt, speed) -- SNAPs whose first snap happened during this step
	  local pose = anim:pose()           -- { [bone]: CFrame } for PetRig:solve

	The pose table is reused between frames; copy it if you need to keep it.
]]

local CrabModel = require(script.Parent.CrabModel)

export type Gait = "Idle" | "Walk" | "Run"

export type CrabAnimation = {
	step: (self: CrabAnimation, dt: number, speed: number) -> number,
	pose: (self: CrabAnimation) -> { [string]: CFrame },
	react: (self: CrabAnimation, count: number?) -> (),
	gait: (self: CrabAnimation) -> Gait,
	isReacting: (self: CrabAnimation) -> boolean,
	sideways: (self: CrabAnimation) -> number,
}

local TAU = 2 * math.pi
local rad = math.rad
local sin, cos = math.sin, math.cos

-- Speeds (studs/s) where the gaits blend, same as the other pets.
local MOVE_START, MOVE_FULL = 0.6, 2.5
local RUN_START, RUN_FULL = 17.5, 21
-- Step cycles per second: crabs take lots of quick little steps.
local WALK_RATE, WALK_RATE_PER_STUD = 2.6, 0.14
local RUN_RATE, RUN_RATE_PER_STUD = 3.6, 0.12
-- How fast it turns sideways when it starts moving (and back when it stops).
local TURN_SPEED = 7

-- Random SNAPs: the first one soon after spawning, then `every` seconds
-- after the previous one ended. A SNAP winds up (claws up, pincers open),
-- snaps three times, in time with the clicks of the default sound, and
-- lowers its claws again.
local FIRST_SNAP_MIN, FIRST_SNAP_MAX = 2, 4
local EVERY = { 4, 8 }
local WINDUP = 0.14
local SNAPS = { 0, 0.18, 0.35 } -- seconds after the windup
local SNAP_CLOSE, SNAP_OPEN = 0.04, 0.12
local SNAP_LENGTH = 1.2
local SNAP_HOP = 0.18
local MAX_QUEUED = 3

local BLINK_MIN, BLINK_MAX = 2, 5
local BLINK_LENGTH = 0.14
local PINCH_GAP_MIN, PINCH_GAP_MAX = 1.5, 4
local PINCH_LENGTH = 0.5
local TAP_GAP_MIN, TAP_GAP_MAX = 2, 6
local TAP_LENGTH = 0.35
local LOOK_GAP_MIN, LOOK_GAP_MAX = 0.8, 2.6

local LEGS = { "FL", "FR", "BL", "BR" }
-- Side of each leg (-1 = left, 1 = right) and its step phase: diagonal pairs
-- step together.
local LEG_SIDE = { FL = -1, FR = 1, BL = -1, BR = 1 }
local LEG_PHASE = { FL = 0, BR = 0, FR = 0.5, BL = 0.5 }

type Impl = {
	_rng: Random,
	_every: { number },
	_time: number,
	_phase: number, -- step cycle, 0..1
	_move: number, -- 0 = standing .. 1 = scuttling (smoothed)
	_run: number, -- 0 = walking .. 1 = running (smoothed)
	_turn: number, -- 0 = facing ahead .. 1 = side first (smoothed)
	_side: number, -- 1 = right side first, -1 = left side first
	_moving: boolean,
	_snapStart: number,
	_snapSignalled: boolean,
	_pending: number,
	_nextSnap: number,
	_blinkUntil: number,
	_wink: number, -- 0 = both eyes, -1 / 1 = only the left / right one
	_nextBlink: number,
	_pinchStart: number,
	_pinchSide: number,
	_nextPinch: number,
	_tapStart: number,
	_tapLeg: string,
	_nextTap: number,
	_eyes: { Vector2 }, -- yaw, pitch per eye stalk (smoothed)
	_eyeTargets: { Vector2 },
	_nextLook: { number },
	_pose: { [string]: CFrame },
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

-- 0 outside [from, to], a smooth hump up to 1 and back down inside.
local function hump(x: number, from: number, to: number): number
	if x <= from or x >= to then
		return 0
	end
	return 0.5 - 0.5 * cos(TAU * (x - from) / (to - from))
end

local CrabAnimation = {}

CrabAnimation.SnapLength = SNAP_LENGTH
CrabAnimation.Windup = WINDUP
CrabAnimation.Snaps = table.freeze(table.clone(SNAPS))
CrabAnimation.Every = table.freeze(EVERY)

function CrabAnimation.new(seed: number?, every: { number }?): CrabAnimation
	local rng = if seed then Random.new(seed) else Random.new()
	local interval = every or EVERY
	local self: Impl = {
		_rng = rng,
		_every = interval,
		_time = 0,
		_phase = 0,
		_move = 0,
		_run = 0,
		_turn = 0,
		_side = 1,
		_moving = false,
		_snapStart = -math.huge,
		_snapSignalled = true,
		_pending = 0,
		_nextSnap = if interval[1] < math.huge
			then rng:NextNumber(math.min(FIRST_SNAP_MIN, interval[1]), math.min(FIRST_SNAP_MAX, interval[2]))
			else math.huge,
		_blinkUntil = -1,
		_wink = 0,
		_nextBlink = rng:NextNumber(BLINK_MIN, BLINK_MAX),
		_pinchStart = -math.huge,
		_pinchSide = 1,
		_nextPinch = rng:NextNumber(0.8, PINCH_GAP_MAX),
		_tapStart = -math.huge,
		_tapLeg = "FL",
		_nextTap = rng:NextNumber(1, TAP_GAP_MAX),
		_eyes = { Vector2.zero, Vector2.zero },
		_eyeTargets = { Vector2.zero, Vector2.zero },
		_nextLook = { rng:NextNumber(0.3, LOOK_GAP_MAX), rng:NextNumber(0.3, LOOK_GAP_MAX) },
		_pose = {},
	}
	return (setmetatable(self, AnimationClass) :: any) :: CrabAnimation
end

-- Asks for `count` SNAPs (1 when nil). The first one starts on the next
-- step, or right after the one going on; the others follow back to back.
function AnimationClass.react(self: Impl, count: number?)
	local snaps = count or 1
	assert(snaps >= 1, "react needs at least one snap")
	self._pending = math.min(self._pending + snaps, MAX_QUEUED)
end

-- Advances time; returns how many SNAPs had their first snap during this
-- step (play the sound and show the bubble for each).
function AnimationClass.step(self: Impl, dt: number, speed: number): number
	dt = math.clamp(dt, 0, 0.25)
	self._time += dt
	local now = self._time
	local rng = self._rng

	local follow = 1 - math.exp(-10 * dt)
	self._move += (smoothstep(MOVE_START, MOVE_FULL, speed) - self._move) * follow
	self._run += (smoothstep(RUN_START, RUN_FULL, speed) - self._run) * follow
	local rate = lerp(WALK_RATE + WALK_RATE_PER_STUD * speed, RUN_RATE + RUN_RATE_PER_STUD * speed, self._run)
	self._phase = (self._phase + dt * rate * self._move) % 1

	-- Each time it sets off it picks which side goes first.
	local moving = speed > MOVE_START
	if moving and not self._moving and self._turn < 0.05 then
		self._side = if rng:NextNumber() < 0.5 then 1 else -1
	end
	self._moving = moving
	local turnTarget = if moving then 1 else 0
	self._turn += (turnTarget - self._turn) * (1 - math.exp(-TURN_SPEED * dt))

	local started = 0
	if now - self._snapStart >= SNAP_LENGTH and (self._pending > 0 or now >= self._nextSnap) then
		self._pending = math.max(self._pending - 1, 0)
		self._snapStart = now
		self._snapSignalled = false
		local every = self._every
		self._nextSnap = if every[1] < math.huge
			then now + SNAP_LENGTH + rng:NextNumber(every[1], every[2])
			else math.huge
	end
	if not self._snapSignalled and now - self._snapStart >= WINDUP then
		self._snapSignalled = true
		started = 1
	end

	if now >= self._nextBlink then
		self._blinkUntil = now + BLINK_LENGTH
		local roll = rng:NextNumber()
		-- Mostly both eyes, sometimes a wink.
		self._wink = if roll < 0.15 then -1 elseif roll < 0.3 then 1 else 0
		self._nextBlink = now + rng:NextNumber(BLINK_MIN, BLINK_MAX)
	end
	if now >= self._nextPinch then
		self._pinchStart = now
		self._pinchSide = if rng:NextNumber() < 0.5 then 1 else -1
		self._nextPinch = now + PINCH_LENGTH + rng:NextNumber(PINCH_GAP_MIN, PINCH_GAP_MAX)
	end
	if now >= self._nextTap then
		self._tapStart = now
		self._tapLeg = LEGS[rng:NextInteger(1, #LEGS)]
		self._nextTap = now + TAP_LENGTH + rng:NextNumber(TAP_GAP_MIN, TAP_GAP_MAX)
	end
	-- The eye stalks look around each on its own; now and then both look the
	-- same way.
	for eye = 1, 2 do
		if now >= self._nextLook[eye] then
			local target = Vector2.new(rad(rng:NextNumber(-40, 40)), rad(rng:NextNumber(-12, 14)))
			self._eyeTargets[eye] = target
			if rng:NextNumber() < 0.3 then
				self._eyeTargets[3 - eye] = target
				self._nextLook[3 - eye] = now + rng:NextNumber(LOOK_GAP_MIN, LOOK_GAP_MAX)
			end
			self._nextLook[eye] = now + rng:NextNumber(LOOK_GAP_MIN, LOOK_GAP_MAX)
		end
		self._eyes[eye] += (self._eyeTargets[eye] - self._eyes[eye]) * (1 - math.exp(-8 * dt))
	end
	return started
end

function AnimationClass.gait(self: Impl): Gait
	if self._move < 0.5 then
		return "Idle"
	end
	return if self._run < 0.5 then "Walk" else "Run"
end

function AnimationClass.isReacting(self: Impl): boolean
	return self._time - self._snapStart < SNAP_LENGTH
end

-- How far it has turned its side to where it goes: 0 = facing ahead, 1 =
-- right side first, -1 = left side first.
function AnimationClass.sideways(self: Impl): number
	return self._turn * self._side
end

-- How closed the pincers are during a SNAP (1 = shut), `age` seconds in.
local function snapClose(age: number): number
	local closed = 0
	for _, at in SNAPS do
		local t = age - WINDUP - at
		if t >= 0 and t < SNAP_CLOSE then
			closed = math.max(closed, t / SNAP_CLOSE)
		elseif t >= SNAP_CLOSE and t < SNAP_CLOSE + SNAP_OPEN then
			closed = math.max(closed, 1 - smoothstep(0, 1, (t - SNAP_CLOSE) / SNAP_OPEN))
		end
	end
	return closed
end

function AnimationClass.pose(self: Impl): { [string]: CFrame }
	local t = self._time
	local move, run = self._move, self._run
	local p = self._phase

	-- SNAP: `snap` blends the claws, eyes and mouth into it.
	local age = t - self._snapStart
	local snap = smoothstep(0, WINDUP, age) * (1 - smoothstep(SNAP_LENGTH - 0.4, SNAP_LENGTH, age))
	local closed = if age < SNAP_LENGTH then snapClose(age) else 0
	local hop = 0
	for _, at in SNAPS do
		hop = math.max(hop, hump(age - WINDUP - at, -0.02, 0.16))
	end

	local idle = 1 - move
	local breath = sin(TAU * 0.55 * t)

	-- Body: breathes, rocks from side to side on its steps (twice per cycle),
	-- sits lower when it hurries, dips before a SNAP.
	local stepWave = sin(TAU * 2 * p)
	local bodyDrop = idle * 0.02 * breath - run * 0.1 * move - 0.08 * hump(age, 0, WINDUP + 0.05)
	local pose = self._pose
	pose.Root = CFrame.new(0, SNAP_HOP * hop, 0) * CFrame.Angles(0, rad(90) * self._turn * self._side, 0)
	pose.Body = CFrame.new(0.05 * stepWave * move, bodyDrop + 0.03 * math.abs(stepWave) * move, 0)
		* CFrame.Angles(rad(2) * sin(TAU * p) * move, 0, rad(4) * stepWave * move)

	-- Legs: diagonal pairs lift and put down in turn, quick and light. A
	-- standing crab taps one foot now and then.
	local tapAge = t - self._tapStart
	local tap = hump(tapAge, 0, TAP_LENGTH)
	local lift = lerp(rad(24), rad(34), run)
	for _, leg in LEGS do
		local side = LEG_SIDE[leg]
		local cycle = (p + LEG_PHASE[leg]) % 1
		local up = if cycle < 0.5 then sin(TAU * cycle) else 0
		local raise = up * lift * move + (if leg == self._tapLeg then rad(22) * tap * idle else 0)
		local swing = cos(TAU * cycle) * rad(10) * move
		pose["Leg" .. leg] = CFrame.Angles(0, swing, side * raise)
		-- The knee bends in as the leg comes up.
		pose["Shin" .. leg] = CFrame.Angles(0, 0, -side * raise * 0.6)
	end

	-- Claws: they breathe up and down when standing, are held up when it
	-- moves, and go up high for a SNAP, jerking on each snap. Now and then a
	-- standing crab opens and closes one pincer.
	local pinchAge = t - self._pinchStart
	local pinch = hump(pinchAge, 0, PINCH_LENGTH)
	for _, side in { -1, 1 } do
		local suffix = if side < 0 then "L" else "R"
		local raise = idle * rad(3) * breath + move * rad(14) + run * rad(10) + snap * rad(40) - rad(8) * closed
		pose["Arm" .. suffix] = CFrame.Angles(0, 0, side * raise)
		pose["Forearm" .. suffix] = CFrame.Angles(0, 0, side * (snap * rad(-42) + move * rad(-8)))
		pose["Pincer" .. suffix] = CFrame.Angles(0, 0, side * snap * rad(-12))
		-- Open: positive. The art has the pincers a little open already.
		local open = snap * (1 - closed) * rad(30)
			- snap * closed * rad(12)
			+ (if self._pinchSide == side then idle * (1 - snap) * rad(22) * pinch else 0)
			+ move * (1 - snap) * rad(6) * (0.5 + 0.5 * sin(TAU * 2 * t + side))
		pose["Finger" .. suffix .. "Out"] = CFrame.Angles(0, 0, -side * open)
		pose["Finger" .. suffix .. "In"] = CFrame.Angles(0, 0, side * open * 0.6)
	end

	-- Eye stalks: each looks around on its own, looks where it is going when
	-- it scuttles, bobs with the steps and pops up for a SNAP. The lids cover
	-- the eyes for a blink.
	local blinking = t < self._blinkUntil
	local ahead = -self._side * rad(55) * self._turn
	for eye, side in { -1, 1 } do
		local suffix = if side < 0 then "L" else "R"
		local look = self._eyes[eye] * (1 - snap) * (1 - move)
		pose["Stalk" .. suffix] = CFrame.new(CrabModel.EyePopOffset * snap)
			* CFrame.Angles(look.Y + rad(6) * stepWave * move, look.X + ahead, side * rad(5) * snap)
		local shut = blinking and (self._wink == 0 or self._wink == side)
		pose["Lid" .. suffix] = if shut then CFrame.new(CrabModel.BlinkOffset) else CFrame.identity
	end

	-- Mouth: open through the SNAP.
	pose.Mouth = CFrame.new(CrabModel.MouthOpenOffset * if snap > 0.5 then 1 else 0)
	return pose
end

return table.freeze(CrabAnimation)

--!strict
--[[
	BunnyAnimation
	Procedural cartoon animation for the bunny pet. Sitting, it breathes,
	twitches its nose in quick little bursts, flicks or turns one ear at a
	time, looks around and blinks. Moving, it hops: a crouch, the hind feet
	push, an arc through the air with the ears streaming back, front paws
	first on landing, then the hind feet, and the ears flop forward. Running
	makes the hops longer, higher and faster, with the body stretched out.
	Now and then it does a binky, the happy bunny jump: straight up with a
	twist in the air, hind feet kicking out, ears flapping, eyes shut and
	mouth open, then a squashy landing.

	Every frame the whole bunny is lifted or lowered so its lowest point
	rests on the ground (or flies above it by the height of the jump): no
	pose can push it into the floor.

	Pure math, no Instances, so it is deterministic and testable:

	  local anim = BunnyAnimation.new(seed, every) -- every = { min, max } seconds between binkies (math.huge = never)
	  local binkies = anim:step(dt, speed) -- binkies that started during this step
	  local pose = anim:pose()             -- { [bone]: CFrame } for PetRig:solve

	The pose table is reused between frames; copy it if you need to keep it.
]]

local BunnyModel = require(script.Parent.BunnyModel)
local PetRig = require(script.Parent.PetRig)

export type Gait = "Idle" | "Walk" | "Run"

export type BunnyAnimation = {
	step: (self: BunnyAnimation, dt: number, speed: number) -> number,
	pose: (self: BunnyAnimation) -> { [string]: CFrame },
	react: (self: BunnyAnimation, count: number?) -> (),
	gait: (self: BunnyAnimation) -> Gait,
	isReacting: (self: BunnyAnimation) -> boolean,
	hopPhase: (self: BunnyAnimation) -> number,
}

local TAU = 2 * math.pi
local rad = math.rad
local sin, cos = math.sin, math.cos

-- Speeds (studs/s) where the gaits blend, same as the other pets.
local MOVE_START, MOVE_FULL = 0.6, 2.5
local RUN_START, RUN_FULL = 17.5, 21
-- Hops per second: more hops the faster it goes, but running hops get longer.
local WALK_RATE, WALK_RATE_PER_STUD = 1.6, 0.1
local RUN_RATE, RUN_RATE_PER_STUD = 2.2, 0.06
-- How high a hop clears the ground (studs).
local WALK_HEIGHT, WALK_HEIGHT_PER_STUD, WALK_HEIGHT_MAX = 0.25, 0.02, 0.6
local RUN_HEIGHT = 1

-- One hop as poses at these points of the cycle: crouched, push-off, top of
-- the arc, front paws land, hind feet land. Angles in degrees, distances in
-- studs. The values in between follow a smooth curve through the keys.
local KEYS = { 0, 0.16, 0.42, 0.68, 0.84 }
local TAKEOFF, LANDING = KEYS[2], KEYS[4]
type Hop = { [string]: { number } }
local WALK: Hop = {
	bodyPitch = { -8, -20, -26, -34, -16 }, -- negative = leaning forward
	surge = { -0.06, 0.06, 0.14, 0.04, -0.08 }, -- ahead of the follow point
	headPitch = { -2, 6, 4, -4, -6 }, -- on top of keeping the face fairly level
	frontSwing = { -4, -32, 8, 16, 2 }, -- positive = paws forward
	footPitch = { 0, -42, -24, 6, 0 }, -- negative = toes down
	footBack = { 0, 0.3, 0.42, 0.18, -0.12 },
	footUp = { 0, 0.06, 0.22, 0.32, 0 },
	earPitch = { -10, 18, 42, 30, -24 }, -- positive = tips back
	earSpread = { 2, 4, 10, 8, 12 },
	tailPitch = { 0, 25, 18, 4, -6 },
}
local RUN: Hop = {
	bodyPitch = { -22, -36, -44, -48, -30 },
	surge = { -0.12, 0.1, 0.24, 0.06, -0.14 },
	headPitch = { 0, 8, 6, -4, -6 },
	frontSwing = { -10, -58, 26, 34, -6 },
	footPitch = { -6, -60, -46, 10, 0 },
	footBack = { 0.1, 0.55, 0.72, 0.3, -0.25 },
	footUp = { 0, 0.1, 0.32, 0.42, 0 },
	earPitch = { 18, 46, 66, 52, -6 },
	earSpread = { 2, 6, 12, 10, 14 },
	tailPitch = { 6, 34, 26, 8, 0 },
}

-- Random binkies: the first one soon after spawning, then `every` seconds
-- after the previous one ended.
local FIRST_BINKY_MIN, FIRST_BINKY_MAX = 1.5, 3.5
local EVERY = { 4.5, 9 }
local BINKY_LENGTH = 1.1
local BINKY_TAKEOFF, BINKY_LANDING = 0.15, 0.64
local BINKY_HEIGHT = 1.6
local MAX_QUEUED = 3

local BLINK_MIN, BLINK_MAX = 2, 5
local BLINK_LENGTH = 0.13
local TWITCH_GAP_MIN, TWITCH_GAP_MAX = 0.4, 2.2
local EAR_GAP_MIN, EAR_GAP_MAX = 1.2, 3.5
local EAR_FLICK_LENGTH, EAR_TURN_LENGTH = 0.3, 1.5
local LOOK_GAP_MIN, LOOK_GAP_MAX = 1.2, 3.5

local PARTS = BunnyModel.Definition.parts

type Impl = {
	_rng: Random,
	_every: { number },
	_time: number,
	_phase: number, -- hop cycle, 0..1
	_speed: number, -- smoothed
	_move: number, -- 0 = sitting .. 1 = hopping (smoothed)
	_run: number, -- 0 = walking .. 1 = running (smoothed)
	_binkyStart: number,
	_binkyTurn: number, -- 1 or -1: which way it twists
	_pending: number, -- binkies asked for that have not started yet
	_nextBinky: number,
	_nextBlink: number,
	_blinkUntil: number,
	_twitchStart: number,
	_twitchLength: number,
	_nextTwitch: number,
	_earStart: number,
	_earSide: number, -- 1 = left ear, -1 = right ear
	_earTurn: boolean, -- a slow listening turn instead of a flick
	_nextEar: number,
	_look: Vector3, -- pitch, yaw, roll of the head when sitting (smoothed)
	_lookTarget: Vector3,
	_nextLook: number,
	_rig: PetRig.PetRig, -- unscaled, to find the lowest point of a pose
	_cframes: { CFrame },
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

-- Key `k` of a hop channel, counting on past the ends of the cycle.
local function key(values: { number }, k: number): (number, number)
	local count = #KEYS
	local index = (k - 1) % count + 1
	return KEYS[index] + (k - index) / count, values[index]
end

-- Value of a hop channel at phase `p`: a smooth curve (cubic Hermite with
-- Catmull-Rom slopes) through the keys, looping around.
local function keyed(values: { number }, p: number): number
	local k = 1
	for index = 2, #KEYS do
		if p >= KEYS[index] then
			k = index
		end
	end
	local t0, v0 = key(values, k - 1)
	local t1, v1 = key(values, k)
	local t2, v2 = key(values, k + 1)
	local t3, v3 = key(values, k + 2)
	local h = t2 - t1
	local u = (p - t1) / h
	local m1 = (v2 - v0) / (t2 - t0) * h
	local m2 = (v3 - v1) / (t3 - t1) * h
	local u2, u3 = u * u, u * u * u
	return (2 * u3 - 3 * u2 + 1) * v1 + (u3 - 2 * u2 + u) * m1 + (3 * u2 - 2 * u3) * v2 + (u3 - u2) * m2
end

-- Lowest point of the bunny for solved part CFrames.
local function lowest(cframes: { CFrame }): number
	local low = math.huge
	for index, def in PARTS do
		local cframe = cframes[index]
		local half = def.size / 2
		local bottom = cframe.Position.Y
			- (
				math.abs(cframe.RightVector.Y) * half.X
				+ math.abs(cframe.UpVector.Y) * half.Y
				+ math.abs(cframe.LookVector.Y) * half.Z
			)
		low = math.min(low, bottom)
	end
	return low
end

local BunnyAnimation = {}

BunnyAnimation.BinkyLength = BINKY_LENGTH
BunnyAnimation.BinkyHeight = BINKY_HEIGHT
BunnyAnimation.BinkyTakeoff = BINKY_TAKEOFF
BunnyAnimation.BinkyLanding = BINKY_LANDING
BunnyAnimation.Every = table.freeze(EVERY)

function BunnyAnimation.new(seed: number?, every: { number }?): BunnyAnimation
	local rng = if seed then Random.new(seed) else Random.new()
	local interval = every or EVERY
	local self: Impl = {
		_rng = rng,
		_every = interval,
		_time = 0,
		_phase = 0,
		_speed = 0,
		_move = 0,
		_run = 0,
		_binkyStart = -math.huge,
		_binkyTurn = 1,
		_pending = 0,
		_nextBinky = if interval[1] < math.huge
			then rng:NextNumber(math.min(FIRST_BINKY_MIN, interval[1]), math.min(FIRST_BINKY_MAX, interval[2]))
			else math.huge,
		_nextBlink = rng:NextNumber(BLINK_MIN, BLINK_MAX),
		_blinkUntil = -1,
		_twitchStart = -math.huge,
		_twitchLength = 0,
		_nextTwitch = rng:NextNumber(0.3, TWITCH_GAP_MAX),
		_earStart = -math.huge,
		_earSide = 1,
		_earTurn = false,
		_nextEar = rng:NextNumber(0.8, EAR_GAP_MAX),
		_look = Vector3.zero,
		_lookTarget = Vector3.zero,
		_nextLook = rng:NextNumber(0.5, LOOK_GAP_MAX),
		_rig = PetRig.new(BunnyModel.Definition),
		_cframes = {},
		_pose = {},
	}
	return (setmetatable(self, AnimationClass) :: any) :: BunnyAnimation
end

-- Asks for `count` binkies (1 when nil). The first one starts on the next
-- step, or right after the one in the air; the others follow back to back.
function AnimationClass.react(self: Impl, count: number?)
	local binkies = count or 1
	assert(binkies >= 1, "react needs at least one binky")
	self._pending = math.min(self._pending + binkies, MAX_QUEUED)
end

-- Advances time; returns how many binkies started (play the sound/bubble for each).
function AnimationClass.step(self: Impl, dt: number, speed: number): number
	dt = math.clamp(dt, 0, 0.25)
	self._time += dt
	local now = self._time
	local rng = self._rng

	local follow = 1 - math.exp(-10 * dt)
	self._speed += (speed - self._speed) * follow
	self._move += (smoothstep(MOVE_START, MOVE_FULL, speed) - self._move) * follow
	self._run += (smoothstep(RUN_START, RUN_FULL, speed) - self._run) * follow
	local rate = lerp(WALK_RATE + WALK_RATE_PER_STUD * speed, RUN_RATE + RUN_RATE_PER_STUD * speed, self._run)
	self._phase = (self._phase + dt * rate * self._move) % 1

	local started = 0
	if now - self._binkyStart >= BINKY_LENGTH and (self._pending > 0 or now >= self._nextBinky) then
		self._pending = math.max(self._pending - 1, 0)
		self._binkyStart = now
		self._binkyTurn = if rng:NextNumber() < 0.5 then 1 else -1
		local every = self._every
		self._nextBinky = if every[1] < math.huge
			then now + BINKY_LENGTH + rng:NextNumber(every[1], every[2])
			else math.huge
		started = 1
	end

	if now >= self._nextBlink then
		self._blinkUntil = now + BLINK_LENGTH
		-- Now and then a quick double blink.
		self._nextBlink = now + if rng:NextNumber() < 0.2 then 0.28 else rng:NextNumber(BLINK_MIN, BLINK_MAX)
	end
	if now >= self._nextTwitch then
		self._twitchStart = now
		self._twitchLength = rng:NextNumber(0.35, 0.9)
		self._nextTwitch = now + self._twitchLength + rng:NextNumber(TWITCH_GAP_MIN, TWITCH_GAP_MAX)
	end
	if now >= self._nextEar then
		self._earStart = now
		self._earSide = if rng:NextNumber() < 0.5 then 1 else -1
		self._earTurn = rng:NextNumber() < 0.35
		local length = if self._earTurn then EAR_TURN_LENGTH else EAR_FLICK_LENGTH
		-- Sometimes the same ear flicks twice in a row.
		local gap = if not self._earTurn and rng:NextNumber() < 0.25
			then 0.08
			else rng:NextNumber(EAR_GAP_MIN, EAR_GAP_MAX)
		self._nextEar = now + length + gap
	end
	if now >= self._nextLook then
		self._lookTarget =
			Vector3.new(rad(rng:NextNumber(-8, 6)), rad(rng:NextNumber(-32, 32)), rad(rng:NextNumber(-10, 10)))
		self._nextLook = now + rng:NextNumber(LOOK_GAP_MIN, LOOK_GAP_MAX)
	end
	self._look += (self._lookTarget - self._look) * (1 - math.exp(-5 * dt))
	return started
end

function AnimationClass.gait(self: Impl): Gait
	if self._move < 0.5 then
		return "Idle"
	end
	return if self._run < 0.5 then "Walk" else "Run"
end

function AnimationClass.isReacting(self: Impl): boolean
	return self._time - self._binkyStart < BINKY_LENGTH
end

-- Where the bunny is in its hop cycle (0..1): crouched at 0, front paws
-- land at 0.68.
function AnimationClass.hopPhase(self: Impl): number
	return self._phase
end

function AnimationClass.pose(self: Impl): { [string]: CFrame }
	local t = self._time
	local move, run = self._move, self._run
	local p = self._phase

	-- Binky: `binky` fades the gait out while it lasts.
	local age = t - self._binkyStart
	local binky = smoothstep(0, 0.08, age) * (1 - smoothstep(BINKY_LENGTH - 0.25, BINKY_LENGTH, age))
	local turn = self._binkyTurn
	local inAir = age > BINKY_TAKEOFF and age < BINKY_LANDING
	local air = if inAir then (age - BINKY_TAKEOFF) / (BINKY_LANDING - BINKY_TAKEOFF) else 0
	local crouch = hump(age, 0, BINKY_TAKEOFF + 0.04)
	local squash = hump(age, BINKY_LANDING - 0.02, BINKY_LANDING + 0.26)
	local lift = hump(air, 0, 1)
	local kick = hump(air, 0.1, 0.9)
	local flap = if inAir then sin(TAU * 6 * age) * lift else 0
	local binkyArc = 4 * air * (1 - air) * BINKY_HEIGHT

	local idleW = (1 - move) * (1 - binky)
	local hopW = move * (1 - binky)
	local function hop(channel: string): number
		return lerp(keyed(WALK[channel], p), keyed(RUN[channel], p), run) * hopW
	end

	local hopArc = 0
	if p > TAKEOFF and p < LANDING then
		local u = (p - TAKEOFF) / (LANDING - TAKEOFF)
		local height =
			lerp(math.min(WALK_HEIGHT + WALK_HEIGHT_PER_STUD * self._speed, WALK_HEIGHT_MAX), RUN_HEIGHT, run)
		hopArc = 4 * u * (1 - u) * height * hopW
	end

	-- Body: sits and breathes, leans into the hops, crouches before a binky,
	-- twists and rolls in the air and squashes on landing.
	local breath = sin(TAU * 0.5 * t)
	local bodyPitch = rad(hop("bodyPitch")) + idleW * rad(1) * breath - rad(14) * crouch - rad(16) * squash
	local bodyYaw = turn * rad(38) * lift
	local bodyRoll = -turn * rad(20) * sin(TAU * air)
	local bodyForward = hop("surge")
	local bodyRotation = CFrame.fromEulerAnglesYXZ(bodyPitch, bodyYaw, bodyRoll)

	-- Head: looks around when sitting, keeps the face fairly level while
	-- hopping, turns against the twist in a binky.
	local look = self._look
	local headPitch = -0.6 * bodyPitch
		+ rad(hop("headPitch"))
		+ idleW * look.X
		+ rad(12) * lift
		- rad(10) * squash
		+ rad(6) * crouch
	local headYaw = idleW * look.Y - turn * rad(26) * lift
	local headRoll = idleW * look.Z + turn * rad(12) * lift
	local headLift = idleW * 0.03 * (0.5 + 0.5 * breath)

	-- Nose and muzzle: quick little twitches in bursts.
	local twitchAge = t - self._twitchStart
	local twitch = 0
	if twitchAge < self._twitchLength then
		twitch = (0.5 - 0.5 * cos(TAU * 7 * twitchAge))
			* math.min(1, 6 * twitchAge, 6 * (self._twitchLength - twitchAge))
	end

	-- Ears: when sitting, one ear at a time flicks or slowly turns to
	-- listen. They stream back in the air and flop forward on landing, and
	-- flap through a binky (folded back, out of the bubble's way).
	local earAge = t - self._earStart
	local earFlick, earTurn = 0, 0
	if self._earTurn then
		earTurn = smoothstep(0, 0.3, earAge) * (1 - smoothstep(EAR_TURN_LENGTH - 0.35, EAR_TURN_LENGTH, earAge))
	else
		earFlick = hump(earAge, 0, EAR_FLICK_LENGTH)
	end
	local earPitch = rad(hop("earPitch"))
		+ idleW * rad(2.5) * sin(TAU * 0.5 * t - 0.8)
		+ rad(55) * lift
		- rad(8) * crouch
		- rad(34) * squash
	local earSpread = rad(hop("earSpread")) + rad(14) * lift + rad(24) * flap + rad(12) * squash
	local function ear(side: number): CFrame
		local active = if self._earSide == side then idleW else 0
		local roll = earSpread + active * (rad(22) * earFlick + rad(8) * earTurn)
		local yaw = active * (rad(10) * earFlick + rad(60) * earTurn)
		return CFrame.fromEulerAnglesYXZ(earPitch + active * rad(14) * earFlick, side * yaw, side * roll)
	end

	-- Front legs hang straight down whatever the body does, then swing;
	-- tucked up in a binky and splayed on its landing.
	local frontSwing = -bodyPitch + rad(hop("frontSwing")) + rad(30) * kick + rad(10) * squash
	local frontSplay = rad(8) * lift + rad(10) * squash

	-- Hind feet: offsets taken in the ground's frame and turned into the
	-- body's, so they push, trail and land wherever the body points. In a
	-- binky they kick out behind and to the sides.
	local footOffset =
		bodyRotation:VectorToObjectSpace(Vector3.new(0, hop("footUp") + 0.3 * kick, hop("footBack") + 0.45 * kick))
	local footPitch = -bodyPitch + rad(hop("footPitch")) - rad(40) * kick
	local footOut = rad(22) * kick

	local tailPitch = rad(hop("tailPitch")) + rad(30) * lift + idleW * rad(5) * sin(TAU * 0.5 * t)
	local tailYaw = rad(14) * sin(TAU * 3 * t) * (lift + 0.4 * hopW)

	-- Eyes shut for a blink and happily through the whole binky; mouth open
	-- in the air.
	local blink = if t < self._blinkUntil or (age > 0.06 and age < BINKY_LENGTH - 0.12) then 1 else 0
	local open = if age > BINKY_TAKEOFF and age < BINKY_LANDING + 0.1 then 1 else 0

	local pose = self._pose
	pose.Body = CFrame.new(0, 0, -bodyForward) * bodyRotation
	pose.Head = CFrame.new(0, headLift, 0) * CFrame.fromEulerAnglesYXZ(headPitch, headYaw, headRoll)
	pose.EarL = ear(1)
	pose.EarR = ear(-1)
	pose.Muzzle = CFrame.new(0, 0.015 * twitch, 0) * CFrame.Angles(rad(4) * twitch, 0, 0)
	pose.Nose = CFrame.new(0, 0.04 * twitch, 0)
	pose.Mouth = CFrame.new(BunnyModel.MouthOpenOffset * open)
	pose.Lids = CFrame.new(BunnyModel.BlinkOffset * blink)
	pose.LegFL = CFrame.fromEulerAnglesYXZ(frontSwing, 0, -frontSplay)
	pose.LegFR = CFrame.fromEulerAnglesYXZ(frontSwing, 0, frontSplay)
	pose.FootL = CFrame.new(footOffset) * CFrame.fromEulerAnglesYXZ(footPitch, footOut, footOut)
	pose.FootR = CFrame.new(footOffset) * CFrame.fromEulerAnglesYXZ(footPitch, -footOut, -footOut)
	pose.Tail = CFrame.fromEulerAnglesYXZ(tailPitch, tailYaw, 0)

	-- Rest the lowest point on the ground, or lift it by the jump's arc.
	local low = lowest(self._rig:solve(CFrame.identity, pose, self._cframes))
	pose.Body = CFrame.new(0, hopArc + binkyArc * binky - low, -bodyForward) * bodyRotation
	return pose
end

return table.freeze(BunnyAnimation)

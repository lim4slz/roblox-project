--!strict
--[[
	DogAnimation
	Procedural cartoon animation for the dog pet. Not realistic on purpose:
	a bouncy waddle when walking, a bounding gallop with the tongue out when
	running, a happy idle, random WOOFs (crouch, hop, head snap, open mouth,
	happy squint) and blinks. Everything is rigid blocks rotating about their
	bones, like a classic Roblox rig.

	Pure math, no Instances, so it is deterministic and testable:

	  local anim = DogAnimation.new(seed, every) -- every = { min, max } seconds between WOOFs (math.huge = never)
	  local barks = anim:step(dt, speed) -- WOOFs that started during this step
	  local pose = anim:pose()           -- { [bone]: CFrame } for PetRig:solve

	The pose table is reused between frames; copy it if you need to keep it.
]]

local DogModel = require(script.Parent.DogModel)

export type Gait = "Idle" | "Walk" | "Run"

export type DogAnimation = {
	step: (self: DogAnimation, dt: number, speed: number) -> number,
	pose: (self: DogAnimation) -> { [string]: CFrame },
	woof: (self: DogAnimation, count: number?) -> (),
	gait: (self: DogAnimation) -> Gait,
	isBarking: (self: DogAnimation) -> boolean,
}

local TAU = 2 * math.pi
local rad = math.rad
local sin, cos = math.sin, math.cos

-- Speeds (studs/s) where the gaits blend. Players walk at 16, so a dog that
-- keeps up walks, and a dog that has to catch up runs.
local MOVE_START, MOVE_FULL = 0.6, 2.5
local RUN_START, RUN_FULL = 17.5, 21
-- Gait cycles per second (they speed up a little with speed).
local WALK_RATE, WALK_RATE_PER_STUD = 1.5, 0.055
local RUN_RATE, RUN_RATE_PER_STUD = 2.1, 0.05

-- Random WOOFs: the first one comes soon after spawning; after each burst of
-- 1-3 barks ends, the next one comes `every` (default 3.5..8) seconds later.
local FIRST_WOOF_MIN, FIRST_WOOF_MAX = 1.5, 3
local EVERY = { 3.5, 8 }
local BARK_GAP = 0.3 -- seconds between the barks of a "woof woof"
local BARK_LENGTH = 0.6 -- seconds one bark animates

local BLINK_MIN, BLINK_MAX = 2, 5.5
local BLINK_LENGTH = 0.13

type Impl = {
	_rng: Random,
	_every: { number },
	_time: number,
	_phase: number, -- gait cycle, 0..1
	_wag: number, -- tail wag cycle, 0..1
	_move: number, -- 0 = standing .. 1 = moving (smoothed)
	_run: number, -- 0 = walking .. 1 = running (smoothed)
	_barks: { number }, -- start times of barks still animating
	_queued: { number }, -- start times of upcoming barks
	_nextWoof: number,
	_nextBlink: number,
	_blinkUntil: number,
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

-- One bark over its age in seconds: a quick crouch, a fast pop, a short hold
-- and a springy settle (with one small undershoot).
local function barkCurve(age: number): (number, number)
	local crouch = if age < 0.09 then sin(math.pi * age / 0.09) else 0
	local pop = 0
	if age >= 0.06 and age < 0.13 then
		local u = (age - 0.06) / 0.07
		pop = 1 - (1 - u) * (1 - u)
	elseif age >= 0.13 and age < 0.24 then
		pop = 1 - 0.1 * (age - 0.13) / 0.11
	elseif age >= 0.24 and age < BARK_LENGTH then
		local v = (age - 0.24) / (BARK_LENGTH - 0.24)
		pop = 0.9 * (1 - v) * (1 - v) * cos(v * math.pi * 2)
	end
	return crouch, pop
end

local DogAnimation = {}

DogAnimation.BarkLength = BARK_LENGTH
DogAnimation.Every = table.freeze(EVERY)

function DogAnimation.new(seed: number?, every: { number }?): DogAnimation
	local rng = if seed then Random.new(seed) else Random.new()
	local interval = every or EVERY
	local self: Impl = {
		_rng = rng,
		_every = interval,
		_time = 0,
		_phase = 0,
		_wag = rng:NextNumber(),
		_move = 0,
		_run = 0,
		_barks = {},
		_queued = {},
		_nextWoof = if interval[1] < math.huge
			then rng:NextNumber(math.min(FIRST_WOOF_MIN, interval[1]), math.min(FIRST_WOOF_MAX, interval[2]))
			else math.huge,
		_nextBlink = rng:NextNumber(BLINK_MIN, BLINK_MAX),
		_blinkUntil = -1,
		_pose = {},
	}
	return (setmetatable(self, AnimationClass) :: any) :: DogAnimation
end

-- Queues a burst of barks right away (random 1-3 when `count` is nil).
function AnimationClass.woof(self: Impl, count: number?)
	local rng = self._rng
	local barks = count
	if barks == nil then
		local roll = rng:NextNumber()
		barks = if roll < 0.6 then 1 elseif roll < 0.92 then 2 else 3
	end
	assert(barks ~= nil and barks >= 1, "woof needs at least one bark")
	local start = self._time
	local last = self._queued[#self._queued] or self._barks[#self._barks]
	if last and last + BARK_GAP > start then
		start = last + BARK_GAP
	end
	for index = 0, barks - 1 do
		-- The first bark is immediate; the following ones get a little jitter.
		local jitter = if index > 0 then rng:NextNumber(0, 0.05) else 0
		table.insert(self._queued, start + index * BARK_GAP + jitter)
	end
	local finished = self._queued[#self._queued] + BARK_LENGTH
	local every = self._every
	self._nextWoof = if every[1] < math.huge then finished + rng:NextNumber(every[1], every[2]) else math.huge
end

-- Advances time; returns how many barks started (play the sound/bubble for each).
function AnimationClass.step(self: Impl, dt: number, speed: number): number
	dt = math.clamp(dt, 0, 0.25)
	self._time += dt
	local now = self._time

	local follow = 1 - math.exp(-10 * dt)
	self._move += (smoothstep(MOVE_START, MOVE_FULL, speed) - self._move) * follow
	self._run += (smoothstep(RUN_START, RUN_FULL, speed) - self._run) * follow
	local rate = lerp(WALK_RATE + WALK_RATE_PER_STUD * speed, RUN_RATE + RUN_RATE_PER_STUD * speed, self._run)
	self._phase = (self._phase + dt * rate * self._move) % 1

	local wagRate = lerp(lerp(2.6, 3.2, self._move), 4.6, self._run * self._move)
	if #self._barks > 0 then
		wagRate *= 1.6
	end
	self._wag = (self._wag + dt * wagRate) % 1

	if #self._queued == 0 and now >= self._nextWoof then
		AnimationClass.woof(self)
	end
	local started = 0
	while self._queued[1] ~= nil and self._queued[1] <= now do
		table.insert(self._barks, table.remove(self._queued, 1) :: number)
		started += 1
	end
	for index = #self._barks, 1, -1 do
		if now - self._barks[index] > BARK_LENGTH then
			table.remove(self._barks, index)
		end
	end

	if now >= self._nextBlink then
		self._blinkUntil = now + BLINK_LENGTH
		-- Now and then a quick double blink.
		local gap = if self._rng:NextNumber() < 0.2 then 0.28 else self._rng:NextNumber(BLINK_MIN, BLINK_MAX)
		self._nextBlink = now + gap
	end
	return started
end

function AnimationClass.gait(self: Impl): Gait
	if self._move < 0.5 then
		return "Idle"
	end
	return if self._run < 0.5 then "Walk" else "Run"
end

function AnimationClass.isBarking(self: Impl): boolean
	return #self._barks > 0
end

function AnimationClass.pose(self: Impl): { [string]: CFrame }
	local t = self._time
	local move, run = self._move, self._run
	local idleW = 1 - move
	local walkW = move * (1 - run)
	local runW = move * run
	local p = TAU * self._phase
	local s, c = sin(p), cos(p)

	-- Bark layer (overlapping barks add up).
	local crouch, pop = 0, 0
	for _, start in self._barks do
		local barkCrouch, barkPop = barkCurve(t - start)
		crouch += barkCrouch
		pop += barkPop
	end
	crouch = math.min(crouch, 1)
	pop = math.clamp(pop, -0.4, 1.25)
	local lift = math.max(pop, 0)

	-- Body: idle bounce, walk waddle (bounce twice per cycle + rock side to
	-- side), run bound (big hops + rocking-horse pitch), bark hop. Only the
	-- positive part of the bark moves the body so the paws never sink.
	local bodyY = idleW * 0.035 * (0.5 + 0.5 * sin(TAU * 1.6 * t))
		+ walkW * 0.12 * math.abs(c)
		+ runW * (0.12 + 0.22 * (0.5 + 0.5 * sin(p - 1.2)))
		+ 0.24 * lift
		- 0.025 * crouch
	local bodyPitch = walkW * rad(2) * sin(2 * p) + runW * (rad(-5) + rad(12) * c) + rad(9) * lift
	local bodyYaw = walkW * rad(5) * s
	local bodyRoll = idleW * rad(2.5) * sin(TAU * 0.45 * t) + walkW * rad(7) * s

	-- Head: idle looks around with a curious tilt; it nods with the steps,
	-- counters the body so it stays fairly level, and snaps up to bark.
	local headPitch = idleW * rad(4) * sin(TAU * 1.6 * t + 0.9)
		+ walkW * rad(5) * cos(2 * p)
		- runW * 0.6 * (rad(-5) + rad(12) * c)
		+ rad(28) * pop
		- rad(16) * crouch
	local headYaw = idleW * rad(14) * sin(TAU * 0.17 * t + 1.1) - walkW * rad(3) * s
	local headRoll = idleW * rad(10) * sin(TAU * 0.3 * t) - walkW * rad(5) * s
	local headForward = -0.1 * pop

	-- Ears: flop behind the steps, sweep back when running, flap up to bark.
	local earPitch = idleW * rad(3) * sin(TAU * 1.6 * t + 1.7)
		+ walkW * rad(8) * sin(2 * p - 0.5)
		+ runW * (rad(50) + rad(12) * sin(2 * p))
		- rad(12) * crouch
	local earOut = walkW * rad(10) * sin(2 * p - 1.1) + runW * rad(8) + rad(28) * pop

	-- Tail: always wagging; streams back when running.
	local wagAmplitude = lerp(rad(32), rad(20), runW) + (if #self._barks > 0 then rad(12) else 0)
	local tailYaw = wagAmplitude * sin(TAU * self._wag)
	local tailPitch = (idleW + walkW) * rad(-10) + runW * rad(25) - rad(10) * lift

	-- Legs: diagonal pairs when walking (lifted while they swing forward),
	-- front pair / back pair when running, paws up when barking.
	local walkSwing = walkW * rad(34) * s
	local walkLift = walkW * 0.08
	local frontRun = runW * rad(52)
	local backRun = runW * rad(48)
	local frontBark = rad(28) * lift
	local backBark = rad(-10) * lift

	-- Mouth: open to bark and to pant while running; eyes squint on the bark.
	local open = if pop > 0.25 or runW > 0.5 then 1 else 0
	local droop = runW * (rad(28) + rad(10) * sin(4 * p)) + rad(12) * lift
	local blink = if t < self._blinkUntil or pop > 0.55 then 1 else 0

	local pose = self._pose
	pose.Body = CFrame.new(0, bodyY, 0) * CFrame.fromEulerAnglesYXZ(bodyPitch, bodyYaw, bodyRoll)
	pose.Head = CFrame.new(0, 0, headForward) * CFrame.fromEulerAnglesYXZ(headPitch, headYaw, headRoll)
	pose.EarL = CFrame.fromEulerAnglesYXZ(earPitch, 0, earOut)
	pose.EarR = CFrame.fromEulerAnglesYXZ(earPitch, 0, -earOut)
	pose.Tail = CFrame.fromEulerAnglesYXZ(tailPitch, tailYaw, 0)
	pose.LegFL = CFrame.new(0, walkLift * math.max(0, c), 0) * CFrame.Angles(walkSwing + frontRun * s + frontBark, 0, 0)
	pose.LegBR = CFrame.new(0, walkLift * math.max(0, c), 0)
		* CFrame.Angles(walkSwing - backRun * sin(p + 0.35) + backBark, 0, 0)
	pose.LegFR = CFrame.new(0, walkLift * math.max(0, -c), 0)
		* CFrame.Angles(-walkSwing + frontRun * sin(p - 0.3) + frontBark, 0, 0)
	pose.LegBL = CFrame.new(0, walkLift * math.max(0, -c), 0)
		* CFrame.Angles(-walkSwing - backRun * sin(p + 0.05) + backBark, 0, 0)
	pose.Jaw = CFrame.new(DogModel.JawOpenOffset * open)
	pose.Tongue = CFrame.Angles(-droop * open, 0, runW * rad(6) * sin(3 * p))
	pose.Lids = CFrame.new(DogModel.BlinkOffset * blink)
	return pose
end

return table.freeze(DogAnimation)

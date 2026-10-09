--!strict
--[[
	DragonAnimation
	Procedural cartoon animation for the dragon pet. It flies: it hovers next
	to its owner flapping its wings (a quick downstroke that lifts the body,
	a slower upstroke), legs dangling and tail swaying. Flying after its owner
	it leans into the flight and flaps harder; hurrying, it stretches out with
	its legs tucked back. When its owner stands still for a while it lands,
	folds its wings and sits, looking around, until its owner moves again.
	Now and then it breathes fire: it rears its head back to take a breath,
	then throws it forward with the jaw wide open and a stream of flames, the
	wings beating hard against the recoil.

	Pure math, no Instances, so it is deterministic and testable:

	  local anim = DragonAnimation.new(seed, every) -- every = { min, max } seconds between fire breaths (math.huge = never)
	  local breaths = anim:step(dt, speed) -- fire breaths whose flames came out during this step
	  local pose = anim:pose()             -- { [bone]: CFrame } for PetRig:solve

	The pose table is reused between frames; copy it if you need to keep it.
]]

local DragonModel = require(script.Parent.DragonModel)

export type Gait = "Idle" | "Walk" | "Run"

export type DragonAnimation = {
	step: (self: DragonAnimation, dt: number, speed: number) -> number,
	pose: (self: DragonAnimation) -> { [string]: CFrame },
	react: (self: DragonAnimation, count: number?) -> (),
	gait: (self: DragonAnimation) -> Gait,
	isReacting: (self: DragonAnimation) -> boolean,
	isLanded: (self: DragonAnimation) -> boolean,
	height: (self: DragonAnimation) -> number,
}

local TAU = 2 * math.pi
local rad = math.rad
local sin, cos = math.sin, math.cos

-- Speeds (studs/s) where the gaits blend, same as the other pets.
local MOVE_START, MOVE_FULL = 0.6, 2.5
local RUN_START, RUN_FULL = 17.5, 21
-- Wing beats per second.
local HOVER_RATE, FLY_RATE, RUN_RATE = 1.9, 2.3, 2.9
-- How high it flies (studs from the ground to the soles of its feet), and
-- how much the body rises and falls with each wing beat.
local HOVER_HEIGHT = 2.2
local BOB = 0.2
-- Standing still this long makes it land; moving again makes it take off.
local LAND_AFTER = 6
local LAND_TIME, TAKEOFF_TIME = 0.9, 0.35

-- Fire breath: it takes a breath, the flames come out (that is when the
-- sound plays), they last a while, then it closes its mouth.
local FIRST_BREATH_MIN, FIRST_BREATH_MAX = 3, 6
local EVERY = { 6, 12 }
local INHALE = 0.45
local FLAMES = 1.3
local FLAME_GAP = 0.06 -- seconds between the flames coming out (and going out)
local BREATH_LENGTH = INHALE + FLAMES + 0.4
local MAX_QUEUED = 3

local BLINK_MIN, BLINK_MAX = 2.5, 6
local BLINK_LENGTH = 0.14
local LOOK_GAP_MIN, LOOK_GAP_MAX = 1.5, 4

local LEGS = { "LegFR", "LegFL", "LegBR", "LegBL" }

type Impl = {
	_rng: Random,
	_every: { number },
	_time: number,
	_flap: number, -- wing beat cycle, 0..1
	_sway: number, -- tail and leg sway cycle, 0..1
	_move: number, -- 0 = hovering .. 1 = flying after its owner (smoothed)
	_run: number, -- 0 = flying .. 1 = hurrying (smoothed)
	_air: number, -- 0 = landed .. 1 = flying
	_still: number, -- seconds its owner has been standing still
	_breathStart: number,
	_breathSignalled: boolean,
	_pending: number,
	_nextBreath: number,
	_blinkUntil: number,
	_nextBlink: number,
	_look: Vector2, -- head yaw, pitch (smoothed)
	_lookTarget: Vector2,
	_nextLook: number,
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

-- One wing beat, -1 (wings down) .. 1 (wings up), for phase 0..1: the
-- downstroke takes 40% of the beat, the upstroke the rest.
local function beat(p: number): number
	if p < 0.4 then
		return cos(math.pi * p / 0.4)
	end
	return -cos(math.pi * (p - 0.4) / 0.6)
end

local DragonAnimation = {}

DragonAnimation.HoverHeight = HOVER_HEIGHT
DragonAnimation.Inhale = INHALE
DragonAnimation.Flames = FLAMES
DragonAnimation.BreathLength = BREATH_LENGTH
DragonAnimation.LandAfter = LAND_AFTER
DragonAnimation.Every = table.freeze(EVERY)

function DragonAnimation.new(seed: number?, every: { number }?): DragonAnimation
	local rng = if seed then Random.new(seed) else Random.new()
	local interval = every or EVERY
	local self: Impl = {
		_rng = rng,
		_every = interval,
		_time = 0,
		_flap = 0,
		_sway = 0,
		_move = 0,
		_run = 0,
		_air = 1,
		_still = 0,
		_breathStart = -math.huge,
		_breathSignalled = true,
		_pending = 0,
		_nextBreath = if interval[1] < math.huge
			then rng:NextNumber(math.min(FIRST_BREATH_MIN, interval[1]), math.min(FIRST_BREATH_MAX, interval[2]))
			else math.huge,
		_blinkUntil = -1,
		_nextBlink = rng:NextNumber(BLINK_MIN, BLINK_MAX),
		_look = Vector2.zero,
		_lookTarget = Vector2.zero,
		_nextLook = rng:NextNumber(0.5, LOOK_GAP_MAX),
		_pose = {},
	}
	return (setmetatable(self, AnimationClass) :: any) :: DragonAnimation
end

-- Asks for `count` fire breaths (1 when nil). The first one starts on the
-- next step, or right after the one going on; the others follow back to
-- back.
function AnimationClass.react(self: Impl, count: number?)
	local breaths = count or 1
	assert(breaths >= 1, "react needs at least one fire breath")
	self._pending = math.min(self._pending + breaths, MAX_QUEUED)
end

-- Advances time; returns how many fire breaths had their flames come out
-- during this step (play the sound and show the bubble for each).
function AnimationClass.step(self: Impl, dt: number, speed: number): number
	dt = math.clamp(dt, 0, 0.25)
	self._time += dt
	local now = self._time
	local rng = self._rng

	local follow = 1 - math.exp(-10 * dt)
	self._move += (smoothstep(MOVE_START, MOVE_FULL, speed) - self._move) * follow
	self._run += (smoothstep(RUN_START, RUN_FULL, speed) - self._run) * follow

	-- Lands after its owner stood still for a while, takes off as soon as
	-- they move.
	self._still = if speed > MOVE_START then 0 else self._still + dt
	if self._still >= LAND_AFTER then
		self._air = math.max(self._air - dt / LAND_TIME, 0)
	else
		self._air = math.min(self._air + dt / TAKEOFF_TIME, 1)
	end

	-- Breathing fire takes strong wing beats; landed, the wings rest.
	local breathing = now - self._breathStart < BREATH_LENGTH
	local rate = lerp(lerp(HOVER_RATE, FLY_RATE, self._move), RUN_RATE, self._run)
	if breathing then
		rate = math.max(rate, RUN_RATE)
	end
	self._flap = (self._flap + dt * rate * math.max(self._air, 0.15)) % 1
	self._sway = (self._sway + dt * 0.45) % 1

	local started = 0
	if not breathing and (self._pending > 0 or now >= self._nextBreath) then
		self._pending = math.max(self._pending - 1, 0)
		self._breathStart = now
		self._breathSignalled = false
		local every = self._every
		self._nextBreath = if every[1] < math.huge
			then now + BREATH_LENGTH + rng:NextNumber(every[1], every[2])
			else math.huge
	end
	if not self._breathSignalled and now - self._breathStart >= INHALE then
		self._breathSignalled = true
		started = 1
	end

	if now >= self._nextBlink then
		self._blinkUntil = now + BLINK_LENGTH
		self._nextBlink = now + if rng:NextNumber() < 0.2 then 0.3 else rng:NextNumber(BLINK_MIN, BLINK_MAX)
	end
	if now >= self._nextLook then
		self._lookTarget = Vector2.new(rad(rng:NextNumber(-35, 35)), rad(rng:NextNumber(-10, 12)))
		self._nextLook = now + rng:NextNumber(LOOK_GAP_MIN, LOOK_GAP_MAX)
	end
	self._look += (self._lookTarget - self._look) * (1 - math.exp(-4 * dt))
	return started
end

function AnimationClass.gait(self: Impl): Gait
	if self._move < 0.5 then
		return "Idle"
	end
	return if self._run < 0.5 then "Walk" else "Run"
end

function AnimationClass.isReacting(self: Impl): boolean
	return self._time - self._breathStart < BREATH_LENGTH
end

function AnimationClass.isLanded(self: Impl): boolean
	return self._air <= 0
end

-- Height of the soles of its feet over the ground, without the bob of the
-- wing beats.
function AnimationClass.height(self: Impl): number
	return HOVER_HEIGHT * smoothstep(0, 1, self._air)
end

function AnimationClass.pose(self: Impl): { [string]: CFrame }
	local t = self._time
	local move, run = self._move, self._run
	local air = smoothstep(0, 1, self._air)
	local landed = 1 - air
	local wings = beat(self._flap)
	local sway = TAU * self._sway

	-- Fire breath: `inhale` rears the head back, `fire` throws it forward
	-- with the jaw open, `breath` blends the whole thing in and out.
	local age = t - self._breathStart
	local breath = smoothstep(0, 0.15, age) * (1 - smoothstep(BREATH_LENGTH - 0.3, BREATH_LENGTH, age))
	local inhale = smoothstep(0, INHALE, age) * (1 - smoothstep(INHALE, INHALE + 0.12, age))
	local fire = smoothstep(INHALE - 0.05, INHALE + 0.1, age)
		* (1 - smoothstep(INHALE + FLAMES - 0.1, INHALE + FLAMES + 0.1, age))
	if age >= BREATH_LENGTH then
		breath, inhale, fire = 0, 0, 0
	end

	-- Body: flies at its height, rising on each downstroke, leans into the
	-- flight; pushed back by the recoil of the flames.
	local height = HOVER_HEIGHT * air + BOB * air * -wings * (1 - 0.4 * run)
	local pitch = -rad(10) * move * air - rad(8) * run * air + rad(8) * inhale - rad(4) * fire
	local roll = rad(3) * sin(sway) * air * (1 - move)
	local recoil = 0.25 * fire
	local pose = self._pose
	pose.Body = CFrame.new(0, height, recoil) * CFrame.Angles(pitch, 0, roll)

	-- Head: looks around (more when landed), keeps level against the body's
	-- lean, rears back to inhale and thrusts forward to breathe fire.
	local look = self._look * (1 - breath) * (1 - 0.7 * move)
	local headPitch = -pitch * 0.8
		+ look.Y
		+ rad(28) * inhale
		- rad(16) * fire
		+ rad(3) * sin(TAU * self._flap) * air
		+ rad(2) * sin(TAU * 0.4 * t) * landed
	local shake = rad(3) * sin(TAU * 9 * t) * fire
	pose.Head = CFrame.Angles(headPitch, look.X + shake, 0)

	-- Jaw: a little open to inhale, wide open for the flames.
	pose.Jaw = CFrame.Angles(-rad(10) * inhale - rad(32) * fire, 0, 0)

	-- Flames: they burst out of the mouth one after the other, flicker and
	-- tumble, and go out in the same order, so the stream breaks off the
	-- mouth before it ends. A flame is either out or hidden in the head,
	-- never on its way through the face.
	local fireAge = age - INHALE
	for index, name in DragonModel.Flames do
		local i = index - 1
		if
			age < BREATH_LENGTH
			and fireAge >= FLAME_GAP * i
			and fireAge < FLAMES - FLAME_GAP * (#DragonModel.Flames - i)
		then
			local offset = DragonModel.FlameStart + DragonModel.FlameSpacing * i
			local flicker = Vector3.new(
				0.1 * sin(TAU * (7 + index) * t + index),
				0.08 * sin(TAU * (9 - index) * t + 2 * index),
				0.15 * sin(TAU * 6 * t + index)
			)
			pose[name] = CFrame.new(offset + flicker * (0.4 + 0.3 * i))
				* CFrame.Angles(TAU * 1.3 * t + index, TAU * (0.9 + 0.2 * index) * t, index)
		else
			pose[name] = CFrame.identity
		end
	end

	-- Eyelids: blinks, and squints while it breathes fire.
	local blink = if t < self._blinkUntil or fire > 0.5 then 1 else 0
	pose.Lids = CFrame.new(DragonModel.BlinkOffset * blink)

	-- Wings: they beat in the air (harder when flying fast or breathing
	-- fire), and fold back over the body when it lands.
	local amplitude = lerp(rad(38), rad(48), math.max(run, breath))
	local up = rad(6) + amplitude * wings
	local spread = up * air + landed * rad(14)
	local fold = landed * rad(58) + air * rad(8) * run
	pose.WingR = CFrame.Angles(0, -fold, spread)
	pose.WingL = CFrame.Angles(0, fold, -spread)

	-- Tail: a slow wave down its three pieces, streaming straight behind
	-- when it flies fast, drooping a little when landed.
	local tailSway = (1 - 0.6 * move) * rad(14)
	local tailLift = -pitch * 0.6 - rad(3) * landed
	pose.Tail1 = CFrame.Angles(tailLift + rad(3) * sin(TAU * self._flap - 0.5) * air, tailSway * sin(sway), 0)
	pose.Tail2 = CFrame.Angles(tailLift, tailSway * sin(sway - 0.9), 0)
	pose.Tail3 = CFrame.Angles(tailLift + rad(4) * landed, tailSway * 1.2 * sin(sway - 1.8), 0)

	-- Legs: dangle and sway in the air, tucked back when it flies fast;
	-- straight when landed.
	for index, name in LEGS do
		local front = index <= 2
		local dangle = rad(6) * sin(sway * 2 + index) + rad(5) * sin(TAU * self._flap + (if front then 0 else 1))
		local tuck = -rad(if front then 25 else 40) * move - rad(30) * run
		pose[name] = CFrame.Angles((dangle + tuck) * air, 0, 0)
	end
	return pose
end

return table.freeze(DragonAnimation)

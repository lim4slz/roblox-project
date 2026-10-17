--!strict
-- Procedural arm animations (throw, slash, lunge, recoil) built from short
-- tweens on the right shoulder joint. No animation assets need uploading, and
-- the same code drives both R6 and R15 rigs.
--
-- We tilt the shoulder's C0 around the torso's sideways axis. C0 sits
-- underneath whatever Roblox's Animator is playing, so these swings layer on
-- top of the default walk/tool-hold animations instead of fighting them.
-- C0 edits are local, so every client animates every player itself when the
-- server broadcasts an ActionFx event.

local TweenService = game:GetService("TweenService")

local ArmAnimator = {}

type Keyframe = { angle: number, roll: number, time: number, style: Enum.EasingStyle? }

-- angle: + swings the arm forward/up, - pulls it back. roll twists across.
local ACTIONS: { [string]: { Keyframe } } = {
	Throw = {
		{ angle = -0.9, roll = 0.15, time = 0.1 },
		{ angle = 1.7, roll = -0.1, time = 0.12, style = Enum.EasingStyle.Back },
		{ angle = 0, roll = 0, time = 0.3 },
	},
	Slash = {
		{ angle = 2.3, roll = 0.4, time = 0.07 },
		{ angle = 0.4, roll = -0.5, time = 0.12, style = Enum.EasingStyle.Back },
		{ angle = 0, roll = 0, time = 0.22 },
	},
	Lunge = {
		{ angle = 1.6, roll = 0, time = 0.08 },
		{ angle = 1.6, roll = 0, time = 0.25 },
		{ angle = 0, roll = 0, time = 0.25 },
	},
	Fire = {
		{ angle = 0.35, roll = 0, time = 0.05 },
		{ angle = 0, roll = 0, time = 0.25 },
	},
}

type JointState = {
	motor: Motor6D,
	baseC0: CFrame,
	value: CFrameValue,
	tween: Tween?,
	runId: number,
}

local joints: { [Motor6D]: JointState } = setmetatable({}, { __mode = "k" }) :: any

local function findShoulder(character: Model): Motor6D?
	-- R15
	local upperArm = character:FindFirstChild("RightUpperArm")
	local shoulder = upperArm and upperArm:FindFirstChild("RightShoulder")
	if shoulder and shoulder:IsA("Motor6D") then
		return shoulder
	end
	-- R6
	local torso = character:FindFirstChild("Torso")
	local r6Shoulder = torso and torso:FindFirstChild("Right Shoulder")
	if r6Shoulder and r6Shoulder:IsA("Motor6D") then
		return r6Shoulder
	end
	return nil
end

local function stateFor(motor: Motor6D): JointState
	local state = joints[motor]
	if state then
		return state
	end
	local value = Instance.new("CFrameValue")
	value.Value = CFrame.identity
	local created: JointState = { motor = motor, baseC0 = motor.C0, value = value, tween = nil, runId = 0 }
	value.Changed:Connect(function(offset)
		-- Rotate in the torso's frame, about the shoulder's position.
		local base = created.baseC0
		motor.C0 = CFrame.new(base.Position) * offset * base.Rotation
	end)
	joints[motor] = created
	return created
end

function ArmAnimator.play(character: Model?, action: string)
	local keyframes = ACTIONS[action]
	if not character or not keyframes then
		return
	end
	local motor = findShoulder(character)
	if not motor then
		return
	end
	local state = stateFor(motor)
	state.runId += 1
	local runId = state.runId

	task.spawn(function()
		for _, keyframe in keyframes do
			if state.runId ~= runId or not motor.Parent then
				return
			end
			if state.tween then
				state.tween:Cancel()
			end
			local tween = TweenService:Create(
				state.value,
				TweenInfo.new(keyframe.time, keyframe.style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Value = CFrame.Angles(keyframe.angle, 0, keyframe.roll) }
			)
			state.tween = tween
			tween:Play()
			task.wait(keyframe.time)
		end
	end)
end

return ArmAnimator

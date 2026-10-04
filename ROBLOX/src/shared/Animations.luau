local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local RunService = game:GetService("RunService")

local Assets = require(script.Parent.Assets)
local Config = require(script.Parent.Config)

local Animations = {}

local cache: { [string]: Animation } = {}

local function animation(name: string): Animation?
	if cache[name] then
		return cache[name]
	end
	local id = Assets.id(Assets.Animations[name])
	if id == nil and RunService:IsStudio() then
		local folder = script.Parent:FindFirstChild("KeyframeSequences")
		local kfs = folder and folder:FindFirstChild(name)
		if kfs and kfs:IsA("KeyframeSequence") then
			id = KeyframeSequenceProvider:RegisterKeyframeSequence(kfs)
		end
	end
	if id == nil then
		warn(`[Ember] animação {name} sem ID. Publique o KeyframeSequence e cole o ID em Assets.Animations.`)
		return nil
	end
	local anim = Instance.new("Animation")
	anim.Name = name
	anim.AnimationId = id
	cache[name] = anim
	return anim
end

function Animations.load(character: Model, name: string): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local anim = animation(name)
	if animator == nil or anim == nil then
		return nil
	end
	local track = animator:LoadAnimation(anim)
	track.Priority = Config.AnimationPriority
	track.Looped = false
	return track
end

return Animations

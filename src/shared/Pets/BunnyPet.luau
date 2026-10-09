--!strict
--[[
	BunnyPet
	The bunny companion on the client: builds the blocky bunny from
	BunnyModel, follows a character (PetFollow), hops after it
	(BunnyAnimation) and sells every binky with a pop-up bubble and a squeak.

	Like the other pets it is cosmetic and local to this client: anchored
	parts that never collide, moved with one workspace:BulkMoveTo call per
	frame.

	  local bunny = BunnyPet.new(character, parentFolder, { raycastParams = params })
	  bunny:update(dt) -- every frame (PreRender)
	  bunny:react()    -- binky now
	  bunny:destroy()
]]

local Workspace = game:GetService("Workspace")

local BunnyAnimation = require(script.Parent.BunnyAnimation)
local BunnyModel = require(script.Parent.BunnyModel)
local PetFollow = require(script.Parent.PetFollow)
local PetKit = require(script.Parent.PetKit)
local PetRig = require(script.Parent.PetRig)

local SQUEAK_PITCH_MIN, SQUEAK_PITCH_MAX = 0.95, 1.2
local BUBBLE_STYLE: PetKit.BubbleStyle = {
	name = "HopBubble",
	textColor = Color3.fromRGB(255, 170, 205),
	strokeColor = Color3.fromRGB(70, 22, 48),
}

local MAX_DT = 0.1

type Impl = {
	model: Model,
	_character: Model,
	_raycastParams: RaycastParams,
	_parts: { BasePart },
	_cframes: { CFrame },
	_rig: PetRig.PetRig,
	_animation: BunnyAnimation.BunnyAnimation,
	_follow: PetFollow.State,
	_spot: Vector3,
	_scale: number,
	_parent: Instance,
	_placed: boolean,
	_head: BasePart,
	_voice: PetKit.Voice,
	_texts: { string },
	_bubbles: PetKit.Bubbles,
	_rng: Random,
}

local BunnyClass = {}
BunnyClass.__index = BunnyClass

local BunnyPet = {}

BunnyPet.Defaults = table.freeze({
	spot = Vector3.new(5.2, 0, 0.6), -- on the owner's right, further out than the dog
	-- "Squeeze Toy Squeaky Rubber With Noisemaker Hits 9" by Pro Sound
	-- Effects, licensed by Roblox for every experience: two quick squeaks.
	sound = "rbxassetid://9125994553",
	soundStart = 0,
	volume = 0.5,
	texts = table.freeze({ "Boing!", "Hop!", "Wheee!", "Yay!" }),
	every = BunnyAnimation.Every,
}) :: PetKit.Defaults

function BunnyPet.new(character: Model, parent: Instance, options: PetKit.Options): PetKit.Pet
	local settings = PetKit.settings(options, BunnyPet.Defaults, "Bunny")
	local seed = options.seed
	local model, parts, definition = PetKit.build("Bunny", BunnyModel.Definition, options.template, settings.scale)
	local head = model:FindFirstChild(BunnyModel.HeadPart) :: BasePart

	local self: Impl = {
		model = model,
		_character = character,
		_raycastParams = options.raycastParams,
		_parts = parts,
		_cframes = table.create(#parts),
		_rig = PetRig.new(definition, settings.scale),
		_animation = BunnyAnimation.new(if seed then seed + 1 else nil, settings.every),
		_follow = PetFollow.new(Vector3.zero, 0, settings.spot),
		_spot = settings.spot,
		_scale = settings.scale,
		_parent = parent,
		_placed = false,
		_head = head,
		_voice = PetKit.voice(head, "Squeak", settings.sound, settings.volume, settings.soundStart),
		_texts = settings.texts,
		_bubbles = PetKit.bubbles(BUBBLE_STYLE, settings.scale),
		_rng = if seed then Random.new(seed) else Random.new(),
	}
	local bunny = (setmetatable(self, BunnyClass) :: any) :: PetKit.Pet
	bunny:update(0)
	return bunny
end

-- Puts the bunny at its spot next to the character and shows it. With
-- StreamingEnabled a character can arrive before its root part does.
function BunnyClass._place(self: Impl, root: BasePart)
	local goal = PetFollow.goal(root.CFrame, self._spot)
	local look = root.CFrame.LookVector
	self._follow = PetFollow.new(
		Vector3.new(goal.X, PetKit.feetHeight(root, self._character), goal.Z),
		math.atan2(-look.X, -look.Z),
		self._spot
	)
	self._placed = true
	self.model.Parent = self._parent
end

function BunnyClass._squeak(self: Impl)
	local rng = self._rng
	self._voice:play(rng:NextNumber(SQUEAK_PITCH_MIN, SQUEAK_PITCH_MAX))
	if #self._texts > 0 then
		self._bubbles:pop(self._head, self.model, self._texts[rng:NextInteger(1, #self._texts)], rng)
	end
end

function BunnyClass.update(self: Impl, dt: number)
	dt = math.min(dt, MAX_DT)
	local root = PetKit.rootOf(self._character)
	if root and not self._placed then
		BunnyClass._place(self, root)
	end
	if not self._placed then
		return
	end
	if root then
		local ground = PetKit.groundBelow(self._follow.position, root, self._character, self._raycastParams)
		PetFollow.step(self._follow, root.CFrame, ground, dt)
	end

	-- A bigger bunny takes longer hops for the same speed.
	local binkies = self._animation:step(dt, self._follow.speed / self._scale)
	self._rig:solve(PetFollow.cframe(self._follow), self._animation:pose(), self._cframes)
	Workspace:BulkMoveTo(self._parts, self._cframes, Enum.BulkMoveMode.FireCFrameChanged)

	for _ = 1, binkies do
		BunnyClass._squeak(self)
	end
	self._bubbles:update(dt)
end

-- Makes the bunny hop for joy right now (`count` binkies in a row, 1 when nil).
function BunnyClass.react(self: Impl, count: number?)
	self._animation:react(count)
end

function BunnyClass.destroy(self: Impl)
	self._bubbles:clear()
	self.model:Destroy()
end

return table.freeze(BunnyPet)

--!strict
--[[
	DogPet
	The dog companion on the client: builds the blocky dog from DogModel,
	follows a character (PetFollow), animates it (DogAnimation) and sells every
	WOOF with a pop-up bubble and a bark.

	The dog is cosmetic and local to this client: its parts are anchored, never
	collide and are moved with one workspace:BulkMoveTo call per frame (no
	physics, no network ownership).

	  local dog = DogPet.new(character, parentFolder, { raycastParams = params })
	  dog:update(dt) -- every frame (PreRender)
	  dog:react()    -- WOOF now
	  dog:destroy()
]]

local Workspace = game:GetService("Workspace")

local DogAnimation = require(script.Parent.DogAnimation)
local DogModel = require(script.Parent.DogModel)
local PetFollow = require(script.Parent.PetFollow)
local PetKit = require(script.Parent.PetKit)
local PetRig = require(script.Parent.PetRig)

local BARK_PITCH_MIN, BARK_PITCH_MAX = 1.05, 1.3
local BUBBLE_STYLE: PetKit.BubbleStyle = {
	name = "WoofBubble",
	textColor = Color3.fromRGB(255, 255, 255),
	strokeColor = Color3.fromRGB(45, 28, 12),
}

local MAX_DT = 0.1

type Impl = {
	model: Model,
	_character: Model,
	_raycastParams: RaycastParams,
	_parts: { BasePart },
	_cframes: { CFrame },
	_rig: PetRig.PetRig,
	_animation: DogAnimation.DogAnimation,
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

local DogClass = {}
DogClass.__index = DogClass

local DogPet = {}

DogPet.Defaults = table.freeze({
	spot = PetFollow.DefaultOffset, -- on the owner's right
	-- "beagle barking", a public audio from the Creator Store.
	sound = "rbxassetid://7103147161",
	soundStart = 0,
	volume = 0.6,
	texts = table.freeze({ "WOOF!", "Woof!", "WOOF!", "WOOF!!" }),
	every = DogAnimation.Every,
}) :: PetKit.Defaults

function DogPet.new(character: Model, parent: Instance, options: PetKit.Options): PetKit.Pet
	local settings = PetKit.settings(options, DogPet.Defaults, "Dog")
	local seed = options.seed
	local model, parts, definition = PetKit.build("Dog", DogModel.Definition, options.template, settings.scale)
	local head = model:FindFirstChild(DogModel.HeadPart) :: BasePart

	local self: Impl = {
		model = model,
		_character = character,
		_raycastParams = options.raycastParams,
		_parts = parts,
		_cframes = table.create(#parts),
		_rig = PetRig.new(definition, settings.scale),
		_animation = DogAnimation.new(if seed then seed + 1 else nil, settings.every),
		_follow = PetFollow.new(Vector3.zero, 0, settings.spot),
		_spot = settings.spot,
		_scale = settings.scale,
		_parent = parent,
		_placed = false,
		_head = head,
		_voice = PetKit.voice(head, "Woof", settings.sound, settings.volume, settings.soundStart),
		_texts = settings.texts,
		_bubbles = PetKit.bubbles(BUBBLE_STYLE, settings.scale),
		_rng = if seed then Random.new(seed) else Random.new(),
	}
	local dog = (setmetatable(self, DogClass) :: any) :: PetKit.Pet
	dog:update(0)
	return dog
end

-- Puts the dog at its spot next to the character and shows it. With
-- StreamingEnabled a character can arrive before its root part does.
function DogClass._place(self: Impl, root: BasePart)
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

function DogClass._bark(self: Impl)
	local rng = self._rng
	self._voice:play(rng:NextNumber(BARK_PITCH_MIN, BARK_PITCH_MAX))
	if #self._texts > 0 then
		self._bubbles:pop(self._head, self.model, self._texts[rng:NextInteger(1, #self._texts)], rng)
	end
end

function DogClass.update(self: Impl, dt: number)
	dt = math.min(dt, MAX_DT)
	local root = PetKit.rootOf(self._character)
	if root and not self._placed then
		DogClass._place(self, root)
	end
	if not self._placed then
		return
	end
	if root then
		local ground = PetKit.groundBelow(self._follow.position, root, self._character, self._raycastParams)
		PetFollow.step(self._follow, root.CFrame, ground, dt)
	end

	-- A bigger dog takes longer strides for the same speed.
	local barks = self._animation:step(dt, self._follow.speed / self._scale)
	self._rig:solve(PetFollow.cframe(self._follow), self._animation:pose(), self._cframes)
	Workspace:BulkMoveTo(self._parts, self._cframes, Enum.BulkMoveMode.FireCFrameChanged)

	for _ = 1, barks do
		DogClass._bark(self)
	end
	self._bubbles:update(dt)
end

-- Makes the dog bark right now (random 1-3 barks when `count` is nil).
function DogClass.react(self: Impl, count: number?)
	self._animation:woof(count)
end

function DogClass.destroy(self: Impl)
	self._bubbles:clear()
	self.model:Destroy()
end

return table.freeze(DogPet)

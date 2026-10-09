--!strict
--[[
	SnakePet
	The snake companion on the client: builds the blocky snake from
	SnakeModel, follows a character with its head (PetFollow), slithers
	(SnakeAnimation) and sells every HISS with a pop-up bubble and a hiss.

	Like the dog it is cosmetic and local to this client: anchored parts that
	never collide, moved with one workspace:BulkMoveTo call per frame.

	  local snake = SnakePet.new(character, parentFolder, { raycastParams = params })
	  snake:update(dt) -- every frame (PreRender)
	  snake:react()    -- HISS now
	  snake:destroy()
]]

local Workspace = game:GetService("Workspace")

local PetFollow = require(script.Parent.PetFollow)
local PetKit = require(script.Parent.PetKit)
local PetRig = require(script.Parent.PetRig)
local SnakeAnimation = require(script.Parent.SnakeAnimation)
local SnakeModel = require(script.Parent.SnakeModel)

local HISS_PITCH_MIN, HISS_PITCH_MAX = 0.9, 1.15
local BUBBLE_STYLE: PetKit.BubbleStyle = {
	name = "HissBubble",
	textColor = Color3.fromRGB(205, 255, 160),
	strokeColor = Color3.fromRGB(22, 60, 14),
}

local MAX_DT = 0.1

type Impl = {
	model: Model,
	_character: Model,
	_raycastParams: RaycastParams,
	_parts: { BasePart },
	_cframes: { CFrame },
	_rig: PetRig.PetRig,
	_animation: SnakeAnimation.SnakeAnimation,
	_follow: PetFollow.State,
	_spot: Vector3,
	_parent: Instance,
	_placed: boolean,
	_head: BasePart,
	_voice: PetKit.Voice,
	_texts: { string },
	_bubbles: PetKit.Bubbles,
	_rng: Random,
}

local SnakeClass = {}
SnakeClass.__index = SnakeClass

local SnakePet = {}

SnakePet.Defaults = table.freeze({
	spot = Vector3.new(-2.6, 0, 3.4), -- on the owner's left, the body trails behind
	-- "Snake Hiss 1 (SFX)" by Pro Sound Effects, licensed by Roblox for every
	-- experience. The file starts with 2.8 seconds of silence.
	sound = "rbxassetid://9119302862",
	soundStart = 2.8,
	volume = 0.9,
	texts = table.freeze({ "HSSS!", "Hssss!", "HISSS!", "Sss!" }),
	every = SnakeAnimation.Every,
}) :: PetKit.Defaults

function SnakePet.new(character: Model, parent: Instance, options: PetKit.Options): PetKit.Pet
	local settings = PetKit.settings(options, SnakePet.Defaults, "Snake")
	local seed = options.seed
	local model, parts, definition = PetKit.build("Snake", SnakeModel.Definition, options.template, settings.scale)
	local head = model:FindFirstChild(SnakeModel.HeadPart) :: BasePart

	local self: Impl = {
		model = model,
		_character = character,
		_raycastParams = options.raycastParams,
		_parts = parts,
		_cframes = table.create(#parts),
		_rig = PetRig.new(definition, settings.scale),
		_animation = SnakeAnimation.new(if seed then seed + 1 else nil, settings.every, settings.scale),
		_follow = PetFollow.new(Vector3.zero, 0, settings.spot),
		_spot = settings.spot,
		_parent = parent,
		_placed = false,
		_head = head,
		_voice = PetKit.voice(head, "Hiss", settings.sound, settings.volume, settings.soundStart),
		_texts = settings.texts,
		_bubbles = PetKit.bubbles(BUBBLE_STYLE, settings.scale),
		_rng = if seed then Random.new(seed) else Random.new(),
	}
	local snake = (setmetatable(self, SnakeClass) :: any) :: PetKit.Pet
	snake:update(0)
	return snake
end

-- Puts the snake at its spot next to the character, body laid out behind
-- it, and shows it. With StreamingEnabled a character can arrive before its
-- root part does.
function SnakeClass._place(self: Impl, root: BasePart)
	local goal = PetFollow.goal(root.CFrame, self._spot)
	local look = root.CFrame.LookVector
	self._follow = PetFollow.new(
		Vector3.new(goal.X, PetKit.feetHeight(root, self._character), goal.Z),
		math.atan2(-look.X, -look.Z),
		self._spot
	)
	self._animation:reset(PetFollow.cframe(self._follow))
	self._placed = true
	self.model.Parent = self._parent
end

function SnakeClass._hiss(self: Impl)
	local rng = self._rng
	self._voice:play(rng:NextNumber(HISS_PITCH_MIN, HISS_PITCH_MAX))
	if #self._texts > 0 then
		self._bubbles:pop(self._head, self.model, self._texts[rng:NextInteger(1, #self._texts)], rng)
	end
end

function SnakeClass.update(self: Impl, dt: number)
	dt = math.min(dt, MAX_DT)
	local root = PetKit.rootOf(self._character)
	if root and not self._placed then
		SnakeClass._place(self, root)
	end
	if not self._placed then
		return
	end
	if root then
		local ground = PetKit.groundBelow(self._follow.position, root, self._character, self._raycastParams)
		PetFollow.step(self._follow, root.CFrame, ground, dt)
	end

	local hisses = self._animation:step(dt, PetFollow.cframe(self._follow), self._follow.speed)
	local pose, pinned = self._animation:pose()
	self._rig:solve(CFrame.identity, pose, self._cframes, pinned)
	Workspace:BulkMoveTo(self._parts, self._cframes, Enum.BulkMoveMode.FireCFrameChanged)

	for _ = 1, hisses do
		SnakeClass._hiss(self)
	end
	self._bubbles:update(dt)
end

-- Makes the snake rear up and hiss right now.
function SnakeClass.react(self: Impl, _count: number?)
	self._animation:hiss()
end

function SnakeClass.destroy(self: Impl)
	self._bubbles:clear()
	self.model:Destroy()
end

return table.freeze(SnakePet)

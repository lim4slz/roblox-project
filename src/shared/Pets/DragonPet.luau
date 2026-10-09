--!strict
--[[
	DragonPet
	The dragon companion on the client: builds the blocky dragon from
	DragonModel, follows a character (PetFollow), flies after it
	(DragonAnimation) and sells every fire breath with a pop-up bubble and
	the whoosh of the flames.

	Like the other pets it is cosmetic and local to this client: anchored
	parts that never collide, moved with one workspace:BulkMoveTo call per
	frame.

	  local dragon = DragonPet.new(character, parentFolder, { raycastParams = params })
	  dragon:update(dt) -- every frame (PreRender)
	  dragon:react()    -- breathe fire now
	  dragon:destroy()
]]

local Workspace = game:GetService("Workspace")

local DragonAnimation = require(script.Parent.DragonAnimation)
local DragonModel = require(script.Parent.DragonModel)
local PetFollow = require(script.Parent.PetFollow)
local PetKit = require(script.Parent.PetKit)
local PetRig = require(script.Parent.PetRig)

local FIRE_PITCH_MIN, FIRE_PITCH_MAX = 0.9, 1.1
local BUBBLE_STYLE: PetKit.BubbleStyle = {
	name = "RoarBubble",
	textColor = Color3.fromRGB(255, 214, 90),
	strokeColor = Color3.fromRGB(110, 24, 6),
}

local MAX_DT = 0.1

type Impl = {
	model: Model,
	_character: Model,
	_raycastParams: RaycastParams,
	_parts: { BasePart },
	_cframes: { CFrame },
	_rig: PetRig.PetRig,
	_animation: DragonAnimation.DragonAnimation,
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

local DragonClass = {}
DragonClass.__index = DragonClass

local DragonPet = {}

DragonPet.Defaults = table.freeze({
	spot = Vector3.new(4.6, 0, 6.6), -- behind the owner on the right, flying over the other pets
	-- "Fire Whoosh 4" by Pro Sound Effects, licensed by Roblox for every
	-- experience. The burst builds up slowly, so it starts 1.3 seconds in.
	sound = "rbxassetid://9114439216",
	soundStart = 1.3,
	volume = 0.6,
	texts = table.freeze({ "ROAR!", "RAWR!", "FWOOSH!", "Rawr!" }),
	every = DragonAnimation.Every,
}) :: PetKit.Defaults

function DragonPet.new(character: Model, parent: Instance, options: PetKit.Options): PetKit.Pet
	local settings = PetKit.settings(options, DragonPet.Defaults, "Dragon")
	local seed = options.seed
	local model, parts, definition = PetKit.build("Dragon", DragonModel.Definition, options.template, settings.scale)
	local head = model:FindFirstChild(DragonModel.HeadPart) :: BasePart

	local self: Impl = {
		model = model,
		_character = character,
		_raycastParams = options.raycastParams,
		_parts = parts,
		_cframes = table.create(#parts),
		_rig = PetRig.new(definition, settings.scale),
		_animation = DragonAnimation.new(if seed then seed + 1 else nil, settings.every),
		_follow = PetFollow.new(Vector3.zero, 0, settings.spot),
		_spot = settings.spot,
		_scale = settings.scale,
		_parent = parent,
		_placed = false,
		_head = head,
		_voice = PetKit.voice(head, "Fire", settings.sound, settings.volume, settings.soundStart),
		_texts = settings.texts,
		_bubbles = PetKit.bubbles(BUBBLE_STYLE, settings.scale),
		_rng = if seed then Random.new(seed) else Random.new(),
	}
	local dragon = (setmetatable(self, DragonClass) :: any) :: PetKit.Pet
	dragon:update(0)
	return dragon
end

-- Puts the dragon at its spot next to the character and shows it. With
-- StreamingEnabled a character can arrive before its root part does.
function DragonClass._place(self: Impl, root: BasePart)
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

function DragonClass._roar(self: Impl)
	local rng = self._rng
	self._voice:play(rng:NextNumber(FIRE_PITCH_MIN, FIRE_PITCH_MAX))
	if #self._texts > 0 then
		self._bubbles:pop(self._head, self.model, self._texts[rng:NextInteger(1, #self._texts)], rng)
	end
end

function DragonClass.update(self: Impl, dt: number)
	dt = math.min(dt, MAX_DT)
	local root = PetKit.rootOf(self._character)
	if root and not self._placed then
		DragonClass._place(self, root)
	end
	if not self._placed then
		return
	end
	if root then
		local ground = PetKit.groundBelow(self._follow.position, root, self._character, self._raycastParams)
		PetFollow.step(self._follow, root.CFrame, ground, dt)
	end

	-- A bigger dragon takes slower wing beats for the same speed.
	local breaths = self._animation:step(dt, self._follow.speed / self._scale)
	self._rig:solve(PetFollow.cframe(self._follow), self._animation:pose(), self._cframes)
	Workspace:BulkMoveTo(self._parts, self._cframes, Enum.BulkMoveMode.FireCFrameChanged)

	for _ = 1, breaths do
		DragonClass._roar(self)
	end
	self._bubbles:update(dt)
end

-- Makes the dragon breathe fire right now (`count` breaths in a row, 1 when nil).
function DragonClass.react(self: Impl, count: number?)
	self._animation:react(count)
end

function DragonClass.destroy(self: Impl)
	self._bubbles:clear()
	self.model:Destroy()
end

return table.freeze(DragonPet)

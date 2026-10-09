--!strict
--[[
	CrabPet
	The crab companion on the client: builds the blocky crab from CrabModel,
	follows a character (PetFollow), scuttles sideways after it
	(CrabAnimation) and sells every SNAP with a pop-up bubble and the clicks
	of a crab claw.

	Like the other pets it is cosmetic and local to this client: anchored
	parts that never collide, moved with one workspace:BulkMoveTo call per
	frame.

	  local crab = CrabPet.new(character, parentFolder, { raycastParams = params })
	  crab:update(dt) -- every frame (PreRender)
	  crab:react()    -- SNAP now
	  crab:destroy()
]]

local Workspace = game:GetService("Workspace")

local CrabAnimation = require(script.Parent.CrabAnimation)
local CrabModel = require(script.Parent.CrabModel)
local PetFollow = require(script.Parent.PetFollow)
local PetKit = require(script.Parent.PetKit)
local PetRig = require(script.Parent.PetRig)

local SNAP_PITCH_MIN, SNAP_PITCH_MAX = 0.95, 1.1
local BUBBLE_STYLE: PetKit.BubbleStyle = {
	name = "SnapBubble",
	textColor = Color3.fromRGB(255, 196, 120),
	strokeColor = Color3.fromRGB(90, 12, 8),
}

local MAX_DT = 0.1

type Impl = {
	model: Model,
	_character: Model,
	_raycastParams: RaycastParams,
	_parts: { BasePart },
	_cframes: { CFrame },
	_rig: PetRig.PetRig,
	_animation: CrabAnimation.CrabAnimation,
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

local CrabClass = {}
CrabClass.__index = CrabClass

local CrabPet = {}

CrabPet.Defaults = table.freeze({
	spot = Vector3.new(-5.8, 0, 0.4), -- on the owner's left, further out than the snake
	-- "Crab Claw Smaller Snaps Plasticky 3" by Pro Sound Effects, licensed by
	-- Roblox for every experience: three snaps, in time with the animation.
	sound = "rbxassetid://9113957844",
	soundStart = 0,
	volume = 0.8,
	texts = table.freeze({ "SNAP!", "Snip snap!", "CLACK!", "Snap snap!" }),
	every = CrabAnimation.Every,
}) :: PetKit.Defaults

function CrabPet.new(character: Model, parent: Instance, options: PetKit.Options): PetKit.Pet
	local settings = PetKit.settings(options, CrabPet.Defaults, "Crab")
	local seed = options.seed
	local model, parts, definition = PetKit.build("Crab", CrabModel.Definition, options.template, settings.scale)
	local head = model:FindFirstChild(CrabModel.HeadPart) :: BasePart

	local self: Impl = {
		model = model,
		_character = character,
		_raycastParams = options.raycastParams,
		_parts = parts,
		_cframes = table.create(#parts),
		_rig = PetRig.new(definition, settings.scale),
		_animation = CrabAnimation.new(if seed then seed + 1 else nil, settings.every),
		_follow = PetFollow.new(Vector3.zero, 0, settings.spot),
		_spot = settings.spot,
		_scale = settings.scale,
		_parent = parent,
		_placed = false,
		_head = head,
		_voice = PetKit.voice(head, "Snap", settings.sound, settings.volume, settings.soundStart),
		_texts = settings.texts,
		_bubbles = PetKit.bubbles(BUBBLE_STYLE, settings.scale),
		_rng = if seed then Random.new(seed) else Random.new(),
	}
	local crab = (setmetatable(self, CrabClass) :: any) :: PetKit.Pet
	crab:update(0)
	return crab
end

-- Puts the crab at its spot next to the character and shows it. With
-- StreamingEnabled a character can arrive before its root part does.
function CrabClass._place(self: Impl, root: BasePart)
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

function CrabClass._snap(self: Impl)
	local rng = self._rng
	self._voice:play(rng:NextNumber(SNAP_PITCH_MIN, SNAP_PITCH_MAX))
	if #self._texts > 0 then
		self._bubbles:pop(self._head, self.model, self._texts[rng:NextInteger(1, #self._texts)], rng)
	end
end

function CrabClass.update(self: Impl, dt: number)
	dt = math.min(dt, MAX_DT)
	local root = PetKit.rootOf(self._character)
	if root and not self._placed then
		CrabClass._place(self, root)
	end
	if not self._placed then
		return
	end
	if root then
		local ground = PetKit.groundBelow(self._follow.position, root, self._character, self._raycastParams)
		PetFollow.step(self._follow, root.CFrame, ground, dt)
	end

	-- A bigger crab takes longer steps for the same speed.
	local snaps = self._animation:step(dt, self._follow.speed / self._scale)
	self._rig:solve(PetFollow.cframe(self._follow), self._animation:pose(), self._cframes)
	Workspace:BulkMoveTo(self._parts, self._cframes, Enum.BulkMoveMode.FireCFrameChanged)

	for _ = 1, snaps do
		CrabClass._snap(self)
	end
	self._bubbles:update(dt)
end

-- Makes the crab SNAP right now (`count` SNAPs in a row, 1 when nil).
function CrabClass.react(self: Impl, count: number?)
	self._animation:react(count)
end

function CrabClass.destroy(self: Impl)
	self._bubbles:clear()
	self.model:Destroy()
end

return table.freeze(CrabPet)

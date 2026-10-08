--!strict
--[[
	DogPet
	The dog companion on the client: builds the blocky dog from DogModel,
	follows a character (PetFollow), animates it (DogAnimation) and sells every
	WOOF with a pop-up bubble and a bark.

	The dog is cosmetic and local to this client: its parts are anchored, never
	collide and are moved with one workspace:BulkMoveTo call per frame (no
	physics, no network ownership).

	  local dog = DogPet.new(character, parentFolder, raycastParams)
	  dog:update(dt) -- every frame (PreRender)
	  dog:destroy()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pets = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pets")
local DogAnimation = require(Pets:WaitForChild("DogAnimation"))
local DogModel = require(Pets:WaitForChild("DogModel"))
local PetFollow = require(Pets:WaitForChild("PetFollow"))
local PetRig = require(Pets:WaitForChild("PetRig"))

-- "beagle barking", a public audio from the Creator Store. Swap it for any
-- bark you like (rbxassetid://<id>).
local BARK_SOUND_ID = "rbxassetid://7103147161"
local BARK_VOLUME = 0.6
local BARK_PITCH_MIN, BARK_PITCH_MAX = 1.05, 1.3

local WOOF_TEXTS = { "WOOF!", "Woof!", "WOOF!", "WOOF!!" }
local BUBBLE_LIFE = 1.05 -- seconds
local BUBBLE_SIZE = UDim2.fromScale(3.6, 1.5) -- studs
local BUBBLE_HEIGHT = 1.3 -- studs above the head
local BUBBLE_RISE = 1.3
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local STROKE_COLOR = Color3.fromRGB(45, 28, 12)

local MAX_DT = 0.1

type Bubble = {
	gui: BillboardGui,
	label: TextLabel,
	stroke: UIStroke,
	scale: UIScale,
	age: number,
	tilt: number,
	drift: number,
}

export type DogPet = {
	model: Model,
	update: (self: DogPet, dt: number) -> (),
	woof: (self: DogPet, count: number?) -> (),
	destroy: (self: DogPet) -> (),
}

type Impl = {
	model: Model,
	_character: Model,
	_raycastParams: RaycastParams,
	_parts: { BasePart },
	_cframes: { CFrame },
	_rig: PetRig.PetRig,
	_animation: DogAnimation.DogAnimation,
	_follow: PetFollow.State,
	_parent: Instance,
	_placed: boolean,
	_head: BasePart,
	_sounds: { Sound },
	_nextSound: number,
	_bubbles: { Bubble },
	_rng: Random,
}

local DogClass = {}
DogClass.__index = DogClass

local DogPet = {}

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Height of the floor under the character's feet, from its rig (no raycast).
local function feetHeight(root: BasePart, character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hipHeight = if humanoid then humanoid.HipHeight else 0
	return root.Position.Y - root.Size.Y / 2 - hipHeight
end

local function buildModel(): (Model, { BasePart }, BasePart)
	local model = Instance.new("Model")
	model.Name = "Dog"
	local parts: { BasePart } = {}
	local head: BasePart? = nil
	for index, def in DogModel.Definition.parts do
		local part = Instance.new("Part")
		part.Name = def.name
		part.Size = def.size
		part.Color = def.color
		part.Material = Enum.Material.Plastic
		part.CFrame = def.cframe
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		part.Parent = model
		parts[index] = part
		if def.name == DogModel.HeadPart then
			head = part
		end
	end
	assert(head, "DogModel.HeadPart missing")
	model.PrimaryPart = parts[1]
	return model, parts, head
end

local function newBubble(adornee: BasePart, parent: Instance, text: string, tilt: number): Bubble
	local gui = Instance.new("BillboardGui")
	gui.Name = "WoofBubble"
	gui.Adornee = adornee
	gui.Size = BUBBLE_SIZE
	gui.StudsOffsetWorldSpace = Vector3.new(0, BUBBLE_HEIGHT, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = TEXT_COLOR
	label.Rotation = tilt
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 2.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label

	gui.Parent = parent
	return { gui = gui, label = label, stroke = stroke, scale = scale, age = 0, tilt = tilt, drift = 0 }
end

-- Pops in with an overshoot, floats up, wobbles and fades out.
local function animateBubble(bubble: Bubble)
	local age = bubble.age
	local life = age / BUBBLE_LIFE
	local scale
	if age < 0.16 then
		local u = age / 0.16 - 1
		scale = 1 + 2.7 * u * u * u + 1.7 * u * u -- ease-out-back
	else
		scale = 1 + 0.05 * math.sin(age * 9) * math.exp(-age * 3)
	end
	local fade = math.clamp((life - 0.65) / 0.35, 0, 1)
	bubble.scale.Scale = scale
	bubble.gui.StudsOffsetWorldSpace =
		Vector3.new(bubble.drift * life, BUBBLE_HEIGHT + BUBBLE_RISE * (1 - (1 - life) * (1 - life)), 0)
	bubble.label.Rotation = bubble.tilt + 8 * math.sin(age * 20) * math.exp(-age * 5)
	bubble.label.TextTransparency = fade
	bubble.stroke.Transparency = fade
end

function DogPet.new(character: Model, parent: Instance, raycastParams: RaycastParams, seed: number?): DogPet
	local model, parts, head = buildModel()
	local rng = if seed then Random.new(seed) else Random.new()

	local sounds = {}
	for index = 1, 2 do -- two voices so a "woof woof" does not cut itself off
		local sound = Instance.new("Sound")
		sound.Name = "Woof" .. index
		sound.SoundId = BARK_SOUND_ID
		sound.Volume = BARK_VOLUME
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = 80
		sound.Parent = head
		sounds[index] = sound
	end

	local self: Impl = {
		model = model,
		_character = character,
		_raycastParams = raycastParams,
		_parts = parts,
		_cframes = table.create(#parts),
		_rig = PetRig.new(DogModel.Definition),
		_animation = DogAnimation.new(if seed then seed + 1 else nil),
		_follow = PetFollow.new(Vector3.zero),
		_parent = parent,
		_placed = false,
		_head = head,
		_sounds = sounds,
		_nextSound = 1,
		_bubbles = {},
		_rng = rng,
	}
	local dog = (setmetatable(self, DogClass) :: any) :: DogPet
	dog:update(0)
	return dog
end

-- Puts the dog at its spot next to the character and shows it. With
-- StreamingEnabled a character can arrive before its root part does.
function DogClass._place(self: Impl, root: BasePart)
	local goal = PetFollow.goal(root.CFrame)
	local look = root.CFrame.LookVector
	self._follow =
		PetFollow.new(Vector3.new(goal.X, feetHeight(root, self._character), goal.Z), math.atan2(-look.X, -look.Z))
	self._placed = true
	self.model.Parent = self._parent
end

function DogClass._groundAt(self: Impl, root: BasePart): number
	local position = self._follow.position
	local top = math.max(root.Position.Y, position.Y) + 3
	local hit = Workspace:Raycast(Vector3.new(position.X, top, position.Z), Vector3.new(0, -30, 0), self._raycastParams)
	if hit then
		return hit.Position.Y
	end
	return feetHeight(root, self._character)
end

function DogClass._bark(self: Impl)
	local rng = self._rng
	local sound = self._sounds[self._nextSound]
	self._nextSound = self._nextSound % #self._sounds + 1
	sound.PlaybackSpeed = rng:NextNumber(BARK_PITCH_MIN, BARK_PITCH_MAX)
	sound:Play()

	local text = WOOF_TEXTS[rng:NextInteger(1, #WOOF_TEXTS)]
	local bubble = newBubble(self._head, self.model, text, rng:NextNumber(-12, 12))
	bubble.drift = rng:NextNumber(-0.6, 0.6)
	table.insert(self._bubbles, bubble)
end

function DogClass.update(self: Impl, dt: number)
	dt = math.min(dt, MAX_DT)
	local root = rootOf(self._character)
	if root and not self._placed then
		DogClass._place(self, root)
	end
	if not self._placed then
		return
	end
	if root then
		PetFollow.step(self._follow, root.CFrame, DogClass._groundAt(self, root), dt)
	end

	local barks = self._animation:step(dt, self._follow.speed)
	self._rig:solve(PetFollow.cframe(self._follow), self._animation:pose(), self._cframes)
	Workspace:BulkMoveTo(self._parts, self._cframes, Enum.BulkMoveMode.FireCFrameChanged)

	for _ = 1, barks do
		DogClass._bark(self)
	end
	local bubbles = self._bubbles
	for index = #bubbles, 1, -1 do
		local bubble = bubbles[index]
		bubble.age += dt
		if bubble.age >= BUBBLE_LIFE then
			bubble.gui:Destroy()
			table.remove(bubbles, index)
		else
			animateBubble(bubble)
		end
	end
end

-- Makes the dog bark right now (random 1-3 barks when `count` is nil).
function DogClass.woof(self: Impl, count: number?)
	self._animation:woof(count)
end

function DogClass.destroy(self: Impl)
	table.clear(self._bubbles)
	self.model:Destroy()
end

return table.freeze(DogPet)

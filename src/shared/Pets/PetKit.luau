--!strict
--[[
	PetKit
	What every pet needs on the client: building its parts, finding the
	ground, pop-up text bubbles and a sound that can overlap itself.

	Building takes an optional template Model with parts named like the
	definition. A part found in the template is cloned, so its color,
	material, decals, particles, lights... come along; its size and position
	still come from the definition so the animation stays right. Any other
	BasePart in the template is an accessory (a hat, a collar...): it keeps
	its own size and position and moves with the bone named by its "Bone"
	attribute (on the part or on a parent Model), or with the closest part.
]]

local Workspace = game:GetService("Workspace")

local PetRig = require(script.Parent.PetRig)

export type Options = {
	raycastParams: RaycastParams,
	seed: number?,
	scale: number?, -- 1 = original size
	spot: Vector3?, -- where it walks next to its owner: X studs to the right, Z studs behind
	template: Model?, -- look of the pet (see above)
	sound: string?, -- "" = silent
	soundStart: number?, -- second of the sound file where the sound actually starts
	volume: number?,
	texts: { string }?, -- {} = no bubbles
	every: ({ number } | boolean)?, -- seconds between reactions on its own { min, max }, false = never
}

export type Pet = {
	model: Model,
	update: (self: Pet, dt: number) -> (),
	react: (self: Pet, count: number?) -> (),
	destroy: (self: Pet) -> (),
}

export type Defaults = {
	spot: Vector3,
	sound: string,
	soundStart: number,
	volume: number,
	texts: { string },
	every: { number },
}

export type PetClass = {
	Defaults: Defaults,
	new: (character: Model, parent: Instance, options: Options) -> Pet,
}

export type BubbleStyle = {
	name: string,
	textColor: Color3,
	strokeColor: Color3,
}

export type Bubbles = {
	pop: (self: Bubbles, adornee: BasePart, parent: Instance, text: string, rng: Random) -> (),
	update: (self: Bubbles, dt: number) -> (),
	clear: (self: Bubbles) -> (),
}

export type Voice = {
	play: (self: Voice, pitch: number) -> (),
}

local BUBBLE_LIFE = 1.05 -- seconds
local BUBBLE_SIZE = Vector2.new(3.6, 1.5) -- studs
local BUBBLE_HEIGHT = 1.3 -- studs above the part
local BUBBLE_RISE = 1.3

local PetKit = {}

PetKit.Never = table.freeze({ math.huge, math.huge })

-- Returns `value` when it passes `ok`, otherwise warns (these values come
-- from a Config people edit by hand) and returns `fallback`. nil means "use
-- the default" and is not a mistake.
local function checked(
	label: string,
	field: string,
	value: any,
	ok: (any) -> boolean,
	expected: string,
	fallback: any
): any
	if value == nil then
		return fallback
	elseif ok(value) then
		return value
	end
	warn(`[Pets] Config.{label}.{field} should be {expected}, using the default instead.`)
	return fallback
end

local function isPositive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

local function isZeroOrMore(value: any): boolean
	return type(value) == "number" and value >= 0 and value < math.huge
end

local function isTexts(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for _, text in value do
		if type(text) ~= "string" then
			return false
		end
	end
	return true
end

local function isInterval(value: any): boolean
	return type(value) == "table" and isZeroOrMore(value[1]) and isZeroOrMore(value[2])
end

-- Fills the gaps in `options` with the pet's defaults. `every` comes back as
-- { min, max } seconds, PetKit.Never when the pet should not react on its own.
-- `name` is the pet's name in the Config, for the warnings.
function PetKit.settings(options: Options, defaults: Defaults, name: string?)
	local label = name or "Pet"
	local scale = checked(label, "Scale", options.scale, isPositive, "a number above 0", 1)
	local every: { number } = defaults.every
	if options.every == false then
		every = PetKit.Never
	elseif options.every ~= nil and options.every ~= true then
		every = checked(label, "Every", options.every, isInterval, "{ min, max } seconds or false", defaults.every)
		if every[1] > every[2] then
			every = { every[2], every[1] }
		end
	end
	local sound = checked(label, "Sound", options.sound, function(value)
		return type(value) == "string"
	end, 'a sound id like "rbxassetid://123"', defaults.sound)
	return {
		scale = scale,
		spot = checked(label, "Spot", options.spot, function(value)
			return typeof(value) == "Vector3"
		end, "a Vector3", defaults.spot) * scale,
		sound = sound,
		soundStart = checked(
			label,
			"SoundStart",
			options.soundStart,
			isZeroOrMore,
			"a number of seconds",
			if sound ~= defaults.sound then 0 else defaults.soundStart
		),
		volume = checked(label, "Volume", options.volume, isZeroOrMore, "a number from 0 to 10", defaults.volume),
		texts = checked(label, "Texts", options.texts, isTexts, 'a list of words like { "Hi!" }', defaults.texts),
		every = every,
	}
end

local function stripParts(instance: Instance)
	for _, child in instance:GetChildren() do
		if child:IsA("BasePart") or child:IsA("Model") then
			child:Destroy()
		elseif child:IsA("JointInstance") or child:IsA("WeldConstraint") then
			child:Destroy()
		else
			stripParts(child)
		end
	end
end

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	stripParts(part)
end

local function boneAttribute(part: BasePart, template: Model): string?
	local current: Instance? = part
	while current and current ~= template do
		local bone = current:GetAttribute("Bone")
		if type(bone) == "string" then
			return bone
		end
		current = current.Parent
	end
	return nil
end

-- Builds the parts of a pet. Returns the model (not parented), its parts in
-- rig order and the definition that matches them (accessories included).
function PetKit.build(
	name: string,
	definition: PetRig.ModelDef,
	template: Model?,
	scale: number?
): (Model, { BasePart }, PetRig.ModelDef)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = name
	local parts: { BasePart } = {}
	local defs: { PetRig.PartDef } = table.clone(definition.parts)
	local used: { [Instance]: boolean } = {}

	for index, def in definition.parts do
		local source = if template then template:FindFirstChild(def.name) else nil
		-- Clone() gives nil for parts that are not Archivable: those get a plain block.
		local clone = if source and source:IsA("BasePart") then source:Clone() else nil
		local part: BasePart
		if source and clone then
			part = clone
			used[source] = true
		else
			local block = Instance.new("Part")
			block.Color = def.color
			block.Material = Enum.Material.Plastic
			block.TopSurface = Enum.SurfaceType.Smooth
			block.BottomSurface = Enum.SurfaceType.Smooth
			if def.shape then
				block.Shape = def.shape
			end
			part = block
		end
		part.Name = def.name
		part.Size = def.size * s
		part.CFrame = def.cframe
		prepare(part)
		part.Parent = model
		parts[index] = part
	end

	if template then
		-- The template sits wherever it was saved: find where its origin is
		-- from a part the definition knows.
		local first = definition.parts[1]
		local bones: { [string]: boolean } = {}
		for _, bone in definition.bones do
			bones[bone.name] = true
		end
		local anchor = template:FindFirstChild(first.name)
		local origin = if anchor and anchor:IsA("BasePart")
			then anchor.CFrame * first.cframe:Inverse()
			else template:GetPivot()
		for _, source in template:GetDescendants() do
			-- Clone() gives nil for parts that are not Archivable: those are skipped.
			local part = if source:IsA("BasePart") and not used[source] then source:Clone() else nil
			if source:IsA("BasePart") and part then
				local local_ = origin:ToObjectSpace(source.CFrame)
				local bone = boneAttribute(source, template)
				if bone and not bones[bone] then
					warn(
						`[Pets] {source:GetFullName()} has Bone "{bone}", but {name} has no such bone. Using the closest one.`
					)
					bone = nil
				end
				if bone == nil then
					local closest = math.huge
					for _, def in definition.parts do
						local distance = (def.cframe.Position - local_.Position).Magnitude
						if distance < closest then
							closest = distance
							bone = def.bone
						end
					end
				end
				part.Size = source.Size * s
				prepare(part)
				part.Parent = model
				table.insert(parts, part)
				table.insert(defs, {
					name = source.Name,
					bone = bone :: string,
					size = part.Size / s,
					cframe = local_,
					color = part.Color,
				})
			end
		end
	end

	model.PrimaryPart = parts[1]
	return model, parts, { bones = definition.bones, parts = defs }
end

function PetKit.rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Height of the floor under the character's feet, from its rig (no raycast).
function PetKit.feetHeight(root: BasePart, character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hipHeight = if humanoid then humanoid.HipHeight else 0
	return root.Position.Y - root.Size.Y / 2 - hipHeight
end

-- Height of the floor under `position`, or under the character when there is nothing.
function PetKit.groundBelow(position: Vector3, root: BasePart, character: Model, params: RaycastParams): number
	local top = math.max(root.Position.Y, position.Y) + 3
	local hit = Workspace:Raycast(Vector3.new(position.X, top, position.Z), Vector3.new(0, -30, 0), params)
	if hit then
		return hit.Position.Y
	end
	return PetKit.feetHeight(root, character)
end

-- Bubbles ---------------------------------------------------------------------

type Bubble = {
	gui: BillboardGui,
	label: TextLabel,
	stroke: UIStroke,
	uiScale: UIScale,
	age: number,
	tilt: number,
	drift: number,
}

type BubblesImpl = {
	_style: BubbleStyle,
	_scale: number,
	_list: { Bubble },
}

local BubblesClass = {}
BubblesClass.__index = BubblesClass

function PetKit.bubbles(style: BubbleStyle, scale: number?): Bubbles
	local self: BubblesImpl = { _style = style, _scale = scale or 1, _list = {} }
	return (setmetatable(self, BubblesClass) :: any) :: Bubbles
end

function BubblesClass.pop(self: BubblesImpl, adornee: BasePart, parent: Instance, text: string, rng: Random)
	local style = self._style
	local s = self._scale
	local gui = Instance.new("BillboardGui")
	gui.Name = style.name
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(BUBBLE_SIZE.X * s, BUBBLE_SIZE.Y * s)
	gui.StudsOffsetWorldSpace = Vector3.new(0, BUBBLE_HEIGHT * s, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90 * math.max(s, 1)

	local tilt = rng:NextNumber(-12, 12)
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = style.textColor
	label.Rotation = tilt
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = style.strokeColor
	stroke.Thickness = 2.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = label

	gui.Parent = parent
	table.insert(self._list, {
		gui = gui,
		label = label,
		stroke = stroke,
		uiScale = uiScale,
		age = 0,
		tilt = tilt,
		drift = rng:NextNumber(-0.6, 0.6),
	})
end

-- Pops in with an overshoot, floats up, wobbles and fades out.
local function animateBubble(bubble: Bubble, s: number)
	local age = bubble.age
	local life = age / BUBBLE_LIFE
	local size
	if age < 0.16 then
		local u = age / 0.16 - 1
		size = 1 + 2.7 * u * u * u + 1.7 * u * u -- ease-out-back
	else
		size = 1 + 0.05 * math.sin(age * 9) * math.exp(-age * 3)
	end
	local fade = math.clamp((life - 0.65) / 0.35, 0, 1)
	bubble.uiScale.Scale = size
	bubble.gui.StudsOffsetWorldSpace = Vector3.new(
		bubble.drift * life,
		BUBBLE_HEIGHT + BUBBLE_RISE * (1 - (1 - life) * (1 - life)),
		0
	) * s
	bubble.label.Rotation = bubble.tilt + 8 * math.sin(age * 20) * math.exp(-age * 5)
	bubble.label.TextTransparency = fade
	bubble.stroke.Transparency = fade
end

function BubblesClass.update(self: BubblesImpl, dt: number)
	local list = self._list
	for index = #list, 1, -1 do
		local bubble = list[index]
		bubble.age += dt
		if bubble.age >= BUBBLE_LIFE then
			bubble.gui:Destroy()
			table.remove(list, index)
		else
			animateBubble(bubble, self._scale)
		end
	end
end

function BubblesClass.clear(self: BubblesImpl)
	for _, bubble in self._list do
		bubble.gui:Destroy()
	end
	table.clear(self._list)
end

-- Voice -----------------------------------------------------------------------

type VoiceImpl = {
	_sounds: { Sound },
	_next: number,
	_start: number,
}

local VoiceClass = {}
VoiceClass.__index = VoiceClass

-- A sound with two channels so a quick second call does not cut the first one
-- off. Silent when `soundId` is "" or `volume` is 0.
function PetKit.voice(parent: Instance, name: string, soundId: string, volume: number, start: number?): Voice
	local sounds = {}
	if soundId ~= "" and volume > 0 then
		for index = 1, 2 do
			local sound = Instance.new("Sound")
			sound.Name = name .. index
			sound.SoundId = soundId
			sound.Volume = volume
			sound.RollOffMinDistance = 8
			sound.RollOffMaxDistance = 80
			sound.Parent = parent
			sounds[index] = sound
		end
	end
	local self: VoiceImpl = { _sounds = sounds, _next = 1, _start = start or 0 }
	return (setmetatable(self, VoiceClass) :: any) :: Voice
end

function VoiceClass.play(self: VoiceImpl, pitch: number)
	local sound = self._sounds[self._next]
	if not sound then
		return
	end
	self._next = self._next % #self._sounds + 1
	sound.PlaybackSpeed = pitch
	sound.TimePosition = self._start
	sound:Play()
end

return table.freeze(PetKit)

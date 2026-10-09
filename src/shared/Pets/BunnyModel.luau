--!strict
--[[
	BunnyModel
	The blocky bunny from the art pass (pets.rbxm, Tool "Bunny") as data, split
	into bones so it can hop. Sizes, positions and colors are the original
	ones, slight asymmetry included (the face sits a little to the right of
	the body). It sits upright at rest: the body leans 22.6 degrees, the front
	legs stand straight and the long hind feet lie flat on either side.
	Five extra parts hide inside the face at rest (two eyelids, two lash
	lines and an open mouth) and only slide out to blink and cheer, so the
	bunny looks exactly like the original when it is not doing anything.

	Units are studs in the bunny's own frame: origin on the ground under the
	body, facing -Z (LookVector), +X is the bunny's right.
]]

local PetRig = require(script.Parent.PetRig)

local rgb = Color3.fromRGB

local WHITE = rgb(237, 234, 234)
local PINK = rgb(255, 148, 148)
local BLACK = rgb(17, 17, 17)
local MOUTH = rgb(150, 40, 60)

-- The art tilts the head, legs and feet 0.19 degrees and the body 22.595.
local FACE_TILT = -0.19
local BODY_TILT = -22.595

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function bone(name: string, parent: string?, pivot: CFrame): PetRig.BoneDef
	return { name = name, parent = parent, pivot = pivot }
end

local function part(name: string, boneName: string, color: Color3, size: Vector3, cframe: CFrame): PetRig.PartDef
	return { name = name, bone = boneName, color = color, size = size, cframe = cframe }
end

-- Parents always come before their children (PetRig requires it).
local BONES: { PetRig.BoneDef } = {
	bone("Body", nil, at(0.005, 1.491, 0)),
	bone("Tail", "Body", at(0.036, 0.937, 0.82, BODY_TILT)), -- where the tail meets the back of the body
	bone("Head", "Body", at(0.078, 2.65, -0.45, FACE_TILT)), -- neck, at the back-bottom of the head
	bone("EarL", "Head", at(-0.531, 4, -0.579)), -- ear bases, on the top plate
	bone("EarR", "Head", at(0.65, 4, -0.579, -0.001)),
	bone("Muzzle", "Head", at(0.169, 3.05, -1.2, FACE_TILT)), -- muzzle and mouth, twitch together
	bone("Nose", "Muzzle", at(0.163, 3.112, -1.25, FACE_TILT)),
	bone("Mouth", "Muzzle", at(0.16, 2.85, -1.36, FACE_TILT)), -- open mouth, tucked inside the muzzle
	bone("Lids", "Head", at(0.151, 3.479, -1.25, FACE_TILT)), -- eyelids, tucked inside the cheeks
	bone("LegFL", "Body", at(-0.647, 2.2, -0.85, FACE_TILT)), -- shoulders, at the top of the front legs
	bone("LegFR", "Body", at(0.669, 2.2, -0.85, FACE_TILT)),
	bone("FootL", "Body", at(-1.33, 0.494, 0.03, FACE_TILT)), -- heels, at the back of the hind feet
	bone("FootR", "Body", at(1.352, 0.494, 0.03, -0.191)),
}

local PARTS: { PetRig.PartDef } = {
	part("Body", "Body", WHITE, Vector3.new(2.182, 2.778, 1.088), at(0.005, 1.491, 0, BODY_TILT)),
	part("BackPlate", "Body", WHITE, Vector3.new(1.851, 2.209, 0.275), at(0.036, 1.765, 0.485, BODY_TILT)),
	part("Tail", "Tail", WHITE, Vector3.new(0.974, 1.04, 0.568), at(0.036, 1.046, 1.082, BODY_TILT)),
	part("TailTip", "Tail", WHITE, Vector3.new(0.682, 0.763, 0.275), at(0.036, 1.166, 1.349, BODY_TILT)),
	part("Head", "Head", WHITE, Vector3.new(2.036, 1.316, 1.462), at(0.078, 3.251, -0.581, FACE_TILT)),
	part("HeadTop", "Head", WHITE, Vector3.new(1.744, 0.146, 1.17), at(0.078, 3.982, -0.584, FACE_TILT)),
	part("CheekL", "Head", WHITE, Vector3.new(0.588, 0.514, 0.639), at(-0.344, 3.504, -1.048, FACE_TILT)),
	part("CheekR", "Head", WHITE, Vector3.new(0.588, 0.514, 0.639), at(0.656, 3.504, -1.048, FACE_TILT)),
	part("EyeL", "Head", BLACK, Vector3.new(0.305, 0.271, 0.665), at(-0.349, 3.479, -1.061, FACE_TILT)),
	part("EyeR", "Head", BLACK, Vector3.new(0.305, 0.271, 0.665), at(0.651, 3.479, -1.061, FACE_TILT)),
	part("Muzzle", "Muzzle", WHITE, Vector3.new(0.828, 0.475, 0.33), at(0.169, 2.938, -1.33, FACE_TILT)),
	part("MouthL", "Muzzle", BLACK, Vector3.new(0.223, 0.164, 0.33), at(-0.006, 2.929, -1.384, FACE_TILT)),
	part("MouthR", "Muzzle", BLACK, Vector3.new(0.209, 0.164, 0.33), at(0.321, 2.929, -1.384, FACE_TILT)),
	part("Nose", "Nose", BLACK, Vector3.new(0.106, 0.203, 0.33), at(0.163, 3.112, -1.384, FACE_TILT)),
	-- Each ear is three layers: the tall white back, the pink inside and a wider white rim.
	part("EarL", "EarL", WHITE, Vector3.new(0.526, 1.316, 0.132), at(-0.531, 4.64, -0.579)),
	part("EarLInner", "EarL", PINK, Vector3.new(0.395, 1.093, 0.143), at(-0.531, 4.595, -0.585)),
	part("EarLRim", "EarL", WHITE, Vector3.new(0.658, 1.118, 0.108), at(-0.531, 4.542, -0.568)),
	part("EarR", "EarR", WHITE, Vector3.new(0.526, 1.316, 0.132), at(0.65, 4.637, -0.579, -0.001)),
	part("EarRInner", "EarR", PINK, Vector3.new(0.395, 1.093, 0.143), at(0.65, 4.591, -0.585, -0.001)),
	part("EarRRim", "EarR", WHITE, Vector3.new(0.658, 1.118, 0.108), at(0.65, 4.538, -0.568)),
	part("LegFL", "LegFL", WHITE, Vector3.new(0.68, 1.927, 0.827), at(-0.647, 1.349, -0.894, FACE_TILT)),
	part("LegFR", "LegFR", WHITE, Vector3.new(0.68, 1.927, 0.827), at(0.669, 1.349, -0.894, FACE_TILT)),
	part("FootL", "FootL", WHITE, Vector3.new(0.553, 0.488, 1.567), at(-1.33, 0.494, -0.703, FACE_TILT)),
	part("FootR", "FootR", WHITE, Vector3.new(0.511, 0.451, 1.448), at(1.352, 0.494, -0.703, -0.191)),
	-- Hidden at rest (inside the cheeks and the muzzle); the animation slides them out.
	part("LidL", "Lids", WHITE, Vector3.new(0.34, 0.3, 0.04), at(-0.349, 3.479, -1.25, FACE_TILT)),
	part("LidR", "Lids", WHITE, Vector3.new(0.34, 0.3, 0.04), at(0.651, 3.479, -1.25, FACE_TILT)),
	part("LashL", "Lids", BLACK, Vector3.new(0.3, 0.05, 0.02), at(-0.349, 3.45, -1.275, FACE_TILT)),
	part("LashR", "Lids", BLACK, Vector3.new(0.3, 0.05, 0.02), at(0.651, 3.45, -1.275, FACE_TILT)),
	part("MouthOpen", "Mouth", MOUTH, Vector3.new(0.34, 0.2, 0.08), at(0.16, 2.85, -1.36, FACE_TILT)),
}

local BunnyModel = {}

BunnyModel.Definition = table.freeze({
	bones = table.freeze(BONES),
	parts = table.freeze(PARTS),
}) :: PetRig.ModelDef

-- Eyelid translation that covers the eyes (a blink, or happy closed eyes).
BunnyModel.BlinkOffset = Vector3.new(0, 0, -0.17)
-- Mouth translation that drops the open mouth out under the muzzle.
BunnyModel.MouthOpenOffset = Vector3.new(0, -0.2, -0.12)
-- Part the bubble floats above.
BunnyModel.HeadPart = "HeadTop"

return table.freeze(BunnyModel)

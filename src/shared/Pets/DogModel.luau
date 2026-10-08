--!strict
--[[
	DogModel
	The blocky dog from the art pass (pets.rbxm, Tool "Dog") as data, split
	into bones so it can be animated. Sizes, positions and colors are the
	original ones. Four extra parts hide inside the head at rest (open mouth,
	tongue and the two eyelids) and only slide out to bark, pant and blink, so
	the dog looks exactly like the original when it is not doing anything.

	Units are studs in the dog's own frame: origin on the ground under the
	body, facing -Z (LookVector), +X is the dog's right.
]]

local PetRig = require(script.Parent.PetRig)

local rgb = Color3.fromRGB

local FUR = rgb(226, 155, 64)
local WHITE = rgb(237, 234, 234)
local CREAM = rgb(254, 243, 187)
local BLACK = rgb(17, 17, 17)
local PINK = rgb(255, 120, 150)

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
	bone("Body", nil, at(-0.046, 1.683, -0.135)),
	bone("Head", "Body", at(-0.03, 2.2, -0.7)), -- neck, at the back-bottom of the head
	bone("EarL", "Head", at(-0.493, 3.021, -1.156, 0, 0, 15.3)), -- ear bases, tilted like the ears
	bone("EarR", "Head", at(0.472, 3.085, -1.169, 0, 0, -17.9)),
	bone("Jaw", "Head", at(-0.014, 2.235, -1.62)), -- open mouth, tucked inside the head
	bone("Tongue", "Jaw", at(-0.014, 2.173, -1.53)),
	bone("Lids", "Head", at(-0.04, 2.928, -1.777)), -- eyelids, tucked behind the eyes
	bone("Tail", "Body", at(-0.038, 1.96, 1.068, -28.7, 0, 0)), -- where the tail leaves the body
	bone("LegFL", "Body", at(-0.549, 1.35, -1.029)), -- hips/shoulders, just inside the body
	bone("LegFR", "Body", at(0.459, 1.35, -1.029)),
	bone("LegBL", "Body", at(-0.548, 1.35, 0.753)),
	bone("LegBR", "Body", at(0.459, 1.35, 0.767)),
}

local PARTS: { PetRig.PartDef } = {
	part("Body", "Body", FUR, Vector3.new(1.558, 0.971, 2.405), at(-0.046, 1.683, -0.135)),
	part("BodyStripe", "Body", WHITE, Vector3.new(0.566, 1.042, 2.489), at(-0.055, 1.681, -0.177)),
	part("HeadLower", "Head", FUR, Vector3.new(1.566, 0.581, 1.384), at(-0.032, 2.349, -1.167)),
	part("HeadUpper", "Head", FUR, Vector3.new(1.385, 0.789, 1.353), at(-0.026, 2.742, -1.151)),
	part("HeadTop", "Head", FUR, Vector3.new(0.991, 0.075, 1.152), at(-0.018, 3.162, -1.137)),
	part("Snout", "Head", FUR, Vector3.new(0.749, 0.581, 0.244), at(-0.064, 2.349, -1.98)),
	part("Nose", "Head", BLACK, Vector3.new(0.371, 0.352, 0.152), at(-0.023, 2.483, -2.091)),
	part("Mouth", "Head", BLACK, Vector3.new(0.121, 0.31, 0.353), at(-0.014, 2.175, -1.99)),
	part("EyeL", "Head", BLACK, Vector3.new(0.448, 0.4, 0.03), at(-0.377, 2.883, -1.842)),
	part("EyeR", "Head", BLACK, Vector3.new(0.448, 0.4, 0.03), at(0.3, 2.883, -1.842)),
	part("EarL", "EarL", FUR, Vector3.new(0.309, 0.676, 0.214), at(-0.582, 3.347, -1.156, 0, 0, 15.3)),
	part("EarLRimIn", "EarL", FUR, Vector3.new(0.086, 0.539, 0.214), at(-0.376, 3.333, -1.156, 0, 0, 15.3)),
	part("EarLRimOut", "EarL", FUR, Vector3.new(0.092, 0.539, 0.214), at(-0.749, 3.231, -1.156, 0, 0, 15.3)),
	part("EarLInner", "EarL", BLACK, Vector3.new(0.237, 0.62, 0.174), at(-0.565, 3.323, -1.194, 0, 0, 15.3)),
	part("EarR", "EarR", FUR, Vector3.new(0.309, 0.676, 0.214), at(0.576, 3.407, -1.169, 0, 0, -17.9)),
	part("EarRRimIn", "EarR", FUR, Vector3.new(0.092, 0.539, 0.214), at(0.372, 3.401, -1.169, 0, 0, -17.9)),
	part("EarRRimOut", "EarR", FUR, Vector3.new(0.086, 0.539, 0.214), at(0.74, 3.282, -1.169, 0, 0, -17.9)),
	part("EarRInner", "EarR", BLACK, Vector3.new(0.237, 0.62, 0.174), at(0.577, 3.378, -1.207, 0, 0, -17.9)),
	part("Tail", "Tail", WHITE, Vector3.new(0.557, 0.666, 1.307), at(-0.038, 2.106, 1.335, -28.7, 0, 0)),
	part("TailTip", "Tail", WHITE, Vector3.new(0.557, 0.666, 0.134), at(-0.038, 2.441, 1.948, -28.7, 0, 0)),
	part("LegFL", "LegFL", FUR, Vector3.new(0.479, 1.03, 0.516), at(-0.549, 0.681, -1.029)),
	part("PawFL", "LegFL", CREAM, Vector3.new(0.479, 0.166, 0.516), at(-0.549, 0.083, -1.029)),
	part("LegFR", "LegFR", FUR, Vector3.new(0.479, 1.03, 0.516), at(0.459, 0.681, -1.029)),
	part("PawFR", "LegFR", CREAM, Vector3.new(0.479, 0.166, 0.516), at(0.459, 0.083, -1.029)),
	part("LegBL", "LegBL", FUR, Vector3.new(0.479, 1.03, 0.516), at(-0.548, 0.681, 0.753)),
	part("PawBL", "LegBL", CREAM, Vector3.new(0.479, 0.166, 0.516), at(-0.548, 0.083, 0.753)),
	part("LegBR", "LegBR", FUR, Vector3.new(0.479, 1.03, 0.516), at(0.459, 0.681, 0.767)),
	part("PawBR", "LegBR", CREAM, Vector3.new(0.479, 0.166, 0.516), at(0.459, 0.083, 0.767)),
	-- Hidden at rest (inside the head); the animation slides them out.
	part("MouthOpen", "Jaw", BLACK, Vector3.new(0.4, 0.28, 0.3), at(-0.014, 2.235, -1.62)),
	part("Tongue", "Tongue", PINK, Vector3.new(0.22, 0.07, 0.3), at(-0.014, 2.138, -1.68)),
	part("LidL", "Lids", FUR, Vector3.new(0.47, 0.31, 0.03), at(-0.377, 2.928, -1.777)),
	part("LidR", "Lids", FUR, Vector3.new(0.47, 0.31, 0.03), at(0.3, 2.928, -1.777)),
}

local DogModel = {}

DogModel.Definition = table.freeze({
	bones = table.freeze(BONES),
	parts = table.freeze(PARTS),
}) :: PetRig.ModelDef

-- Jaw translation that brings the open mouth (and tongue) out in front of the snout.
DogModel.JawOpenOffset = Vector3.new(0, -0.08, -0.4)
-- Eyelid translation that covers the eyes (a blink).
DogModel.BlinkOffset = Vector3.new(0, 0, -0.1)
-- Part the WOOF bubble floats above.
DogModel.HeadPart = "HeadTop"

return table.freeze(DogModel)

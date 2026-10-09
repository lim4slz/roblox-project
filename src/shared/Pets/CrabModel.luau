--!strict
--[[
	CrabModel
	The blocky crab from the art pass (pets.rbxm, Tool "Crab") as data, split
	into bones so it can be animated. Sizes, positions and colors are the
	original ones (the art was turned 1.606 degrees, that is undone here).
	Five extra parts hide at rest (an eyelid inside each eye rim, a neck
	inside the shell under each eye stalk and a mouth inside the belly) and
	only slide out to blink, pop the eyes up and snap, so the crab looks
	exactly like the original when it is not doing anything.

	Units are studs in the crab's own frame: origin on the ground under the
	body, facing -Z (LookVector), +X is the crab's right.

	Root carries the whole crab (it turns its side to where it walks and hops
	when it snaps); the shell, eyes and claws sit on Body, the legs on Root,
	so the shell can bob and rock while the feet stay on the ground. Each
	claw lies in one upright plane and its bones are turned like that plane:
	a rotation about their Z axis swings the claw, or a pincer finger, inside
	the plane. The legs and the eye stalks have upright, unturned bones.
]]

local PetRig = require(script.Parent.PetRig)

local rgb = Color3.fromRGB

local RED = rgb(255, 0, 0)
local LIGHT_RED = rgb(255, 89, 89)
local BLACK = rgb(17, 17, 17)

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
	bone("Root", nil, at(0, 0, 0)),
	bone("Body", "Root", at(0.139, 1.248, 0)), -- where the shell meets the belly
	bone("Mouth", "Body", at(0.03, 0.97, -1.035)), -- open mouth, tucked inside the belly
	bone("StalkL", "Body", at(-0.687, 1.72, -0.218)), -- eye stalks, where they leave the shell
	bone("LidL", "StalkL", at(-0.681, 2.285, -0.37)), -- eyelids, tucked inside the eye rims
	bone("StalkR", "Body", at(0.726, 1.72, -0.262)),
	bone("LidR", "StalkR", at(0.726, 2.2605, -0.41)),
	-- Claws: shoulder (inside the body), elbow, wrist, finger hinges.
	bone("ArmL", "Body", at(-0.865, 1.1, -0.844, 0, -26.84, 0)),
	bone("ForearmL", "ArmL", at(-1.415, 0.937, -1.121, 0, -26.84, 0)),
	bone("PincerL", "ForearmL", at(-1.585, 1.585, -1.211, 0, -26.84, 0)),
	bone("FingerLIn", "PincerL", at(-1.456, 1.877, -1.146, 0, -26.84, 0)),
	bone("FingerLOut", "PincerL", at(-1.713, 1.878, -1.276, 0, -26.84, 0)),
	bone("ArmR", "Body", at(1.258, 1.338, -0.88, -3.023, 39.323, 0)),
	bone("ForearmR", "ArmR", at(1.688, 0.991, -1.214, -3.023, 39.323, 0)),
	bone("PincerR", "ForearmR", at(1.973, 1.557, -1.474, -3.023, 39.323, 0)),
	bone("FingerRIn", "PincerR", at(1.926, 1.883, -1.454, -3.023, 39.323, 0)),
	bone("FingerROut", "PincerR", at(2.144, 1.796, -1.628, -3.023, 39.323, 0)),
	-- Legs: hips just inside the belly, knees where the two segments meet.
	bone("LegFL", "Root", at(-1.011, 1.003, -0.225)),
	bone("ShinFL", "LegFL", at(-2.168, 1.473, -0.484)),
	bone("LegFR", "Root", at(1.089, 1.03, -0.009)),
	bone("ShinFR", "LegFR", at(2.123, 1.481, -0.606)),
	bone("LegBL", "Root", at(-1.079, 0.968, 0.486)),
	bone("ShinBL", "LegBL", at(-2.117, 1.484, 1.018)),
	bone("LegBR", "Root", at(1.019, 1.003, 0.558)),
	bone("ShinBR", "LegBR", at(2.145, 1.492, 0.907)),
}

local PARTS: { PetRig.PartDef } = {
	part("Shell", "Body", RED, Vector3.new(2.671, 0.472, 2.471), at(0.129, 1.484, 0)),
	part("Belly", "Body", LIGHT_RED, Vector3.new(2.48, 0.472, 2.108), at(0.149, 1.012, -0.035)),
	part("StalkL", "StalkL", RED, Vector3.new(0.523, 0.581, 0.522), at(-0.687, 1.902, -0.218)),
	part("EyeRimL", "StalkL", RED, Vector3.new(0.613, 0.681, 0.424), at(-0.672, 2.294, -0.181)),
	part("EyeL", "StalkL", BLACK, Vector3.new(0.505, 0.651, 0.4), at(-0.681, 2.279, -0.199)),
	part("StalkR", "StalkR", RED, Vector3.new(0.523, 0.448, 0.522), at(0.726, 1.945, -0.262, 0, -0.001, 0)),
	part("EyeRimR", "StalkR", RED, Vector3.new(0.632, 0.681, 0.424), at(0.731, 2.271, -0.225, 0, -0.001, 0)),
	part("EyeR", "StalkR", BLACK, Vector3.new(0.522, 0.651, 0.4), at(0.726, 2.256, -0.242, 0, -0.001, 0)),
	part("ArmL", "ArmL", RED, Vector3.new(0.765, 0.264, 0.35), at(-1.196, 1.005, -1.011, 0, -26.84, 14.371)),
	part("ForearmL", "ForearmL", RED, Vector3.new(0.347, 0.692, 0.35), at(-1.492, 1.272, -1.16, 0, -26.84, 14.371)),
	part("PincerL", "PincerL", RED, Vector3.new(0.486, 0.296, 0.405), at(-1.581, 1.733, -1.209, 0, -26.84, -1.772)),
	part("FingerLIn", "FingerLIn", RED, Vector3.new(0.197, 0.301, 0.405), at(-1.452, 2.027, -1.144, 0, -26.84, -1.772)),
	part(
		"FingerLOut",
		"FingerLOut",
		RED,
		Vector3.new(0.197, 0.377, 0.405),
		at(-1.747, 2.063, -1.293, 0, -26.84, 11.633)
	),
	part("ArmR", "ArmR", RED, Vector3.new(0.775, 0.267, 0.355), at(1.517, 1.132, -1.082, -3.023, 39.323, -30.215)),
	part(
		"ForearmR",
		"ForearmR",
		RED,
		Vector3.new(0.352, 0.701, 0.355),
		at(1.824, 1.288, -1.342, -3.023, 39.323, -30.215)
	),
	part("PincerR", "PincerR", RED, Vector3.new(0.493, 0.3, 0.411), at(2.001, 1.701, -1.505, -3.023, 39.323, -14.072)),
	part(
		"FingerRIn",
		"FingerRIn",
		RED,
		Vector3.new(0.2, 0.305, 0.411),
		at(1.955, 2.029, -1.485, -3.023, 39.323, -14.072)
	),
	part(
		"FingerROut",
		"FingerROut",
		RED,
		Vector3.new(0.2, 0.382, 0.411),
		at(2.212, 1.962, -1.693, -3.023, 39.323, -27.477)
	),
	part(
		"LegFL",
		"LegFL",
		LIGHT_RED,
		Vector3.new(1.462, 0.429, 0.507),
		at(-1.683, 1.249, -0.375, -1.079, -12.195, -19.924)
	),
	part(
		"ShinFL",
		"ShinFL",
		LIGHT_RED,
		Vector3.new(0.429, 1.462, 0.507),
		at(-2.149, 0.742, -0.466, -1.079, -12.195, 1.524)
	),
	part(
		"LegFR",
		"LegFR",
		LIGHT_RED,
		Vector3.new(1.462, 0.429, 0.507),
		at(1.689, 1.266, -0.354, -3.472, 28.834, 20.509)
	),
	part(
		"ShinFR",
		"ShinFR",
		LIGHT_RED,
		Vector3.new(0.429, 1.462, 0.507),
		at(2.112, 0.752, -0.556, -3.472, 28.834, -0.94)
	),
	part(
		"LegBL",
		"LegBL",
		LIGHT_RED,
		Vector3.new(1.462, 0.429, 0.507),
		at(-1.683, 1.241, 0.794, 4.002, 25.487, -23.731)
	),
	part(
		"ShinBL",
		"ShinBL",
		LIGHT_RED,
		Vector3.new(0.429, 1.462, 0.507),
		at(-2.143, 0.754, 0.98, 4.002, 25.487, -2.283)
	),
	part(
		"LegBR",
		"LegBR",
		LIGHT_RED,
		Vector3.new(1.462, 0.429, 0.507),
		at(1.673, 1.26, 0.761, -0.431, -17.401, 20.438)
	),
	part(
		"ShinBR",
		"ShinBR",
		LIGHT_RED,
		Vector3.new(0.429, 1.462, 0.507),
		at(2.133, 0.761, 0.909, -0.431, -17.401, -1.01)
	),
	-- Hidden at rest; the animation slides them out.
	part("Mouth", "Mouth", BLACK, Vector3.new(0.5, 0.16, 0.1), at(0.03, 0.97, -1.035)),
	part("NeckL", "StalkL", RED, Vector3.new(0.47, 0.32, 0.47), at(-0.687, 1.555, -0.218)),
	part("NeckR", "StalkR", RED, Vector3.new(0.47, 0.32, 0.47), at(0.726, 1.56, -0.262)),
	part("LidL", "LidL", RED, Vector3.new(0.53, 0.66, 0.03), at(-0.681, 2.285, -0.37)),
	part("LidR", "LidR", RED, Vector3.new(0.55, 0.66, 0.03), at(0.726, 2.2605, -0.41)),
}

local CrabModel = {}

CrabModel.Definition = table.freeze({
	bones = table.freeze(BONES),
	parts = table.freeze(PARTS),
}) :: PetRig.ModelDef

-- Mouth translation that brings the open mouth out under the front of the shell.
CrabModel.MouthOpenOffset = Vector3.new(0, 0, -0.08)
-- Eye stalk translation that pops the eyes up (the necks fill the gap).
CrabModel.EyePopOffset = Vector3.new(0, 0.28, 0)
-- Eyelid translation that covers the eyes (a blink).
CrabModel.BlinkOffset = Vector3.new(0, -0.004, -0.07)
-- Part the SNAP bubble floats above.
CrabModel.HeadPart = "EyeRimL"

return table.freeze(CrabModel)

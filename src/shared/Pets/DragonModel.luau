--!strict
--[[
	DragonModel
	The blocky dragon from the art pass (Dragon_Pet.rbxm) as data, rigged
	into bones so it can fly: the head with a jaw that opens, two wings that
	flap from their roots, a tail in three pieces and four legs. Sizes,
	positions and colors are the original ones.

	Extra parts hide at rest and only come out when animated, so the dragon
	looks exactly like the original when it is not doing anything: two
	eyelids inside the head, the inside of the mouth inside the jaw, and four
	flames (Neon) inside the head that it breathes out.

	Units are studs in the dragon's own frame: origin on the ground under the
	body, facing -Z (LookVector), +X is the dragon's right. The art names its
	groups as seen from the front (its "wingL" is the dragon's right wing);
	here every L and R is the dragon's own left and right.
]]

local PetRig = require(script.Parent.PetRig)

local rgb = Color3.fromRGB

local GREEN = rgb(75, 151, 75)
local YELLOW = rgb(248, 217, 109)
local PALE = rgb(253, 234, 141)
local WHITE = rgb(237, 234, 234)
local BLACK = rgb(17, 17, 17)
local MOUTH = rgb(120, 22, 22)

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function bone(name: string, parent: string?, pivot: CFrame): PetRig.BoneDef
	return { name = name, parent = parent, pivot = pivot }
end

local function part(name: string, boneName: string, color: Color3, size: Vector3, cframe: CFrame): PetRig.PartDef
	return { name = name, bone = boneName, color = color, size = size, cframe = cframe }
end

-- The flames wait inside the head, all in the same place.
local FIRE_PIVOT = at(-0.06, 2.95, -1.45)

local function flame(name: string, color: Color3, size: number, transparency: number): PetRig.PartDef
	return {
		name = name,
		bone = name,
		color = color,
		size = Vector3.one * size,
		cframe = FIRE_PIVOT,
		material = Enum.Material.Neon,
		transparency = transparency,
	}
end

local WING_R = { 0, 0, 8.772 }
local WING_L = { 1.007, 0, -6.374 }
local TAIL = 5.177

-- Parents always come before their children (PetRig requires it).
local BONES: { PetRig.BoneDef } = {
	bone("Body", nil, at(-0.059, 1.891, 0)),
	bone("Head", "Body", at(-0.06, 2.45, -1)), -- neck, at the back-bottom of the head
	bone("Jaw", "Head", at(-0.07, 2.4615, -1.885)), -- hinge at the back-top of the jaw
	bone("Lids", "Head", at(-0.06, 3.19, -2.23)),
	bone("Fire1", "Head", FIRE_PIVOT),
	bone("Fire2", "Head", FIRE_PIVOT),
	bone("Fire3", "Head", FIRE_PIVOT),
	bone("Fire4", "Head", FIRE_PIVOT),
	bone("WingR", "Body", at(0.62, 2.58, -0.1)), -- wing roots, on the back
	bone("WingL", "Body", at(-0.6, 2.6, 0.05)),
	bone("Tail1", "Body", at(-0.029, 2.204, 0.684)), -- front end of each tail piece
	bone("Tail2", "Tail1", at(-0.029, 2.1, 1.83)),
	bone("Tail3", "Tail2", at(-0.031, 2.007, 2.786)),
	bone("LegFR", "Body", at(0.53, 1.387, -1.207)), -- hips, at the top of the legs
	bone("LegFL", "Body", at(-0.638, 1.387, -1.203)),
	bone("LegBR", "Body", at(0.53, 1.387, 1.09)),
	bone("LegBL", "Body", at(-0.638, 1.387, 1.079)),
}

local PARTS: { PetRig.PartDef } = {
	-- Body: the main block, the belly, the plate on the back and a thin
	-- panel on each side.
	part("Body", "Body", GREEN, Vector3.new(1.644, 1.058, 2.798), at(-0.059, 1.891, 0)),
	part("Belly", "Body", GREEN, Vector3.new(1.356, 1.057, 2.791), at(-0.056, 1.851, -0.124)),
	part("Back", "Body", GREEN, Vector3.new(1.47, 0.319, 2.154), at(-0.058, 2.545, 0.203)),
	part("SideR", "Body", GREEN, Vector3.new(0.032, 0.819, 1.497), at(0.782, 1.922, 0.65)),
	part("SideL", "Body", GREEN, Vector3.new(0.01, 0.819, 1.497), at(-0.889, 1.922, 0.65)),
	-- Head
	part("Head", "Head", GREEN, Vector3.new(1.84, 1.472, 1.54), at(-0.059, 2.913, -1.483)),
	part("HeadBack", "Head", GREEN, Vector3.new(1.711, 1.43, 0.899), at(-0.067, 2.892, -1.087)),
	part("Cheeks", "Head", GREEN, Vector3.new(1.947, 1.085, 1.167), at(-0.062, 2.827, -1.518)),
	part("HornR", "Head", GREEN, Vector3.new(0.38, 0.36, 1.593), at(0.496, 3.88, -1, -39.839)),
	part("HornL", "Head", GREEN, Vector3.new(0.356, 0.36, 1.55), at(-0.618, 3.877, -1.025, -39.839)),
	part("EyeR", "Head", BLACK, Vector3.new(0.305, 0.337, 0.174), at(0.392, 3.194, -2.189)),
	part("EyeL", "Head", BLACK, Vector3.new(0.305, 0.337, 0.174), at(-0.511, 3.189, -2.189)),
	part("Snout", "Head", GREEN, Vector3.new(1.066, 0.451, 0.736), at(-0.07, 2.687, -2.253)),
	part("NostrilR", "Head", PALE, Vector3.new(0.36, 0.152, 0.021), at(0.204, 2.724, -2.632)),
	part("NostrilL", "Head", PALE, Vector3.new(0.36, 0.152, 0.021), at(-0.32, 2.724, -2.632)),
	part("FangR", "Head", WHITE, Vector3.new(0.115, 0.269, 0.162), at(0.451, 2.333, -2.556)),
	part("FangL", "Head", WHITE, Vector3.new(0.115, 0.269, 0.162), at(-0.573, 2.333, -2.556)),
	part("Jaw", "Jaw", YELLOW, Vector3.new(1.066, 0.177, 0.736), at(-0.07, 2.373, -2.253)),
	-- Wings: a green frame (root, leading edge, rib, tip) holding two
	-- yellow panels.
	part("WingRRoot", "WingR", GREEN, Vector3.new(0.156, 0.214, 1.613), at(0.59, 2.57, -0.013, table.unpack(WING_R))),
	part("WingREdge", "WingR", GREEN, Vector3.new(2.844, 0.214, 0.239), at(2.072, 2.8, -0.7, table.unpack(WING_R))),
	part("WingRInner", "WingR", YELLOW, Vector3.new(1.706, 0.214, 1.377), at(1.51, 2.713, 0.108, table.unpack(WING_R))),
	part("WingRRib", "WingR", GREEN, Vector3.new(0.156, 0.15, 1.583), at(2.406, 2.798, 0, table.unpack(WING_R))),
	part(
		"WingROuter",
		"WingR",
		YELLOW,
		Vector3.new(1.138, 0.214, 1.064),
		at(2.916, 2.93, -0.048, table.unpack(WING_R))
	),
	part("WingRTip", "WingR", GREEN, Vector3.new(0.16, 0.214, 1.275), at(3.557, 3.029, -0.154, table.unpack(WING_R))),
	part("WingLRoot", "WingL", GREEN, Vector3.new(0.156, 0.214, 1.613), at(-0.577, 2.583, 0.12, table.unpack(WING_L))),
	part(
		"WingLEdge",
		"WingL",
		GREEN,
		Vector3.new(2.844, 0.214, 0.239),
		at(-2.068, 2.761, -0.564, table.unpack(WING_L))
	),
	part(
		"WingLInner",
		"WingL",
		YELLOW,
		Vector3.new(1.706, 0.214, 1.377),
		at(-1.503, 2.684, 0.243, table.unpack(WING_L))
	),
	part("WingLRib", "WingL", GREEN, Vector3.new(0.156, 0.15, 1.583), at(-2.404, 2.712, 0.136, table.unpack(WING_L))),
	part(
		"WingLOuter",
		"WingL",
		YELLOW,
		Vector3.new(1.138, 0.214, 1.064),
		at(-2.916, 2.845, 0.089, table.unpack(WING_L))
	),
	part("WingLTip", "WingL", GREEN, Vector3.new(0.16, 0.214, 1.275), at(-3.561, 2.918, -0.015, table.unpack(WING_L))),
	-- Tail
	part("Tail1", "Tail1", GREEN, Vector3.new(0.679, 0.694, 1.15), at(-0.029, 2.152, 1.257, TAIL)),
	part("Tail2", "Tail2", GREEN, Vector3.new(0.679, 0.694, 1.15), at(-0.029, 2.048, 2.402, TAIL)),
	part("Tail3", "Tail3", GREEN, Vector3.new(0.556, 0.567, 1.634), at(-0.031, 1.933, 3.6, TAIL)),
	-- Legs and feet
	part("LegFR", "LegFR", GREEN, Vector3.new(0.694, 1.387, 0.694), at(0.53, 0.694, -1.207)),
	part("LegFL", "LegFL", GREEN, Vector3.new(0.694, 1.387, 0.694), at(-0.638, 0.694, -1.203)),
	part("LegBR", "LegBR", GREEN, Vector3.new(0.694, 1.387, 0.694), at(0.53, 0.694, 1.09)),
	part("LegBL", "LegBL", GREEN, Vector3.new(0.694, 1.387, 0.694), at(-0.638, 0.694, 1.079)),
	part("FootFR", "LegFR", YELLOW, Vector3.new(0.573, 0.463, 0.803), at(0.528, 0.231, -1.276)),
	part("FootFL", "LegFL", YELLOW, Vector3.new(0.573, 0.463, 0.803), at(-0.64, 0.231, -1.272)),
	part("FootBR", "LegBR", YELLOW, Vector3.new(0.573, 0.463, 0.803), at(0.528, 0.231, 1.021)),
	part("FootBL", "LegBL", YELLOW, Vector3.new(0.573, 0.463, 0.803), at(-0.64, 0.231, 1.01)),
	-- Hidden at rest; the animation brings them out.
	part("LidR", "Lids", GREEN, Vector3.new(0.33, 0.36, 0.03), at(0.392, 3.194, -2.23)),
	part("LidL", "Lids", GREEN, Vector3.new(0.33, 0.36, 0.03), at(-0.511, 3.189, -2.23)),
	part("Mouth", "Head", MOUTH, Vector3.new(0.9, 0.16, 0.62), at(-0.07, 2.38, -2.2)),
	flame("Fire1", rgb(255, 236, 110), 0.45, 0),
	flame("Fire2", rgb(255, 176, 50), 0.65, 0.1),
	flame("Fire3", rgb(255, 112, 26), 0.85, 0.2),
	flame("Fire4", rgb(222, 56, 20), 1.05, 0.35),
}

local DragonModel = {}

DragonModel.Definition = table.freeze({
	bones = table.freeze(BONES),
	parts = table.freeze(PARTS),
}) :: PetRig.ModelDef

-- Eyelid translation that covers the eyes (a blink).
DragonModel.BlinkOffset = Vector3.new(0, 0, -0.06)
-- The flames, from the one at the mouth to the one furthest out.
DragonModel.Flames = table.freeze({ "Fire1", "Fire2", "Fire3", "Fire4" })
-- Flame translation (head frame, from inside the head) that puts a flame
-- just in front of the mouth; each next flame goes FlameSpacing further.
DragonModel.FlameStart = Vector3.new(0, -0.5, -1.3)
DragonModel.FlameSpacing = Vector3.new(0, -0.08, -0.85)
-- Part the bubble floats above.
DragonModel.HeadPart = "Head"

return table.freeze(DragonModel)

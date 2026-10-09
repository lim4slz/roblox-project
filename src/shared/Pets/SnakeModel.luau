--!strict
--[[
	SnakeModel
	The blocky snake from the art pass (pets.rbxm, Tool "Sneak") as data, split
	into bones so it can slither. Sizes, positions and colors are the original
	ones; the art turned most blocks 90 degrees, here they are stored
	axis-aligned (same boxes). Five extra parts hide inside the head at rest
	(open mouth, two fangs and two angry brows) and only slide out to hiss, so
	the snake looks exactly like the original when it is not doing anything.

	Units are studs in the snake's own frame: origin on the ground under the
	center of the head, facing -Z (LookVector), +X is the snake's right. The
	body trails behind along +Z.

	The spine is a chain of rigid bones (the head, then the ten body
	segments). Every spine bone pivots at its front joint on the spine axis
	and points from its back joint to its front joint, so a pose can lay the
	body along any curve (see SnakeAnimation).
]]

local PetRig = require(script.Parent.PetRig)

local rgb = Color3.fromRGB

local GREEN = rgb(44, 101, 29)
local LIGHT_GREEN = rgb(91, 154, 76)
local BLACK = rgb(17, 17, 17)
local TONGUE = rgb(218, 134, 122)
local WHITE = rgb(248, 248, 240)

-- Height of the spine axis above the ground (the body blocks sit on the ground).
local SPINE_HEIGHT = 0.408
-- Distance of every spine joint along the body, from the center of the head
-- to the tip of the tail. Spine bone i spans JOINTS[i]..JOINTS[i + 1].
local JOINTS = { 0, 0.749, 2.042, 3.336, 4.63, 5.923, 7.217, 8.522, 9.623, 10.559, 12.041, 13.523 }
local SPINE = { "Head", "Body1", "Body2", "Body3", "Body4", "Body5", "Body6", "Body7", "Body8", "Body9", "Body10" }

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function bone(name: string, parent: string?, pivot: CFrame): PetRig.BoneDef
	return { name = name, parent = parent, pivot = pivot }
end

local function part(name: string, boneName: string, color: Color3, size: Vector3, cframe: CFrame): PetRig.PartDef
	return { name = name, bone = boneName, color = color, size = size, cframe = cframe }
end

local function wedge(name: string, boneName: string, color: Color3, size: Vector3, cframe: CFrame): PetRig.PartDef
	return { name = name, bone = boneName, color = color, size = size, cframe = cframe, shape = Enum.PartType.Wedge }
end

-- Parents always come before their children (PetRig requires it).
local BONES: { PetRig.BoneDef } = {}
for index, name in SPINE do
	table.insert(BONES, bone(name, nil, CFrame.new(0, SPINE_HEIGHT, JOINTS[index])))
end
table.insert(BONES, bone("Tongue", "Head", at(-0.067, 0.381, -0.8))) -- where the tongue leaves the face
table.insert(BONES, bone("Mouth", "Head", at(-0.04, 0.33, -0.75))) -- open mouth and fangs, behind the face
table.insert(BONES, bone("BrowL", "Head", at(-0.41, 0.66, -0.07))) -- angry brows, inside the head
table.insert(BONES, bone("BrowR", "Head", at(0.44, 0.66, -0.07)))

local PARTS: { PetRig.PartDef } = {
	part("Head", "Head", GREEN, Vector3.new(1.226, 0.885, 1.498), at(0, 0.442, 0)),
	part("HeadTop", "Head", LIGHT_GREEN, Vector3.new(1.057, 0.034, 1.073), at(0, 0.902, -0.076)),
	part("Face", "Head", LIGHT_GREEN, Vector3.new(1.057, 0.675, 0.052), at(-0.017, 0.45, -0.775)),
	part("SideL", "Head", LIGHT_GREEN, Vector3.new(0.068, 0.75, 1.371), at(-0.613, 0.442, -0.005)),
	part("SideR", "Head", LIGHT_GREEN, Vector3.new(0.068, 0.75, 1.371), at(0.647, 0.442, -0.005)),
	part("EyeL", "Head", BLACK, Vector3.new(0.105, 0.478, 0.69), at(-0.631, 0.51, -0.073)),
	part("EyeR", "Head", BLACK, Vector3.new(0.105, 0.478, 0.69), at(0.662, 0.51, -0.073)),
	part("Tongue", "Tongue", TONGUE, Vector3.new(0.34, 0.136, 1.226), at(-0.067, 0.381, -1.278)),
	wedge("ForkL", "Tongue", TONGUE, Vector3.new(0.136, 0.204, 0.272), at(-0.211, 0.382, -2.027, 0, 0, -90)),
	wedge("ForkR", "Tongue", TONGUE, Vector3.new(0.136, 0.204, 0.272), at(0.069, 0.382, -2.027, 0, 0, 90)),
	part("Body1", "Body1", LIGHT_GREEN, Vector3.new(0.953, 0.817, 1.294), at(0, 0.408, 1.396)),
	part("Body2", "Body2", GREEN, Vector3.new(0.953, 0.817, 1.294), at(0, 0.408, 2.689)),
	part("Body3", "Body3", LIGHT_GREEN, Vector3.new(0.953, 0.817, 1.294), at(0, 0.408, 3.983)),
	part("Body4", "Body4", GREEN, Vector3.new(0.953, 0.817, 1.294), at(0, 0.408, 5.277)),
	part("Body5", "Body5", LIGHT_GREEN, Vector3.new(0.953, 0.817, 1.294), at(0, 0.408, 6.57)),
	part("Body6", "Body6", GREEN, Vector3.new(0.953, 0.817, 1.294), at(0, 0.408, 7.864)),
	part("Body7", "Body7", LIGHT_GREEN, Vector3.new(0.838, 0.718, 1.137), at(0, 0.442, 9.09)),
	part("Body8", "Body8", GREEN, Vector3.new(0.69, 0.592, 0.937), at(0.034, 0.408, 10.091)),
	part("Body9", "Body9", LIGHT_GREEN, Vector3.new(0.554, 0.456, 1.482), at(0.034, 0.408, 11.3)),
	part("Body10", "Body10", GREEN, Vector3.new(0.554, 0.456, 1.482), at(0.034, 0.408, 12.782)),
	-- Hidden at rest (inside the head); the hiss slides them out.
	part("Mouth", "Mouth", BLACK, Vector3.new(0.62, 0.3, 0.2), at(-0.04, 0.33, -0.645)),
	wedge("FangL", "Mouth", WHITE, Vector3.new(0.05, 0.16, 0.1), at(-0.27, 0.39, -0.77, 180, -90, 0)),
	wedge("FangR", "Mouth", WHITE, Vector3.new(0.05, 0.16, 0.1), at(0.19, 0.39, -0.77, 180, 90, 0)),
	part("BrowL", "BrowL", GREEN, Vector3.new(0.04, 0.2, 0.76), at(-0.41, 0.66, -0.07, -18, 0, 0)),
	part("BrowR", "BrowR", GREEN, Vector3.new(0.04, 0.2, 0.76), at(0.44, 0.66, -0.07, -18, 0, 0)),
}

local SnakeModel = {}

SnakeModel.Definition = table.freeze({
	bones = table.freeze(BONES),
	parts = table.freeze(PARTS),
}) :: PetRig.ModelDef

SnakeModel.SpineHeight = SPINE_HEIGHT
SnakeModel.Spine = table.freeze(SPINE)
SnakeModel.Joints = table.freeze(JOINTS)
SnakeModel.Length = JOINTS[#JOINTS]

-- Tongue translation that pulls it (fork included) back inside the head.
SnakeModel.TongueInOffset = Vector3.new(0, 0, 1.41)
-- Mouth translation that brings the open mouth and the fangs out in front of the face.
SnakeModel.MouthOpenOffset = Vector3.new(0, 0, -0.1)
-- How far each brow slides out of the side of the head (left to -X, right to +X).
SnakeModel.BrowOut = 0.3
-- Part the HSSS bubble floats above.
SnakeModel.HeadPart = "HeadTop"

return table.freeze(SnakeModel)

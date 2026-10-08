--!strict
--[[
	PetRig
	Forward kinematics for blocky pets made of rigid parts grouped into bones.

	A model definition lists bones (pivot CFrame in model space + parent bone)
	and parts (rest CFrame in model space + owning bone). Every frame the
	animation supplies one local transform per bone: a rotation about the
	bone's pivot and/or a translation along the bone's own axes. `solve` turns
	that pose into world CFrames for every part, in definition order, ready for
	workspace:BulkMoveTo.

	  local rig = PetRig.new(DogModel.Definition)
	  rig:solve(rootCFrame, pose, cframes) -- fills `cframes` (one per part)
]]

export type BoneDef = { name: string, parent: string?, pivot: CFrame }
export type PartDef = { name: string, bone: string, size: Vector3, cframe: CFrame, color: Color3 }
export type ModelDef = { bones: { BoneDef }, parts: { PartDef } }
-- Local transform per bone name. Missing bones stay in their rest pose.
export type Pose = { [string]: CFrame }

export type PetRig = {
	solve: (self: PetRig, root: CFrame, pose: Pose, out: { CFrame }) -> { CFrame },
	boneCFrame: (self: PetRig, name: string) -> CFrame,
}

type RigImpl = {
	_names: { string },
	_parents: { number }, -- 0 = attached to the root
	_relative: { CFrame }, -- rest pivot relative to the parent pivot (or the root)
	_world: { CFrame }, -- last solved world pivot per bone
	_indexOf: { [string]: number },
	_partBones: { number },
	_partOffsets: { CFrame }, -- part rest CFrame relative to its bone pivot
}

local RigClass = {}
RigClass.__index = RigClass

local PetRig = {}

function PetRig.new(definition: ModelDef): PetRig
	local self: RigImpl = {
		_names = {},
		_parents = {},
		_relative = {},
		_world = {},
		_indexOf = {},
		_partBones = {},
		_partOffsets = {},
	}
	for index, bone in definition.bones do
		assert(self._indexOf[bone.name] == nil, "duplicate bone " .. bone.name)
		local parentIndex = 0
		local relative = bone.pivot
		if bone.parent then
			parentIndex = self._indexOf[bone.parent]
			assert(parentIndex ~= nil, "bone " .. bone.name .. " must come after its parent " .. bone.parent)
			relative = definition.bones[parentIndex].pivot:Inverse() * bone.pivot
		end
		self._indexOf[bone.name] = index
		self._names[index] = bone.name
		self._parents[index] = parentIndex
		self._relative[index] = relative
		self._world[index] = bone.pivot
	end
	for index, part in definition.parts do
		local boneIndex = self._indexOf[part.bone]
		assert(boneIndex ~= nil, "part " .. part.name .. " uses unknown bone " .. part.bone)
		self._partBones[index] = boneIndex
		self._partOffsets[index] = definition.bones[boneIndex].pivot:Inverse() * part.cframe
	end
	return (setmetatable(self, RigClass) :: any) :: PetRig
end

function RigClass.solve(self: RigImpl, root: CFrame, pose: Pose, out: { CFrame }): { CFrame }
	local world = self._world
	for index, name in self._names do
		local parentIndex = self._parents[index]
		local parent = if parentIndex == 0 then root else world[parentIndex]
		local transform = pose[name]
		if transform then
			world[index] = parent * self._relative[index] * transform
		else
			world[index] = parent * self._relative[index]
		end
	end
	for index, boneIndex in self._partBones do
		out[index] = world[boneIndex] * self._partOffsets[index]
	end
	return out
end

-- World pivot of a bone as of the last `solve`.
function RigClass.boneCFrame(self: RigImpl, name: string): CFrame
	local index = self._indexOf[name]
	assert(index ~= nil, "unknown bone " .. name)
	return self._world[index]
end

return table.freeze(PetRig)

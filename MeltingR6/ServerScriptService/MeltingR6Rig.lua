--[[
	Builds the R6 rig for MeltingR6 (Humanoid, HumanoidRootPart and the Motor6Ds).

	In a game: keep this Script in ServerScriptService. When the server starts, every imported
	MeltingR6 sitting in Workspace gets turned into a working R6 character.

	In Studio (to animate it in the Animation Editor): copy all of this, paste it into the
	Command Bar and hit Enter. The rig gets saved into the place and this script leaves it alone.
]]

local BODY = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

-- stock R6 C0s (same as the Rig Builder), in torso space
local JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ "Neck", "Torso", "Head", CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ "Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ "Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	{ "Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ "Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
}

-- "Left Arm", "Left_Arm" and "LeftArm" all count as the same name
local function key(name)
	return (string.lower(name):gsub("[^%w]", ""))
end

local function partsOf(model)
	local parts = {}
	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") then
			local k = key(obj.Name)
			if not parts[k] then
				parts[k] = obj
			end
		end
	end
	return parts
end

local function isUnrigged(obj)
	if not obj:IsA("Model") or obj:FindFirstChildWhichIsA("Humanoid") then
		return false
	end
	local parts = partsOf(obj)
	for _, name in BODY do
		if not parts[key(name)] then
			return false
		end
	end
	return true
end

local function findModels()
	local found = {}
	local function check(obj)
		local current = obj
		while current and current ~= game and current ~= workspace do
			if isUnrigged(current) then
				if not table.find(found, current) then
					table.insert(found, current)
				end
				return
			end
			current = current.Parent
		end
	end

	local ok, selection = pcall(function()
		return game:GetService("Selection"):Get()
	end)
	if ok then
		for _, obj in selection do
			check(obj)
		end
	end
	for _, obj in workspace:GetChildren() do
		check(obj)
	end
	return found
end

local function rig(model)
	local found = partsOf(model)
	local parts = {}
	local isBody = {}
	for _, name in BODY do
		local p = found[key(name)]
		p.Name = name
		p.Parent = model -- the Humanoid looks for the limbs directly under the model
		parts[name] = p
		isBody[p] = true
	end
	local torso = parts.Torso

	local function legsCenter()
		return (parts["Left Leg"].Position + parts["Right Leg"].Position) / 2
	end

	-- scale: on an R6 the torso center sits 2 studs above the legs center
	local height = (torso.Position - legsCenter()).Magnitude
	if math.abs(height - 2) > 0.01 then
		model:ScaleTo(model:GetScale() * 2 / height)
	end

	-- body frame taken from where the parts are, so it doesn't matter
	-- how the importer turned the model
	local up = (torso.Position - legsCenter()).Unit
	local side = parts["Right Arm"].Position - parts["Left Arm"].Position
	local right = (side - up * side:Dot(up)).Unit
	local current = CFrame.fromMatrix(torso.Position, right, up)

	-- stand it up, still facing the same way
	local forward = current.LookVector * Vector3.new(1, 0, 1)
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(0, 0, -1)
	end
	local body = CFrame.lookAt(torso.Position, torso.Position + forward.Unit)
	if (current.UpVector - body.UpVector).Magnitude > 1e-4 then
		model:PivotTo(body * current:Inverse() * model:GetPivot())
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = body
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = false
	root.Parent = model
	parts.HumanoidRootPart = root

	for name, p in parts do
		if name ~= "HumanoidRootPart" then
			p.Anchored = false
			p.Massless = false
			p.CanCollide = name == "Torso" or name == "Head"
			pcall(function()
				p.CollisionFidelity = Enum.CollisionFidelity.Box
			end)
		end
	end

	for _, j in JOINTS do
		local p0, p1 = parts[j[2]], parts[j[3]]
		local joint = body * j[4]
		local motor = Instance.new("Motor6D")
		motor.Name = j[1]
		motor.Part0 = p0
		motor.Part1 = p1
		motor.C0 = p0.CFrame:ToObjectSpace(joint)
		motor.C1 = p1.CFrame:ToObjectSpace(joint)
		motor.MaxVelocity = 0.1
		motor.Parent = p0
	end

	-- everything else (eye, teeth, gums, nerve, mouth, sockets) gets welded to the closest limb
	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") and not isBody[obj] and obj ~= root then
			local target, closest = torso, math.huge
			for _, name in BODY do
				local d = (parts[name].Position - obj.Position).Magnitude
				if d < closest then
					target, closest = parts[name], d
				end
			end
			obj.Anchored = false
			obj.Massless = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.Parent = model
			local weld = Instance.new("Weld")
			weld.Part0 = target
			weld.Part1 = obj
			weld.C0 = target.CFrame:ToObjectSpace(obj.CFrame)
			weld.Parent = obj
		end
	end

	-- clean up the empty folders/models the importer left behind
	local removed = true
	while removed do
		removed = false
		for _, obj in model:GetDescendants() do
			if (obj:IsA("Model") or obj:IsA("Folder")) and #obj:GetChildren() == 0 then
				obj:Destroy()
				removed = true
			end
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid

	model.PrimaryPart = root

	-- if the mesh came in turned inside its part, the rig still works, but the C0s won't have
	-- the usual values (scripts that write a fixed Neck.C0 would spin the head around)
	local aligned = torso.CFrame.LookVector:Dot(body.LookVector) > 0.99
		and torso.CFrame.UpVector:Dot(body.UpVector) > 0.99
	if not aligned then
		warn("[MeltingR6] The mesh came in rotated. The rig works fine, but the C0s aren't the "
			.. "stock values. If you use scripts with a fixed C0 (like a head that follows the mouse), "
			.. "import it again switching World Forward (Front/Back) until the face points forward in the preview.")
	end
end

local models = findModels()
if #models == 0 then
	if not workspace:FindFirstChildWhichIsA("Humanoid", true) then
		warn("[MeltingR6] Couldn't find the imported model in Workspace (it needs Head, Torso, "
			.. "Left Arm, Right Arm, Left Leg and Right Leg). Import MeltingR6.glb with Merge Meshes off.")
	end
	return
end

local history = game:GetService("ChangeHistoryService")
local recording
pcall(function()
	recording = history:TryBeginRecording("Build R6 rig")
end)

local rigged = {}
local allGood = true
for _, model in models do
	local ok, err = pcall(rig, model)
	if ok then
		table.insert(rigged, model)
		print("[MeltingR6] R6 rig ready: " .. model:GetFullName())
	else
		allGood = false
		warn("[MeltingR6] Couldn't rig " .. model:GetFullName() .. ": " .. tostring(err))
	end
end

if recording then
	pcall(function()
		history:FinishRecording(
			recording,
			if allGood then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end)
end

pcall(function()
	game:GetService("Selection"):Set(rigged)
end)

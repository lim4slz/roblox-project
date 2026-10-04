--!strict
-- Monta os KeyframeSequence (.rbxm) a partir de _cache/kfs/*.kfs.json e relê pra conferir.
--   lune run SCRIPTS/lune/build_kfs.luau [ANIM_01_ATOMIC_ECLIPSE ...] [--xml]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Enum = roblox.Enum

local ROOT = process.cwd
local SPEC_DIR = ROOT .. "/_cache/kfs"
local OUT_DIR = ROOT .. "/EXPORT/KeyframeSequences"
local REPORT_DIR = ROOT .. "/EXPORT/reports"

local function cframeOf(c: { number })
	return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end

local function buildSequence(spec: any)
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = spec.name
	kfs.Loop = spec.loop
	kfs.Priority = (Enum.AnimationPriority :: any)[spec.priority]
	kfs.AuthoredHipHeight = spec.authored_hip_height

	local children: { [string]: { string } } = {}
	for bone, parent in spec.parents do
		children[parent] = children[parent] or {}
		table.insert(children[parent], bone)
	end
	for _, list in children do
		table.sort(list)
	end

	for _, kd in spec.keyframes do
		local kf = Instance.new("Keyframe")
		kf.Name = "Keyframe"
		kf.Time = kd.t
		for _, m in kd.markers do
			local marker = Instance.new("KeyframeMarker")
			marker.Name = m.name
			marker.Value = m.value
			marker.Parent = kf
		end

		local function makePose(name: string, parent: any)
			local pose = Instance.new("Pose")
			pose.Name = name
			local comps = kd.poses[name]
			pose.CFrame = if comps then cframeOf(comps) else CFrame.new()
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			pose.EasingDirection = Enum.PoseEasingDirection.Out
			pose.Weight = 1
			pose.Parent = parent
			for _, child in children[name] or {} do
				if kd.poses[child] ~= nil or children[child] ~= nil then
					makePose(child, pose)
				end
			end
		end
		makePose(spec.root, kf)
		kf.Parent = kfs
	end
	return kfs
end

local function verify(path: string, spec: any)
	local inst = roblox.deserializeModel(fs.readFile(path))[1]
	assert(inst.ClassName == "KeyframeSequence", "não é KeyframeSequence")
	local list = inst:GetChildren()
	table.sort(list, function(a: any, b: any)
		return a.Time < b.Time
	end)
	assert(#list == #spec.keyframes, `keyframes {#list} ~= {#spec.keyframes}`)

	local markers, poses, maxErr = 0, 0, 0
	local names = {}
	for i, kf in list do
		local kd = spec.keyframes[i]
		assert(math.abs(kf.Time - kd.t) < 1e-5, "tempo diferente")
		for _, d in kf:GetDescendants() do
			if d.ClassName == "KeyframeMarker" then
				markers += 1
				table.insert(names, d.Name)
			elseif d.ClassName == "Pose" then
				local comps = kd.poses[d.Name]
				if comps then
					poses += 1
					local got = { d.CFrame:GetComponents() }
					for k = 1, 12 do
						maxErr = math.max(maxErr, math.abs(got[k] - comps[k]))
					end
				end
			end
		end
	end

	local expected = 0
	for _, kd in spec.keyframes do
		expected += #kd.markers
	end
	assert(markers == expected, "quantidade de markers diferente")
	return {
		keyframes = #list,
		markers = markers,
		poses = poses,
		maxComponentError = maxErr,
		length = list[#list].Time,
		priority = tostring(inst.Priority),
		loop = inst.Loop,
	}
end

local names = {}
local xml = false
for _, arg in process.args do
	if arg == "--xml" then
		xml = true
	else
		table.insert(names, arg)
	end
end
if #names == 0 then
	for _, file in fs.readDir(SPEC_DIR) do
		local n = string.match(file, "^(.+)%.kfs%.json$")
		if n then
			table.insert(names, n)
		end
	end
	table.sort(names)
end

fs.writeDir(OUT_DIR)
fs.writeDir(REPORT_DIR)
for _, name in names do
	local spec = serde.decode("json", fs.readFile(`{SPEC_DIR}/{name}.kfs.json`))
	local kfs = buildSequence(spec)
	local path = `{OUT_DIR}/{name}.rbxm`
	fs.writeFile(path, roblox.serializeModel({ kfs }, false))
	local result = verify(path, spec)
	result.bytes = #fs.readFile(path)
	if xml then
		local xmlPath = `{OUT_DIR}/{name}.rbxmx`
		fs.writeFile(xmlPath, roblox.serializeModel({ kfs }, true))
		local rx = verify(xmlPath, spec)
		result.maxComponentError = math.max(result.maxComponentError, rx.maxComponentError)
	end
	fs.writeFile(`{REPORT_DIR}/{name}_kfs.json`, serde.encode("json", result, true))
	print(
		`{name}: {result.keyframes} keyframes, {result.markers} markers, {result.poses} poses, `
			.. `erro máx {string.format("%.2e", result.maxComponentError)}, {result.length}s, {result.bytes // 1024} KB`
	)
end

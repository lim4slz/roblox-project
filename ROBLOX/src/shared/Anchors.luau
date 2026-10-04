local Workspace = game:GetService("Workspace")

local Anchors = {}

local BLADE_TIP = CFrame.new(0, 0, -2.5)
local BLADE_BASE = CFrame.new(0, 0, -0.9)
local BLADE_GRIP = CFrame.new(0, 0, 2.1)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local ignore: { Instance } = {}

function Anchors.ignore(list: { Instance })
	ignore = list
end

local function part(character: Model, name: string): BasePart?
	local p = character:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p
	end
	return nil
end

local function root(character: Model): CFrame
	local hrp = part(character, "HumanoidRootPart")
	if hrp then
		return hrp.CFrame
	end
	return character:GetPivot()
end

local groundCache: { [Model]: { at: number, y: number } } = setmetatable({}, { __mode = "k" }) :: any

function Anchors.ground(character: Model, from: Vector3?): number
	if from == nil then
		local c = groundCache[character]
		if c and os.clock() - c.at < 0.1 then
			return c.y
		end
	end
	local origin = from or root(character).Position
	local list = table.clone(ignore)
	table.insert(list, character)
	rayParams.FilterDescendantsInstances = list
	local hit = Workspace:Raycast(origin + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), rayParams)
	local y
	if hit then
		y = hit.Position.Y + 0.02
	else
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hrp = part(character, "HumanoidRootPart")
		y = origin.Y - (humanoid and humanoid.HipHeight or 2) - (hrp and hrp.Size.Y / 2 or 1)
	end
	if from == nil then
		groundCache[character] = { at = os.clock(), y = y }
	end
	return y
end

function Anchors.cframe(character: Model, name: string): CFrame
	local blade = part(character, "EmberBlade")
	if name == "blade_tip" and blade then
		return blade.CFrame * BLADE_TIP
	elseif name == "blade_base" and blade then
		return blade.CFrame * BLADE_BASE
	elseif name == "blade_mid" and blade then
		return blade.CFrame * BLADE_BASE:Lerp(BLADE_TIP, 0.5)
	elseif name == "grip" and blade then
		return blade.CFrame * BLADE_GRIP
	elseif name == "chest" then
		local ut = part(character, "UpperTorso")
		return ut and ut.CFrame or root(character)
	elseif name == "hands" then
		local l = part(character, "LeftHand")
		local r = part(character, "RightHand")
		local grip = if blade then (blade.CFrame * BLADE_GRIP).Position elseif r then r.Position else nil
		if l and grip then
			return CFrame.new((l.Position + grip) / 2)
		end
		return root(character)
	elseif name == "feet" then
		local r = root(character)
		return CFrame.new(r.Position.X, Anchors.ground(character), r.Position.Z) * r.Rotation
	elseif name == "root" or name == "character" then
		return root(character)
	elseif string.sub(name, 1, 4) == "sky:" then
		local r = root(character)
		return CFrame.new(r.Position + Vector3.new(0, tonumber(string.sub(name, 5)) or 0, 0))
	end
	local p = part(character, name)
	if p then
		return p.CFrame
	end
	return root(character)
end

function Anchors.position(character: Model, name: string): Vector3
	return Anchors.cframe(character, name).Position
end

return Anchors

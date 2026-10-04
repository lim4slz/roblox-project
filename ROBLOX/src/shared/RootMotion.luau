-- O Roblox não tem root motion: o KeyframeSequence só mexe nas juntas.
-- Aqui o HumanoidRootPart anda pelo caminho que saiu do Blender ({ t, x, z, yaw }).

local RootMotion = {}
RootMotion.__index = RootMotion

local function sample(keys, t: number): (number, number, number)
	if #keys == 0 then
		return 0, 0, 0
	end
	if t <= keys[1][1] then
		return keys[1][2], keys[1][3], keys[1][4]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			local k = (t - a[1]) / math.max(b[1] - a[1], 1e-6)
			return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k
		end
	end
	local last = keys[#keys]
	return last[2], last[3], last[4]
end

RootMotion.sample = sample

function RootMotion.new(character: Model, keys)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if hrp == nil or humanoid == nil then
		return nil
	end
	local self = setmetatable({}, RootMotion)
	self.keys = keys
	self.hrp = hrp
	self.humanoid = humanoid
	local look = hrp.CFrame.LookVector
	self.start = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(look.X, 0, look.Z))
	self.walkSpeed = humanoid.WalkSpeed
	self.autoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	return self
end

function RootMotion:update(t: number)
	local x, z, yaw = sample(self.keys, t)
	local target = self.start * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
	local pos = self.hrp.Position
	local delta = Vector3.new(target.Position.X - pos.X, 0, target.Position.Z - pos.Z)
	local speed = delta.Magnitude / 0.12
	if speed > 0.2 then
		self.humanoid.WalkSpeed = math.min(speed, 40)
		self.humanoid:Move(delta.Unit, false)
	else
		self.humanoid:Move(Vector3.zero, false)
	end
	local look = Vector3.new(target.LookVector.X, 0, target.LookVector.Z).Unit
	local cur = self.hrp.CFrame.LookVector
	if Vector3.new(cur.X, 0, cur.Z).Unit:Dot(look) < 0.9998 then
		self.hrp.CFrame = CFrame.lookAt(pos, pos + look)
	end
end

function RootMotion:stop()
	local humanoid = self.humanoid
	humanoid:Move(Vector3.zero, false)
	humanoid.WalkSpeed = self.walkSpeed
	humanoid.AutoRotate = self.autoRotate
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
end

return RootMotion

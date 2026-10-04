local Workspace = game:GetService("Workspace")

local Pool = {}

local FAR = CFrame.new(0, -10000, 0)
local MATERIAL = {
	neon = Enum.Material.Neon,
	smoke = Enum.Material.SmoothPlastic,
	dark = Enum.Material.SmoothPlastic,
	rock = Enum.Material.Slate,
	glass = Enum.Material.Glass,
	field = Enum.Material.ForceField,
}

local free: { [string]: { BasePart } } = {}
local folder: Folder? = nil
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

function Pool.folder(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "EmberFX"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function make(shape: string, look: string): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.AudioCanCollide = false
	p.CastShadow = look == "rock"
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = MATERIAL[look] or Enum.Material.Neon
	if shape == "ball" or shape == "hiball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "cylinder" or shape == "disc" then
		p.Shape = Enum.PartType.Cylinder
	else
		p.Shape = Enum.PartType.Block
	end
	p.Size = Vector3.one
	p.CFrame = FAR
	p.Parent = Pool.folder()
	return p
end

function Pool.get(shape: string, look: string): BasePart
	local key = shape .. ":" .. look
	local list = free[key]
	if list and #list > 0 then
		local p = table.remove(list) :: BasePart
		p.Transparency = 0
		return p
	end
	local p = make(shape, look)
	p:SetAttribute("PoolKey", key)
	return p
end

function Pool.release(p: BasePart)
	local key = p:GetAttribute("PoolKey")
	p.Transparency = 1
	p.CFrame = FAR
	if type(key) ~= "string" then
		p:Destroy()
		return
	end
	local list = free[key]
	if list == nil then
		list = {}
		free[key] = list
	end
	if #list < 300 then
		table.insert(list, p)
	else
		p:Destroy()
	end
end

function Pool.move(p: BasePart, cf: CFrame)
	table.insert(moveParts, p)
	table.insert(moveCFrames, cf)
end

function Pool.flush()
	if #moveParts > 0 then
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(moveParts)
		table.clear(moveCFrames)
	end
end

-- cilindro do Roblox é deitado no eixo X; isso deixa ele em pé no Y do objeto
Pool.UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

function Pool.isCylinder(shape: string): boolean
	return shape == "cylinder" or shape == "disc"
end

return Pool

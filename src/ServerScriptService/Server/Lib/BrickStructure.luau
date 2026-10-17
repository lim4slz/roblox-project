--!strict
-- A breakable structure (a team tower or the lobby practice wall) made of
-- anchored bricks.
--
-- Expected model layout (the map builder produces this, and anything built by
-- hand in Studio works the same way):
--   <Model>
--     Bricks/  BaseParts that count toward health. Bottom-row bricks carry the
--              attribute Grounded = true.
--     Decor/   BaseParts that fall with the structure but don't count (flag,
--              ladder, trims).
--
-- Bombs knock individual bricks loose; anything left without a path to the
-- ground falls as welded chunks that burst apart on impact.

local Debris = game:GetService("Debris")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Signal = require(game:GetService("ReplicatedStorage").Shared.Signal)
local BrickGraph = require(script.Parent.BrickGraph)

export type BrickStructure = {
	Model: Model,
	TeamName: string?,
	Destroyed: boolean,
	LastAttacker: Player?,
	-- (structuralBricksLost, attacker?) fired after every change
	BricksLost: Signal.Signal<number, Player?>,

	health: (self: BrickStructure) -> number,
	breakInRadius: (self: BrickStructure, position: Vector3, radius: number, attacker: Player?) -> (number, number),
	collapseAll: (self: BrickStructure) -> number,
	destroy: (self: BrickStructure) -> (),
}

type Internal = BrickStructure & {
	_parts: { BasePart },
	_indexOf: { [BasePart]: number },
	_structural: { boolean },
	_structuralTotal: number,
	_structuralAlive: number,
	_graph: BrickGraph.BrickGraph,
	_overlapParams: OverlapParams,
}

local BrickStructure = {}
BrickStructure.__index = BrickStructure

-- Shared across every structure so one huge collapse can't swamp physics.
local looseBrickCount = 0

local function getDebrisFolder(): Folder
	local folder = workspace:FindFirstChild("Debris")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "Debris"
	created.Parent = workspace
	return created
end

local function collectParts(container: Instance?, into: { BasePart }, flags: { boolean }, structural: boolean)
	if not container then
		return
	end
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(into, descendant)
			table.insert(flags, structural)
		end
	end
end

local function scheduleCleanup(part: BasePart, lifetime: number)
	Debris:AddItem(part, lifetime)
	task.delay(lifetime, function()
		looseBrickCount = math.max(0, looseBrickCount - 1)
	end)
end

-- Turns an anchored brick into a loose physics brick flying away from `origin`.
local function fling(part: BasePart, origin: Vector3?, strength: number)
	part.Parent = getDebrisFolder()
	part.CanQuery = false
	part.CanTouch = false

	if looseBrickCount >= Config.Tower.MaxLooseBricks then
		-- Over budget: vanish instead of simulating. Players won't notice one
		-- missing brick in a cloud of fifty.
		part:Destroy()
		return
	end
	looseBrickCount += 1

	part.CollisionGroup = "Debris"
	part.Anchored = false
	local direction = if origin then (part.Position - origin) else Vector3.new(0, 1, 0)
	if direction.Magnitude < 1e-3 then
		direction = Vector3.new(0, 1, 0)
	end
	local random = Random.new()
	part.AssemblyLinearVelocity = direction.Unit * strength * random:NextNumber(0.6, 1.1)
		+ Vector3.new(0, strength * 0.45, 0)
	part.AssemblyAngularVelocity =
		Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-8, 8), random:NextNumber(-8, 8))
	scheduleCleanup(part, Config.Tower.DebrisLifetime + random:NextNumber(0, 1.5))
end

-- Welds a floating cluster into one assembly so it topples as a single piece,
-- then lets it burst apart a moment later.
local function dropChunk(parts: { BasePart })
	if #parts == 1 then
		fling(parts[1], nil, 6)
		return
	end
	local folder = getDebrisFolder()
	local root = parts[1]
	local welds = {}
	local random = Random.new()

	for _, part in parts do
		part.Parent = folder
		part.CanQuery = false
		part.CanTouch = false
		part.CollisionGroup = "Debris"
		if part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root
			table.insert(welds, weld)
		end
	end
	for _, part in parts do
		part.Anchored = false
	end
	looseBrickCount += #parts
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	-- A gentle shove so it leans and topples instead of dropping straight down.
	root.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-0.8, 0.8), 0, random:NextNumber(-0.8, 0.8))

	task.delay(Config.Tower.ChunkScatterDelay, function()
		for _, weld in welds do
			weld:Destroy()
		end
		for _, part in parts do
			if part.Parent then
				part.AssemblyLinearVelocity += Vector3.new(
					random:NextNumber(-12, 12),
					random:NextNumber(4, 14),
					random:NextNumber(-12, 12)
				)
			end
		end
	end)
	for _, part in parts do
		scheduleCleanup(part, Config.Tower.ChunkScatterDelay + Config.Tower.DebrisLifetime + random:NextNumber(0, 1.5))
	end
end

function BrickStructure.new(model: Model, teamName: string?): BrickStructure
	local parts: { BasePart } = {}
	local structural: { boolean } = {}
	collectParts(model:FindFirstChild("Bricks"), parts, structural, true)
	collectParts(model:FindFirstChild("Decor"), parts, structural, false)

	-- Prefer explicit Grounded attributes; fall back to "touching the lowest
	-- point" for hand-built structures that don't set them.
	local usesAttributes = false
	local lowest = math.huge
	for _, part in parts do
		if part:GetAttribute("Grounded") ~= nil then
			usesAttributes = true
		end
		lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2)
	end

	local boxes: { BrickGraph.Box } = table.create(#parts)
	local indexOf: { [BasePart]: number } = {}
	local structuralTotal = 0
	for index, part in parts do
		local grounded
		if usesAttributes then
			grounded = part:GetAttribute("Grounded") == true
		else
			grounded = (part.Position.Y - part.Size.Y / 2) <= lowest + 0.3
		end
		boxes[index] =
			BrickGraph.boxFromCFrame(part.CFrame, part.Size, grounded, part:GetAttribute("Supports") ~= false)
		indexOf[part] = index
		if structural[index] then
			structuralTotal += 1
		end
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { model }

	local self = setmetatable({
		Model = model,
		TeamName = teamName,
		Destroyed = false,
		LastAttacker = nil,
		BricksLost = Signal.new(),
		_parts = parts,
		_indexOf = indexOf,
		_structural = structural,
		_structuralTotal = math.max(1, structuralTotal),
		_structuralAlive = structuralTotal,
		_graph = BrickGraph.new(boxes),
		_overlapParams = overlapParams,
	}, BrickStructure)
	return (self :: any) :: BrickStructure
end

-- Fraction of structural bricks still standing (1 = pristine).
function BrickStructure.health(self: Internal): number
	return self._structuralAlive / self._structuralTotal
end

-- Removes a brick from the graph and returns whether it was structural.
local function detach(self: Internal, index: number): boolean
	if not self._graph:remove(index) then
		return false
	end
	if self._structural[index] then
		self._structuralAlive -= 1
		return true
	end
	return false
end

-- Drops everything that lost its connection to the ground. Returns how many
-- structural bricks fell.
local function collapseUnsupported(self: Internal): number
	local unsupported = self._graph:findUnsupported()
	if #unsupported == 0 then
		return 0
	end
	local structuralLost = 0
	for _, index in unsupported do
		if detach(self, index) then
			structuralLost += 1
		end
	end
	for _, cluster in self._graph:components(unsupported) do
		local clusterParts = table.create(#cluster)
		for _, index in cluster do
			table.insert(clusterParts, self._parts[index])
		end
		dropChunk(clusterParts)
	end
	return structuralLost
end

-- Knocks out bricks inside the blast and drops anything left hanging.
-- Returns (bricks blasted directly, bricks lost to the collapse).
function BrickStructure.breakInRadius(
	self: Internal,
	position: Vector3,
	radius: number,
	attacker: Player?
): (number, number)
	if self.Destroyed then
		return 0, 0
	end
	local hits = workspace:GetPartBoundsInRadius(position, radius, self._overlapParams)
	local blasted = 0
	for _, part in hits do
		local index = self._indexOf[part]
		if index and self._graph:isAlive(index) then
			-- Bounding-box overlap is generous; require the brick centre to be
			-- reasonably close so blasts carve round holes, not square ones.
			if (part.Position - position).Magnitude <= radius + 1 then
				if detach(self, index) then
					blasted += 1
				end
				fling(part, position, 42)
			end
		end
	end
	if blasted == 0 then
		return 0, 0
	end

	local collapsed = collapseUnsupported(self)
	if attacker then
		self.LastAttacker = attacker
	end
	self.BricksLost:Fire(blasted + collapsed, attacker)
	return blasted, collapsed
end

-- Brings the whole structure down (tower defeated, or admin fun).
function BrickStructure.collapseAll(self: Internal): number
	if self.Destroyed then
		return 0
	end
	self.Destroyed = true
	local remaining = {}
	local lost = 0
	for index = 1, #self._parts do
		if self._graph:isAlive(index) then
			if detach(self, index) then
				lost += 1
			end
			table.insert(remaining, index)
		end
	end
	-- Shatter the tower into a handful of big chunks instead of one monolith.
	for _, cluster in self._graph:components(remaining) do
		local clusterParts = {}
		for _, index in cluster do
			table.insert(clusterParts, self._parts[index])
		end
		local chunkSize = 40
		for start = 1, #clusterParts, chunkSize do
			local chunk = table.move(clusterParts, start, math.min(start + chunkSize - 1, #clusterParts), 1, {})
			dropChunk(chunk)
		end
	end
	if lost > 0 then
		self.BricksLost:Fire(lost, self.LastAttacker)
	end
	return lost
end

function BrickStructure.destroy(self: Internal)
	self.Destroyed = true
	self.BricksLost:DisconnectAll()
	self.Model:Destroy()
end

return BrickStructure

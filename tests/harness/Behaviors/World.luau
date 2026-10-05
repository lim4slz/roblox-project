--[[
	World behaviors: BasePart, Model, Attachment, Workspace, Camera, Terrain.
	No physics is simulated; geometry is kept consistent (CFrame <-> Position <->
	Orientation, model pivots, attachment world positions) so game code that
	measures distances or moves things behaves correctly.
]]

local roblox = require("@lune/roblox")
local Instances = require("../Instances")
local Reflection = require("../Reflection")

local CFrame, Vector3, Vector2 = roblox.CFrame, roblox.Vector3, roblox.Vector2
local states = Instances.state

local function ctxOf(st)
	return st.server.scheduler:currentCtx()
end

-- Character movement made by the owning client replicates (network ownership).
local function replicatesFromClient(st, ctx)
	if not (ctx and ctx.kind == "client" and ctx.player) then
		return false
	end
	local character = ctx.characterProxy
	return character ~= nil and Instances.isDescendantOf(st, character)
end

local function getCFrame(st, ctx)
	return Instances.getProp(st, "CFrame", ctx) or CFrame.identity
end

local function setCFrame(st, cframe, ctx)
	Instances.storeProp(st, "CFrame", cframe, ctx, replicatesFromClient(st, ctx))
	-- Derived properties change together.
	Instances.fire(st, "Changed", nil, "Position")
end

local function toDegrees(rx, ry, rz)
	return Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
end

Instances.define("PVInstance", {
	methods = {
		GetPivot = function(self)
			local st = states(self)
			return getCFrame(st, ctxOf(st))
		end,
		PivotTo = function(self, cframe)
			local st = states(self)
			setCFrame(st, cframe, ctxOf(st))
		end,
	},
})

Instances.define("BasePart", {
	props = {
		CFrame = {
			get = function(_, st, ctx)
				return getCFrame(st, ctx)
			end,
			set = function(_, st, value, ctx)
				setCFrame(st, value, ctx)
			end,
			datatype = "CFrame",
		},
		Position = {
			get = function(_, st, ctx)
				return getCFrame(st, ctx).Position
			end,
			set = function(_, st, value, ctx)
				local current = getCFrame(st, ctx)
				setCFrame(st, CFrame.new(value) * current.Rotation, ctx)
			end,
			datatype = "Vector3",
		},
		Orientation = {
			get = function(_, st, ctx)
				local rx, ry, rz = getCFrame(st, ctx):ToOrientation()
				return toDegrees(rx, ry, rz)
			end,
			set = function(_, st, value, ctx)
				local position = getCFrame(st, ctx).Position
				setCFrame(
					st,
					CFrame.new(position) * CFrame.fromOrientation(math.rad(value.X), math.rad(value.Y), math.rad(value.Z)),
					ctx
				)
			end,
			datatype = "Vector3",
		},
		Rotation = {
			get = function(_, st, ctx)
				local rx, ry, rz = getCFrame(st, ctx):ToEulerAnglesXYZ()
				return toDegrees(rx, ry, rz)
			end,
			set = function(_, st, value, ctx)
				local position = getCFrame(st, ctx).Position
				setCFrame(
					st,
					CFrame.new(position) * CFrame.Angles(math.rad(value.X), math.rad(value.Y), math.rad(value.Z)),
					ctx
				)
			end,
			datatype = "Vector3",
		},
		AssemblyLinearVelocity = { default = Vector3.zero, datatype = "Vector3" },
		AssemblyAngularVelocity = { default = Vector3.zero, datatype = "Vector3" },
	},
	methods = {
		GetPivot = function(self)
			local st = states(self)
			return getCFrame(st, ctxOf(st))
		end,
		PivotTo = function(self, cframe)
			local st = states(self)
			setCFrame(st, cframe, ctxOf(st))
		end,
		SetNetworkOwner = function(self, player)
			local st = states(self)
			local ctx = ctxOf(st)
			if ctx and ctx.kind == "client" then
				error("SetNetworkOwner can only be called from the server", 2)
			end
			st.extra.networkOwner = player
		end,
		GetNetworkOwner = function(self)
			return states(self).extra.networkOwner
		end,
		SetNetworkOwnershipAuto = function(self)
			states(self).extra.networkOwner = nil
		end,
		CanSetNetworkOwnership = function()
			return true, nil
		end,
		GetMass = function(self)
			local size = Instances.getProp(states(self), "Size", nil) or Vector3.one
			return size.X * size.Y * size.Z * 0.7
		end,
		ApplyImpulse = function() end,
		GetTouchingParts = function()
			return {}
		end,
	},
	events = { Touched = true, TouchEnded = true },
})

local function modelParts(st, ctx)
	local parts = {}
	Instances.forEachDescendant(st, function(descendant)
		if Reflection.isA(descendant.className, "BasePart") and Instances.visible(descendant, ctx) then
			table.insert(parts, descendant)
		end
	end)
	return parts
end

local function modelPivot(st, ctx)
	local primary = Instances.getProp(st, "PrimaryPart", ctx)
	if primary and states(primary) then
		return getCFrame(states(primary), ctx)
	end
	if st.extra.worldPivot then
		return st.extra.worldPivot
	end
	local parts = modelParts(st, ctx)
	if #parts == 0 then
		return CFrame.identity
	end
	local sum = Vector3.zero
	for _, part in parts do
		sum += getCFrame(part, ctx).Position
	end
	return CFrame.new(sum / #parts)
end

local function boundingBox(st, ctx)
	local parts = modelParts(st, ctx)
	if #parts == 0 then
		return modelPivot(st, ctx), Vector3.zero
	end
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in parts do
		local position = getCFrame(part, ctx).Position
		local half = (Instances.getProp(part, "Size", ctx) or Vector3.one) / 2
		minV = minV:Min(position - half)
		maxV = maxV:Max(position + half)
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

Instances.define("Model", {
	props = {
		WorldPivot = {
			get = function(_, st, ctx)
				return modelPivot(st, ctx)
			end,
			set = function(_, st, value)
				st.extra.worldPivot = value
			end,
			datatype = "CFrame",
		},
	},
	methods = {
		GetPivot = function(self)
			local st = states(self)
			return modelPivot(st, ctxOf(st))
		end,
		PivotTo = function(self, cframe)
			local st = states(self)
			local ctx = ctxOf(st)
			local delta = cframe * modelPivot(st, ctx):Inverse()
			for _, part in modelParts(st, ctx) do
				setCFrame(part, delta * getCFrame(part, ctx), ctx)
			end
			if st.extra.worldPivot then
				st.extra.worldPivot = cframe
			end
		end,
		GetBoundingBox = function(self)
			local st = states(self)
			return boundingBox(st, ctxOf(st))
		end,
		GetExtentsSize = function(self)
			local st = states(self)
			local _, size = boundingBox(st, ctxOf(st))
			return size
		end,
		ScaleTo = function(self, scale)
			assert(type(scale) == "number" and scale > 0, "ScaleTo expects a positive number")
			states(self).extra.scale = scale
		end,
		GetScale = function(self)
			return states(self).extra.scale or 1
		end,
	},
})

Instances.define("Attachment", {
	props = {
		WorldCFrame = {
			get = function(_, st, ctx)
				local parent = st.parent and states(st.parent)
				local local_ = Instances.getProp(st, "CFrame", ctx) or CFrame.identity
				if parent and parent.members.CFrame then
					return getCFrame(parent, ctx) * local_
				end
				return local_
			end,
			readOnly = true,
		},
		WorldPosition = {
			get = function(_, st, ctx)
				local parent = st.parent and states(st.parent)
				local local_ = Instances.getProp(st, "CFrame", ctx) or CFrame.identity
				if parent and parent.members.CFrame then
					return (getCFrame(parent, ctx) * local_).Position
				end
				return local_.Position
			end,
			readOnly = true,
		},
		Position = {
			get = function(_, st, ctx)
				return (Instances.getProp(st, "CFrame", ctx) or CFrame.identity).Position
			end,
			set = function(_, st, value, ctx)
				local current = Instances.getProp(st, "CFrame", ctx) or CFrame.identity
				Instances.storeProp(st, "CFrame", CFrame.new(value) * current.Rotation, ctx)
			end,
			datatype = "Vector3",
		},
	},
})

Instances.define("Workspace", {
	props = {
		CurrentCamera = {
			get = function(_, st, ctx)
				local server = st.server
				if ctx and ctx.kind == "client" then
					return ctx.camera
				end
				return server.serverCamera
			end,
			set = function() end,
			datatype = "Ref",
		},
		DistributedGameTime = {
			get = function(_, st)
				return st.server.scheduler.clock
			end,
			readOnly = true,
		},
		Terrain = {
			get = function(_, st)
				return st.server.terrain
			end,
			readOnly = true,
		},
	},
	methods = {
		GetServerTimeNow = function(self)
			return states(self).server.scheduler:time()
		end,
		Raycast = function(self, origin, direction)
			local st = states(self)
			table.insert(st.server.raycasts, { origin = origin, direction = direction })
			return nil
		end,
		Blockcast = function()
			return nil
		end,
		Spherecast = function()
			return nil
		end,
		BulkMoveTo = function(self, parts, cframes)
			local st = states(self)
			local ctx = ctxOf(st)
			assert(#parts == #cframes, "BulkMoveTo: partList and cframeList must have the same length")
			for index, part in parts do
				local partState = states(part)
				if partState then
					setCFrame(partState, cframes[index], ctx)
				end
			end
		end,
		GetPartBoundsInRadius = function(self, position, radius)
			local st = states(self)
			local ctx = ctxOf(st)
			local result = {}
			for _, part in modelParts(st, ctx) do
				if (getCFrame(part, ctx).Position - position).Magnitude <= radius then
					table.insert(result, part.proxy)
				end
			end
			return result
		end,
		GetPartsInPart = function()
			return {}
		end,
	},
})

Instances.define("Camera", {
	props = {
		ViewportSize = {
			get = function(_, st)
				return st.extra.viewport or Vector2.new(1280, 720)
			end,
			readOnly = true,
		},
	},
	methods = {
		WorldToViewportPoint = function(self, position)
			local st = states(self)
			local viewport = st.extra.viewport or Vector2.new(1280, 720)
			return Vector3.new(viewport.X / 2, viewport.Y / 2, 10), true
		end,
		WorldToScreenPoint = function(self, position)
			local st = states(self)
			local viewport = st.extra.viewport or Vector2.new(1280, 720)
			return Vector3.new(viewport.X / 2, viewport.Y / 2, 10), true
		end,
	},
})

Instances.define("Terrain", {
	methods = {
		FillBlock = function(self, cframe, size, material)
			table.insert(states(self).server.terrainOps, { kind = "Block", cframe = cframe, size = size, material = material })
		end,
		FillBall = function(self, center, radius, material)
			table.insert(states(self).server.terrainOps, { kind = "Ball", center = center, radius = radius, material = material })
		end,
		FillCylinder = function(self, cframe, height, radius, material)
			table.insert(
				states(self).server.terrainOps,
				{ kind = "Cylinder", cframe = cframe, height = height, radius = radius, material = material }
			)
		end,
		FillWedge = function(self, cframe, size, material)
			table.insert(states(self).server.terrainOps, { kind = "Wedge", cframe = cframe, size = size, material = material })
		end,
		Clear = function(self)
			table.clear(states(self).server.terrainOps)
		end,
	},
})

return true

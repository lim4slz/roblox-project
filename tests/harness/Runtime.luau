--[[
	Runtime
	Headless Roblox simulation driven by tests.

	  local world = Runtime.new({ place = "build/test.rbxl", sourcemap = "build/sourcemap.json" })
	  local server = world:createServer()
	  server:start()                          -- runs every server Script from the place
	  local alice = server:addPlayer({ userId = 1, name = "Alice", runClient = true })
	  world:advance(5)                        -- 5 virtual seconds
	  local response = alice:request("Shop.Buy", { kind = "Furniture", id = "Beanbag" })
	  server:removePlayer(alice)
	  world:assertHealthy()                   -- no script errors were thrown

	The place file is the real output of `rojo build`, so the instance tree,
	script sources and properties are exactly what Roblox Studio would load.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local Scheduler = require("./Scheduler")
local Registry = require("./Registry")
local Reflection = require("./Reflection")
local Instances = require("./Instances")
local RbxSignal = require("./RbxSignal")
local Environment = require("./Environment")
local Serialize = require("./Serialize")

require("./Behaviors/World")
require("./Behaviors/Players")
require("./Behaviors/Remotes")
require("./Behaviors/Gui")
require("./Behaviors/Misc")
require("./Services/Core")
local Cloud = require("./Services/Cloud")

local Enum = roblox.Enum
local CFrame, Vector3, Vector2 = roblox.CFrame, roblox.Vector3, roblox.Vector2
local states = Instances.state

local Runtime = {}
Runtime.__index = Runtime

local Server = {}
Server.__index = Server

local Client = {}
Client.__index = Client

--------------------------------------------------------------------------------
-- Place loading
--------------------------------------------------------------------------------

local placeCache = {}

local function loadPlace(path)
	local cached = placeCache[path]
	if cached then
		return cached
	end
	local place = roblox.deserializePlace(fs.readFile(path))
	placeCache[path] = place
	return place
end

local function loadSourcemap(path)
	local map = {}
	if not path or not fs.isFile(path) then
		return map
	end
	local root = serde.decode("json", fs.readFile(path))
	local function walk(node, prefix)
		local name = if prefix == nil then nil elseif prefix == "" then node.name else prefix .. "." .. node.name
		if name and node.filePaths then
			for _, filePath in node.filePaths do
				if string.match(filePath, "%.luau?$") then
					map[name] = filePath
					break
				end
			end
		end
		for _, child in node.children or {} do
			walk(child, name or "")
		end
	end
	walk(root, nil)
	return map
end

--------------------------------------------------------------------------------
-- World
--------------------------------------------------------------------------------

function Runtime.new(options)
	options = options or {}
	local self = setmetatable({}, Runtime)
	self.scheduler = Scheduler.new({ epoch = options.epoch })
	self.cloud = Cloud.newBackend(self.scheduler)
	self.placePath = options.place or "build/test.rbxl"
	self.place = loadPlace(self.placePath)
	self.sourceMap = loadSourcemap(options.sourcemap or "build/sourcemap.json")
	self.verbose = options.verbose or false
	self.servers = {}
	self.logs = {}
	self.userNames = {}
	self.friends = {}
	self.policies = {}
	self.countries = {}
	self.badges = {}
	self.invitePrompts = {}
	self.soundsPlayed = {}
	self.emotesPlayed = {}
	self.chat = {}
	self.teleports = {}
	self.canInvite = true
	self.frameDt = options.dt or 1 / 30
	self.remoteLog = {
		counts = {},
		record = function(log, direction, remoteName, args)
			local key = direction .. ":" .. remoteName
			log.counts[key] = (log.counts[key] or 0) + 1
		end,
	}
	local world = self
	self.scheduler.onError = function(entry)
		table.insert(world.logs, { level = "error", ctx = entry.ctx, message = entry.traceback })
		if world.verbose then
			print("[error][" .. entry.ctx .. "] " .. entry.traceback)
		end
	end
	return self
end

function Runtime:log(level, ctx, message)
	local entry = { level = level, ctx = ctx and ctx.id or "main", message = message, time = self.scheduler.clock }
	table.insert(self.logs, entry)
	if self.verbose or level == "error" then
		print(string.format("[%s][%s] %s", level, entry.ctx, message))
	end
end

function Runtime:errors()
	local result = {}
	for _, entry in self.logs do
		if entry.level == "error" then
			table.insert(result, entry)
		end
	end
	return result
end

function Runtime:warnings(pattern)
	local result = {}
	for _, entry in self.logs do
		if entry.level == "warn" and (pattern == nil or string.find(entry.message, pattern, 1, true)) then
			table.insert(result, entry)
		end
	end
	return result
end

function Runtime:printed(pattern)
	for _, entry in self.logs do
		if entry.level == "print" and string.find(entry.message, pattern, 1, true) then
			return true
		end
	end
	return false
end

-- Fails if any script error was recorded (unless matching an allowed pattern).
function Runtime:assertHealthy(allowedPatterns)
	local unexpected = {}
	for _, entry in self:errors() do
		local allowed = false
		for _, pattern in allowedPatterns or {} do
			if string.find(entry.message, pattern, 1, true) then
				allowed = true
			end
		end
		if not allowed then
			table.insert(unexpected, "[" .. entry.ctx .. "] " .. entry.message)
		end
	end
	if #unexpected > 0 then
		error("Script errors were raised:\n" .. table.concat(unexpected, "\n\n"), 2)
	end
end

local function engineHooks(world)
	return {
		preSimulation = function(dt)
			for _, server in world.servers do
				if not server.closed then
					local run = states(server.services.RunService)
					Instances.fire(run, "Stepped", nil, world.scheduler.clock, dt)
					Instances.fire(run, "PreSimulation", nil, dt)
					Instances.fire(run, "PreRender", function(ctx)
						return ctx ~= nil and ctx.kind == "client"
					end, dt)
					Instances.fire(run, "RenderStepped", function(ctx)
						return ctx ~= nil and ctx.kind == "client"
					end, dt)
					for _, ctx in server.clientContexts() do
						for _, step in ctx.renderSteps do
							world.scheduler:deferIn(ctx, step.fn, table.pack(dt))
						end
					end
				end
			end
		end,
		heartbeat = function(dt)
			for _, server in world.servers do
				if not server.closed then
					local run = states(server.services.RunService)
					Instances.fire(run, "PostSimulation", nil, dt)
					Instances.fire(run, "Heartbeat", nil, dt)
				end
			end
		end,
	}
end

function Runtime:step(dt)
	self.scheduler:step(dt or self.frameDt, engineHooks(self))
end

function Runtime:flush()
	self.scheduler:flushDeferred()
end

-- Advances virtual time by `seconds`.
function Runtime:advance(seconds, dt)
	local frame = dt or self.frameDt
	local target = self.scheduler.clock + seconds
	while self.scheduler.clock + 1e-9 < target do
		self:step(math.min(frame, target - self.scheduler.clock))
	end
	self:flush()
end

-- Re-scopes a test closure so its globals resolve to the context's sandbox
-- (Instance, task, game, workspace, Vector3, ...) before the spec's own globals.
local function sandboxed(ctx, fn)
	if ctx == nil or ctx.globals == nil then
		return fn
	end
	local original = getfenv(fn)
	local globals = ctx.globals
	setfenv(
		fn,
		setmetatable({}, {
			__index = function(_, key)
				local value = globals[key]
				if value ~= nil then
					return value
				end
				return original[key]
			end,
		})
	)
	return fn
end
Runtime.sandboxed = sandboxed

-- Runs `fn` in a thread of `ctx` and steps time until it finishes.
function Runtime:runIn(ctx, fn, timeout)
	sandboxed(ctx, fn)
	local done, results = false, nil
	local thread = self.scheduler:newThread(function()
		results = table.pack(pcall(fn))
		done = true
	end, ctx)
	self.scheduler:resume(thread)
	self:flush()
	local limit = self.scheduler.clock + (timeout or 120)
	while not done do
		if self.scheduler.clock >= limit then
			error("Runtime:runIn timed out after " .. tostring(timeout or 120) .. " virtual seconds", 2)
		end
		self:step()
	end
	if not results[1] then
		error(results[2], 2)
	end
	return table.unpack(results, 2, results.n)
end

-- Simulates a completed Robux developer product purchase.
function Runtime:buyProduct(server, player, productId)
	local backend = self.cloud
	backend.purchaseCounter += 1
	local playerState = states(player)
	local receipt = {
		PlayerId = playerState.extra.userId,
		PlaceIdWherePurchased = server.placeId,
		PurchaseId = string.format("PURCHASE-%06d", backend.purchaseCounter),
		ProductId = productId,
		CurrencyType = Enum.CurrencyType.Robux,
		CurrencySpent = backend.productPrices[productId] or 100,
	}
	local clientCtx = server.clientCtxFor(player)
	local market = states(server.services.MarketplaceService)
	Instances.fire(market, "PromptProductPurchaseFinished", function(ctx)
		return ctx == nil or ctx.kind == "server" or ctx == clientCtx
	end, playerState.extra.userId, productId, true)
	Cloud.processReceipt(server, receipt)
	return receipt
end

-- Re-delivers receipts that were answered NotProcessedYet (Roblox retries on rejoin).
function Runtime:retryReceipts(server, userId)
	local pending = self.cloud.pendingReceipts[userId]
	if not pending then
		return
	end
	for _, receipt in table.clone(pending) do
		Cloud.processReceipt(server, receipt)
	end
end

--------------------------------------------------------------------------------
-- Server
--------------------------------------------------------------------------------

local SERVER_RUN_CONTAINERS = { Workspace = true, ServerScriptService = true }

function Runtime:createServer(options)
	options = options or {}
	local world = self
	local server = setmetatable({
		world = world,
		scheduler = world.scheduler,
		jobId = options.jobId or ("job-" .. tostring(#world.servers + 1)),
		placeId = options.placeId or 104729,
		gameId = options.gameId or 7777,
		isStudio = options.isStudio or false,
		maxPlayers = options.maxPlayers or 16,
		services = {},
		tagged = {},
		tagSignals = {},
		closeCallbacks = {},
		collisionGroups = {},
		terrainOps = {},
		raycasts = {},
		clients = {},
		clientList = {},
		players = {},
		closed = false,
		loading = true,
		started = false,
	}, Server)
	table.insert(world.servers, server)

	server.log = function(level, ctx, message)
		world:log(level, ctx, message)
	end
	server.serverCtx = {
		kind = "server",
		id = "server:" .. server.jobId,
		server = server,
		modules = {},
		shared = {},
		_G = {},
	}
	server.loader = {
		require = function(ctx, module)
			return server:requireModule(ctx, module)
		end,
	}

	server.clientCtxFor = function(player)
		return server.clients[player]
	end
	server.clientContexts = function()
		local list = {}
		for _, ctx in server.clientList do
			if not ctx.dead then
				table.insert(list, ctx)
			end
		end
		return list
	end
	server.getService = function(name, create)
		local existing = server.services[name]
		if existing then
			return existing
		end
		local info = Reflection.class(name)
		if not info or not info.isService then
			if create then
				error(string.format("'%s' is not a valid Service name", tostring(name)), 3)
			end
			return nil
		end
		if not create then
			return nil
		end
		local proxy, st = Instances.create(server, name, nil, { internal = true })
		st.name = name
		server.services[name] = proxy
		Instances.setParent(st, server.dataModel, nil)
		if name == "ServerScriptService" or name == "ServerStorage" then
			st.childrenServerOnly = true
		end
		return proxy
	end

	-- Tags
	server.tagSignal = function(tag, kind)
		server.tagSignals[tag] = server.tagSignals[tag] or {}
		local entry = server.tagSignals[tag][kind]
		if not entry then
			local proxy, signalState = RbxSignal.new(world.scheduler, "Tag" .. kind .. ":" .. tag)
			entry = { proxy = proxy, state = signalState }
			server.tagSignals[tag][kind] = entry
		end
		return entry
	end
	local function fireTag(st, tag, kind)
		local signals = server.tagSignals[tag]
		local entry = signals and signals[kind]
		if entry then
			RbxSignal.fire(entry.state, function(ctx)
				return Instances.visible(st, ctx)
			end, st.proxy)
		end
	end
	server.addTag = function(st, tag)
		if st.tags[tag] then
			return
		end
		st.tags[tag] = true
		server.tagged[tag] = server.tagged[tag] or {}
		table.insert(server.tagged[tag], st)
		if Instances.inDataModel(st) then
			fireTag(st, tag, "added")
		end
	end
	server.removeTag = function(st, tag)
		if not st.tags[tag] then
			return
		end
		st.tags[tag] = nil
		local list = server.tagged[tag]
		local index = list and table.find(list, st)
		if index then
			table.remove(list, index)
		end
		if Instances.inDataModel(st) then
			fireTag(st, tag, "removed")
		end
	end
	server.onCreated = function(st)
		-- nothing yet; tags are registered through addTag
	end
	server.onMembershipChanged = function(st, inDataModel)
		for tag in st.tags do
			local list = server.tagged[tag]
			if list and not table.find(list, st) then
				table.insert(list, st)
			end
			fireTag(st, tag, if inDataModel then "added" else "removed")
		end
		if inDataModel and not server.loading then
			server:maybeRunScript(st)
		end
	end
	server.onReparented = function(st)
		if not server.loading and st.parent and Instances.inDataModel(st) then
			server:maybeRunScript(st)
			Instances.forEachDescendant(st, function(descendant)
				server:maybeRunScript(descendant)
			end)
		end
	end
	server.onScriptEnabledChanged = function(st, enabled)
		if enabled and not server.loading then
			server:maybeRunScript(st)
		end
	end
	server.kickPlayer = function(playerState, message)
		local ctx = server.clients[playerState.proxy]
		if ctx then
			ctx.kickMessage = message
		end
		world:log("print", server.serverCtx, string.format("Kicked %s: %s", playerState.name, message))
		server:disconnect(playerState.proxy, "Kicked")
	end

	-- DataModel + services from the place
	local dataModel, dataModelState = Instances.create(server, "DataModel", nil, { internal = true })
	dataModelState.name = "Game"
	server.dataModel = dataModel
	server:importPlace(world.place)

	-- Engine-provided instances
	local workspace = server.getService("Workspace", true)
	local terrain = Instances.findChild(states(workspace), "Terrain", nil)
	if not terrain then
		local terrainProxy, terrainState = Instances.create(server, "Terrain", nil, { internal = true })
		terrainState.name = "Terrain"
		Instances.setParent(terrainState, workspace, nil)
		terrain = terrainProxy
	end
	server.terrain = terrain
	local camera, cameraState = Instances.create(server, "Camera", nil, { internal = true })
	cameraState.name = "Camera"
	Instances.setParent(cameraState, workspace, nil)
	server.serverCamera = camera
	for _, name in {
		"Players",
		"ReplicatedStorage",
		"ReplicatedFirst",
		"ServerScriptService",
		"ServerStorage",
		"StarterGui",
		"StarterPlayer",
		"StarterPack",
		"Lighting",
		"SoundService",
		"RunService",
		"TextChatService",
	} do
		server.getService(name, true)
	end
	local starterPlayer = states(server.services.StarterPlayer)
	if not Instances.findChild(starterPlayer, "StarterPlayerScripts", nil) then
		local proxy, st = Instances.create(server, "StarterPlayerScripts", nil, { internal = true })
		st.name = "StarterPlayerScripts"
		Instances.setParent(st, server.services.StarterPlayer, nil)
	end
	if not Instances.findChild(starterPlayer, "StarterCharacterScripts", nil) then
		local proxy, st = Instances.create(server, "StarterCharacterScripts", nil, { internal = true })
		st.name = "StarterCharacterScripts"
		Instances.setParent(st, server.services.StarterPlayer, nil)
	end
	-- TextChatService channels
	local textChat = states(server.services.TextChatService)
	local channels, channelsState = Instances.create(server, "Folder", nil, { internal = true })
	channelsState.name = "TextChannels"
	Instances.setParent(channelsState, textChat.proxy, nil)
	for _, channelName in { "RBXGeneral", "RBXSystem" } do
		local _, channelState = Instances.create(server, "TextChannel", nil, { internal = true })
		channelState.name = channelName
		Instances.setParent(channelState, channels, nil)
	end
	server.serverCtx.globals = Environment.build(server.serverCtx, server, server.loader)
	server.loading = false
	return server
end

-- Copies the services and instances of a deserialized (Lune) place into this server.
function Server:importPlace(place)
	local refs = {}
	local mapping = {}

	local function copyProperties(source, st)
		local info = Reflection.class(st.className)
		if not info then
			return
		end
		for name, prop in info.props do
			if name ~= "Name" and name ~= "Parent" and name ~= "ClassName" then
				local ok, value = pcall(function()
					return source[name]
				end)
				if ok and value ~= nil then
					if prop.datatype == "Ref" then
						refs[#refs + 1] = { st = st, name = name, target = value }
					elseif not (prop.hasDefault and value == prop.default) then
						st.props[name] = value
					end
				end
			end
		end
		local okAttributes, attributes = pcall(function()
			return source:GetAttributes()
		end)
		if okAttributes then
			for key, value in attributes do
				st.attributes[key] = value
			end
		end
		local okTags, tags = pcall(function()
			return source:GetTags()
		end)
		if okTags then
			for _, tag in tags do
				self.addTag(st, tag)
			end
		end
	end

	local function copyChildren(source, parentProxy)
		for _, child in source:GetChildren() do
			local proxy, st = Instances.create(self, child.ClassName, nil, { internal = true })
			st.name = child.Name
			mapping[child] = proxy
			copyProperties(child, st)
			Instances.setParent(st, parentProxy, nil)
			copyChildren(child, proxy)
		end
	end

	for _, service in place:GetChildren() do
		local ok, proxy = pcall(self.getService, service.ClassName, true)
		if ok and proxy then
			local st = states(proxy)
			mapping[service] = proxy
			copyProperties(service, st)
			copyChildren(service, proxy)
		end
	end
	for _, ref in refs do
		local target = mapping[ref.target]
		if target then
			ref.st.props[ref.name] = target
		end
	end
end

local function sourceOf(st)
	local source = st.props.Source
	if source == nil or source == Instances.NIL then
		return ""
	end
	return source
end

function Server:debugName(st)
	local fullName = Instances.fullName(st)
	return self.world.sourceMap[fullName] or fullName
end

function Server:requireModule(ctx, module)
	local st = states(module)
	if not st or st.className ~= "ModuleScript" then
		error("Attempted to call require with invalid argument(s).", 3)
	end
	local cache = ctx.modules[st]
	if cache then
		if cache.loading then
			error("Requested module was required recursively: " .. Instances.fullName(st), 3)
		end
		if cache.failed then
			error("Requested module experienced an error while loading: " .. Instances.fullName(st), 3)
		end
		return cache.value
	end
	cache = { loading = true }
	ctx.modules[st] = cache
	local env = Environment.forScript(ctx, module)
	local ok, chunk = pcall(Environment.compile, sourceOf(st), self:debugName(st), env)
	if not ok then
		cache.loading = false
		cache.failed = true
		error(chunk, 0)
	end
	local results = table.pack(pcall(chunk))
	cache.loading = false
	if not results[1] then
		cache.failed = true
		error(results[2], 0)
	end
	if results.n ~= 2 then
		cache.failed = true
		error("Module code did not return exactly one value: " .. Instances.fullName(st), 3)
	end
	cache.value = results[2]
	return cache.value
end

local function ancestorOfClass(st, className)
	local current = st.parent and states(st.parent)
	while current do
		if current.className == className then
			return current
		end
		current = current.parent and states(current.parent)
	end
	return nil
end

local function topContainer(st)
	local current = st
	while current.parent and states(current.parent).className ~= "DataModel" do
		current = states(current.parent)
	end
	return current
end

-- Context in which a script must run, or nil if it should not run here.
function Server:scriptContext(st)
	if st.className ~= "Script" and st.className ~= "LocalScript" then
		return nil
	end
	if Instances.getProp(st, "Disabled", nil) == true or not Instances.inDataModel(st) then
		return nil
	end
	local container = topContainer(st)
	if st.className == "Script" then
		local runContext = Instances.getProp(st, "RunContext", nil)
		local mode = tostring(runContext)
		if mode == "Enum.RunContext.Client" then
			return nil
		end
		if not SERVER_RUN_CONTAINERS[container.className] then
			if not (mode == "Enum.RunContext.Server" and container.className == "ReplicatedStorage") then
				return nil
			end
		end
		local actor = ancestorOfClass(st, "Actor")
		if actor then
			return self:actorContext(self.serverCtx, actor)
		end
		return self.serverCtx
	end
	-- LocalScript: runs for the player whose PlayerScripts/PlayerGui/Backpack/Character holds it.
	local owner = st.owner
	if owner and owner.kind == "client" then
		local playerState = states(owner.player)
		if Instances.isDescendantOf(st, owner.player) or (owner.characterProxy and Instances.isDescendantOf(st, owner.characterProxy)) then
			if playerState then
				local actor = ancestorOfClass(st, "Actor")
				if actor then
					return self:actorContext(owner, actor)
				end
				return owner
			end
		end
	end
	return nil
end

function Server:actorContext(peerCtx, actorState)
	actorState.extra.contexts = actorState.extra.contexts or {}
	local existing = actorState.extra.contexts[peerCtx]
	if existing then
		return existing
	end
	local ctx = setmetatable({
		id = peerCtx.id .. "/actor:" .. actorState.name,
		actor = actorState.proxy,
		modules = {},
		parent = peerCtx,
	}, { __index = peerCtx })
	ctx.globals = Environment.build(ctx, self, self.loader)
	actorState.extra.contexts[peerCtx] = ctx
	return ctx
end

function Server:maybeRunScript(st)
	if st.ran then
		return
	end
	local ctx = self:scriptContext(st)
	if not ctx then
		return
	end
	st.ran = true
	local env = Environment.forScript(ctx, st.proxy)
	local ok, chunk = pcall(Environment.compile, sourceOf(st), self:debugName(st), env)
	if not ok then
		self.world:log("error", ctx, tostring(chunk))
		return
	end
	self.scheduler:spawnIn(ctx, chunk)
end

-- Runs every server Script in the place.
function Server:start()
	assert(not self.started, "server already started")
	self.started = true
	local scripts = {}
	local function collect(st)
		for _, child in st.children do
			local childState = states(child)
			table.insert(scripts, childState)
			collect(childState)
		end
	end
	collect(states(self.dataModel))
	for _, st in scripts do
		self:maybeRunScript(st)
	end
	self.world:flush()
	return self
end

function Server:service(name)
	return self.services[name] or self.getService(name, true)
end

-- Finds an instance by dotted path, e.g. "ReplicatedStorage.Remotes.Request".
function Server:find(path)
	local current = self.dataModel
	for segment in string.gmatch(path, "[^%.]+") do
		local st = states(current)
		local child = Instances.findChild(st, segment, nil)
		if not child then
			return nil
		end
		current = child
	end
	return current
end

function Server:tagged(tag)
	local result = {}
	for _, st in self.tagged[tag] or {} do
		if not st.destroyed and Instances.inDataModel(st) then
			table.insert(result, st.proxy)
		end
	end
	return result
end

function Server:requireAs(ctx, path)
	local module = self:find(path)
	assert(module, "module not found: " .. path)
	return self.world:runIn(ctx or self.serverCtx, function()
		return self:requireModule(ctx or self.serverCtx, module)
	end)
end

function Server:buildRig(name, ctx)
	local model, modelState = Instances.create(self, "Model", ctx, { internal = true })
	modelState.name = name
	local function part(partName, size, offset)
		local proxy, st = Instances.create(self, "Part", ctx, { internal = true })
		st.name = partName
		st.props.Size = size
		st.props.CFrame = CFrame.new(offset)
		Instances.setParent(st, model, ctx)
		return proxy, st
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	states(root).props.Transparency = 1
	part("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0))
	part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.5, 0))
	modelState.props.PrimaryPart = root
	local humanoid, humanoidState = Instances.create(self, "Humanoid", ctx, { internal = true })
	humanoidState.name = "Humanoid"
	Instances.setParent(humanoidState, model, ctx)
	local animator, animatorState = Instances.create(self, "Animator", ctx, { internal = true })
	animatorState.name = "Animator"
	Instances.setParent(animatorState, humanoid, ctx)
	return model
end

local function spawnPosition(server)
	local workspace = states(server.services.Workspace)
	local found = nil
	Instances.forEachDescendant(workspace, function(st)
		if not found and st.className == "SpawnLocation" then
			found = st
		end
	end)
	if found then
		local cframe = found.props.CFrame
		if cframe == nil or cframe == Instances.NIL then
			cframe = CFrame.identity
		end
		return cframe.Position + Vector3.new(0, 3, 0)
	end
	return Vector3.new(0, 5, 0)
end

function Server:spawnCharacter(playerState)
	local player = playerState.proxy
	local ctx = self.clients[player]
	local old = Instances.getProp(playerState, "Character", nil)
	if old and states(old) then
		Instances.fire(playerState, "CharacterRemoving", nil, old)
		Instances.destroy(states(old), nil)
	end
	local model = self:buildRig(playerState.name, nil)
	local position = spawnPosition(self)
	model:PivotTo(CFrame.new(position))
	playerState.props.Character = model
	if ctx then
		ctx.characterProxy = model
	end
	Instances.setParent(states(model), self.services.Workspace, nil)
	-- StarterGui contents are cloned into PlayerGui on spawn (ResetOnSpawn).
	local playerGui = Instances.findChild(playerState, "PlayerGui", nil)
	if playerGui then
		for _, gui in Instances.children(states(self.services.StarterGui), nil) do
			local guiState = states(gui)
			local existing = Instances.findChild(states(playerGui), guiState.name, ctx)
			local resets = Instances.getProp(guiState, "ResetOnSpawn", nil) ~= false
			if not existing or resets then
				if existing then
					Instances.destroy(states(existing), nil)
				end
				local copy = Instances.clone(guiState, nil)
				Instances.setParent(states(copy), playerGui, nil)
			end
		end
	end
	Instances.fire(playerState, "CharacterAdded", nil, model)
	Instances.fire(playerState, "CharacterAppearanceLoaded", nil, model)
	return model
end

function Server:addPlayer(options)
	options = options or {}
	local userId = options.userId or (#self.world.servers * 1000 + #self.clientList + 1)
	local name = options.name or ("Player" .. tostring(userId))
	self.world.userNames[userId] = name
	local player, playerState = Instances.create(self, "Player", nil, { internal = true })
	playerState.name = name
	playerState.extra.userId = userId
	playerState.extra.displayName = options.displayName or name
	playerState.extra.accountAge = options.accountAge or 120
	playerState.extra.membership = options.premium and Enum.MembershipType.Premium or Enum.MembershipType.None
	playerState.extra.joinData = options.joinData

	local ctx = {
		kind = "client",
		id = "client:" .. tostring(userId),
		server = self,
		player = player,
		userId = userId,
		modules = {},
		shared = {},
		_G = {},
		device = options.device or "Desktop",
		actions = {},
		renderSteps = {},
		core = {},
		coreGui = {},
		systemMessages = {},
		keysDown = {},
		received = {},
		state = nil,
	}
	ctx.globals = Environment.build(ctx, self, self.loader)
	self.clients[player] = ctx
	table.insert(self.clientList, ctx)

	local camera, cameraState = Instances.create(self, "Camera", ctx, { internal = true })
	cameraState.name = "Camera"
	cameraState.extra.viewport = options.viewport or (if ctx.device == "Mobile" then Vector2.new(844, 390) else Vector2.new(1280, 720))
	Instances.setParent(cameraState, self.services.Workspace, ctx)
	ctx.camera = camera

	ctx.onRemote = function(remoteName, args)
		local copy = Serialize.remoteArgs(args)
		table.insert(ctx.received, { remote = remoteName, args = copy, time = self.scheduler.clock })
		if remoteName == "State" then
			if copy[1] == "snapshot" then
				ctx.state = copy[2]
			elseif copy[1] == "patch" and ctx.state then
				for key, value in copy[2] do
					ctx.state[key] = value
				end
			end
		end
	end

	for _, containerName in { "PlayerGui", "PlayerScripts", "Backpack" } do
		local proxy, st = Instances.create(self, containerName, nil, { internal = true })
		st.name = containerName
		if containerName ~= "Backpack" then
			st.privateTo = ctx
		end
		Instances.setParent(st, player, nil)
	end

	local client = setmetatable({
		server = self,
		world = self.world,
		ctx = ctx,
		player = player,
		userId = userId,
		name = name,
	}, Client)
	ctx.client = client

	Instances.setParent(playerState, self.services.Players, nil)
	Instances.fire(states(self.services.Players), "PlayerAdded", function(listener)
		return listener == nil or listener.kind == "server" or not listener.dead
	end, player)

	if options.runClient then
		client:startScripts()
	end

	local autoLoads = Instances.getProp(states(self.services.Players), "CharacterAutoLoads", nil)
	if autoLoads ~= false then
		self.scheduler:delay(0.1, function()
			if not ctx.dead then
				self:spawnCharacter(playerState)
			end
		end)
	end
	-- Pending developer product receipts are retried when the player joins.
	self.scheduler:delay(1, function()
		if not ctx.dead then
			self.world:retryReceipts(self, userId)
		end
	end)
	self.world:flush()
	return client
end

function Server:disconnect(player, reason)
	local ctx = self.clients[player]
	if not ctx or ctx.dead then
		return
	end
	local playerState = states(player)
	ctx.disconnectReason = reason
	Instances.fire(states(self.services.Players), "PlayerRemoving", function(listener)
		return listener == nil or listener.kind == "server" or listener ~= ctx
	end, player)
	ctx.dead = true
	self.world:flush()
	local character = Instances.getProp(playerState, "Character", nil)
	if character and states(character) and not states(character).destroyed then
		Instances.destroy(states(character), nil)
	end
	if ctx.camera and states(ctx.camera) then
		local cameraState = states(ctx.camera)
		cameraState.owner = nil
		Instances.destroy(cameraState, nil)
	end
	Instances.setParent(playerState, nil, nil)
	self.clients[player] = nil
	self.world:flush()
end

function Server:removePlayer(client)
	self:disconnect(client.player, "Left")
end

-- Graceful shutdown: players leave, BindToClose callbacks run (max 30 virtual seconds).
function Server:shutdown()
	for _, ctx in table.clone(self.clientList) do
		if not ctx.dead then
			self:disconnect(ctx.player, "Shutdown")
		end
	end
	local pending = 0
	for _, callback in self.closeCallbacks do
		pending += 1
		self.scheduler:spawnIn(callback.ctx or self.serverCtx, function()
			local ok, err = pcall(callback.fn)
			if not ok then
				self.world:log("error", self.serverCtx, "BindToClose callback errored: " .. tostring(err))
			end
			pending -= 1
		end)
	end
	local deadline = self.scheduler.clock + 30
	while pending > 0 and self.scheduler.clock < deadline do
		self.world:step()
	end
	self.closed = true
	self.serverCtx.dead = true
	return pending == 0
end

-- Abrupt termination: no BindToClose, no saves (simulates a crashed server).
function Server:crash()
	for _, ctx in self.clientList do
		ctx.dead = true
	end
	self.closed = true
	self.serverCtx.dead = true
end

--------------------------------------------------------------------------------
-- Client
--------------------------------------------------------------------------------

function Client:startScripts()
	local server = self.server
	local ctx = self.ctx
	local playerScripts = Instances.findChild(states(self.player), "PlayerScripts", nil)
	local starterScripts = server:find("StarterPlayer.StarterPlayerScripts")
	server.world.scheduler:spawnIn(ctx, function()
		for _, child in Instances.children(states(starterScripts), ctx) do
			local copy = Instances.clone(states(child), ctx)
			if copy then
				Instances.setParent(states(copy), playerScripts, ctx)
			end
		end
	end)
	self.world:flush()
end

function Client:run(fn, timeout)
	return self.world:runIn(self.ctx, fn, timeout)
end

function Client:require(path)
	return self.server:requireAs(self.ctx, path)
end

-- Invokes the game's Request remote as this client. Returns the server response.
function Client:request(action, payload)
	local remote = self.server:find("ReplicatedStorage.Remotes.Request")
	assert(remote, "ReplicatedStorage.Remotes.Request not found")
	return self:run(function()
		return remote:InvokeServer(action, payload)
	end)
end

-- Raw remote access for adversarial tests (any arguments).
function Client:invokeRaw(...)
	local remote = self.server:find("ReplicatedStorage.Remotes.Request")
	local args = table.pack(...)
	return self:run(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
end

function Client:fireEvent(kind, payload)
	local remote = self.server:find("ReplicatedStorage.Remotes.ClientEvent")
	self:run(function()
		remote:FireServer(kind, payload)
	end)
	self.world:flush()
end

function Client:fireRaw(...)
	local remote = self.server:find("ReplicatedStorage.Remotes.ClientEvent")
	local args = table.pack(...)
	self:run(function()
		remote:FireServer(table.unpack(args, 1, args.n))
	end)
end

-- Server -> client messages received on a remote (default "Notify"), optionally filtered by kind.
function Client:received(kind, remoteName)
	local result = {}
	for _, message in self.ctx.received do
		if message.remote == (remoteName or "Notify") and (kind == nil or message.args[1] == kind) then
			table.insert(result, message.args[2])
		end
	end
	return result
end

function Client:clearReceived()
	table.clear(self.ctx.received)
end

-- The player data as replicated to this client (snapshot + patches).
function Client:state()
	return self.ctx.state
end

function Client:character()
	return Instances.getProp(states(self.player), "Character", nil)
end

function Client:root()
	local character = self:character()
	if not character then
		return nil
	end
	return Instances.findChild(states(character), "HumanoidRootPart", nil)
end

function Client:position()
	local root = self:root()
	return root and states(root).proxy.Position
end

-- Moves the character (as the owning client, so it replicates).
function Client:teleport(position)
	local character = self:character()
	assert(character, "player has no character")
	self:run(function()
		character:PivotTo(CFrame.new(position))
	end)
end

-- Moves the character next to an instance (part, model or attachment).
function Client:moveNear(target, offset)
	local st = states(target)
	local position
	self:run(function()
		if st.className == "Attachment" then
			position = target.WorldPosition
		elseif Reflection.isA(st.className, "BasePart") then
			position = target.Position
		else
			position = target:GetPivot().Position
		end
	end)
	self:teleport(position + (offset or Vector3.new(0, 0, 3)))
end

local function promptPosition(promptState)
	local parent = promptState.parent and states(promptState.parent)
	if not parent then
		return nil
	end
	if parent.className == "Attachment" then
		return parent.proxy.WorldPosition
	elseif Reflection.isA(parent.className, "BasePart") then
		return parent.proxy.Position
	elseif parent.className == "Model" then
		return parent.proxy:GetPivot().Position
	end
	return nil
end

-- Triggers a ProximityPrompt like a real player would (must be visible, enabled and in range).
-- options.bypass = true skips the client-side checks (simulates an exploit firing the prompt).
function Client:triggerPrompt(prompt, options)
	options = options or {}
	local st = states(prompt)
	assert(st and st.className == "ProximityPrompt", "triggerPrompt expects a ProximityPrompt")
	local ctx = self.ctx
	if not options.bypass then
		if not Instances.visible(st, ctx) then
			error("prompt is not visible to this client", 2)
		end
		local enabled
		self:run(function()
			enabled = prompt.Enabled
		end)
		if not enabled then
			error("prompt is disabled for this client", 2)
		end
		local position = promptPosition(st)
		local root = self:position()
		local maxDistance = Instances.getProp(st, "MaxActivationDistance", nil) or 10
		if position and root and (position - root).Magnitude > maxDistance then
			error(string.format("prompt out of range (%.1f > %.1f)", (position - root).Magnitude, maxDistance), 2)
		end
	end
	local player = self.player
	local service = states(self.server.services.ProximityPromptService)
	Instances.fire(st, "Triggered", function(listener)
		return listener == nil or listener.kind == "server" or listener == ctx
	end, player)
	Instances.fire(service, "PromptTriggered", function(listener)
		return listener == nil or listener.kind == "server" or listener == ctx
	end, prompt, player)
	Instances.fire(st, "TriggerEnded", function(listener)
		return listener == nil or listener.kind == "server" or listener == ctx
	end, player)
	self.world:flush()
end

-- Finds prompts (descendants of `root`, default Workspace) matching `predicate(prompt)`.
function Client:prompts(predicate, root)
	local result = {}
	local base = states(root or self.server.services.Workspace)
	Instances.forEachDescendant(base, function(st)
		if st.className == "ProximityPrompt" and Instances.visible(st, self.ctx) and (predicate == nil or predicate(st.proxy)) then
			table.insert(result, st.proxy)
		end
	end)
	return result
end

local function guiVisible(st, ctx)
	local current = st
	while current do
		if current.className == "PlayerGui" then
			return true
		end
		if Reflection.isA(current.className, "GuiObject") and Instances.getProp(current, "Visible", ctx) == false then
			return false
		end
		if Reflection.isA(current.className, "LayerCollector") and Instances.getProp(current, "Enabled", ctx) == false then
			return false
		end
		current = current.parent and states(current.parent)
	end
	return false
end

function Client:playerGui()
	return Instances.findChild(states(self.player), "PlayerGui", nil)
end

-- Every visible GuiObject under PlayerGui matching `predicate`.
function Client:guiObjects(predicate)
	local result = {}
	local playerGui = self:playerGui()
	if not playerGui then
		return result
	end
	Instances.forEachDescendant(states(playerGui), function(st)
		if Instances.visible(st, self.ctx) and Reflection.isA(st.className, "GuiObject") and guiVisible(st, self.ctx) then
			if predicate == nil or predicate(st) then
				table.insert(result, st.proxy)
			end
		end
	end)
	return result
end

function Client:texts()
	local result = {}
	for _, gui in self:guiObjects(function(st)
		return st.className == "TextLabel" or st.className == "TextButton" or st.className == "TextBox"
	end) do
		table.insert(result, Instances.getProp(states(gui), "Text", self.ctx) or "")
	end
	return result
end

function Client:hasText(pattern)
	for _, text in self:texts() do
		if string.find(text, pattern, 1, true) then
			return true
		end
	end
	return false
end

-- Finds a visible button whose own text or a descendant label's text contains `pattern`.
function Client:findButton(pattern)
	for _, gui in self:guiObjects(function(st)
		return Reflection.isA(st.className, "GuiButton")
	end) do
		local st = states(gui)
		local text = Instances.getProp(st, "Text", self.ctx)
		if text and string.find(text, pattern, 1, true) then
			return gui
		end
		local found = nil
		Instances.forEachDescendant(st, function(descendant)
			if not found and (descendant.className == "TextLabel") then
				local label = Instances.getProp(descendant, "Text", self.ctx)
				if label and string.find(label, pattern, 1, true) then
					found = gui
				end
			end
		end)
		if found then
			return found
		end
		local name = st.name
		if string.find(name, pattern, 1, true) then
			return gui
		end
	end
	return nil
end

-- Clicks a GUI button: it must be visible and Active/Interactable.
function Client:click(button)
	local st = states(button)
	assert(st and Reflection.isA(st.className, "GuiButton"), "click expects a GuiButton")
	if not guiVisible(st, self.ctx) then
		error("button is not visible: " .. Instances.fullName(st), 2)
	end
	if Instances.getProp(st, "Interactable", self.ctx) == false or Instances.getProp(st, "Active", self.ctx) == false then
		error("button is not interactable: " .. Instances.fullName(st), 2)
	end
	local ctx = self.ctx
	local input, inputState = Instances.create(self.server, "InputObject", ctx, { internal = true })
	inputState.props.UserInputType = Enum.UserInputType.MouseButton1
	inputState.props.UserInputState = Enum.UserInputState.End
	local filter = function(listener)
		return listener == ctx
	end
	Instances.fire(st, "MouseButton1Down", filter, 0, 0)
	Instances.fire(st, "MouseButton1Up", filter, 0, 0)
	Instances.fire(st, "MouseButton1Click", filter)
	Instances.fire(st, "Activated", filter, input, 1)
	self.world:flush()
end

function Client:clickText(pattern)
	local button = self:findButton(pattern)
	if not button then
		error("no visible button matching '" .. pattern .. "'. Visible texts: " .. table.concat(self:texts(), " | "), 2)
	end
	self:click(button)
end

-- Simulates a key press through ContextActionService and UserInputService.
function Client:pressKey(keyCode)
	local ctx = self.ctx
	local server = self.server
	local input, inputState = Instances.create(server, "InputObject", ctx, { internal = true })
	inputState.props.KeyCode = keyCode
	inputState.props.UserInputType = Enum.UserInputType.Keyboard
	local filter = function(listener)
		return listener == ctx
	end
	inputState.props.UserInputState = Enum.UserInputState.Begin
	ctx.keysDown[keyCode] = true
	Instances.fire(states(server.services.UserInputService or server.getService("UserInputService", true)), "InputBegan", filter, input, false)
	for name, action in ctx.actions do
		for _, bound in action.inputs do
			if bound == keyCode then
				server.scheduler:deferIn(ctx, action.fn, table.pack(name, Enum.UserInputState.Begin, input))
			end
		end
	end
	self.world:flush()
	inputState.props.UserInputState = Enum.UserInputState.End
	ctx.keysDown[keyCode] = nil
	Instances.fire(states(server.services.UserInputService), "InputEnded", filter, input, false)
	for name, action in ctx.actions do
		for _, bound in action.inputs do
			if bound == keyCode then
				server.scheduler:deferIn(ctx, action.fn, table.pack(name, Enum.UserInputState.End, input))
			end
		end
	end
	self.world:flush()
end

function Client:systemMessages()
	return self.ctx.systemMessages
end

function Client:isConnected()
	return not self.ctx.dead
end

Runtime.Instances = Instances
Runtime.Registry = Registry
Runtime.Reflection = Reflection
Runtime.Enum = Enum
Runtime.CFrame = CFrame
Runtime.Vector3 = Vector3
Runtime.Vector2 = Vector2

return Runtime

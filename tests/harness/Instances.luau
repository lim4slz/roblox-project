--[[
	Instances
	Core of the mock DataModel.

	Fidelity rules implemented here:
	  * member lookup order: property -> method -> event -> child (same as Roblox)
	  * unknown members, wrong property types and read-only writes raise errors
	  * one instance tree per server, shared by its clients, with replication rules:
	      - instances created by a client exist only for that client
	      - property/attribute changes made by a client on replicated instances are
	        local to that client (overlays) - except character movement
	      - ServerScriptService / ServerStorage contents are invisible to clients
	      - a player's PlayerGui / PlayerScripts are invisible to other clients
	  * Parent is locked after Destroy; destroyed instances drop their connections
	  * CollectionService tags, attributes and change signals
]]

local Registry = require("./Registry")
local Reflection = require("./Reflection")
local RbxSignal = require("./RbxSignal")

local Instances = {}

local states = Registry.states
local NIL = newproxy(false) -- sentinel for properties explicitly set to nil

local behaviors = {}
local memberCache = {}

--------------------------------------------------------------------------------
-- Behavior registry
--------------------------------------------------------------------------------

-- def = { props = { Name = { get?, set?, readOnly?, datatype?, default? } },
--         methods = { Name = function(self, ...) }, events = { Name = { immediate? } | true },
--         init = function(st) }
function Instances.define(className: string, def)
	local existing = behaviors[className]
	if not existing then
		behaviors[className] = {
			props = def.props or {},
			methods = def.methods or {},
			events = def.events or {},
			init = def.init,
		}
		return
	end
	for key, value in def.props or {} do
		existing.props[key] = value
	end
	for key, value in def.methods or {} do
		existing.methods[key] = value
	end
	for key, value in def.events or {} do
		existing.events[key] = value
	end
	if def.init then
		local previous = existing.init
		existing.init = if previous
			then function(st)
				previous(st)
				def.init(st)
			end
			else def.init
	end
	memberCache = {}
end

local function classChain(className: string)
	local info = Reflection.class(className)
	if info then
		return info.chain, info
	end
	return { className, "Instance" }, nil
end

local function membersOf(className: string)
	local cached = memberCache[className]
	if cached then
		return cached
	end
	local chain, info = classChain(className)
	local members = {}
	-- Behaviors first, most specific class first.
	for _, name in chain do
		local def = behaviors[name]
		if def then
			for key, prop in def.props do
				if members[key] == nil then
					local reflected = info and info.props[key]
					members[key] = {
						kind = "prop",
						get = prop.get,
						set = prop.set,
						readOnly = prop.readOnly or false,
						datatype = prop.datatype or (reflected and reflected.datatype),
						default = if prop.default ~= nil then prop.default else (reflected and reflected.default),
						hasDefault = prop.default ~= nil or (reflected ~= nil and reflected.hasDefault),
						custom = true,
					}
				end
			end
			for key, fn in def.methods do
				if members[key] == nil then
					members[key] = { kind = "method", fn = fn }
				end
			end
			for key, eventDef in def.events do
				if members[key] == nil then
					members[key] = {
						kind = "event",
						immediate = type(eventDef) == "table" and eventDef.immediate,
						onConnect = type(eventDef) == "table" and eventDef.onConnect or nil,
					}
				end
			end
		end
	end
	-- Reflected properties.
	if info then
		for key, prop in info.props do
			if members[key] == nil and prop.scriptability ~= "None" then
				members[key] = {
					kind = "prop",
					readOnly = prop.readOnly,
					datatype = prop.datatype,
					default = prop.default,
					hasDefault = prop.hasDefault,
					deprecated = prop.deprecated,
				}
			end
		end
	end
	memberCache[className] = members
	return members
end

local function initChain(st)
	local chain = classChain(st.className)
	for index = #chain, 1, -1 do
		local def = behaviors[chain[index]]
		if def and def.init then
			def.init(st)
		end
	end
end

--------------------------------------------------------------------------------
-- Context & visibility helpers
--------------------------------------------------------------------------------

local function currentCtx(st)
	return st.server.scheduler:currentCtx()
end

local function isClient(ctx)
	return ctx ~= nil and ctx.kind == "client"
end

-- Is `st` itself visible from `ctx` (ignoring ancestors)?
local function selfVisible(st, ctx)
	if st.owner ~= nil and st.owner ~= ctx then
		return false
	end
	if isClient(ctx) then
		if st.hidden and st.hidden[ctx] then
			return false
		end
		if st.privateTo and st.privateTo ~= ctx then
			return false
		end
		local parent = st.parent and states[st.parent]
		if parent and parent.childrenServerOnly then
			return false
		end
	end
	return true
end

function Instances.visible(st, ctx): boolean
	local current = st
	while current do
		if not selfVisible(current, ctx) then
			return false
		end
		current = current.parent and states[current.parent]
	end
	return true
end

function Instances.state(proxy)
	return states[proxy]
end

function Instances.isInstance(value): boolean
	return states[value] ~= nil
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function Instances.event(st, name: string)
	local entry = st.events[name]
	if not entry then
		local members = st.members
		local member = members[name]
		local immediate = member and member.kind == "event" and member.immediate
		local onConnect = member and member.kind == "event" and member.onConnect
		local proxy, signalState = RbxSignal.new(st.server.scheduler, name, {
			immediate = immediate,
			onConnect = if onConnect
				then function(connection)
					onConnect(st, connection)
				end
				else nil,
		})
		entry = { proxy = proxy, state = signalState }
		st.events[name] = entry
	end
	return entry
end

function Instances.fire(st, name: string, filter, ...)
	local entry = st.events[name]
	if entry then
		RbxSignal.fire(entry.state, filter, ...)
	end
end

local function visibleFilter(st)
	return function(ctx)
		return Instances.visible(st, ctx)
	end
end

local function propertySignal(st, name)
	local entry = st.propSignals[name]
	if not entry then
		local proxy, signalState = RbxSignal.new(st.server.scheduler, name .. "Changed")
		entry = { proxy = proxy, state = signalState }
		st.propSignals[name] = entry
	end
	return entry
end

local function attributeSignal(st, name)
	local entry = st.attrSignals[name]
	if not entry then
		local proxy, signalState = RbxSignal.new(st.server.scheduler, name .. "AttributeChanged")
		entry = { proxy = proxy, state = signalState }
		st.attrSignals[name] = entry
	end
	return entry
end

local function firePropertyChanged(st, name, filter)
	if st.valueChanged then
		if name == "Value" then
			Instances.fire(st, "Changed", filter, Instances.getProp(st, "Value", nil))
		end
	else
		Instances.fire(st, "Changed", filter, name)
	end
	local entry = st.propSignals[name]
	if entry then
		RbxSignal.fire(entry.state, filter)
	end
end

--------------------------------------------------------------------------------
-- Properties
--------------------------------------------------------------------------------

local function rawGet(st, name, ctx)
	if ctx and st.overlays then
		local overlay = st.overlays[ctx]
		if overlay and overlay.props[name] ~= nil then
			local value = overlay.props[name]
			return if value == NIL then nil else value, true
		end
	end
	local value = st.props[name]
	if value ~= nil then
		return if value == NIL then nil else value, true
	end
	return nil, false
end

function Instances.getProp(st, name, ctx)
	local member = st.members[name]
	local value, found = rawGet(st, name, ctx)
	if found then
		return value
	end
	if member and member.hasDefault then
		return member.default
	end
	return nil
end

-- Stores a property value (no validation). `ctx` decides overlay vs replicated write.
function Instances.storeProp(st, name, value, ctx, forceReplicated)
	local stored = if value == nil then NIL else value
	if isClient(ctx) and st.owner ~= ctx and not forceReplicated then
		st.overlays = st.overlays or {}
		local overlay = st.overlays[ctx]
		if not overlay then
			overlay = { props = {}, attrs = {} }
			st.overlays[ctx] = overlay
		end
		overlay.props[name] = stored
		firePropertyChanged(st, name, function(listener)
			return listener == ctx
		end)
		return
	end
	st.props[name] = stored
	if st.overlays then
		-- A replicated (server) write replaces any client-local value.
		for _, overlay in st.overlays do
			overlay.props[name] = nil
		end
	end
	firePropertyChanged(st, name, visibleFilter(st))
end

local function writeProperty(st, proxy, name, value)
	local member = st.members[name]
	if not member or member.kind ~= "prop" then
		error(string.format("%s is not a valid member of %s \"%s\"", tostring(name), st.className, Instances.fullName(st)), 3)
	end
	if member.readOnly then
		error(string.format("Unable to assign property %s. Property is read only", name), 3)
	end
	local ctx = currentCtx(st)
	if ctx and ctx.parallel and st.server.scheduler:isParallel() then
		error(string.format("Property %s.%s is not safe to write in parallel", st.className, name), 3)
	end
	if member.datatype then
		local ok, coerced, err = Reflection.coerce(member.datatype, value, Instances.isInstance)
		if not ok then
			error(string.format("Unable to assign property %s. %s", name, err), 3)
		end
		value = coerced
	end
	if member.set then
		member.set(proxy, st, value, ctx)
	else
		Instances.storeProp(st, name, value, ctx)
	end
end

local function readProperty(st, proxy, name, member)
	local ctx = currentCtx(st)
	if member.get then
		return member.get(proxy, st, ctx)
	end
	return Instances.getProp(st, name, ctx)
end

--------------------------------------------------------------------------------
-- Tree
--------------------------------------------------------------------------------

function Instances.fullName(st): string
	local parts = {}
	local current = st
	while current and current.className ~= "DataModel" do
		table.insert(parts, 1, current.name)
		current = current.parent and states[current.parent]
	end
	return table.concat(parts, ".")
end

function Instances.isDescendantOf(st, ancestorProxy): boolean
	local current = st.parent
	while current do
		if current == ancestorProxy then
			return true
		end
		current = states[current].parent
	end
	return false
end

function Instances.inDataModel(st): boolean
	local current = st
	while current do
		if current.className == "DataModel" then
			return true
		end
		current = current.parent and states[current.parent]
	end
	return false
end

local function forEachDescendant(st, fn)
	for _, child in st.children do
		local childState = states[child]
		fn(childState)
		forEachDescendant(childState, fn)
	end
end
Instances.forEachDescendant = forEachDescendant

local function notifyAncestors(st, eventName, subject)
	local current = st.parent and states[st.parent]
	while current do
		Instances.fire(current, eventName, visibleFilter(subject), subject.proxy)
		current = current.parent and states[current.parent]
	end
end

function Instances.setParent(st, newParent, ctx)
	if st.parentLocked then
		error(
			string.format(
				"The Parent property of %s is locked, current parent: %s, new parent %s",
				st.name,
				st.parent and states[st.parent].name or "NULL",
				newParent and states[newParent].name or "NULL"
			),
			3
		)
	end
	if newParent == st.parent then
		return
	end
	if newParent then
		if newParent == st.proxy then
			error("Attempt to set " .. st.name .. " as its own parent", 3)
		end
		local parentState = states[newParent]
		if Instances.isDescendantOf(parentState, st.proxy) then
			error("Attempt to set parent of " .. st.name .. " to " .. parentState.name .. " would result in circular reference", 3)
		end
		if parentState.server ~= st.server then
			error("Cannot parent an instance across different servers", 3)
		end
	end
	-- A client cannot really move a replicated instance; removing it is local-only.
	if isClient(ctx) and st.owner ~= ctx then
		if newParent == nil then
			st.hidden = st.hidden or {}
			st.hidden[ctx] = true
			return
		end
		error("harness: client-side reparenting of a replicated instance (" .. Instances.fullName(st) .. ") is not supported", 3)
	end
	local server = st.server
	local wasInDataModel = Instances.inDataModel(st)
	local oldParent = st.parent
	if oldParent then
		local oldState = states[oldParent]
		notifyAncestors(st, "DescendantRemoving", st)
		forEachDescendant(st, function(descendant)
			notifyAncestors(descendant, "DescendantRemoving", descendant)
		end)
		local index = table.find(oldState.children, st.proxy)
		if index then
			table.remove(oldState.children, index)
		end
		st.parent = nil
		Instances.fire(oldState, "ChildRemoved", visibleFilter(st), st.proxy)
	end
	st.parent = newParent
	if newParent then
		local parentState = states[newParent]
		table.insert(parentState.children, st.proxy)
		Instances.fire(parentState, "ChildAdded", visibleFilter(st), st.proxy)
		notifyAncestors(st, "DescendantAdded", st)
		forEachDescendant(st, function(descendant)
			notifyAncestors(descendant, "DescendantAdded", descendant)
		end)
		-- Wake WaitForChild waiters
		local waiters = parentState.childWaiters and parentState.childWaiters[st.name]
		if waiters then
			for index = #waiters, 1, -1 do
				local waiter = waiters[index]
				if Instances.visible(st, waiter.ctx) then
					table.remove(waiters, index)
					server.scheduler:deferIn(waiter.ctx, waiter.thread, table.pack(st.proxy))
				end
			end
		end
	end
	Instances.fire(st, "AncestryChanged", visibleFilter(st), st.proxy, newParent)
	forEachDescendant(st, function(descendant)
		Instances.fire(descendant, "AncestryChanged", visibleFilter(descendant), st.proxy, newParent)
	end)
	local isNowInDataModel = Instances.inDataModel(st)
	if wasInDataModel ~= isNowInDataModel and server.onMembershipChanged then
		server.onMembershipChanged(st, isNowInDataModel)
		forEachDescendant(st, function(descendant)
			server.onMembershipChanged(descendant, isNowInDataModel)
		end)
	end
	if server.onReparented then
		server.onReparented(st)
	end
end

function Instances.children(st, ctx)
	local result = {}
	for _, child in st.children do
		if selfVisible(states[child], ctx) then
			table.insert(result, child)
		end
	end
	return result
end

function Instances.findChild(st, name, ctx)
	for _, child in st.children do
		local childState = states[child]
		if childState.name == name and selfVisible(childState, ctx) then
			return child
		end
	end
	return nil
end

function Instances.destroy(st, ctx)
	if isClient(ctx) and st.owner ~= ctx then
		-- Local-only removal of a replicated instance.
		st.hidden = st.hidden or {}
		st.hidden[ctx] = true
		return
	end
	if st.destroyed then
		return
	end
	Instances.fire(st, "Destroying", nil)
	for _, child in table.clone(st.children) do
		Instances.destroy(states[child], ctx)
	end
	if st.parent then
		Instances.setParent(st, nil, ctx)
	end
	st.destroyed = true
	st.parentLocked = true
	-- Destroy disconnects everything once pending deferred handlers ran.
	st.server.scheduler:deferIn(nil, function()
		for _, entry in st.events do
			RbxSignal.disconnectAll(entry.state)
		end
		for _, entry in st.propSignals do
			RbxSignal.disconnectAll(entry.state)
		end
		for _, entry in st.attrSignals do
			RbxSignal.disconnectAll(entry.state)
		end
	end)
	if st.onDestroy then
		st.onDestroy(st)
	end
end

--------------------------------------------------------------------------------
-- Creation
--------------------------------------------------------------------------------

local function makeProxy(st)
	return Registry.proxy("Instance", function(mt)
		mt.__index = function(proxy, key)
			local member = st.members[key]
			if member then
				local kind = member.kind
				if kind == "prop" then
					return readProperty(st, proxy, key, member)
				elseif kind == "method" then
					return member.fn
				else
					return Instances.event(st, key).proxy
				end
			end
			if type(key) == "string" then
				local child = Instances.findChild(st, key, currentCtx(st))
				if child then
					return child
				end
			end
			error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), st.className, Instances.fullName(st)), 2)
		end
		mt.__newindex = function(proxy, key, value)
			if key == "Name" then
				if type(value) ~= "string" then
					error("Unable to assign property Name. string expected, got " .. typeof(value), 2)
				end
				local ctx = currentCtx(st)
				if isClient(ctx) and st.owner ~= ctx then
					error("harness: client-side rename of a replicated instance is not supported", 2)
				end
				st.name = value
				firePropertyChanged(st, "Name", nil)
				return
			elseif key == "Parent" then
				if value ~= nil and not states[value] then
					error("Unable to assign property Parent. Instance expected, got " .. typeof(value), 2)
				end
				Instances.setParent(st, value, currentCtx(st))
				return
			end
			writeProperty(st, proxy, key, value)
		end
		mt.__tostring = function()
			return st.name
		end
	end)
end

-- Creates an instance on `server`. `ctx` is the creating context (client-owned if client).
function Instances.create(server, className: string, ctx, options)
	options = options or {}
	local info = Reflection.class(className)
	if not options.internal then
		if not info then
			error(string.format('Unable to create an Instance of type "%s"', tostring(className)), 3)
		end
		if not info.creatable then
			error(string.format('Unable to create an Instance of type "%s"', className), 3)
		end
	end
	local st = {
		className = className,
		server = server,
		name = className,
		props = {},
		children = {},
		attributes = {},
		tags = {},
		events = {},
		propSignals = {},
		attrSignals = {},
		extra = {},
		owner = if isClient(ctx) then ctx else nil,
		members = membersOf(className),
	}
	st.proxy = makeProxy(st)
	states[st.proxy] = st
	initChain(st)
	if server.onCreated then
		server.onCreated(st)
	end
	return st.proxy, st
end

function Instances.clone(st, ctx)
	if Instances.getProp(st, "Archivable", nil) == false then
		return nil
	end
	local proxy, copy = Instances.create(st.server, st.className, ctx, { internal = true })
	copy.name = st.name
	for key, value in st.props do
		copy.props[key] = value
	end
	-- Client-local values become real values in the client's own copy.
	if ctx and st.overlays and st.overlays[ctx] then
		for key, value in st.overlays[ctx].props do
			copy.props[key] = value
		end
	end
	for key, value in st.attributes do
		copy.attributes[key] = value
	end
	for tag in st.tags do
		copy.tags[tag] = true
	end
	if st.onClone then
		st.onClone(st, copy)
	end
	for _, child in st.children do
		local childState = states[child]
		if selfVisible(childState, ctx) then
			local childCopy = Instances.clone(childState, ctx)
			if childCopy then
				Instances.setParent(states[childCopy], proxy, ctx)
			end
		end
	end
	return proxy
end

--------------------------------------------------------------------------------
-- Attributes & tags
--------------------------------------------------------------------------------

local ATTRIBUTE_TYPES = {
	boolean = true,
	number = true,
	string = true,
	UDim = true,
	UDim2 = true,
	BrickColor = true,
	Color3 = true,
	Vector2 = true,
	Vector3 = true,
	CFrame = true,
	NumberSequence = true,
	ColorSequence = true,
	NumberRange = true,
	Rect = true,
	Font = true,
	EnumItem = true,
}

function Instances.setAttribute(st, name, value, ctx)
	if type(name) ~= "string" or #name == 0 or #name > 100 or not string.match(name, "^[%w_]+$") then
		error("Attribute name must be alphanumeric/underscore and at most 100 characters: " .. tostring(name), 3)
	end
	if value ~= nil and not ATTRIBUTE_TYPES[typeof(value)] then
		error(string.format("%s is not a supported attribute type", typeof(value)), 3)
	end
	if isClient(ctx) and st.owner ~= ctx then
		st.overlays = st.overlays or {}
		local overlay = st.overlays[ctx]
		if not overlay then
			overlay = { props = {}, attrs = {} }
			st.overlays[ctx] = overlay
		end
		overlay.attrs[name] = if value == nil then NIL else value
		local filter = function(listener)
			return listener == ctx
		end
		Instances.fire(st, "AttributeChanged", filter, name)
		local entry = st.attrSignals[name]
		if entry then
			RbxSignal.fire(entry.state, filter)
		end
		return
	end
	st.attributes[name] = value
	if st.overlays then
		for _, overlay in st.overlays do
			overlay.attrs[name] = nil
		end
	end
	local filter = visibleFilter(st)
	Instances.fire(st, "AttributeChanged", filter, name)
	local entry = st.attrSignals[name]
	if entry then
		RbxSignal.fire(entry.state, filter)
	end
end

function Instances.getAttribute(st, name, ctx)
	if ctx and st.overlays and st.overlays[ctx] then
		local value = st.overlays[ctx].attrs[name]
		if value ~= nil then
			return if value == NIL then nil else value
		end
	end
	return st.attributes[name]
end

--------------------------------------------------------------------------------
-- Base Instance behavior
--------------------------------------------------------------------------------

local function selfState(self)
	local st = states[self]
	if not st then
		error("Expected ':' not '.' calling member function", 3)
	end
	return st
end

local function matchesClass(st, className)
	return Reflection.isA(st.className, className) or st.className == className
end

local function findDescendant(st, ctx, predicate)
	for _, child in st.children do
		local childState = states[child]
		if selfVisible(childState, ctx) then
			if predicate(childState) then
				return child
			end
			local found = findDescendant(childState, ctx, predicate)
			if found then
				return found
			end
		end
	end
	return nil
end

Instances.define("Instance", {
	props = {
		Name = {
			get = function(_, st)
				return st.name
			end,
			datatype = "String",
		},
		Parent = {
			get = function(_, st, ctx)
				if isClient(ctx) and st.hidden and st.hidden[ctx] then
					return nil
				end
				return st.parent
			end,
			datatype = "Ref",
		},
		ClassName = {
			get = function(_, st)
				return st.className
			end,
			readOnly = true,
		},
	},
	methods = {
		GetChildren = function(self)
			local st = selfState(self)
			return Instances.children(st, currentCtx(st))
		end,
		GetDescendants = function(self)
			local st = selfState(self)
			local ctx = currentCtx(st)
			local result = {}
			local function walk(s)
				for _, child in s.children do
					local childState = states[child]
					if selfVisible(childState, ctx) then
						table.insert(result, child)
						walk(childState)
					end
				end
			end
			walk(st)
			return result
		end,
		FindFirstChild = function(self, name, recursive)
			local st = selfState(self)
			local ctx = currentCtx(st)
			if recursive then
				return findDescendant(st, ctx, function(s)
					return s.name == name
				end)
			end
			return Instances.findChild(st, name, ctx)
		end,
		FindFirstDescendant = function(self, name)
			local st = selfState(self)
			return findDescendant(st, currentCtx(st), function(s)
				return s.name == name
			end)
		end,
		FindFirstChildOfClass = function(self, className)
			local st = selfState(self)
			local ctx = currentCtx(st)
			for _, child in st.children do
				local childState = states[child]
				if childState.className == className and selfVisible(childState, ctx) then
					return child
				end
			end
			return nil
		end,
		FindFirstChildWhichIsA = function(self, className, recursive)
			local st = selfState(self)
			local ctx = currentCtx(st)
			if recursive then
				return findDescendant(st, ctx, function(s)
					return matchesClass(s, className)
				end)
			end
			for _, child in st.children do
				local childState = states[child]
				if matchesClass(childState, className) and selfVisible(childState, ctx) then
					return child
				end
			end
			return nil
		end,
		FindFirstAncestor = function(self, name)
			local current = selfState(self).parent
			while current do
				local s = states[current]
				if s.name == name then
					return current
				end
				current = s.parent
			end
			return nil
		end,
		FindFirstAncestorOfClass = function(self, className)
			local current = selfState(self).parent
			while current do
				local s = states[current]
				if s.className == className then
					return current
				end
				current = s.parent
			end
			return nil
		end,
		FindFirstAncestorWhichIsA = function(self, className)
			local current = selfState(self).parent
			while current do
				local s = states[current]
				if matchesClass(s, className) then
					return current
				end
				current = s.parent
			end
			return nil
		end,
		WaitForChild = function(self, name, timeout)
			local st = selfState(self)
			local ctx = currentCtx(st)
			local existing = Instances.findChild(st, name, ctx)
			if existing then
				return existing
			end
			local scheduler = st.server.scheduler
			local thread = coroutine.running()
			st.childWaiters = st.childWaiters or {}
			st.childWaiters[name] = st.childWaiters[name] or {}
			local waiter = { thread = thread, ctx = ctx }
			table.insert(st.childWaiters[name], waiter)
			local timeoutAt = timeout
			if timeoutAt then
				scheduler:delay(timeoutAt, function()
					local list = st.childWaiters[name]
					local index = list and table.find(list, waiter)
					if index then
						table.remove(list, index)
						scheduler:resume(thread, nil)
					end
				end)
			else
				scheduler:delay(5, function()
					local list = st.childWaiters[name]
					if list and table.find(list, waiter) then
						st.server.log("warn", ctx, string.format('Infinite yield possible on \'%s:WaitForChild("%s")\'', Instances.fullName(st), name))
					end
				end)
			end
			return coroutine.yield()
		end,
		IsA = function(self, className)
			return matchesClass(selfState(self), className)
		end,
		IsDescendantOf = function(self, ancestor)
			return Instances.isDescendantOf(selfState(self), ancestor)
		end,
		IsAncestorOf = function(self, descendant)
			local st = selfState(self)
			return states[descendant] ~= nil and Instances.isDescendantOf(states[descendant], st.proxy)
		end,
		GetFullName = function(self)
			return Instances.fullName(selfState(self))
		end,
		Destroy = function(self)
			local st = selfState(self)
			Instances.destroy(st, currentCtx(st))
		end,
		ClearAllChildren = function(self)
			local st = selfState(self)
			local ctx = currentCtx(st)
			for _, child in table.clone(st.children) do
				if selfVisible(states[child], ctx) then
					Instances.destroy(states[child], ctx)
				end
			end
		end,
		Clone = function(self)
			local st = selfState(self)
			return Instances.clone(st, currentCtx(st))
		end,
		GetAttribute = function(self, name)
			local st = selfState(self)
			return Instances.getAttribute(st, name, currentCtx(st))
		end,
		SetAttribute = function(self, name, value)
			local st = selfState(self)
			Instances.setAttribute(st, name, value, currentCtx(st))
		end,
		GetAttributes = function(self)
			local st = selfState(self)
			local ctx = currentCtx(st)
			local result = table.clone(st.attributes)
			if ctx and st.overlays and st.overlays[ctx] then
				for key, value in st.overlays[ctx].attrs do
					result[key] = if value == NIL then nil else value
				end
			end
			return result
		end,
		GetAttributeChangedSignal = function(self, name)
			return attributeSignal(selfState(self), name).proxy
		end,
		GetPropertyChangedSignal = function(self, name)
			local st = selfState(self)
			local member = st.members[name]
			if not member or member.kind ~= "prop" then
				error(string.format("%s is not a valid property name.", tostring(name)), 2)
			end
			return propertySignal(st, name).proxy
		end,
		AddTag = function(self, tag)
			local st = selfState(self)
			st.server.addTag(st, tag)
		end,
		RemoveTag = function(self, tag)
			local st = selfState(self)
			st.server.removeTag(st, tag)
		end,
		HasTag = function(self, tag)
			return selfState(self).tags[tag] == true
		end,
		GetTags = function(self)
			local result = {}
			for tag in selfState(self).tags do
				table.insert(result, tag)
			end
			table.sort(result)
			return result
		end,
		GetActor = function(self)
			local current = selfState(self).parent
			while current do
				local s = states[current]
				if s.className == "Actor" then
					return current
				end
				current = s.parent
			end
			return nil
		end,
	},
	events = {
		ChildAdded = true,
		ChildRemoved = true,
		DescendantAdded = true,
		DescendantRemoving = true,
		AncestryChanged = true,
		Changed = true,
		Destroying = { immediate = true },
		AttributeChanged = true,
	},
})

Instances.NIL = NIL

return Instances

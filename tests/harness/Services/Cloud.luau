--[[
	Cloud services backed by world-level stores shared by every simulated server:
	DataStoreService, MessagingService, MemoryStoreService, MarketplaceService,
	AnalyticsService.

	Failure injection: world.cloud:failNext(service, count, filter?) makes the
	next matching calls throw the same kind of error Roblox returns.
]]

local roblox = require("@lune/roblox")
local Instances = require("../Instances")
local Serialize = require("../Serialize")
local Registry = require("../Registry")

local states = Instances.state
local Enum = roblox.Enum

local Cloud = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function ctxOf(st)
	return st.server.scheduler:currentCtx()
end

local function requireServer(st, method)
	local ctx = ctxOf(st)
	if ctx and ctx.kind == "client" then
		error(method .. " can only be called from the server", 3)
	end
end

--------------------------------------------------------------------------------
-- Backend (one per world)
--------------------------------------------------------------------------------

function Cloud.newBackend(scheduler)
	local backend = {
		scheduler = scheduler,
		latency = 0.05,
		stores = {}, -- [storeKey][key] = entry
		ordered = {}, -- [storeKey][key] = integer
		failures = {}, -- { service, remaining, message, filter }
		calls = {}, -- log of { service, method, store, key }
		budget = 120,
		topics = {}, -- [topic] = { subscriptions }
		published = {},
		maps = {}, -- [mapName][key] = { value, expiresAt, sortKey }
		passes = {}, -- [userId][passId] = true
		subscriptions = {}, -- [userId][subscriptionId] = { IsSubscribed, IsRenewing }
		prompts = {},
		autoBuy = false,
		purchaseCounter = 0,
		pendingReceipts = {}, -- [userId] = { receipt }
		receiptLog = {},
		productPrices = {},
		analytics = {},
	}

	function backend:failNext(service, count, filter, message)
		table.insert(self.failures, {
			service = service,
			remaining = count or 1,
			filter = filter,
			message = message,
		})
	end

	function backend:clearFailures()
		table.clear(self.failures)
	end

	function backend:check(service, method, storeName, key)
		table.insert(self.calls, { service = service, method = method, store = storeName, key = key })
		for index, failure in self.failures do
			if failure.service == service and (failure.filter == nil or failure.filter(method, storeName, key)) then
				failure.remaining -= 1
				if failure.remaining <= 0 then
					table.remove(self.failures, index)
				end
				local message = failure.message
				if not message then
					if service == "DataStore" then
						message = "502: API Services rejected request with error. HTTP 500 (Internal Server Error)"
					elseif service == "Messaging" then
						message = "MessagingService: request failed (ServiceUnavailable)"
					elseif service == "MemoryStore" then
						message = "Code: InternalError, Error: The request failed"
					else
						message = service .. ": request failed"
					end
				end
				error(message, 0)
			end
		end
	end

	function backend:rawGet(storeName, key, scope)
		local store = self.stores[storeName .. "/" .. (scope or "global")]
		local entry = store and store[key]
		return entry and deepCopy(entry.value) or nil
	end

	function backend:rawSet(storeName, key, value, scope)
		local storeKey = storeName .. "/" .. (scope or "global")
		self.stores[storeKey] = self.stores[storeKey] or {}
		local now = math.floor(self.scheduler:time() * 1000)
		self.stores[storeKey][key] = {
			value = deepCopy(value),
			version = 1,
			created = now,
			updated = now,
			userIds = {},
			metadata = {},
		}
	end

	function backend:callCount(service, method)
		local n = 0
		for _, call in self.calls do
			if call.service == service and (method == nil or call.method == method) then
				n += 1
			end
		end
		return n
	end

	function backend:grantPass(userId, passId)
		self.passes[userId] = self.passes[userId] or {}
		self.passes[userId][passId] = true
	end

	function backend:setSubscription(userId, subscriptionId, subscribed)
		self.subscriptions[userId] = self.subscriptions[userId] or {}
		self.subscriptions[userId][subscriptionId] = { IsSubscribed = subscribed, IsRenewing = subscribed }
	end

	function backend:analyticsOf(userId, method)
		local result = {}
		for _, entry in self.analytics do
			if (userId == nil or entry.userId == userId) and (method == nil or entry.method == method) then
				table.insert(result, entry)
			end
		end
		return result
	end

	return backend
end

--------------------------------------------------------------------------------
-- DataStoreService
--------------------------------------------------------------------------------

local function validateKey(key)
	if type(key) ~= "string" or #key == 0 then
		error("Argument 1 missing or nil", 3)
	end
	if #key > 50 then
		error("101: Key name exceeds the 50 character limit.", 3)
	end
end

local function makeKeyInfo(server, entry)
	local proxy, st = Instances.create(server, "DataStoreKeyInfo", nil, { internal = true })
	st.extra.entry = {
		version = entry.version,
		created = entry.created,
		updated = entry.updated,
		userIds = deepCopy(entry.userIds),
		metadata = deepCopy(entry.metadata),
	}
	return proxy
end

Instances.define("DataStoreKeyInfo", {
	props = {
		Version = {
			get = function(_, st)
				return string.format("%016d.%010d.%016d.01", 0, st.extra.entry.version, 0)
			end,
			readOnly = true,
		},
		CreatedTime = {
			get = function(_, st)
				return st.extra.entry.created
			end,
			readOnly = true,
		},
		UpdatedTime = {
			get = function(_, st)
				return st.extra.entry.updated
			end,
			readOnly = true,
		},
	},
	methods = {
		GetUserIds = function(self)
			return deepCopy(states(self).extra.entry.userIds)
		end,
		GetMetadata = function(self)
			return deepCopy(states(self).extra.entry.metadata)
		end,
	},
})

local function storeOf(st)
	local backend = st.server.world.cloud
	local key = st.extra.storeKey
	backend.stores[key] = backend.stores[key] or {}
	return backend.stores[key], backend
end

local function writeEntry(st, store, key, value, userIds, metadata)
	local copy = Serialize.datastore(value, key)
	if Serialize.size(copy) > 4194304 then
		error("105: Serialized value exceeds 4MB limit.", 3)
	end
	local now = math.floor(st.server.scheduler:time() * 1000)
	local entry = store[key]
	if entry then
		entry.value = copy
		entry.version += 1
		entry.updated = now
		entry.userIds = deepCopy(userIds or entry.userIds)
		entry.metadata = deepCopy(metadata or entry.metadata)
	else
		entry = {
			value = copy,
			version = 1,
			created = now,
			updated = now,
			userIds = deepCopy(userIds or {}),
			metadata = deepCopy(metadata or {}),
		}
		store[key] = entry
	end
	return entry
end

local function callTransform(transform, ...)
	-- UpdateAsync transforms must not yield (Roblox errors if they do).
	local thread = coroutine.create(transform)
	local results = table.pack(coroutine.resume(thread, ...))
	if not results[1] then
		error(results[2], 0)
	end
	if coroutine.status(thread) ~= "dead" then
		error("UpdateAsync: transform function yielded, which is not allowed", 0)
	end
	return table.unpack(results, 2, results.n)
end

Instances.define("GlobalDataStore", {
	methods = {
		GetAsync = function(self, key)
			local st = states(self)
			requireServer(st, "GetAsync")
			validateKey(key)
			local store, backend = storeOf(st)
			backend:check("DataStore", "GetAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			local entry = store[key]
			if not entry then
				return nil, nil
			end
			return deepCopy(entry.value), makeKeyInfo(st.server, entry)
		end,
		SetAsync = function(self, key, value, userIds)
			local st = states(self)
			requireServer(st, "SetAsync")
			validateKey(key)
			local store, backend = storeOf(st)
			backend:check("DataStore", "SetAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			local entry = writeEntry(st, store, key, value, userIds, nil)
			return string.format("%016d.%010d.%016d.01", 0, entry.version, 0)
		end,
		UpdateAsync = function(self, key, transform)
			local st = states(self)
			requireServer(st, "UpdateAsync")
			validateKey(key)
			local store, backend = storeOf(st)
			backend:check("DataStore", "UpdateAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			local entry = store[key]
			local current = entry and deepCopy(entry.value) or nil
			local keyInfo = entry and makeKeyInfo(st.server, entry) or nil
			local newValue, userIds, metadata = callTransform(transform, current, keyInfo)
			if newValue == nil then
				return nil, nil
			end
			entry = writeEntry(st, store, key, newValue, userIds, metadata)
			return deepCopy(entry.value), makeKeyInfo(st.server, entry)
		end,
		IncrementAsync = function(self, key, delta)
			local st = states(self)
			requireServer(st, "IncrementAsync")
			validateKey(key)
			local store, backend = storeOf(st)
			backend:check("DataStore", "IncrementAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			local entry = store[key]
			local current = entry and entry.value or 0
			if type(current) ~= "number" then
				error("IncrementAsync: value is not a number", 2)
			end
			entry = writeEntry(st, store, key, math.floor(current + (delta or 1)), nil, nil)
			return entry.value, makeKeyInfo(st.server, entry)
		end,
		RemoveAsync = function(self, key)
			local st = states(self)
			requireServer(st, "RemoveAsync")
			validateKey(key)
			local store, backend = storeOf(st)
			backend:check("DataStore", "RemoveAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			local entry = store[key]
			store[key] = nil
			if entry then
				return deepCopy(entry.value), makeKeyInfo(st.server, entry)
			end
			return nil, nil
		end,
	},
})

Instances.define("DataStore", {
	methods = {
		GetVersionAsync = function(self, key)
			local st = states(self)
			local store = storeOf(st)
			local entry = store[key]
			if not entry then
				return nil, nil
			end
			return deepCopy(entry.value), makeKeyInfo(st.server, entry)
		end,
		ListVersionsAsync = function(self)
			local st = states(self)
			return Cloud.pages(st.server, {})
		end,
	},
})

function Cloud.pages(server, entries, pageSize)
	local proxy, st = Instances.create(server, "DataStorePages", nil, { internal = true })
	st.extra.entries = entries
	st.extra.pageSize = pageSize or math.max(#entries, 1)
	st.extra.offset = 0
	return proxy
end

Instances.define("Pages", {
	props = {
		IsFinished = {
			get = function(_, st)
				return st.extra.offset + st.extra.pageSize >= #st.extra.entries
			end,
			readOnly = true,
		},
	},
	methods = {
		GetCurrentPage = function(self)
			local st = states(self)
			local page = {}
			for index = st.extra.offset + 1, math.min(st.extra.offset + st.extra.pageSize, #st.extra.entries) do
				table.insert(page, deepCopy(st.extra.entries[index]))
			end
			return page
		end,
		AdvanceToNextPageAsync = function(self)
			local st = states(self)
			st.server.scheduler:wait(0.05)
			st.extra.offset += st.extra.pageSize
		end,
	},
})

local function orderedOf(st)
	local backend = st.server.world.cloud
	local key = st.extra.storeKey
	backend.ordered[key] = backend.ordered[key] or {}
	return backend.ordered[key], backend
end

local function validateOrderedValue(value)
	if type(value) ~= "number" or value % 1 ~= 0 or value ~= value then
		error("OrderedDataStore values must be integers", 3)
	end
end

Instances.define("OrderedDataStore", {
	methods = {
		GetAsync = function(self, key)
			local st = states(self)
			validateKey(key)
			local store, backend = orderedOf(st)
			backend:check("DataStore", "OrderedGetAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			return store[key]
		end,
		SetAsync = function(self, key, value)
			local st = states(self)
			requireServer(st, "SetAsync")
			validateKey(key)
			validateOrderedValue(value)
			local store, backend = orderedOf(st)
			backend:check("DataStore", "OrderedSetAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			store[key] = value
			return ""
		end,
		IncrementAsync = function(self, key, delta)
			local st = states(self)
			validateKey(key)
			local store, backend = orderedOf(st)
			backend:check("DataStore", "OrderedIncrementAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			store[key] = (store[key] or 0) + math.floor(delta or 1)
			return store[key]
		end,
		UpdateAsync = function(self, key, transform)
			local st = states(self)
			validateKey(key)
			local store, backend = orderedOf(st)
			backend:check("DataStore", "OrderedUpdateAsync", st.extra.storeKey, key)
			st.server.scheduler:wait(backend.latency)
			local value = callTransform(transform, store[key])
			if value == nil then
				return nil
			end
			validateOrderedValue(value)
			store[key] = value
			return value
		end,
		RemoveAsync = function(self, key)
			local st = states(self)
			local store = orderedOf(st)
			local old = store[key]
			store[key] = nil
			return old
		end,
		GetSortedAsync = function(self, ascending, pageSize, minValue, maxValue)
			local st = states(self)
			local store, backend = orderedOf(st)
			backend:check("DataStore", "GetSortedAsync", st.extra.storeKey, nil)
			if type(pageSize) ~= "number" or pageSize < 1 or pageSize > 100 then
				error("GetSortedAsync: pageSize must be between 1 and 100", 2)
			end
			st.server.scheduler:wait(backend.latency)
			local entries = {}
			for key, value in store do
				if (minValue == nil or value >= minValue) and (maxValue == nil or value <= maxValue) then
					table.insert(entries, { key = key, value = value })
				end
			end
			table.sort(entries, function(a, b)
				if a.value == b.value then
					return a.key < b.key
				end
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			return Cloud.pages(st.server, entries, pageSize)
		end,
	},
})

Instances.define("DataStoreService", {
	methods = {
		GetDataStore = function(self, name, scope)
			local st = states(self)
			requireServer(st, "GetDataStore")
			if type(name) ~= "string" or #name == 0 or #name > 50 then
				error("DataStore name must be 1-50 characters", 2)
			end
			local storeKey = name .. "/" .. (scope or "global")
			st.extra.cache = st.extra.cache or {}
			local existing = st.extra.cache[storeKey]
			if existing then
				return existing
			end
			local proxy, ds = Instances.create(st.server, "DataStore", nil, { internal = true })
			ds.name = name
			ds.extra.storeKey = storeKey
			st.extra.cache[storeKey] = proxy
			return proxy
		end,
		GetGlobalDataStore = function(self)
			return self:GetDataStore("__global")
		end,
		GetOrderedDataStore = function(self, name, scope)
			local st = states(self)
			requireServer(st, "GetOrderedDataStore")
			local storeKey = "ordered:" .. name .. "/" .. (scope or "global")
			st.extra.ordered = st.extra.ordered or {}
			local existing = st.extra.ordered[storeKey]
			if existing then
				return existing
			end
			local proxy, ds = Instances.create(st.server, "OrderedDataStore", nil, { internal = true })
			ds.name = name
			ds.extra.storeKey = storeKey
			st.extra.ordered[storeKey] = proxy
			return proxy
		end,
		GetRequestBudgetForRequestType = function(self)
			return states(self).server.world.cloud.budget
		end,
	},
})

--------------------------------------------------------------------------------
-- MessagingService
--------------------------------------------------------------------------------

Instances.define("MessagingService", {
	methods = {
		SubscribeAsync = function(self, topic, callback)
			local st = states(self)
			requireServer(st, "SubscribeAsync")
			local backend = st.server.world.cloud
			if type(topic) ~= "string" or #topic == 0 or #topic > 80 then
				error("MessagingService: topic must be 1-80 characters", 2)
			end
			backend:check("Messaging", "SubscribeAsync", topic, nil)
			st.server.scheduler:wait(backend.latency)
			backend.topics[topic] = backend.topics[topic] or {}
			local subscription = {
				server = st.server,
				ctx = ctxOf(st),
				fn = callback,
				connected = true,
			}
			table.insert(backend.topics[topic], subscription)
			return Registry.proxy("RBXScriptConnection", function(mt)
				mt.__index = function(_, key)
					if key == "Connected" then
						return subscription.connected
					elseif key == "Disconnect" then
						return function()
							subscription.connected = false
						end
					end
					error(tostring(key) .. " is not a valid member of RBXScriptConnection", 2)
				end
			end)
		end,
		PublishAsync = function(self, topic, message)
			local st = states(self)
			requireServer(st, "PublishAsync")
			local backend = st.server.world.cloud
			local copy = Serialize.remote(message, "message")
			if Serialize.size(copy) > 1024 then
				error("MessagingService: message exceeds the 1kB limit", 2)
			end
			backend:check("Messaging", "PublishAsync", topic, nil)
			st.server.scheduler:wait(backend.latency)
			table.insert(backend.published, { topic = topic, data = deepCopy(copy), from = st.server.jobId })
			local sent = st.server.scheduler:time()
			for _, subscription in backend.topics[topic] or {} do
				if subscription.connected and not subscription.server.closed then
					subscription.server.scheduler:deferIn(
						subscription.ctx,
						subscription.fn,
						table.pack({ Data = deepCopy(copy), Sent = sent })
					)
				end
			end
		end,
	},
})

--------------------------------------------------------------------------------
-- MemoryStoreService (sorted maps)
--------------------------------------------------------------------------------

local MAX_EXPIRATION = 3888000

local function mapOf(st)
	local backend = st.server.world.cloud
	backend.maps[st.extra.mapName] = backend.maps[st.extra.mapName] or {}
	return backend.maps[st.extra.mapName], backend
end

local function liveEntry(st, map, key)
	local entry = map[key]
	if entry and entry.expiresAt <= st.server.scheduler:time() then
		map[key] = nil
		return nil
	end
	return entry
end

local function validateExpiration(expiration)
	if type(expiration) ~= "number" or expiration <= 0 or expiration > MAX_EXPIRATION then
		error("MemoryStore: expiration must be between 0 and 3,888,000 seconds", 3)
	end
end

Instances.define("MemoryStoreSortedMap", {
	methods = {
		GetAsync = function(self, key)
			local st = states(self)
			local map, backend = mapOf(st)
			backend:check("MemoryStore", "GetAsync", st.extra.mapName, key)
			st.server.scheduler:wait(backend.latency)
			local entry = liveEntry(st, map, key)
			if not entry then
				return nil
			end
			return deepCopy(entry.value), entry.sortKey
		end,
		SetAsync = function(self, key, value, expiration, sortKey)
			local st = states(self)
			validateExpiration(expiration)
			local map, backend = mapOf(st)
			backend:check("MemoryStore", "SetAsync", st.extra.mapName, key)
			st.server.scheduler:wait(backend.latency)
			local isNew = liveEntry(st, map, key) == nil
			map[key] = {
				value = Serialize.datastore(value, key),
				expiresAt = st.server.scheduler:time() + expiration,
				sortKey = sortKey,
			}
			return isNew
		end,
		UpdateAsync = function(self, key, transform, expiration)
			local st = states(self)
			validateExpiration(expiration)
			local map, backend = mapOf(st)
			backend:check("MemoryStore", "UpdateAsync", st.extra.mapName, key)
			st.server.scheduler:wait(backend.latency)
			local entry = liveEntry(st, map, key)
			local newValue, newSortKey = callTransform(transform, entry and deepCopy(entry.value) or nil, entry and entry.sortKey)
			if newValue == nil then
				return nil
			end
			map[key] = {
				value = Serialize.datastore(newValue, key),
				expiresAt = st.server.scheduler:time() + expiration,
				sortKey = newSortKey,
			}
			return deepCopy(newValue)
		end,
		RemoveAsync = function(self, key)
			local st = states(self)
			local map, backend = mapOf(st)
			backend:check("MemoryStore", "RemoveAsync", st.extra.mapName, key)
			st.server.scheduler:wait(backend.latency)
			map[key] = nil
		end,
		GetRangeAsync = function(self, direction, count)
			local st = states(self)
			local map, backend = mapOf(st)
			backend:check("MemoryStore", "GetRangeAsync", st.extra.mapName, nil)
			st.server.scheduler:wait(backend.latency)
			local entries = {}
			for key in map do
				local entry = liveEntry(st, map, key)
				if entry then
					table.insert(entries, { key = key, value = deepCopy(entry.value), sortKey = entry.sortKey })
				end
			end
			table.sort(entries, function(a, b)
				return a.key < b.key
			end)
			if tostring(direction) == "Enum.SortDirection.Descending" then
				local reversed = {}
				for index = #entries, 1, -1 do
					table.insert(reversed, entries[index])
				end
				entries = reversed
			end
			local result = {}
			for index = 1, math.min(count, #entries) do
				result[index] = entries[index]
			end
			return result
		end,
	},
})

Instances.define("MemoryStoreService", {
	methods = {
		GetSortedMap = function(self, name)
			local st = states(self)
			requireServer(st, "GetSortedMap")
			local proxy, map = Instances.create(st.server, "MemoryStoreSortedMap", nil, { internal = true })
			map.extra.mapName = name
			return proxy
		end,
	},
})

--------------------------------------------------------------------------------
-- MarketplaceService
--------------------------------------------------------------------------------

local function fireOnServerAndClient(st, eventName, clientCtx, ...)
	Instances.fire(st, eventName, function(ctx)
		return ctx == nil or ctx.kind == "server" or ctx == clientCtx
	end, ...)
end

function Cloud.processReceipt(server, receipt)
	local backend = server.world.cloud
	local market = server.services.MarketplaceService
	local marketState = states(market)
	local callback = marketState.extra.processReceipt
	if not callback then
		return nil
	end
	local result
	local done = false
	server.scheduler:spawnIn(server.serverCtx, function()
		local ok, decision = pcall(callback, deepCopy(receipt))
		if not ok then
			server.log("error", server.serverCtx, "ProcessReceipt errored: " .. tostring(decision))
			decision = nil
		end
		result = decision
		done = true
		table.insert(backend.receiptLog, { receipt = receipt, decision = decision, jobId = server.jobId })
		local pending = backend.pendingReceipts[receipt.PlayerId] or {}
		if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
			for index, entry in pending do
				if entry.PurchaseId == receipt.PurchaseId then
					table.remove(pending, index)
					break
				end
			end
		else
			local present = false
			for _, entry in pending do
				if entry.PurchaseId == receipt.PurchaseId then
					present = true
				end
			end
			if not present then
				table.insert(pending, receipt)
			end
			backend.pendingReceipts[receipt.PlayerId] = pending
		end
	end)
	return function()
		return done, result
	end
end

Instances.define("MarketplaceService", {
	props = {
		ProcessReceipt = {
			get = function()
				error("ProcessReceipt is a callback member of MarketplaceService; you can only set the callback value, get is not available", 3)
			end,
			set = function(_, st, value)
				local ctx = ctxOf(st)
				if ctx and ctx.kind == "client" then
					error("ProcessReceipt can only be set on the server", 3)
				end
				st.extra.processReceipt = value
			end,
		},
	},
	methods = {
		UserOwnsGamePassAsync = function(self, userId, passId)
			local st = states(self)
			local backend = st.server.world.cloud
			backend:check("Marketplace", "UserOwnsGamePassAsync", nil, userId)
			st.server.scheduler:wait(backend.latency)
			local owned = backend.passes[userId]
			return owned ~= nil and owned[passId] == true
		end,
		PromptGamePassPurchase = function(self, player, passId)
			local st = states(self)
			local backend = st.server.world.cloud
			local clientCtx = st.server.clientCtxFor(player)
			table.insert(backend.prompts, { kind = "GamePass", userId = states(player).extra.userId, id = passId })
			if backend.autoBuy and clientCtx then
				backend:grantPass(states(player).extra.userId, passId)
				fireOnServerAndClient(st, "PromptGamePassPurchaseFinished", clientCtx, player, passId, true)
			end
		end,
		PromptProductPurchase = function(self, player, productId)
			local st = states(self)
			local backend = st.server.world.cloud
			local userId = states(player).extra.userId
			table.insert(backend.prompts, { kind = "Product", userId = userId, id = productId })
			if backend.autoBuy then
				st.server.world:buyProduct(st.server, player, productId)
			end
		end,
		PromptSubscriptionPurchase = function(self, player, subscriptionId)
			local st = states(self)
			table.insert(
				st.server.world.cloud.prompts,
				{ kind = "Subscription", userId = states(player).extra.userId, id = subscriptionId }
			)
		end,
		PromptPurchase = function(self, player, assetId)
			local st = states(self)
			table.insert(st.server.world.cloud.prompts, { kind = "Asset", userId = states(player).extra.userId, id = assetId })
		end,
		GetUserSubscriptionStatusAsync = function(self, player, subscriptionId)
			local st = states(self)
			requireServer(st, "GetUserSubscriptionStatusAsync")
			local backend = st.server.world.cloud
			st.server.scheduler:wait(backend.latency)
			local userSubs = backend.subscriptions[states(player).extra.userId]
			local status = userSubs and userSubs[subscriptionId]
			return deepCopy(status or { IsSubscribed = false, IsRenewing = false })
		end,
		GetProductInfo = function(self, assetId)
			local st = states(self)
			st.server.scheduler:wait(0.05)
			return {
				Name = "Product " .. tostring(assetId),
				PriceInRobux = st.server.world.cloud.productPrices[assetId] or 100,
				IsForSale = true,
				ProductId = assetId,
			}
		end,
		PlayerOwnsAsset = function()
			return false
		end,
	},
	events = {
		PromptProductPurchaseFinished = true,
		PromptGamePassPurchaseFinished = true,
		PromptPurchaseFinished = true,
		PromptSubscriptionPurchaseFinished = true,
	},
})

--------------------------------------------------------------------------------
-- AnalyticsService
--------------------------------------------------------------------------------

local function validateCustomFields(fields)
	if fields == nil then
		return
	end
	if type(fields) ~= "table" then
		error("AnalyticsService: customFields must be a table", 3)
	end
	local count = 0
	for key, value in fields do
		count += 1
		if type(key) ~= "string" or not string.match(key, "^CustomField0[123]$") then
			error("AnalyticsService: custom field keys must be Enum.AnalyticsCustomFieldKeys names, got " .. tostring(key), 3)
		end
		if type(value) ~= "string" then
			error("AnalyticsService: custom field values must be strings", 3)
		end
	end
	if count > 3 then
		error("AnalyticsService: at most 3 custom fields", 3)
	end
end

local function analyticsPlayer(player)
	local st = states(player)
	if not st or st.className ~= "Player" then
		error("AnalyticsService: player argument must be a Player", 3)
	end
	return st.extra.userId
end

local function record(st, method, player, data)
	requireServer(st, method)
	local userId = analyticsPlayer(player)
	data.method = method
	data.userId = userId
	table.insert(st.server.world.cloud.analytics, data)
end

Instances.define("AnalyticsService", {
	methods = {
		LogCustomEvent = function(self, player, eventName, value, customFields)
			assert(type(eventName) == "string" and #eventName > 0 and #eventName <= 50, "LogCustomEvent: invalid eventName")
			assert(value == nil or type(value) == "number", "LogCustomEvent: value must be a number")
			validateCustomFields(customFields)
			record(states(self), "LogCustomEvent", player, { eventName = eventName, value = value, fields = customFields })
		end,
		LogEconomyEvent = function(self, player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields)
			assert(typeof(flowType) == "EnumItem", "LogEconomyEvent: flowType must be Enum.AnalyticsEconomyFlowType")
			assert(type(currencyType) == "string" and #currencyType > 0, "LogEconomyEvent: invalid currencyType")
			assert(type(amount) == "number" and amount > 0, "LogEconomyEvent: amount must be positive")
			assert(type(endingBalance) == "number" and endingBalance >= 0, "LogEconomyEvent: invalid endingBalance")
			assert(type(transactionType) == "string" and #transactionType > 0, "LogEconomyEvent: invalid transactionType")
			assert(itemSku == nil or type(itemSku) == "string", "LogEconomyEvent: itemSku must be a string")
			validateCustomFields(customFields)
			record(states(self), "LogEconomyEvent", player, {
				flowType = tostring(flowType),
				currency = currencyType,
				amount = amount,
				balance = endingBalance,
				transaction = transactionType,
				sku = itemSku,
				fields = customFields,
			})
		end,
		LogOnboardingFunnelStepEvent = function(self, player, step, stepName, customFields)
			assert(type(step) == "number" and step >= 1 and step % 1 == 0, "LogOnboardingFunnelStepEvent: invalid step")
			validateCustomFields(customFields)
			record(states(self), "LogOnboardingFunnelStepEvent", player, { step = step, stepName = stepName })
		end,
		LogFunnelStepEvent = function(self, player, funnelName, sessionId, step, stepName, customFields)
			assert(type(funnelName) == "string" and #funnelName > 0, "LogFunnelStepEvent: invalid funnelName")
			validateCustomFields(customFields)
			record(states(self), "LogFunnelStepEvent", player, { funnel = funnelName, session = sessionId, step = step, stepName = stepName })
		end,
		LogProgressionEvent = function(self, player, path, status, level, levelName, customFields)
			assert(type(path) == "string" and #path > 0, "LogProgressionEvent: invalid path")
			assert(typeof(status) == "EnumItem", "LogProgressionEvent: status must be Enum.AnalyticsProgressionType")
			assert(type(level) == "number", "LogProgressionEvent: level must be a number")
			validateCustomFields(customFields)
			record(states(self), "LogProgressionEvent", player, { path = path, status = tostring(status), level = level, levelName = levelName })
		end,
		LogProgressionCompleteEvent = function(self, player, path, level, levelName, customFields)
			validateCustomFields(customFields)
			record(states(self), "LogProgressionCompleteEvent", player, { path = path, level = level, levelName = levelName })
		end,
		LogProgressionStartEvent = function(self, player, path, level, levelName, customFields)
			validateCustomFields(customFields)
			record(states(self), "LogProgressionStartEvent", player, { path = path, level = level, levelName = levelName })
		end,
		LogProgressionFailEvent = function(self, player, path, level, levelName, customFields)
			validateCustomFields(customFields)
			record(states(self), "LogProgressionFailEvent", player, { path = path, level = level, levelName = levelName })
		end,
	},
})

return Cloud

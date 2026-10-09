--[[
	Core engine services: DataModel, RunService, CollectionService, TweenService,
	HttpService, UserInputService, ContextActionService, ProximityPromptService,
	SocialService, PolicyService, LocalizationService, BadgeService,
	TextChatService, StarterGui, GuiService, SoundService, Debris, PhysicsService,
	ContentProvider, VRService, TeleportService.
]]

local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Instances = require("../Instances")
local RbxSignal = require("../RbxSignal")
local Serialize = require("../Serialize")
local Datatypes = require("../Datatypes")

local states = Instances.state
local Enum = roblox.Enum
local Vector2 = roblox.Vector2

local function ctxOf(st)
	return st.server.scheduler:currentCtx()
end

local function isClient(ctx)
	return ctx ~= nil and ctx.kind == "client"
end

local function requireServer(st, method)
	if isClient(ctxOf(st)) then
		error(method .. " can only be called from the server", 3)
	end
end

local function requireClient(st, method)
	if not isClient(ctxOf(st)) then
		error(method .. " can only be called from a LocalScript", 3)
	end
end

Instances.define("DataModel", {
	props = {
		PlaceId = {
			get = function(_, st)
				return st.server.placeId
			end,
			readOnly = true,
		},
		GameId = {
			get = function(_, st)
				return st.server.gameId
			end,
			readOnly = true,
		},
		JobId = {
			get = function(_, st)
				return st.server.jobId
			end,
			readOnly = true,
		},
		PlaceVersion = {
			get = function()
				return 1
			end,
			readOnly = true,
		},
		CreatorId = {
			get = function()
				return 1
			end,
			readOnly = true,
		},
		Workspace = {
			get = function(_, st)
				return st.server.services.Workspace
			end,
			readOnly = true,
		},
	},
	methods = {
		GetService = function(self, name)
			local st = states(self)
			return st.server.getService(name, true)
		end,
		FindService = function(self, name)
			local st = states(self)
			return st.server.getService(name, false)
		end,
		BindToClose = function(self, fn)
			local st = states(self)
			requireServer(st, "BindToClose")
			table.insert(st.server.closeCallbacks, { fn = fn, ctx = ctxOf(st) })
		end,
		IsLoaded = function()
			return true
		end,
	},
	events = { Loaded = true, Close = true },
})

local function inDataModel(st)
	return Instances.inDataModel(st)
end

Instances.define("RunService", {
	methods = {
		IsServer = function(self)
			return not isClient(ctxOf(states(self)))
		end,
		IsClient = function(self)
			return isClient(ctxOf(states(self)))
		end,
		IsStudio = function(self)
			return states(self).server.isStudio
		end,
		IsRunning = function()
			return true
		end,
		IsRunMode = function()
			return false
		end,
		IsEdit = function()
			return false
		end,
		BindToRenderStep = function(self, name, priority, fn)
			local st = states(self)
			requireClient(st, "BindToRenderStep")
			local ctx = ctxOf(st)
			ctx.renderSteps[name] = { priority = priority, fn = fn }
		end,
		UnbindFromRenderStep = function(self, name)
			local st = states(self)
			local ctx = ctxOf(st)
			if ctx and ctx.renderSteps then
				ctx.renderSteps[name] = nil
			end
		end,
	},
	events = {
		Heartbeat = true,
		Stepped = true,
		RenderStepped = true,
		PreSimulation = true,
		PostSimulation = true,
		PreRender = true,
		PreAnimation = true,
	},
})

Instances.define("CollectionService", {
	methods = {
		GetTagged = function(self, tag)
			local st = states(self)
			local ctx = ctxOf(st)
			local result = {}
			for _, tagged in st.server.tagged[tag] or {} do
				if not tagged.destroyed and inDataModel(tagged) and Instances.visible(tagged, ctx) then
					table.insert(result, tagged.proxy)
				end
			end
			return result
		end,
		GetInstanceAddedSignal = function(self, tag)
			return states(self).server.tagSignal(tag, "added").proxy
		end,
		GetInstanceRemovedSignal = function(self, tag)
			return states(self).server.tagSignal(tag, "removed").proxy
		end,
		AddTag = function(self, instance, tag)
			states(self).server.addTag(states(instance), tag)
		end,
		RemoveTag = function(self, instance, tag)
			states(self).server.removeTag(states(instance), tag)
		end,
		HasTag = function(_, instance, tag)
			return states(instance).tags[tag] == true
		end,
		GetTags = function(_, instance)
			return instance:GetTags()
		end,
		GetAllTags = function(self)
			local result = {}
			for tag in states(self).server.tagged do
				table.insert(result, tag)
			end
			return result
		end,
	},
})

local EASINGS = {}
EASINGS.Linear = function(t)
	return t
end
EASINGS.Quad = function(t)
	return t * t
end
EASINGS.Cubic = function(t)
	return t * t * t
end
EASINGS.Sine = function(t)
	return 1 - math.cos(t * math.pi / 2)
end

Instances.define("TweenService", {
	methods = {
		Create = function(self, instance, tweenInfo, goals)
			local st = states(self)
			local targetState = states(instance)
			if not targetState then
				error("TweenService:Create: instance expected", 2)
			end
			if Datatypes.typeName(tweenInfo) ~= "TweenInfo" then
				error("TweenService:Create: TweenInfo expected", 2)
			end
			if type(goals) ~= "table" then
				error("TweenService:Create: property table expected", 2)
			end
			for property, value in goals do
				local member = targetState.members[property]
				if not member or member.kind ~= "prop" then
					error(string.format("TweenService:Create property named '%s' cannot be tweened due to type mismatch (property is a 'nil', but given type is '%s')", tostring(property), typeof(value)), 2)
				end
				local kind = typeof(value)
				if kind ~= "number" and kind ~= "Vector3" and kind ~= "Vector2" and kind ~= "CFrame" and kind ~= "Color3" and kind ~= "UDim2" and kind ~= "UDim" and kind ~= "Rect" and kind ~= "boolean" and kind ~= "EnumItem" then
					error("TweenService:Create: property " .. property .. " of type " .. kind .. " cannot be tweened", 2)
				end
			end
			local tween, tweenState = Instances.create(st.server, "Tween", ctxOf(st), { internal = true })
			tweenState.extra.target = instance
			tweenState.extra.info = Datatypes.tweenInfoFields(tweenInfo)
			tweenState.extra.goals = table.clone(goals)
			tweenState.extra.ctx = ctxOf(st)
			return tween
		end,
		GetValue = function(_, alpha, style)
			local name = string.match(tostring(style), "%.(%w+)$") or "Linear"
			local easing = EASINGS[name] or EASINGS.Linear
			return easing(math.clamp(alpha, 0, 1))
		end,
	},
})

local guidCounter = 0

Instances.define("HttpService", {
	methods = {
		GenerateGUID = function(self, wrap)
			guidCounter += 1
			local hex = string.format("%08x-%04x-4%03x-a%03x-%012x", guidCounter * 2654435761 % 4294967296, guidCounter % 65536, guidCounter % 4096, (guidCounter * 7) % 4096, guidCounter)
			hex = string.upper(hex)
			if wrap == false then
				return hex
			end
			return "{" .. hex .. "}"
		end,
		JSONEncode = function(_, value)
			local copy = Serialize.datastore(value, "JSONEncode")
			return serde.encode("json", copy)
		end,
		JSONDecode = function(_, text)
			if type(text) ~= "string" then
				error("Can't parse JSON", 2)
			end
			local ok, result = pcall(serde.decode, "json", text)
			if not ok then
				error("Can't parse JSON", 2)
			end
			return result
		end,
		UrlEncode = function(_, text)
			return (string.gsub(text, "[^%w%-_%.~]", function(char)
				return string.format("%%%02X", string.byte(char))
			end))
		end,
		GetAsync = function()
			error("Http requests are not enabled. Enable via game settings", 2)
		end,
		PostAsync = function()
			error("Http requests are not enabled. Enable via game settings", 2)
		end,
		RequestAsync = function()
			error("Http requests are not enabled. Enable via game settings", 2)
		end,
	},
})

local function device(ctx)
	return (ctx and ctx.device) or "Desktop"
end

Instances.define("UserInputService", {
	props = {
		TouchEnabled = {
			get = function(_, _, ctx)
				local kind = device(ctx)
				return kind == "Mobile" or kind == "Tablet"
			end,
			readOnly = true,
		},
		KeyboardEnabled = {
			get = function(_, _, ctx)
				return device(ctx) == "Desktop"
			end,
			readOnly = true,
		},
		MouseEnabled = {
			get = function(_, _, ctx)
				return device(ctx) == "Desktop"
			end,
			readOnly = true,
		},
		GamepadEnabled = {
			get = function(_, _, ctx)
				return device(ctx) == "Console"
			end,
			readOnly = true,
		},
		VREnabled = {
			get = function(_, _, ctx)
				return device(ctx) == "VR"
			end,
			readOnly = true,
		},
		PreferredInput = {
			get = function(_, _, ctx)
				local kind = device(ctx)
				if kind == "Mobile" or kind == "Tablet" then
					return Enum.PreferredInput.Touch
				elseif kind == "Console" then
					return Enum.PreferredInput.Gamepad
				end
				return Enum.PreferredInput.KeyboardAndMouse
			end,
			readOnly = true,
		},
	},
	methods = {
		GetLastInputType = function(self)
			local ctx = ctxOf(states(self))
			local kind = device(ctx)
			if kind == "Mobile" or kind == "Tablet" then
				return Enum.UserInputType.Touch
			elseif kind == "Console" then
				return Enum.UserInputType.Gamepad1
			end
			return Enum.UserInputType.MouseButton1
		end,
		IsKeyDown = function(self, keyCode)
			local ctx = ctxOf(states(self))
			return ctx and ctx.keysDown and ctx.keysDown[keyCode] == true or false
		end,
		GetFocusedTextBox = function()
			return nil
		end,
		GetMouseLocation = function()
			return Vector2.new(640, 360)
		end,
		GetKeysPressed = function()
			return {}
		end,
	},
	events = {
		InputBegan = true,
		InputEnded = true,
		InputChanged = true,
		TouchStarted = true,
		TouchEnded = true,
		TouchTap = true,
		LastInputTypeChanged = true,
		JumpRequest = true,
		WindowFocused = true,
		WindowFocusReleased = true,
	},
})

Instances.define("ContextActionService", {
	methods = {
		BindAction = function(self, name, fn, createTouchButton, ...)
			local st = states(self)
			local ctx = ctxOf(st)
			requireClient(st, "BindAction")
			ctx.actions[name] = { fn = fn, inputs = { ... }, priority = 0 }
		end,
		BindActionAtPriority = function(self, name, fn, createTouchButton, priority, ...)
			local st = states(self)
			local ctx = ctxOf(st)
			requireClient(st, "BindActionAtPriority")
			ctx.actions[name] = { fn = fn, inputs = { ... }, priority = priority }
		end,
		UnbindAction = function(self, name)
			local ctx = ctxOf(states(self))
			if ctx and ctx.actions then
				ctx.actions[name] = nil
			end
		end,
		SetTitle = function() end,
		SetImage = function() end,
		SetPosition = function() end,
		SetDescription = function() end,
		GetButton = function()
			return nil
		end,
	},
})

Instances.define("ProximityPromptService", {
	events = {
		PromptTriggered = true,
		PromptTriggerEnded = true,
		PromptShown = true,
		PromptHidden = true,
		PromptButtonHoldBegan = true,
		PromptButtonHoldEnded = true,
	},
})

Instances.define("SocialService", {
	methods = {
		PromptGameInvite = function(self, player)
			local st = states(self)
			requireClient(st, "PromptGameInvite")
			table.insert(st.server.world.invitePrompts, { userId = states(player).extra.userId })
		end,
		CanSendGameInviteAsync = function(self)
			local st = states(self)
			st.server.scheduler:wait(0.05)
			return st.server.world.canInvite
		end,
	},
	events = { GameInvitePromptClosed = true },
})

Instances.define("PolicyService", {
	methods = {
		GetPolicyInfoForPlayerAsync = function(self, player)
			local st = states(self)
			st.server.scheduler:wait(0.05)
			local override = st.server.world.policies[states(player).extra.userId]
			return override
				or {
					AreAdsAllowed = true,
					ArePaidRandomItemsRestricted = false,
					AllowedExternalLinkReferences = { "Discord", "YouTube", "Twitch", "Facebook", "X" },
					IsContentSharingAllowed = true,
					IsEligibleToPurchaseSubscription = true,
					IsPaidItemTradingAllowed = true,
					IsSubjectToChinaPolicies = false,
				}
		end,
	},
})

Instances.define("LocalizationService", {
	methods = {
		GetCountryRegionForPlayerAsync = function(self, player)
			local st = states(self)
			st.server.scheduler:wait(0.05)
			return st.server.world.countries[states(player).extra.userId] or "US"
		end,
	},
})

Instances.define("BadgeService", {
	methods = {
		AwardBadge = function(self, userId, badgeId)
			local st = states(self)
			requireServer(st, "AwardBadge")
			table.insert(st.server.world.badges, { userId = userId, badgeId = badgeId })
			return true
		end,
		AwardBadgeAsync = function(self, userId, badgeId)
			local st = states(self)
			requireServer(st, "AwardBadgeAsync")
			table.insert(st.server.world.badges, { userId = userId, badgeId = badgeId })
			return true
		end,
		UserHasBadgeAsync = function(self, userId, badgeId)
			for _, badge in states(self).server.world.badges do
				if badge.userId == userId and badge.badgeId == badgeId then
					return true
				end
			end
			return false
		end,
	},
})

Instances.define("TextChannel", {
	methods = {
		DisplaySystemMessage = function(self, text)
			local st = states(self)
			local ctx = ctxOf(st)
			requireClient(st, "DisplaySystemMessage")
			table.insert(ctx.systemMessages, text)
			return nil
		end,
		SendAsync = function(self, text)
			local st = states(self)
			table.insert(st.server.world.chat, { text = text, ctx = ctxOf(st) and ctxOf(st).id })
		end,
	},
	events = { MessageReceived = true },
})

Instances.define("StarterGui", {
	methods = {
		SetCore = function(self, name, value)
			local st = states(self)
			requireClient(st, "SetCore")
			ctxOf(st).core[name] = value
		end,
		GetCore = function(self, name)
			local ctx = ctxOf(states(self))
			return ctx and ctx.core and ctx.core[name]
		end,
		SetCoreGuiEnabled = function(self, coreType, enabled)
			local st = states(self)
			requireClient(st, "SetCoreGuiEnabled")
			ctxOf(st).coreGui[tostring(coreType)] = enabled
		end,
		GetCoreGuiEnabled = function(self, coreType)
			local ctx = ctxOf(states(self))
			local value = ctx and ctx.coreGui and ctx.coreGui[tostring(coreType)]
			return value ~= false
		end,
	},
})

Instances.define("GuiService", {
	props = {
		TopbarInset = {
			get = function()
				return roblox.Rect.new(0, 0, 1280, 58)
			end,
			readOnly = true,
		},
	},
	methods = {
		IsTenFootInterface = function(self)
			return device(ctxOf(states(self))) == "Console"
		end,
		GetGuiInset = function()
			return Vector2.new(0, 58), Vector2.zero
		end,
	},
	events = { MenuOpened = true, MenuClosed = true },
})

Instances.define("SoundService", {
	methods = {
		PlayLocalSound = function(self, sound)
			local st = states(self)
			table.insert(st.server.world.soundsPlayed, {
				soundId = sound.SoundId,
				speed = sound.PlaybackSpeed,
				ctx = ctxOf(st) and ctxOf(st).id or "server",
			})
		end,
	},
})

Instances.define("Debris", {
	methods = {
		AddItem = function(self, item, lifetime)
			local st = states(self)
			local ctx = ctxOf(st)
			st.server.scheduler:delay(lifetime or 10, function()
				local itemState = states(item)
				if itemState and not itemState.destroyed then
					st.server.scheduler:spawnIn(ctx, function()
						item:Destroy()
					end)
				end
			end)
		end,
	},
})

Instances.define("PhysicsService", {
	methods = {
		RegisterCollisionGroup = function(self, name)
			local st = states(self)
			requireServer(st, "RegisterCollisionGroup")
			st.server.collisionGroups[name] = st.server.collisionGroups[name] or {}
		end,
		IsCollisionGroupRegistered = function(self, name)
			return name == "Default" or states(self).server.collisionGroups[name] ~= nil
		end,
		CollisionGroupSetCollidable = function(self, a, b, collidable)
			local st = states(self)
			local groups = st.server.collisionGroups
			if (a ~= "Default" and not groups[a]) or (b ~= "Default" and not groups[b]) then
				error("CollisionGroupSetCollidable: collision group is not registered", 2)
			end
			groups[a] = groups[a] or {}
			groups[b] = groups[b] or {}
			groups[a][b] = collidable
			groups[b][a] = collidable
		end,
		CollisionGroupsAreCollidable = function(self, a, b)
			local groups = states(self).server.collisionGroups
			local entry = groups[a] and groups[a][b]
			return entry ~= false
		end,
		GetRegisteredCollisionGroups = function(self)
			local result = { { name = "Default" } }
			for name in states(self).server.collisionGroups do
				table.insert(result, { name = name })
			end
			return result
		end,
	},
})

Instances.define("ContentProvider", {
	props = {
		RequestQueueSize = {
			get = function()
				return 0
			end,
			readOnly = true,
		},
	},
	methods = {
		PreloadAsync = function(_, list, callback)
			if callback then
				for _, item in list do
					callback(if type(item) == "string" then item else "", Enum.AssetFetchStatus.Success)
				end
			end
		end,
	},
})

Instances.define("TeleportService", {
	methods = {
		TeleportAsync = function(self, placeId, players)
			table.insert(states(self).server.world.teleports, { placeId = placeId, count = #players })
		end,
	},
})

Instances.define("InputObject", {})

return { RbxSignal = RbxSignal }

--[[
	Players, Player, Humanoid, Animator, AnimationTrack.
	Characters are simple rigs (HumanoidRootPart, Head, Torso, Humanoid) created
	by the harness when a player spawns.
]]

local roblox = require("@lune/roblox")
local Instances = require("../Instances")
local Reflection = require("../Reflection")

local states = Instances.state
local Enum = roblox.Enum

local DEFAULT_EMOTES = { wave = true, point = true, cheer = true, laugh = true, dance = true, dance2 = true, dance3 = true }

local function ctxOf(st)
	return st.server.scheduler:currentCtx()
end

local function requireServer(st, method)
	local ctx = ctxOf(st)
	if ctx and ctx.kind == "client" then
		error(method .. " can only be called from the server", 3)
	end
end

Instances.define("Players", {
	props = {
		LocalPlayer = {
			get = function(_, _, ctx)
				if ctx and ctx.kind == "client" then
					return ctx.player
				end
				return nil
			end,
			readOnly = true,
		},
		MaxPlayers = {
			get = function(_, st)
				return st.server.maxPlayers
			end,
			readOnly = true,
		},
	},
	methods = {
		GetPlayers = function(self)
			local st = states(self)
			local ctx = ctxOf(st)
			local result = {}
			for _, child in Instances.children(st, ctx) do
				if states(child).className == "Player" then
					table.insert(result, child)
				end
			end
			return result
		end,
		GetPlayerByUserId = function(self, userId)
			local st = states(self)
			for _, child in Instances.children(st, ctxOf(st)) do
				local childState = states(child)
				if childState.className == "Player" and childState.extra.userId == userId then
					return child
				end
			end
			return nil
		end,
		GetPlayerFromCharacter = function(self, character)
			local st = states(self)
			if character == nil then
				return nil
			end
			for _, child in Instances.children(st, ctxOf(st)) do
				local childState = states(child)
				if childState.className == "Player" and Instances.getProp(childState, "Character", nil) == character then
					return child
				end
			end
			return nil
		end,
		CreateHumanoidModelFromDescription = function(self, description, rigType)
			local st = states(self)
			requireServer(st, "CreateHumanoidModelFromDescription")
			return st.server:buildRig("Character", ctxOf(st), description)
		end,
		GetNameFromUserIdAsync = function(self, userId)
			local st = states(self)
			st.server.scheduler:wait(0.05)
			local known = st.server.world.userNames[userId]
			if known then
				return known
			end
			if type(userId) ~= "number" or userId <= 0 then
				error("HTTP 400 (Bad Request)", 2)
			end
			return "User" .. tostring(userId)
		end,
		GetUserIdFromNameAsync = function(self, name)
			local st = states(self)
			st.server.scheduler:wait(0.05)
			for userId, known in st.server.world.userNames do
				if known == name then
					return userId
				end
			end
			error("HTTP 400 (Bad Request)", 2)
		end,
		GetHumanoidDescriptionFromUserId = function(self)
			local st = states(self)
			local description = Instances.create(st.server, "HumanoidDescription", ctxOf(st))
			return description
		end,
	},
	events = {
		PlayerAdded = true,
		PlayerRemoving = true,
		UserSubscriptionStatusChanged = true,
	},
})

Instances.define("Player", {
	props = {
		UserId = {
			get = function(_, st)
				return st.extra.userId
			end,
			readOnly = true,
		},
		DisplayName = {
			get = function(_, st)
				return st.extra.displayName or st.name
			end,
			readOnly = true,
		},
		AccountAge = {
			get = function(_, st)
				return st.extra.accountAge or 100
			end,
			readOnly = true,
		},
		MembershipType = {
			get = function(_, st)
				return st.extra.membership or Enum.MembershipType.None
			end,
			readOnly = true,
		},
		LocaleId = {
			get = function(_, st)
				return st.extra.locale or "en-us"
			end,
			readOnly = true,
		},
	},
	methods = {
		Kick = function(self, message)
			local st = states(self)
			local ctx = ctxOf(st)
			if ctx and ctx.kind == "client" and ctx.player ~= self then
				error("Cannot kick a non-local Player from a LocalScript", 2)
			end
			st.server.kickPlayer(st, message or "")
		end,
		LoadCharacter = function(self)
			local st = states(self)
			requireServer(st, "LoadCharacter")
			st.server:spawnCharacter(st)
		end,
		GetJoinData = function(self)
			return table.clone(states(self).extra.joinData or {})
		end,
		IsFriendsWith = function(self, userId)
			local st = states(self)
			st.server.scheduler:wait(0.02)
			local friends = st.server.world.friends[st.extra.userId]
			return friends ~= nil and friends[userId] == true
		end,
		GetRankInGroup = function()
			return 0
		end,
		GetRoleInGroup = function()
			return "Guest"
		end,
		IsInGroup = function()
			return false
		end,
		HasAppearanceLoaded = function()
			return true
		end,
		DistanceFromCharacter = function(self, point)
			local st = states(self)
			local character = Instances.getProp(st, "Character", nil)
			local root = character and states(character) and Instances.findChild(states(character), "HumanoidRootPart", nil)
			if not root then
				return 0
			end
			return (states(root).proxy.Position - point).Magnitude
		end,
	},
	events = {
		CharacterAdded = true,
		CharacterRemoving = true,
		CharacterAppearanceLoaded = true,
		Chatted = true,
		Idled = true,
	},
})

Instances.define("Humanoid", {
	props = {
		RootPart = {
			get = function(_, st, ctx)
				local model = st.parent and states(st.parent)
				return model and Instances.findChild(model, "HumanoidRootPart", ctx)
			end,
			readOnly = true,
		},
	},
	methods = {
		PlayEmote = function(self, name)
			local st = states(self)
			local ctx = ctxOf(st)
			if not (ctx and ctx.kind == "client") then
				error("PlayEmote can only be called from the client", 2)
			end
			if not DEFAULT_EMOTES[name] then
				return false
			end
			table.insert(st.server.world.emotesPlayed, { user = ctx.userId, emote = name })
			return true
		end,
		MoveTo = function(self, position)
			local st = states(self)
			local model = st.parent
			if model then
				local modelState = states(model)
				local root = Instances.findChild(modelState, "HumanoidRootPart", nil)
				if root then
					local current = states(root).proxy.CFrame
					model:PivotTo(roblox.CFrame.new(position + roblox.Vector3.new(0, 3, 0)) * current.Rotation)
				end
			end
			Instances.fire(st, "MoveToFinished", nil, true)
		end,
		GetState = function()
			return Enum.HumanoidStateType.Running
		end,
		ChangeState = function() end,
		SetStateEnabled = function() end,
		TakeDamage = function(self, amount)
			local st = states(self)
			local health = Instances.getProp(st, "Health", nil) or 100
			self.Health = math.max(0, health - amount)
		end,
		LoadAnimation = function(self, animation)
			local st = states(self)
			local track = Instances.create(st.server, "AnimationTrack", ctxOf(st), { internal = true })
			states(track).extra.animation = animation
			return track
		end,
		ApplyDescription = function(self, description)
			local st = states(self)
			requireServer(st, "ApplyDescription")
			st.server.scheduler:wait(0.1)
			st.extra.description = description
		end,
		GetAppliedDescription = function(self)
			local st = states(self)
			return st.extra.description or Instances.create(st.server, "HumanoidDescription", ctxOf(st))
		end,
		UnequipTools = function() end,
		EquipTool = function() end,
	},
	events = {
		Died = true,
		HealthChanged = true,
		MoveToFinished = true,
		Running = true,
		StateChanged = true,
		Jumping = true,
		FreeFalling = true,
	},
})

Instances.define("Animator", {
	methods = {
		LoadAnimation = function(self, animation)
			local st = states(self)
			if not (animation and states(animation) and Reflection.isA(states(animation).className, "Animation")) then
				error("Unable to cast value to Object", 2)
			end
			local track = Instances.create(st.server, "AnimationTrack", st.server.scheduler:currentCtx(), { internal = true })
			states(track).extra.animation = animation
			return track
		end,
		GetPlayingAnimationTracks = function()
			return {}
		end,
	},
})

Instances.define("AnimationTrack", {
	props = {
		IsPlaying = {
			get = function(_, st)
				return st.extra.playing == true
			end,
			readOnly = true,
		},
		Length = {
			get = function()
				return 1
			end,
			readOnly = true,
		},
		Animation = {
			get = function(_, st)
				return st.extra.animation
			end,
			readOnly = true,
		},
	},
	methods = {
		Play = function(self)
			states(self).extra.playing = true
		end,
		Stop = function(self)
			local st = states(self)
			if st.extra.playing then
				st.extra.playing = false
				Instances.fire(st, "Stopped", nil)
			end
		end,
		AdjustSpeed = function() end,
		AdjustWeight = function() end,
		GetMarkerReachedSignal = function(self, name)
			return Instances.event(states(self), "KeyframeReached").proxy
		end,
	},
	events = { Stopped = true, Ended = true, DidLoop = true, KeyframeReached = true },
})

return true

--[[
	Misc behaviors: ProximityPrompt, ClickDetector, Sound, ParticleEmitter, Tween,
	Actor (Parallel Luau messaging), ValueBase, scripts, Seat, DataStoreOptions.
]]

local roblox = require("@lune/roblox")
local Instances = require("../Instances")
local Serialize = require("../Serialize")
local RbxSignal = require("../RbxSignal")
local Registry = require("../Registry")

local states = Instances.state
local Enum = roblox.Enum

local function ctxOf(st)
	return st.server.scheduler:currentCtx()
end

Instances.define("ProximityPrompt", {
	methods = {
		InputHoldBegin = function(self)
			states(self).extra.holding = true
		end,
		InputHoldEnd = function(self)
			states(self).extra.holding = false
		end,
	},
	events = {
		Triggered = true,
		TriggerEnded = true,
		PromptShown = true,
		PromptHidden = true,
		PromptButtonHoldBegan = true,
		PromptButtonHoldEnded = true,
	},
})

Instances.define("ClickDetector", {
	events = { MouseClick = true, MouseHoverEnter = true, MouseHoverLeave = true, RightMouseClick = true },
})

Instances.define("Sound", {
	props = {
		IsPlaying = {
			get = function(_, st)
				return st.extra.playing == true
			end,
			readOnly = true,
		},
		IsPaused = {
			get = function(_, st)
				return st.extra.playing ~= true
			end,
			readOnly = true,
		},
		IsLoaded = {
			get = function()
				return true
			end,
			readOnly = true,
		},
		TimeLength = {
			get = function()
				return 1
			end,
			readOnly = true,
		},
	},
	methods = {
		Play = function(self)
			local st = states(self)
			local ctx = ctxOf(st)
			st.extra.playing = true
			st.extra.playId = (st.extra.playId or 0) + 1
			local playId = st.extra.playId
			table.insert(st.server.world.soundsPlayed, {
				soundId = Instances.getProp(st, "SoundId", ctx),
				speed = Instances.getProp(st, "PlaybackSpeed", ctx),
				ctx = ctx and ctx.id or "server",
			})
			Instances.fire(st, "Played", nil, Instances.getProp(st, "SoundId", ctx))
			if not Instances.getProp(st, "Looped", ctx) then
				local speed = Instances.getProp(st, "PlaybackSpeed", ctx) or 1
				st.server.scheduler:delay(1 / math.max(speed, 0.01), function()
					if st.extra.playId == playId and st.extra.playing then
						st.extra.playing = false
						Instances.fire(st, "Ended", nil, Instances.getProp(st, "SoundId", ctx))
					end
				end)
			end
		end,
		Stop = function(self)
			local st = states(self)
			if st.extra.playing then
				st.extra.playing = false
				Instances.fire(st, "Stopped", nil, Instances.getProp(st, "SoundId", nil))
			end
		end,
		Pause = function(self)
			states(self).extra.playing = false
		end,
		Resume = function(self)
			states(self).extra.playing = true
		end,
	},
	events = { Played = true, Ended = true, Stopped = true, Paused = true, Resumed = true, Loaded = true, DidLoop = true },
})

Instances.define("ParticleEmitter", {
	methods = {
		Emit = function(self, count)
			local st = states(self)
			st.extra.emitted = (st.extra.emitted or 0) + (count or 16)
		end,
		Clear = function() end,
	},
})

Instances.define("Tween", {
	props = {
		PlaybackState = {
			get = function(_, st)
				return st.extra.playbackState or Enum.PlaybackState.Begin
			end,
			readOnly = true,
		},
		TweenInfo = {
			get = function(_, st)
				return st.extra.info
			end,
			readOnly = true,
		},
		Instance = {
			get = function(_, st)
				return st.extra.target
			end,
			readOnly = true,
		},
	},
	methods = {
		Play = function(self)
			local st = states(self)
			local extra = st.extra
			if extra.playbackState == Enum.PlaybackState.Playing then
				return
			end
			extra.playbackState = Enum.PlaybackState.Playing
			extra.runId = (extra.runId or 0) + 1
			local runId = extra.runId
			local info = extra.info
			local scheduler = st.server.scheduler
			local ctx = extra.ctx
			local repeatCount = info.RepeatCount
			local function finish()
				if extra.runId ~= runId then
					return
				end
				local targetState = states(extra.target)
				if targetState and not targetState.destroyed then
					for property, value in extra.goals do
						local final = if info.Reverses then extra.initial[property] else value
						scheduler:spawnIn(ctx, function()
							extra.target[property] = final
						end)
					end
				end
				extra.playbackState = Enum.PlaybackState.Completed
				Instances.fire(st, "Completed", nil, Enum.PlaybackState.Completed)
			end
			-- Capture initial values for reversing tweens.
			extra.initial = extra.initial or {}
			for property in extra.goals do
				if extra.initial[property] == nil then
					scheduler:spawnIn(ctx, function()
						extra.initial[property] = extra.target[property]
					end)
				end
			end
			if repeatCount < 0 then
				-- Infinite tweens never complete; apply the goal so state is observable.
				for property, value in extra.goals do
					scheduler:spawnIn(ctx, function()
						extra.target[property] = value
					end)
				end
				return
			end
			local duration = info.DelayTime + info.Time * (repeatCount + 1) * (if info.Reverses then 2 else 1)
			scheduler:delay(duration, finish)
		end,
		Pause = function(self)
			local st = states(self)
			st.extra.runId = (st.extra.runId or 0) + 1
			st.extra.playbackState = Enum.PlaybackState.Paused
		end,
		Cancel = function(self)
			local st = states(self)
			if st.extra.playbackState == Enum.PlaybackState.Playing then
				st.extra.runId = (st.extra.runId or 0) + 1
				st.extra.playbackState = Enum.PlaybackState.Cancelled
				Instances.fire(st, "Completed", nil, Enum.PlaybackState.Cancelled)
			end
		end,
	},
	events = { Completed = true },
})

local function messageConnection(bindings, binding)
	return Registry.proxy("RBXScriptConnection", function(mt)
		mt.__index = function(_, key)
			if key == "Connected" then
				return binding.connected
			elseif key == "Disconnect" then
				return function()
					binding.connected = false
					local index = table.find(bindings, binding)
					if index then
						table.remove(bindings, index)
					end
				end
			end
			error(tostring(key) .. " is not a valid member of RBXScriptConnection", 2)
		end
	end)
end

local function bind(self, topic, fn, parallel)
	local st = states(self)
	local ctx = ctxOf(st)
	if not (ctx and ctx.actor == self) then
		error("BindToMessage can only be called from a script that is a descendant of this Actor", 3)
	end
	st.extra.bindings = st.extra.bindings or {}
	local list = st.extra.bindings[topic]
	if not list then
		list = {}
		st.extra.bindings[topic] = list
	end
	local binding = { fn = fn, ctx = ctx, parallel = parallel, connected = true }
	table.insert(list, binding)
	-- Deliver messages that arrived before the actor's script bound the topic.
	local pending = st.extra.pending and st.extra.pending[topic]
	if pending then
		st.extra.pending[topic] = nil
		for _, args in pending do
			st.server.scheduler:deferIn(ctx, fn, args, parallel)
		end
	end
	return messageConnection(list, binding)
end

Instances.define("Actor", {
	methods = {
		SendMessage = function(self, topic, ...)
			local st = states(self)
			local args = Serialize.remoteArgs(table.pack(...))
			local list = st.extra.bindings and st.extra.bindings[topic]
			if not list or #list == 0 then
				st.extra.pending = st.extra.pending or {}
				st.extra.pending[topic] = st.extra.pending[topic] or {}
				table.insert(st.extra.pending[topic], args)
				return
			end
			for _, binding in list do
				if binding.connected then
					st.server.scheduler:deferIn(binding.ctx, binding.fn, args, binding.parallel)
				end
			end
		end,
		BindToMessage = function(self, topic, fn)
			return bind(self, topic, fn, false)
		end,
		BindToMessageParallel = function(self, topic, fn)
			return bind(self, topic, fn, true)
		end,
	},
})

Instances.define("ValueBase", {
	init = function(st)
		st.valueChanged = true
	end,
})

local function scriptEnabledProp(name, invert)
	return {
		get = function(_, st)
			local disabled = Instances.getProp(st, "Disabled", nil) == true
			if invert then
				return not disabled
			end
			return disabled
		end,
		set = function(_, st, value)
			local disabled = if invert then not value else value
			Instances.storeProp(st, "Disabled", disabled, nil)
			if st.server.onScriptEnabledChanged then
				st.server.onScriptEnabledChanged(st, not disabled)
			end
		end,
		datatype = "Bool",
	}
end

Instances.define("BaseScript", {
	props = {
		Disabled = scriptEnabledProp("Disabled", false),
		Enabled = scriptEnabledProp("Enabled", true),
	},
})

Instances.define("Seat", {
	methods = {
		Sit = function(self, humanoid)
			states(self).extra.occupant = humanoid
		end,
	},
	props = {
		Occupant = {
			get = function(_, st)
				return st.extra.occupant
			end,
			readOnly = true,
		},
	},
})

Instances.define("DataStoreOptions", {
	methods = {
		SetExperimentalFeatures = function(self, features)
			states(self).extra.features = features
		end,
	},
})

Instances.define("DataStoreSetOptions", {
	methods = {
		SetMetadata = function(self, metadata)
			states(self).extra.metadata = metadata
		end,
		GetMetadata = function(self)
			return states(self).extra.metadata or {}
		end,
	},
})

return { RbxSignal = RbxSignal }

-- Uma execução de habilidade num cliente: dispara os cues na hora certa,
-- presa ao tempo da AnimationTrack quando ela existe (quem lançou) ou ao
-- relógio do servidor (quem está assistindo).

local RunService = game:GetService("RunService")

local Anchors = require(script.Parent.Anchors)
local Config = require(script.Parent.Config)
local Palette = require(script.Parent.Palette)
local QwinkleBridge = require(script.Parent.QwinkleBridge)
local Rig = require(script.Parent.Rig)
local RootMotion = require(script.Parent.RootMotion)
local Util = require(script.Parent.Util)
local VFX = require(script.Parent.VFX)

local Cast = {}
Cast.__index = Cast

Cast.active = {} :: { [any]: boolean }

export type Options = {
	track: AnimationTrack?,
	startClock: number?,
	rootMotion: boolean?,
	onFinished: (() -> ())?,
}

function Cast.new(character: Model, ability, options: Options?)
	local opts = options or {}
	local self = setmetatable({}, Cast)
	self.character = character
	self.ability = ability
	self.track = opts.track
	self.startClock = opts.startClock or os.clock()
	self.running = true
	self.nextCue = 1
	self.onFinished = opts.onFinished
	self.quality = VFX.quality()
	self.ctx = VFX.context(self, character, self.quality)
	if opts.rootMotion and ability.RootMotion then
		self.root = RootMotion.new(character, ability.RootMotion)
	end
	Cast.active[self] = true
	self.connection = RunService.Heartbeat:Connect(function()
		self:update()
	end)
	return self
end

function Cast:time(): number
	local t = os.clock() - self.startClock
	local track = self.track
	if track and track.IsPlaying then
		local tp = track.TimePosition
		if tp > 0 and math.abs(tp - t) > 0.12 then
			self.startClock = os.clock() - tp
			t = tp
		end
	end
	return t
end

function Cast:fire(cue)
	local character = self.character
	if cue.fx == "emit" then
		if not VFX.allowed(cue.tier, self.quality) then
			return
		end
		local origin = Anchors.cframe(character, cue.anchor or "root")
		if QwinkleBridge.emit(self.ability.Name, cue, origin) and Config.QwinkleReplaces then
			return
		end
		for _, layer in cue.params.layers do
			local effect = VFX.spawn(layer, self.ctx, cue.t, cue.anchor or "root")
			if effect then
				VFX.track(effect, self)
			end
		end
	elseif cue.fx == "trail" then
		local p = cue.params
		local colors = nil
		if p.color then
			colors = { Util.color(p.color, Palette), Util.color(p.color2 or p.color, Palette) }
		end
		Rig.setTrail(character, p.on == true, colors)
	end
end

function Cast:update()
	if not self.running then
		return
	end
	if self.character.Parent == nil then
		self:stop()
		return
	end
	local now = self:time()
	local cues = self.ability.Cues
	while self.nextCue <= #cues and cues[self.nextCue].t <= now do
		self:fire(cues[self.nextCue])
		self.nextCue += 1
	end
	if self.root then
		self.root:update(now)
	end
	if now >= self.ability.Duration then
		self:finish()
	end
end

function Cast:finish()
	if self.root then
		self.root:stop()
		self.root = nil
	end
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	-- efeitos que ainda estão no ar terminam sozinhos
	task.delay(8, function()
		if self.running then
			self:stop()
		end
	end)
	if self.onFinished then
		self.onFinished()
		self.onFinished = nil
	end
end

function Cast:stop()
	if not self.running then
		return
	end
	self.running = false
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	if self.root then
		self.root:stop()
		self.root = nil
	end
	if self.track and self.track.IsPlaying then
		self.track:Stop(0.2)
	end
	VFX.stopCast(self)
	VFX.Specials.blade.restore(self.character)
	Rig.setTrail(self.character, false)
	Cast.active[self] = nil
	if self.onFinished then
		self.onFinished()
		self.onFinished = nil
	end
end

return Cast

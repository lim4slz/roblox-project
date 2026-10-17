--!strict
-- Client-side sound playback. Sound templates live in
-- SoundService.GameAudio (built into the place file); if one is missing we fall
-- back to building it from AudioLibrary so a stripped-down place still works.

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local AudioLibrary = require(script.Parent.AudioLibrary)

local SoundPlayer = {}

type PlayOptions = {
	volume: number?,
	pitch: number?,
	-- Random +/- pitch variation so repeated sounds don't feel robotic.
	pitchJitter: number?,
	-- Fade out and stop after this many seconds (for long library clips).
	maxDuration: number?,
}

local function findTemplate(category: string, name: string): Sound?
	local root = SoundService:FindFirstChild("GameAudio")
	local folder = root and root:FindFirstChild(category)
	local sound = folder and folder:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		return sound
	end
	return nil
end

local function specFor(category: string, name: string): AudioLibrary.SoundSpec?
	local group = (AudioLibrary :: any)[category]
	return group and group[name]
end

-- Returns a fresh Sound for `name`, or nil if the name is unknown.
function SoundPlayer.create(category: string, name: string): Sound?
	local template = findTemplate(category, name)
	if template then
		return template:Clone()
	end
	local spec = specFor(category, name)
	if not spec then
		warn(`[SoundPlayer] Unknown sound {category}.{name}`)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = AudioLibrary.assetUri(spec.Id)
	sound.Volume = spec.Volume
	sound.Looped = spec.Looped == true
	if spec.RollOff then
		sound.RollOffMinDistance = spec.RollOff[1]
		sound.RollOffMaxDistance = spec.RollOff[2]
	end
	return sound
end

local function applyOptions(sound: Sound, options: PlayOptions?)
	if not options then
		return
	end
	if options.volume then
		sound.Volume = options.volume
	end
	local pitch = options.pitch or 1
	if options.pitchJitter then
		pitch += (math.random() * 2 - 1) * options.pitchJitter
	end
	sound.PlaybackSpeed = pitch
end

local FADE_TIME = 0.6

local function cleanupAfterPlay(sound: Sound, holder: Instance, options: PlayOptions?)
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	local maxDuration = options and options.maxDuration
	if maxDuration then
		task.delay(maxDuration, function()
			if holder.Parent then
				TweenService:Create(sound, TweenInfo.new(FADE_TIME), { Volume = 0 }):Play()
				Debris:AddItem(holder, FADE_TIME + 0.05)
			end
		end)
	end
	-- Safety net in case the asset never loads and Ended never fires.
	Debris:AddItem(holder, 15)
end

-- Non-positional sound (UI clicks, announcements).
function SoundPlayer.play(name: string, options: PlayOptions?): Sound?
	local sound = SoundPlayer.create("Sfx", name)
	if not sound then
		return nil
	end
	applyOptions(sound, options)
	sound.Parent = SoundService
	sound:Play()
	cleanupAfterPlay(sound, sound, options)
	return sound
end

-- 3D sound at a world position.
function SoundPlayer.playAt(name: string, position: Vector3, options: PlayOptions?): Sound?
	local sound = SoundPlayer.create("Sfx", name)
	if not sound then
		return nil
	end
	applyOptions(sound, options)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Sfx_" .. name
	attachment.Parent = workspace.Terrain
	attachment.WorldPosition = position
	sound.Parent = attachment
	sound:Play()
	cleanupAfterPlay(sound, attachment, options)
	return sound
end

return SoundPlayer

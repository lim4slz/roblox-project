--!strict
-- Music that follows the match: calm lobby tune, driving battle track, and a
-- tense loop for the Final Showdown, with smooth crossfades in between. Win
-- and loss stings play over the results screen. Ambient wind (and a distant
-- crowd during battles) sits underneath everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AudioLibrary = require(ReplicatedStorage.Shared.AudioLibrary)
local GameState = require(ReplicatedStorage.Shared.GameState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundPlayer = require(ReplicatedStorage.Shared.SoundPlayer)

local MusicController = {}

local CROSSFADE_TIME = 1.6
local player = Players.LocalPlayer

local musicGroup: SoundGroup
local ambientGroup: SoundGroup
local tracks: { [string]: Sound } = {}
local currentTrack: string? = nil
-- On the results screen we stay silent until the win/lose sting has played,
-- then drift back into the lobby tune.
local resultsStingDone = false
local muted = false

local function fadeTo(sound: Sound, volume: number, duration: number): Tween
	local tween = TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Volume = volume })
	tween:Play()
	return tween
end

local function buildTrack(category: string, name: string, group: SoundGroup): Sound?
	local sound = SoundPlayer.create(category, name)
	if not sound then
		return nil
	end
	sound.SoundGroup = group
	sound:SetAttribute("BaseVolume", sound.Volume)
	sound.Volume = 0

	-- Trim the fade-out tail so the loop is seamless. Wrapped in pcall in case
	-- an older engine lacks playback regions; plain looping still works.
	local spec = ((AudioLibrary :: any)[category] or {})[name]
	if spec and spec.Loop then
		pcall(function()
			sound.PlaybackRegionsEnabled = true
			sound.LoopRegion = NumberRange.new(spec.Loop[1], spec.Loop[2])
		end)
	end
	sound.Parent = SoundService
	return sound
end

local function baseVolume(sound: Sound): number
	local value = sound:GetAttribute("BaseVolume")
	return if typeof(value) == "number" then value else 0.5
end

-- Crossfades to `name` (nil = silence).
function MusicController.play(name: string?)
	if name == currentTrack then
		return
	end
	local previous = if currentTrack then tracks[currentTrack] else nil
	currentTrack = name

	if previous then
		local fading = previous
		fadeTo(fading, 0, CROSSFADE_TIME).Completed:Once(function()
			if tracks[currentTrack or ""] ~= fading then
				fading:Stop()
			end
		end)
	end
	local nextSound = if name then tracks[name] else nil
	if nextSound then
		if not nextSound.IsPlaying then
			nextSound.TimePosition = 0
			nextSound:Play()
		end
		fadeTo(nextSound, baseVolume(nextSound), CROSSFADE_TIME)
	end
end

local function desiredTrack(): string?
	local phase = GameState.phase()
	if phase == GameState.Phase.Battle then
		return if GameState.get(GameState.Key.Showdown) then "Showdown" else "Battle"
	elseif phase == GameState.Phase.GetReady then
		-- Silence under the countdown beeps builds anticipation.
		return nil
	elseif phase == GameState.Phase.Results then
		return if resultsStingDone then "Lobby" else nil
	end
	return "Lobby"
end

local function refresh()
	MusicController.play(desiredTrack())
	local crowd = tracks.Crowd
	if crowd then
		local inBattle = GameState.phase() == GameState.Phase.Battle
		fadeTo(crowd, if inBattle then baseVolume(crowd) else 0, 2)
	end
end

local function playSting(name: string)
	local sting = tracks[name]
	if not sting then
		return
	end
	resultsStingDone = false
	refresh()
	sting.Volume = baseVolume(sting)
	sting.TimePosition = 0
	sting:Play()
	local finished = false
	local function done()
		if finished then
			return
		end
		finished = true
		resultsStingDone = true
		refresh()
	end
	sting.Ended:Once(done)
	-- In case the sting never loads.
	task.delay(12, done)
end

function MusicController.setMuted(value: boolean)
	muted = value
	musicGroup.Volume = if muted then 0 else 1
end

function MusicController.isMuted(): boolean
	return muted
end

function MusicController.init()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Parent = SoundService
	ambientGroup = Instance.new("SoundGroup")
	ambientGroup.Name = "Ambient"
	ambientGroup.Parent = SoundService

	for name in AudioLibrary.Music do
		local sound = buildTrack("Music", name, musicGroup)
		if sound then
			sound.Looped = AudioLibrary.Music[name].Looped == true
			tracks[name] = sound
		end
	end
	for name in AudioLibrary.Ambient do
		local sound = buildTrack("Ambient", name, ambientGroup)
		if sound then
			sound.Looped = true
			tracks[name] = sound
		end
	end
end

function MusicController.start()
	local wind = tracks.Wind
	if wind then
		wind:Play()
		fadeTo(wind, baseVolume(wind), 3)
	end
	local crowd = tracks.Crowd
	if crowd then
		crowd:Play()
	end

	GameState.changed(GameState.Key.Phase):Connect(function()
		if GameState.phase() == GameState.Phase.Results then
			resultsStingDone = false
		end
		refresh()
	end)
	GameState.changed(GameState.Key.Showdown):Connect(refresh)
	refresh()

	Remotes.get("MatchResults").OnClientEvent:Connect(function(results)
		local myTeam = if player.Team then player.Team.Name else nil
		local lost = myTeam ~= nil and results.winner ~= "Draw" and results.winner ~= myTeam
		playSting(if lost then "Defeat" else "Victory")
	end)
end

return MusicController

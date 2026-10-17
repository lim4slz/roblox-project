--!nonstrict
-- Builds SoundService.GameAudio from Shared/AudioLibrary so every sound is a
-- real Sound object you can preview and tweak in Studio's Explorer.

local Builder = require("./Builder")
local AudioLibrary = require("../../src/ReplicatedStorage/Shared/AudioLibrary")

local Instance = Builder.Instance
local roblox = Builder.roblox

local Audio = {}

local function buildSound(name: string, spec, parent)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = AudioLibrary.assetUri(spec.Id)
	sound.Volume = spec.Volume
	sound.Looped = spec.Looped == true
	if spec.RollOff then
		sound.RollOffMinDistance = spec.RollOff[1]
		sound.RollOffMaxDistance = spec.RollOff[2]
	end
	if spec.Loop then
		sound.PlaybackRegionsEnabled = true
		sound.LoopRegion = roblox.NumberRange.new(spec.Loop[1], spec.Loop[2])
	end
	sound:SetAttribute("Title", spec.Title)
	sound.Parent = parent
	return sound
end

function Audio.build()
	local root = Builder.folder("GameAudio", nil)
	local count = 0
	for _, category in { "Music", "Sfx", "Ambient" } do
		local folder = Builder.folder(category, root)
		local names = {}
		for name in AudioLibrary[category] do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			buildSound(name, AudioLibrary[category][name], folder)
			count += 1
		end
	end
	return root, count
end

return Audio

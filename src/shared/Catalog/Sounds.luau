--!strict
--[[
	Sounds
	Sound effects use the audio files that ship inside every Roblox client
	(content/sounds), so the game makes noise without uploaded assets. Short
	"jingles" are built by replaying a tick at rising pitches.

	To upgrade: upload your own audio and replace `id` with "rbxassetid://<id>".
	Background music is optional - add uploaded music ids to `Music`.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type Note = { id: string, speed: number, volume: number, delay: number }
export type SoundDef = { notes: { Note } }

local TICK = "rbxasset://sounds/volume_slider.ogg"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local WHOOSH = "rbxasset://sounds/action_get_up.mp3"
local SWIM = "rbxasset://sounds/action_swim.mp3"

local function note(id: string, speed: number, volume: number, delay: number): Note
	return { id = id, speed = speed, volume = volume, delay = delay }
end

local DEFINITIONS: { [string]: SoundDef } = {
	Click = { notes = { note(TICK, 1.2, 0.5, 0) } },
	Open = { notes = { note(TICK, 1.0, 0.4, 0), note(TICK, 1.3, 0.4, 0.05) } },
	Close = { notes = { note(TICK, 1.3, 0.4, 0), note(TICK, 1.0, 0.4, 0.05) } },
	Error = { notes = { note(TICK, 0.6, 0.6, 0), note(TICK, 0.5, 0.6, 0.09) } },
	Coins = { notes = { note(TICK, 1.6, 0.5, 0), note(TICK, 2.0, 0.5, 0.06) } },
	Pickup = { notes = { note(THUD, 1.4, 0.5, 0), note(TICK, 1.8, 0.4, 0.04) } },
	Reward = {
		notes = { note(TICK, 1.0, 0.6, 0), note(TICK, 1.25, 0.6, 0.08), note(TICK, 1.5, 0.6, 0.16) },
	},
	LevelUp = {
		notes = {
			note(TICK, 1.0, 0.7, 0),
			note(TICK, 1.26, 0.7, 0.1),
			note(TICK, 1.5, 0.7, 0.2),
			note(TICK, 2.0, 0.8, 0.32),
		},
	},
	Rare = {
		notes = {
			note(TICK, 1.5, 0.7, 0),
			note(TICK, 2.0, 0.7, 0.07),
			note(TICK, 2.5, 0.7, 0.14),
			note(TICK, 3.0, 0.8, 0.21),
		},
	},
	Cast = { notes = { note(WHOOSH, 1.3, 0.6, 0), note(SPLASH, 1.4, 0.4, 0.45) } },
	Bite = { notes = { note(SPLASH, 1.8, 0.8, 0) } },
	Catch = { notes = { note(SPLASH, 1.0, 0.7, 0), note(TICK, 1.5, 0.5, 0.15) } },
	Water = { notes = { note(SWIM, 1.4, 0.6, 0) } },
	Announcement = { notes = { note(TICK, 0.8, 0.6, 0), note(TICK, 1.2, 0.6, 0.12) } },
}

local Sounds = {}

Sounds.Definitions = TableUtil.deepFreeze(DEFINITIONS)
-- Uploaded music ids ("rbxassetid://...") played in a loop when Music is enabled.
Sounds.Music = table.freeze({} :: { string })

function Sounds.get(name: string): SoundDef?
	return DEFINITIONS[name]
end

return table.freeze(Sounds)

--!strict
-- Every sound the game uses, in one place.
--
-- All IDs point at audio that Roblox has licensed for use in any experience
-- (Roblox's own uploads, the APM music library and the Pro Sound Effects
-- library), so the game has working audio the moment it is opened in Studio.
-- To use your own tracks, upload them through the Asset Manager and swap the Id.
--
-- Loop = { start, finish } (seconds) trims the fade-out tail off library tracks
-- so they loop seamlessly. The points were measured on whole bars.
--
-- Pure data, no Roblox types: the Lune map builder reads this file too.

export type SoundSpec = {
	Id: number,
	Volume: number,
	Title: string,
	Looped: boolean?,
	Loop: { number }?,
	PlaybackSpeed: number?,
	-- Positional sounds: distance at which they start fading, and silence.
	RollOff: { number }?,
}

local AudioLibrary = {}

AudioLibrary.Music = {
	Lobby = {
		Id = 1837768517,
		Volume = 0.32,
		Title = "Bossa Me (a) - Peter Christiansen (APM)",
		Looped = true,
		Loop = { 0.665, 139.079 },
	},
	Battle = {
		Id = 1839465913,
		Volume = 0.34,
		Title = "Battle Action - Kosinus (APM)",
		Looped = true,
		Loop = { 0.036, 97.888 },
	},
	Showdown = {
		Id = 1839847752,
		Volume = 0.5,
		Title = "Against Time - Juice Music (APM)",
		Looped = true,
		Loop = { 0.251, 66.689 },
	},
	Victory = {
		Id = 1837762472,
		Volume = 0.45,
		Title = "Victory Dance (sting a) - Glenn Herweijer (APM)",
	},
	Defeat = {
		Id = 1846942404,
		Volume = 0.4,
		Title = "Loser Sting Three B - John Epping (APM)",
	},
} :: { [string]: SoundSpec }

AudioLibrary.Sfx = {
	Explosion = { Id = 9117982449, Volume = 1.4, Title = "Pyro Explosion 1", RollOff = { 18, 420 } },
	BrickCrumble = { Id = 9118587494, Volume = 2.2, Title = "Rock Drop On Concrete", RollOff = { 14, 300 } },
	TowerCollapse = { Id = 3149249837, Volume = 1.6, Title = "Cannon_Explode", RollOff = { 30, 700 } },
	FuseTick = { Id = 12221976, Volume = 0.6, Title = "clickfast.wav", RollOff = { 8, 90 } },
	Throw = { Id = 12222200, Volume = 0.7, Title = "swoosh.wav", RollOff = { 8, 120 } },
	Bounce = { Id = 9113262444, Volume = 1.2, Title = "Ball Bounce Exterior 3", RollOff = { 6, 80 } },
	SwordSlash = { Id = 12222216, Volume = 0.8, Title = "swordslash.wav", RollOff = { 8, 120 } },
	SwordLunge = { Id = 12222208, Volume = 0.6, Title = "swordlunge.wav", RollOff = { 8, 120 } },
	Hit = { Id = 12222046, Volume = 0.5, Title = "hit.wav", RollOff = { 8, 120 } },
	RocketFire = { Id = 12222084, Volume = 0.6, Title = "Rocket shot.wav", RollOff = { 10, 250 } },
	PowerUp = { Id = 9116422213, Volume = 0.9, Title = "Magic Transformation 17" },
	Countdown = { Id = 12221990, Volume = 0.6, Title = "electronicpingshort.wav" },
	BattleStart = { Id = 9114631615, Volume = 0.8, Title = "Gong Whoosh 6" },
	ZoneAlarm = { Id = 9113089565, Volume = 0.35, Title = "Alarm Tone 2 Tone Fast High Low" },
	ZoneZap = { Id = 9114277757, Volume = 0.6, Title = "Electric Zaps 12" },
	Notify = { Id = 17208361335, Volume = 0.6, Title = "Roblox GUI - Notification High" },
	Knockout = { Id = 12222253, Volume = 0.5, Title = "victory.wav" },
	Fireworks = { Id = 9114447096, Volume = 0.7, Title = "Fireworks Fast 1", RollOff = { 40, 900 } },
	Cheer = { Id = 9112766176, Volume = 0.5, Title = "Crowd Cheer And Applause 1" },
	UiClick = { Id = 15675059323, Volume = 0.5, Title = "Roblox_UI_Bright_Click" },
	UiHover = { Id = 10066931761, Volume = 0.25, Title = "RBLX UI Hover 01" },
	Pop = { Id = 15675055424, Volume = 0.6, Title = "Roblox_UI_Cute_Pop" },
} :: { [string]: SoundSpec }

AudioLibrary.Ambient = {
	Wind = { Id = 9114057104, Volume = 0.9, Title = "Desert Wind Whistley Light Gusts 1", Looped = true },
	Crowd = { Id = 9112766176, Volume = 0.06, Title = "Crowd Cheer And Applause 1", Looped = true },
} :: { [string]: SoundSpec }

function AudioLibrary.assetUri(id: number): string
	return "rbxassetid://" .. tostring(id)
end

return AudioLibrary

-- CRAB -----------------------------------------------------------------------
Config.Crab = {
	-- 1 = original size, 2 = twice as big, 0.5 = half.
	Scale = 1,
	-- Where it scuttles next to its owner, in studs: X to the right
	-- (negative = left), Z behind (negative = in front).
	Spot = Vector3.new(-5.8, 0, 0.4),
	-- The claw clicks of a SNAP. Any sound id your game is allowed to play.
	-- "" = no sound.
	Sound = "rbxassetid://9113957844",
	SoundStart = 0, -- second of the sound file where the first click is
	Volume = 0.8,
	-- Words that pop up over its head when it snaps. {} = no bubble.
	Texts = { "SNAP!", "Snip snap!", "CLACK!", "Snap snap!" },
	-- Seconds between the SNAPs it does on its own: { min, max }.
	-- false = it only snaps when your scripts call PetSpawner.react.
	Every = { 4, 8 },
}

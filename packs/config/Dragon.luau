-- DRAGON ---------------------------------------------------------------------
Config.Dragon = {
	-- 1 = original size, 2 = twice as big, 0.5 = half.
	Scale = 1,
	-- Where it flies next to its owner, in studs: X to the right (negative =
	-- left), Z behind (negative = in front). It flies about 2 studs up.
	Spot = Vector3.new(4.6, 0, 6.6),
	-- The whoosh of its fire. Any sound id your game is allowed to play.
	-- "" = no sound.
	Sound = "rbxassetid://9114439216",
	-- Second of the sound file where the whoosh starts. The default sound
	-- builds up slowly, so it starts 1.3 seconds in. Set it to 0 when you use
	-- your own sound.
	SoundStart = 1.3,
	Volume = 0.6,
	-- Words that pop up over its head when it breathes fire. {} = no bubble.
	Texts = { "ROAR!", "RAWR!", "FWOOSH!", "Rawr!" },
	-- Seconds between the fire breaths it does on its own: { min, max }.
	-- false = it only breathes fire when your scripts call PetSpawner.react.
	Every = { 6, 12 },
}

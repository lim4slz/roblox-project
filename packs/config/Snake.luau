-- SNAKE ----------------------------------------------------------------------
Config.Snake = {
	-- 1 = original size, 2 = twice as big, 0.5 = half.
	Scale = 1,
	-- Where its head goes next to its owner, in studs: X to the right
	-- (negative = left), Z behind (negative = in front). The body trails behind.
	Spot = Vector3.new(-2.6, 0, 3.4),
	-- The hiss. Any sound id your game is allowed to play. "" = no sound.
	Sound = "rbxassetid://9119302862",
	-- Second of the sound file where the hiss starts. The default sound has
	-- 2.8 seconds of silence first. Set it to 0 when you use your own sound.
	SoundStart = 2.8,
	Volume = 0.9,
	-- Words that pop up over its head when it hisses. {} = no bubble.
	Texts = { "HSSS!", "Hssss!", "HISSS!", "Sss!" },
	-- Seconds between the hisses it does on its own: { min, max }.
	-- false = it only hisses when your scripts call PetSpawner.react.
	Every = { 5, 10 },
}

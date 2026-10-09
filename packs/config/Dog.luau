-- DOG ------------------------------------------------------------------------
Config.Dog = {
	-- 1 = original size, 2 = twice as big, 0.5 = half.
	Scale = 1,
	-- Where it walks next to its owner, in studs: X to the right (negative =
	-- left), Z behind (negative = in front).
	Spot = Vector3.new(2.6, 0, 3.4),
	-- The bark. Any sound id your game is allowed to play. "" = no sound.
	Sound = "rbxassetid://7103147161",
	SoundStart = 0, -- second of the sound file where the bark starts
	Volume = 0.6,
	-- Words that pop up over its head when it barks. {} = no bubble.
	Texts = { "WOOF!", "Woof!", "WOOF!", "WOOF!!" },
	-- Seconds between the barks it does on its own: { min, max }.
	-- false = it only barks when your scripts call PetSpawner.react.
	Every = { 3.5, 8 },
}

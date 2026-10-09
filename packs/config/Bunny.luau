-- BUNNY ----------------------------------------------------------------------
Config.Bunny = {
	-- 1 = original size, 2 = twice as big, 0.5 = half.
	Scale = 1,
	-- Where it hops next to its owner, in studs: X to the right (negative =
	-- left), Z behind (negative = in front).
	Spot = Vector3.new(5.2, 0, 0.6),
	-- The squeak of a binky. Any sound id your game is allowed to play.
	-- "" = no sound.
	Sound = "rbxassetid://9125994553",
	SoundStart = 0, -- second of the sound file where the squeak starts
	Volume = 0.5,
	-- Words that pop up over its head when it does a binky. {} = no bubble.
	Texts = { "Boing!", "Hop!", "Wheee!", "Yay!" },
	-- Seconds between the binkies it does on its own: { min, max }.
	-- false = it only does them when your scripts call PetSpawner.react.
	Every = { 4.5, 9 },
}

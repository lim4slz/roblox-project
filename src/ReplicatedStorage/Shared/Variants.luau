--!strict
-- Match variants keep back-to-back rounds from feeling the same. One is rolled
-- in the lobby (weighted) unless the admin picks the next one manually.
--
-- Modifier names map onto the server's Rules table: any key ending in
-- "Multiplier" multiplies the base value, anything else replaces it.

export type Variant = {
	Id: string,
	Name: string,
	Description: string,
	Weight: number,
	Modifiers: { [string]: number },
}

local Variants = {}

Variants.List = {
	{
		Id = "Classic",
		Name = "Classic",
		Description = "The original brick-smashing showdown.",
		Weight = 5,
		Modifiers = {},
	},
	{
		Id = "MegaBombs",
		Name = "Mega Bombs",
		Description = "Huge blasts, longer fuses, slower reloads.",
		Weight = 2,
		Modifiers = { BlastRadiusMultiplier = 1.45, FuseTime = 3.6, ReloadMultiplier = 1.35 },
	},
	{
		Id = "LowGravity",
		Name = "Low Gravity",
		Description = "Moon jumps and long-range lobs.",
		Weight = 2,
		Modifiers = { Gravity = 80 },
	},
	{
		Id = "BombFrenzy",
		Name = "Bomb Frenzy",
		Description = "Bombs reload almost instantly, but hit softer.",
		Weight = 2,
		Modifiers = { ReloadMultiplier = 0.3, DamageMultiplier = 0.7 },
	},
	{
		Id = "Chaos",
		Name = "Chaos",
		Description = "A random event every 30 seconds!",
		Weight = 1,
		Modifiers = { EventInterval = 30 },
	},
} :: { Variant }

function Variants.get(id: string?): Variant
	for _, variant in Variants.List do
		if variant.Id == id then
			return variant
		end
	end
	return Variants.List[1]
end

-- Weighted roll. `random` is injectable so the roll can be tested.
function Variants.roll(random: Random?, avoidId: string?): Variant
	local rng = random or Random.new()
	local total = 0
	for _, variant in Variants.List do
		if variant.Id ~= avoidId then
			total += variant.Weight
		end
	end
	local pick = rng:NextNumber() * total
	for _, variant in Variants.List do
		if variant.Id ~= avoidId then
			pick -= variant.Weight
			if pick <= 0 then
				return variant
			end
		end
	end
	return Variants.List[1]
end

return Variants

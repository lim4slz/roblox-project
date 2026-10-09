--!strict
--[[
	Items
	Stackable resources that live in the backpack: fruit from bushes and fish
	from fishing spots. They are sold at the Market or handed in for quests.
	Icons are emoji so the UI needs no uploaded image assets.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type ItemCategory = "Fruit" | "Fish"

export type ItemDef = {
	id: string,
	name: string,
	icon: string,
	category: ItemCategory,
	rarity: string,
	sellPrice: number,
	xp: number,
	description: string,
	-- Foraging only: picking a bush of this fruit can yield a rarer variant instead.
	rareVariant: string?,
	rareChance: number?,
}

local DEFINITIONS: { ItemDef } = {
	-- Fruit -------------------------------------------------------------------
	{
		id = "Apple",
		name = "Apple",
		icon = "🍎",
		category = "Fruit",
		rarity = "Common",
		sellPrice = 4,
		xp = 6,
		description = "Crisp and shiny. Baker Bram can never have enough.",
		rareVariant = "GoldenApple",
		rareChance = 0.02,
	},
	{
		id = "Grapes",
		name = "Grapes",
		icon = "🍇",
		category = "Fruit",
		rarity = "Common",
		sellPrice = 3,
		xp = 5,
		description = "A juicy bunch from the park vines.",
	},
	{
		id = "Orange",
		name = "Orange",
		icon = "🍊",
		category = "Fruit",
		rarity = "Uncommon",
		sellPrice = 6,
		xp = 7,
		description = "Sweet, sunny and great for juice.",
	},
	{
		id = "GoldenApple",
		name = "Golden Apple",
		icon = "🌟",
		category = "Fruit",
		rarity = "Epic",
		sellPrice = 60,
		xp = 25,
		description = "Legend says it glows brighter when friends are near.",
	},
	{
		id = "Cherry",
		name = "Cherries",
		icon = "🍒",
		category = "Fruit",
		rarity = "Rare",
		sellPrice = 12,
		xp = 10,
		description = "Only grows in the Hilltop Orchard breeze.",
		rareVariant = "Starfruit",
		rareChance = 0.06,
	},
	{
		id = "Starfruit",
		name = "Starfruit",
		icon = "⭐",
		category = "Fruit",
		rarity = "Epic",
		sellPrice = 40,
		xp = 20,
		description = "Fell from the sky, or so the Mayor claims.",
	},

	-- Fish --------------------------------------------------------------------
	{
		id = "Minnow",
		name = "Minnow",
		icon = "🐟",
		category = "Fish",
		rarity = "Common",
		sellPrice = 5,
		xp = 12,
		description = "Tiny, fast and always in a hurry.",
	},
	{
		id = "Perch",
		name = "Perch",
		icon = "🐟",
		category = "Fish",
		rarity = "Common",
		sellPrice = 7,
		xp = 14,
		description = "A striped regular of Brightbrook Lake.",
	},
	{
		id = "Trout",
		name = "Rainbow Trout",
		icon = "🐠",
		category = "Fish",
		rarity = "Uncommon",
		sellPrice = 12,
		xp = 18,
		description = "Shimmers in every color when the sun hits it.",
	},
	{
		id = "Pufferfish",
		name = "Pufferfish",
		icon = "🐡",
		category = "Fish",
		rarity = "Rare",
		sellPrice = 20,
		xp = 25,
		description = "Puffs up when surprised. Which is always.",
	},
	{
		id = "GoldenCarp",
		name = "Golden Carp",
		icon = "🐠",
		category = "Fish",
		rarity = "Epic",
		sellPrice = 60,
		xp = 45,
		description = "Brings good luck, according to Fisher Finn.",
	},
	{
		id = "MoonKoi",
		name = "Moon Koi",
		icon = "🎏",
		category = "Fish",
		rarity = "Legendary",
		sellPrice = 250,
		xp = 120,
		description = "Only a handful of anglers have ever seen one.",
	},
	{
		id = "OldBoot",
		name = "Old Boot",
		icon = "👢",
		category = "Fish",
		rarity = "Junk",
		sellPrice = 1,
		xp = 3,
		description = "Someone lost a boot. Someone else found it. You.",
	},
}

export type PoolEntry = { item: string, weight: number }

-- Fishing pools: weights are relative. Each fishing spot in the world names a pool.
local POOLS: { [string]: { minLevel: number, entries: { PoolEntry } } } = {
	Lake = {
		minLevel = 2,
		entries = {
			{ item = "Minnow", weight = 42 },
			{ item = "Perch", weight = 28 },
			{ item = "Trout", weight = 16 },
			{ item = "OldBoot", weight = 6 },
			{ item = "Pufferfish", weight = 6 },
			{ item = "GoldenCarp", weight = 1.8 },
			{ item = "MoonKoi", weight = 0.2 },
		},
	},
	MoonPond = {
		minLevel = 5,
		entries = {
			{ item = "Minnow", weight = 12 },
			{ item = "Perch", weight = 14 },
			{ item = "Trout", weight = 24 },
			{ item = "OldBoot", weight = 4 },
			{ item = "Pufferfish", weight = 22 },
			{ item = "GoldenCarp", weight = 18 },
			{ item = "MoonKoi", weight = 6 },
		},
	},
}

local byId: { [string]: ItemDef } = {}
for _, def in DEFINITIONS do
	assert(byId[def.id] == nil, "duplicate item id " .. def.id)
	byId[def.id] = def
end

local Items = {}

Items.List = TableUtil.deepFreeze(DEFINITIONS)
Items.Pools = TableUtil.deepFreeze(POOLS)

function Items.get(id: string): ItemDef?
	return byId[id]
end

function Items.exists(id: string): boolean
	return byId[id] ~= nil
end

function Items.ofCategory(category: ItemCategory): { ItemDef }
	local result = {}
	for _, def in DEFINITIONS do
		if def.category == category then
			table.insert(result, def)
		end
	end
	return result
end

return table.freeze(Items)

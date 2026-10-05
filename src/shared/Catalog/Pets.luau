--!strict
--[[
	Pets
	Companions that follow their owner. Pets are cosmetic: they never change
	rewards, speed or any other stat (no pay-to-win). One pet can be equipped.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type PetShape = "Cat" | "Dog" | "Bunny" | "Duck" | "Fox" | "Owl" | "Turtle" | "Moth" | "Dragon"

export type PetDef = {
	id: string,
	name: string,
	icon: string,
	rarity: string,
	description: string,
	source: "Quest" | "Shop" | "Collection" | "Festival" | "Product",
	price: { currency: "Tokens" | "Tickets", amount: number }?,
	level: number,
	model: { shape: PetShape, primary: Color3, secondary: Color3, flying: boolean, sparkle: boolean? },
}

local rgb = Color3.fromRGB

local DEFINITIONS: { PetDef } = {
	{
		id = "Kitten",
		name = "Kitten",
		icon = "🐱",
		rarity = "Common",
		description = "Your very first friend in Brightbrook.",
		source = "Quest",
		level = 1,
		model = { shape = "Cat", primary = rgb(240, 160, 80), secondary = rgb(255, 240, 225), flying = false },
	},
	{
		id = "Puppy",
		name = "Puppy",
		icon = "🐶",
		rarity = "Common",
		description = "Wags so hard the whole puppy wags.",
		source = "Shop",
		price = { currency = "Tokens", amount = 900 },
		level = 2,
		model = { shape = "Dog", primary = rgb(170, 120, 80), secondary = rgb(250, 235, 215), flying = false },
	},
	{
		id = "Bunny",
		name = "Bunny",
		icon = "🐰",
		rarity = "Uncommon",
		description = "Hops along and steals the occasional carrot.",
		source = "Shop",
		price = { currency = "Tokens", amount = 1400 },
		level = 3,
		model = { shape = "Bunny", primary = rgb(245, 245, 245), secondary = rgb(255, 180, 200), flying = false },
	},
	{
		id = "Duckling",
		name = "Duckling",
		icon = "🐥",
		rarity = "Uncommon",
		description = "Quack. That is the whole personality. We love it.",
		source = "Shop",
		price = { currency = "Tokens", amount = 2200 },
		level = 5,
		model = { shape = "Duck", primary = rgb(255, 220, 80), secondary = rgb(255, 150, 50), flying = false },
	},
	{
		id = "Fox",
		name = "Fox",
		icon = "🦊",
		rarity = "Rare",
		description = "Clever, curious and very fluffy.",
		source = "Shop",
		price = { currency = "Tokens", amount = 4000 },
		level = 8,
		model = { shape = "Fox", primary = rgb(230, 110, 40), secondary = rgb(250, 245, 240), flying = false },
	},
	{
		id = "Owl",
		name = "Owl",
		icon = "🦉",
		rarity = "Rare",
		description = "Knows every secret path in town.",
		source = "Shop",
		price = { currency = "Tokens", amount = 7500 },
		level = 12,
		model = { shape = "Owl", primary = rgb(140, 100, 70), secondary = rgb(235, 215, 180), flying = true },
	},
	{
		id = "Turtle",
		name = "Turtle",
		icon = "🐢",
		rarity = "Epic",
		description = "Reward for completing the Angler's Album. Slow and steady.",
		source = "Collection",
		level = 1,
		model = { shape = "Turtle", primary = rgb(90, 160, 90), secondary = rgb(120, 90, 60), flying = false },
	},
	{
		id = "LanternMoth",
		name = "Lantern Moth",
		icon = "🦋",
		rarity = "Epic",
		description = "Drawn to the warm glow of the Lantern Festival.",
		source = "Festival",
		price = { currency = "Tickets", amount = 120 },
		level = 1,
		model = { shape = "Moth", primary = rgb(255, 210, 120), secondary = rgb(255, 150, 60), flying = true },
	},
	{
		id = "Dragonling",
		name = "Baby Dragon",
		icon = "🐉",
		rarity = "Legendary",
		description = "Tiny wings, giant heart. Does not breathe fire (yet).",
		source = "Shop",
		price = { currency = "Tokens", amount = 20000 },
		level = 20,
		model = { shape = "Dragon", primary = rgb(110, 200, 140), secondary = rgb(255, 210, 90), flying = true },
	},
	{
		id = "GoldenPup",
		name = "Golden Pup",
		icon = "🐕",
		rarity = "Legendary",
		description = "A shimmering companion. Available in the Premium shop.",
		source = "Product",
		level = 1,
		model = {
			shape = "Dog",
			primary = rgb(255, 200, 70),
			secondary = rgb(255, 245, 210),
			flying = false,
			sparkle = true,
		},
	},
}

local byId: { [string]: PetDef } = {}
for _, def in DEFINITIONS do
	assert(byId[def.id] == nil, "duplicate pet id " .. def.id)
	byId[def.id] = def
end

local Pets = {}

Pets.List = TableUtil.deepFreeze(DEFINITIONS)

function Pets.get(id: string): PetDef?
	return byId[id]
end

function Pets.exists(id: string): boolean
	return byId[id] ~= nil
end

return table.freeze(Pets)

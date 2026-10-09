--!strict
--[[
	Cosmetics
	Purely visual avatar items. None of them changes gameplay stats (no pay-to-win).
	  Hat   - a small model welded to the head (built by Visuals/ModelFactory)
	  Trail - a Trail between two attachments on the HumanoidRootPart
	  Aura  - a ParticleEmitter around the character
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type CosmeticSlot = "Hat" | "Trail" | "Aura"
export type Currency = "Tokens" | "Tickets"
export type Price = { currency: Currency, amount: number }

export type CosmeticDef = {
	id: string,
	name: string,
	slot: CosmeticSlot,
	icon: string,
	rarity: string,
	description: string,
	-- How it is obtained. "Shop"/"Festival" items have a price; the rest are rewards.
	source: "Shop" | "Festival" | "Quest" | "Collection" | "Pass" | "Product" | "Subscription",
	price: Price?,
	level: number?,
	visual: {
		kind: string?,
		primary: Color3?,
		secondary: Color3?,
		colors: { Color3 }?,
		width: number?,
		lifetime: number?,
		rate: number?,
		size: number?,
		speed: number?,
	},
}

local rgb = Color3.fromRGB

local DEFINITIONS: { CosmeticDef } = {
	-- Hats ---------------------------------------------------------------------
	{
		id = "StrawHat",
		name = "Straw Hat",
		slot = "Hat",
		icon = "👒",
		rarity = "Common",
		description = "Perfect for long sunny days in the orchard.",
		source = "Shop",
		price = { currency = "Tokens", amount = 250 },
		level = 1,
		visual = { kind = "Brim", primary = rgb(233, 205, 140), secondary = rgb(214, 70, 70) },
	},
	{
		id = "PartyCone",
		name = "Party Cone",
		slot = "Hat",
		icon = "🥳",
		rarity = "Common",
		description = "Every day is a party in Brightbrook.",
		source = "Shop",
		price = { currency = "Tokens", amount = 500 },
		level = 1,
		visual = { kind = "Cone", primary = rgb(255, 120, 190), secondary = rgb(255, 220, 90) },
	},
	{
		id = "ChefHat",
		name = "Chef Hat",
		slot = "Hat",
		icon = "🍳",
		rarity = "Uncommon",
		description = "A gift from Baker Bram for the freshest fruit in town.",
		source = "Quest",
		visual = { kind = "Chef", primary = rgb(250, 250, 250), secondary = rgb(230, 230, 236) },
	},
	{
		id = "BucketHat",
		name = "Angler's Bucket Hat",
		slot = "Hat",
		icon = "🎣",
		rarity = "Uncommon",
		description = "Smells faintly of lake water. In a good way.",
		source = "Shop",
		price = { currency = "Tokens", amount = 900 },
		level = 3,
		visual = { kind = "Bucket", primary = rgb(120, 140, 80), secondary = rgb(90, 104, 60) },
	},
	{
		id = "PostalCap",
		name = "Postal Cap",
		slot = "Hat",
		icon = "📮",
		rarity = "Rare",
		description = "Awarded to Brightbrook's most reliable couriers.",
		source = "Quest",
		visual = { kind = "Cap", primary = rgb(44, 92, 170), secondary = rgb(250, 200, 70) },
	},
	{
		id = "TopHat",
		name = "Top Hat",
		slot = "Hat",
		icon = "🎩",
		rarity = "Rare",
		description = "Very fancy. Mayor Maple approves.",
		source = "Shop",
		price = { currency = "Tokens", amount = 2500 },
		level = 6,
		visual = { kind = "TopHat", primary = rgb(30, 30, 36), secondary = rgb(140, 70, 200) },
	},
	{
		id = "ExplorerHat",
		name = "Explorer Hat",
		slot = "Hat",
		icon = "🧭",
		rarity = "Epic",
		description = "For those who found every postcard in Brightbrook.",
		source = "Collection",
		visual = { kind = "Brim", primary = rgb(196, 170, 120), secondary = rgb(110, 80, 50) },
	},
	{
		id = "LanternHat",
		name = "Lantern Hat",
		slot = "Hat",
		icon = "🏮",
		rarity = "Epic",
		description = "Glows softly. Only sold at the Lantern Festival booth.",
		source = "Festival",
		price = { currency = "Tickets", amount = 30 },
		level = 1,
		visual = { kind = "Lantern", primary = rgb(226, 60, 50), secondary = rgb(255, 205, 80) },
	},
	{
		id = "SunflowerHat",
		name = "Sunflower Hat",
		slot = "Hat",
		icon = "🌻",
		rarity = "Epic",
		description = "Exclusive to the Starter Pack.",
		source = "Product",
		visual = { kind = "Sunflower", primary = rgb(255, 205, 50), secondary = rgb(120, 80, 40) },
	},
	{
		id = "RoyalCrown",
		name = "Royal Crown",
		slot = "Hat",
		icon = "👑",
		rarity = "Legendary",
		description = "Proof of a truly dedicated Brightbrook citizen.",
		source = "Shop",
		price = { currency = "Tokens", amount = 12000 },
		level = 15,
		visual = { kind = "Crown", primary = rgb(255, 196, 60), secondary = rgb(220, 40, 70) },
	},

	-- Trails -------------------------------------------------------------------
	{
		id = "SparkleTrail",
		name = "Sparkle Trail",
		slot = "Trail",
		icon = "✨",
		rarity = "Uncommon",
		description = "Leave a little sparkle wherever you go.",
		source = "Shop",
		price = { currency = "Tokens", amount = 1500 },
		level = 4,
		visual = { colors = { rgb(255, 255, 255), rgb(160, 210, 255) }, width = 1.2, lifetime = 0.6 },
	},
	{
		id = "LeafTrail",
		name = "Leaf Trail",
		slot = "Trail",
		icon = "🍃",
		rarity = "Rare",
		description = "Reward for completing the Orchard Album.",
		source = "Collection",
		visual = { colors = { rgb(120, 200, 90), rgb(60, 140, 60) }, width = 1.4, lifetime = 0.7 },
	},
	{
		id = "RainbowTrail",
		name = "Rainbow Trail",
		slot = "Trail",
		icon = "🌈",
		rarity = "Epic",
		description = "All the colors, all the time.",
		source = "Shop",
		price = { currency = "Tokens", amount = 5000 },
		level = 10,
		visual = {
			colors = {
				rgb(255, 80, 80),
				rgb(255, 170, 60),
				rgb(255, 235, 80),
				rgb(90, 220, 110),
				rgb(80, 160, 255),
				rgb(170, 100, 255),
			},
			width = 1.6,
			lifetime = 0.8,
		},
	},
	{
		id = "FireflyTrail",
		name = "Firefly Trail",
		slot = "Trail",
		icon = "💫",
		rarity = "Epic",
		description = "Warm festival light. Sold only at the Lantern Festival booth.",
		source = "Festival",
		price = { currency = "Tickets", amount = 50 },
		level = 1,
		visual = { colors = { rgb(255, 230, 120), rgb(255, 150, 40) }, width = 1.3, lifetime = 0.9 },
	},
	{
		id = "VipGoldTrail",
		name = "VIP Gold Trail",
		slot = "Trail",
		icon = "💛",
		rarity = "Legendary",
		description = "Included with Brightbrook VIP.",
		source = "Pass",
		visual = { colors = { rgb(255, 240, 160), rgb(255, 190, 40) }, width = 1.5, lifetime = 0.8 },
	},
	{
		id = "PlusTrail",
		name = "VIP Plus Trail",
		slot = "Trail",
		icon = "💠",
		rarity = "Legendary",
		description = "Included with the VIP Plus subscription.",
		source = "Subscription",
		visual = { colors = { rgb(80, 230, 220), rgb(150, 90, 255) }, width = 1.5, lifetime = 0.8 },
	},

	-- Auras --------------------------------------------------------------------
	{
		id = "RosyAura",
		name = "Rosy Aura",
		slot = "Aura",
		icon = "💗",
		rarity = "Rare",
		description = "A soft pink shimmer that follows you around.",
		source = "Shop",
		price = { currency = "Tokens", amount = 3000 },
		level = 8,
		visual = { primary = rgb(255, 130, 190), rate = 6, size = 0.6, speed = 1.5 },
	},
	{
		id = "BubbleAura",
		name = "Bubble Aura",
		slot = "Aura",
		icon = "💧",
		rarity = "Epic",
		description = "Pop! Pop! Pop!",
		source = "Shop",
		price = { currency = "Tokens", amount = 4500 },
		level = 12,
		visual = { primary = rgb(170, 225, 255), rate = 4, size = 0.9, speed = 1 },
	},
	{
		id = "StarAura",
		name = "Star Aura",
		slot = "Aura",
		icon = "🌠",
		rarity = "Legendary",
		description = "Sold only at the Lantern Festival booth.",
		source = "Festival",
		price = { currency = "Tickets", amount = 80 },
		level = 1,
		visual = { primary = rgb(255, 220, 90), rate = 8, size = 0.5, speed = 2 },
	},
}

local byId: { [string]: CosmeticDef } = {}
for _, def in DEFINITIONS do
	assert(byId[def.id] == nil, "duplicate cosmetic id " .. def.id)
	byId[def.id] = def
end

local Cosmetics = {}

Cosmetics.List = TableUtil.deepFreeze(DEFINITIONS)
Cosmetics.Slots = table.freeze({ "Hat", "Trail", "Aura" } :: { CosmeticSlot })

function Cosmetics.get(id: string): CosmeticDef?
	return byId[id]
end

function Cosmetics.exists(id: string): boolean
	return byId[id] ~= nil
end

function Cosmetics.isSlot(slot: string): boolean
	return slot == "Hat" or slot == "Trail" or slot == "Aura"
end

return table.freeze(Cosmetics)

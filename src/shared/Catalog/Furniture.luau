--!strict
--[[
	Furniture & House
	Every player's house has fixed furniture slots. A slot accepts furniture of
	its category. Each furniture piece has "comfort" points; the sum is the
	house's Home Rating, shown on the house sign (status, not power).
	Premium slots/paints require the "Dream Home Upgrade" game pass.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type FurnitureCategory = "Seat" | "Table" | "Light" | "Rug" | "Plant" | "Wall" | "Bed" | "Shelf" | "Garden" | "Balcony"

export type SlotDef = {
	id: string,
	name: string,
	category: FurnitureCategory,
	premium: boolean,
}

export type FurnitureDef = {
	id: string,
	name: string,
	icon: string,
	category: FurnitureCategory,
	comfort: number,
	description: string,
	source: "Shop" | "Festival" | "Quest",
	price: { currency: "Tokens" | "Tickets", amount: number }?,
	level: number,
	-- Builder used by Visuals/ModelFactory and its colors.
	model: { kind: string, primary: Color3, secondary: Color3? },
}

export type PaintDef = {
	id: string,
	name: string,
	wall: Color3,
	roof: Color3,
	premium: boolean,
}

local rgb = Color3.fromRGB

local SLOTS: { SlotDef } = {
	{ id = "Seat", name = "Seat", category = "Seat", premium = false },
	{ id = "Table", name = "Table", category = "Table", premium = false },
	{ id = "Light", name = "Lamp", category = "Light", premium = false },
	{ id = "Rug", name = "Rug", category = "Rug", premium = false },
	{ id = "Plant", name = "Plant", category = "Plant", premium = false },
	{ id = "Wall", name = "Wall Decor", category = "Wall", premium = false },
	{ id = "Bed", name = "Bed", category = "Bed", premium = false },
	{ id = "Shelf", name = "Shelf", category = "Shelf", premium = false },
	{ id = "Garden1", name = "Garden (left)", category = "Garden", premium = true },
	{ id = "Garden2", name = "Garden (right)", category = "Garden", premium = true },
	{ id = "Balcony", name = "Balcony", category = "Balcony", premium = true },
}

local FURNITURE: { FurnitureDef } = {
	-- Seats
	{
		id = "WoodenStool",
		name = "Wooden Stool",
		icon = "🪑",
		category = "Seat",
		comfort = 2,
		description = "Simple, sturdy, a little wobbly.",
		source = "Shop",
		price = { currency = "Tokens", amount = 60 },
		level = 1,
		model = { kind = "Stool", primary = rgb(164, 116, 73) },
	},
	{
		id = "Beanbag",
		name = "Beanbag",
		icon = "🛋️",
		category = "Seat",
		comfort = 5,
		description = "Sink in and never get up.",
		source = "Shop",
		price = { currency = "Tokens", amount = 300 },
		level = 1,
		model = { kind = "Beanbag", primary = rgb(240, 130, 90) },
	},
	{
		id = "ComfySofa",
		name = "Comfy Sofa",
		icon = "🛋️",
		category = "Seat",
		comfort = 8,
		description = "Room for you and two best friends.",
		source = "Shop",
		price = { currency = "Tokens", amount = 450 },
		level = 2,
		model = { kind = "Sofa", primary = rgb(90, 140, 200), secondary = rgb(70, 110, 170) },
	},
	{
		id = "RoyalArmchair",
		name = "Royal Armchair",
		icon = "👑",
		category = "Seat",
		comfort = 18,
		description = "Velvet cushions fit for a mayor.",
		source = "Shop",
		price = { currency = "Tokens", amount = 2400 },
		level = 8,
		model = { kind = "Armchair", primary = rgb(150, 40, 60), secondary = rgb(255, 196, 60) },
	},
	-- Tables
	{
		id = "SmallTable",
		name = "Small Table",
		icon = "🟫",
		category = "Table",
		comfort = 2,
		description = "Holds exactly one cup of cocoa.",
		source = "Shop",
		price = { currency = "Tokens", amount = 80 },
		level = 1,
		model = { kind = "Table", primary = rgb(176, 128, 82) },
	},
	{
		id = "CoffeeTable",
		name = "Coffee Table",
		icon = "☕",
		category = "Table",
		comfort = 6,
		description = "Low, wide and great for board games.",
		source = "Shop",
		price = { currency = "Tokens", amount = 380 },
		level = 2,
		model = { kind = "CoffeeTable", primary = rgb(120, 84, 56), secondary = rgb(230, 230, 230) },
	},
	{
		id = "WritingDesk",
		name = "Writing Desk",
		icon = "📝",
		category = "Table",
		comfort = 10,
		description = "For writing postcards to faraway friends.",
		source = "Shop",
		price = { currency = "Tokens", amount = 900 },
		level = 4,
		model = { kind = "Desk", primary = rgb(98, 70, 48), secondary = rgb(60, 140, 90) },
	},
	-- Lights
	{
		id = "FloorLamp",
		name = "Floor Lamp",
		icon = "💡",
		category = "Light",
		comfort = 3,
		description = "Warm light for cozy evenings.",
		source = "Shop",
		price = { currency = "Tokens", amount = 150 },
		level = 1,
		model = { kind = "FloorLamp", primary = rgb(60, 60, 66), secondary = rgb(255, 236, 190) },
	},
	{
		id = "LavaLamp",
		name = "Lava Lamp",
		icon = "🔮",
		category = "Light",
		comfort = 8,
		description = "Blob. Blob. Blob. Hypnotic.",
		source = "Shop",
		price = { currency = "Tokens", amount = 700 },
		level = 3,
		model = { kind = "LavaLamp", primary = rgb(150, 150, 160), secondary = rgb(255, 90, 160) },
	},
	{
		id = "PaperLantern",
		name = "Paper Lantern",
		icon = "🏮",
		category = "Light",
		comfort = 9,
		description = "A keepsake from the Lantern Festival.",
		source = "Festival",
		price = { currency = "Tickets", amount = 25 },
		level = 1,
		model = { kind = "PaperLantern", primary = rgb(226, 60, 50), secondary = rgb(255, 205, 80) },
	},
	-- Rugs
	{
		id = "StripedRug",
		name = "Striped Rug",
		icon = "🟥",
		category = "Rug",
		comfort = 2,
		description = "Red and white, like a picnic blanket.",
		source = "Shop",
		price = { currency = "Tokens", amount = 120 },
		level = 1,
		model = { kind = "Rug", primary = rgb(210, 70, 70), secondary = rgb(245, 240, 230) },
	},
	{
		id = "CozyRug",
		name = "Cozy Round Rug",
		icon = "🟣",
		category = "Rug",
		comfort = 7,
		description = "So soft your pet will claim it immediately.",
		source = "Shop",
		price = { currency = "Tokens", amount = 520 },
		level = 3,
		model = { kind = "RoundRug", primary = rgb(150, 110, 200), secondary = rgb(200, 170, 240) },
	},
	-- Plants
	{
		id = "PottedFern",
		name = "Potted Fern",
		icon = "🌿",
		category = "Plant",
		comfort = 2,
		description = "Very hard to kill. A great first plant.",
		source = "Shop",
		price = { currency = "Tokens", amount = 90 },
		level = 1,
		model = { kind = "Plant", primary = rgb(70, 150, 70), secondary = rgb(190, 110, 70) },
	},
	{
		id = "SunflowerPot",
		name = "Sunflower Pot",
		icon = "🌻",
		category = "Plant",
		comfort = 6,
		description = "Always facing the nearest window.",
		source = "Shop",
		price = { currency = "Tokens", amount = 400 },
		level = 2,
		model = { kind = "Flower", primary = rgb(255, 205, 50), secondary = rgb(190, 110, 70) },
	},
	{
		id = "BonsaiTree",
		name = "Bonsai Tree",
		icon = "🌳",
		category = "Plant",
		comfort = 14,
		description = "Patiently trimmed for a hundred years. Or a week.",
		source = "Shop",
		price = { currency = "Tokens", amount = 1600 },
		level = 6,
		model = { kind = "Bonsai", primary = rgb(60, 130, 70), secondary = rgb(80, 60, 50) },
	},
	-- Wall decor
	{
		id = "SeasidePainting",
		name = "Seaside Painting",
		icon = "🖼️",
		category = "Wall",
		comfort = 5,
		description = "A calm view of Brightbrook Lake.",
		source = "Shop",
		price = { currency = "Tokens", amount = 300 },
		level = 2,
		model = { kind = "Painting", primary = rgb(90, 160, 220), secondary = rgb(150, 110, 60) },
	},
	{
		id = "CuckooClock",
		name = "Cuckoo Clock",
		icon = "🕰️",
		category = "Wall",
		comfort = 11,
		description = "Cuckoo! (It is always the right time for cocoa.)",
		source = "Shop",
		price = { currency = "Tokens", amount = 1100 },
		level = 5,
		model = { kind = "Clock", primary = rgb(120, 80, 50), secondary = rgb(245, 240, 225) },
	},
	-- Beds
	{
		id = "SimpleBed",
		name = "Simple Bed",
		icon = "🛏️",
		category = "Bed",
		comfort = 4,
		description = "Good night, Brightbrook.",
		source = "Shop",
		price = { currency = "Tokens", amount = 200 },
		level = 1,
		model = { kind = "Bed", primary = rgb(170, 120, 80), secondary = rgb(110, 170, 230) },
	},
	{
		id = "CanopyBed",
		name = "Canopy Bed",
		icon = "🛏️",
		category = "Bed",
		comfort = 20,
		description = "Dreams come in extra-large.",
		source = "Shop",
		price = { currency = "Tokens", amount = 2800 },
		level = 9,
		model = { kind = "CanopyBed", primary = rgb(240, 236, 228), secondary = rgb(200, 120, 160) },
	},
	-- Shelves
	{
		id = "Bookshelf",
		name = "Bookshelf",
		icon = "📚",
		category = "Shelf",
		comfort = 8,
		description = "Full of mysteries, recipes and fishing manuals.",
		source = "Shop",
		price = { currency = "Tokens", amount = 650 },
		level = 3,
		model = { kind = "Bookshelf", primary = rgb(120, 84, 56) },
	},
	{
		id = "FishTank",
		name = "Fish Tank",
		icon = "🐠",
		category = "Shelf",
		comfort = 16,
		description = "Your very own tiny lake.",
		source = "Shop",
		price = { currency = "Tokens", amount = 2000 },
		level = 7,
		model = { kind = "FishTank", primary = rgb(60, 60, 70), secondary = rgb(90, 180, 230) },
	},
	-- Garden (premium slots)
	{
		id = "FlowerBed",
		name = "Flower Bed",
		icon = "🌷",
		category = "Garden",
		comfort = 7,
		description = "Tulips in every color.",
		source = "Shop",
		price = { currency = "Tokens", amount = 500 },
		level = 1,
		model = { kind = "FlowerBed", primary = rgb(255, 110, 150), secondary = rgb(110, 80, 60) },
	},
	{
		id = "GardenGnome",
		name = "Garden Gnome",
		icon = "🍄",
		category = "Garden",
		comfort = 5,
		description = "He sees everything. He says nothing.",
		source = "Shop",
		price = { currency = "Tokens", amount = 350 },
		level = 1,
		model = { kind = "Gnome", primary = rgb(220, 50, 50), secondary = rgb(80, 120, 200) },
	},
	{
		id = "BirdBath",
		name = "Bird Bath",
		icon = "🐦",
		category = "Garden",
		comfort = 10,
		description = "Local birds rate it five stars.",
		source = "Shop",
		price = { currency = "Tokens", amount = 900 },
		level = 4,
		model = { kind = "BirdBath", primary = rgb(200, 200, 205), secondary = rgb(120, 190, 230) },
	},
	-- Balcony (premium slot)
	{
		id = "Hammock",
		name = "Hammock",
		icon = "🌴",
		category = "Balcony",
		comfort = 12,
		description = "The official Brightbrook nap spot.",
		source = "Shop",
		price = { currency = "Tokens", amount = 1200 },
		level = 1,
		model = { kind = "Hammock", primary = rgb(240, 200, 120), secondary = rgb(130, 90, 60) },
	},
	{
		id = "Telescope",
		name = "Telescope",
		icon = "🔭",
		category = "Balcony",
		comfort = 22,
		description = "Is that... a Moon Koi in the sky?",
		source = "Shop",
		price = { currency = "Tokens", amount = 3000 },
		level = 10,
		model = { kind = "Telescope", primary = rgb(70, 80, 110), secondary = rgb(200, 170, 90) },
	},
}

local PAINTS: { PaintDef } = {
	{ id = "Cream", name = "Cream", wall = rgb(245, 232, 205), roof = rgb(176, 84, 70), premium = false },
	{ id = "Sky", name = "Sky", wall = rgb(180, 214, 240), roof = rgb(70, 96, 150), premium = false },
	{ id = "Mint", name = "Mint", wall = rgb(190, 236, 210), roof = rgb(60, 130, 100), premium = false },
	{ id = "Peach", name = "Peach", wall = rgb(255, 210, 180), roof = rgb(190, 100, 70), premium = false },
	{ id = "Lilac", name = "Lilac", wall = rgb(214, 196, 240), roof = rgb(110, 80, 150), premium = false },
	{ id = "Butter", name = "Butter", wall = rgb(255, 238, 160), roof = rgb(150, 110, 60), premium = false },
	{ id = "Royal", name = "Royal Blue", wall = rgb(60, 90, 180), roof = rgb(240, 200, 80), premium = true },
	{ id = "Midnight", name = "Midnight", wall = rgb(40, 44, 70), roof = rgb(120, 130, 200), premium = true },
	{ id = "RoseGold", name = "Rose Gold", wall = rgb(236, 180, 170), roof = rgb(180, 120, 110), premium = true },
	{ id = "Emerald", name = "Emerald", wall = rgb(40, 150, 100), roof = rgb(240, 236, 220), premium = true },
	{ id = "Coral", name = "Coral", wall = rgb(255, 130, 110), roof = rgb(90, 70, 120), premium = true },
	{ id = "Charcoal", name = "Charcoal", wall = rgb(70, 72, 78), roof = rgb(200, 90, 60), premium = true },
}

local slotById: { [string]: SlotDef } = {}
for _, slot in SLOTS do
	assert(slotById[slot.id] == nil, "duplicate slot " .. slot.id)
	slotById[slot.id] = slot
end

local furnitureById: { [string]: FurnitureDef } = {}
for _, def in FURNITURE do
	assert(furnitureById[def.id] == nil, "duplicate furniture " .. def.id)
	furnitureById[def.id] = def
end

local paintById: { [string]: PaintDef } = {}
for _, paint in PAINTS do
	assert(paintById[paint.id] == nil, "duplicate paint " .. paint.id)
	paintById[paint.id] = paint
end

local Furniture = {}

Furniture.Slots = TableUtil.deepFreeze(SLOTS)
Furniture.List = TableUtil.deepFreeze(FURNITURE)
Furniture.Paints = TableUtil.deepFreeze(PAINTS)
Furniture.DefaultPaint = "Cream"

function Furniture.get(id: string): FurnitureDef?
	return furnitureById[id]
end

function Furniture.getSlot(id: string): SlotDef?
	return slotById[id]
end

function Furniture.getPaint(id: string): PaintDef?
	return paintById[id]
end

return table.freeze(Furniture)

--!strict
--[[
	Collections
	Albums filled by playing: every fruit picked, fish caught, postcard found and
	neighbor met is recorded. Completing an album unlocks a one-time reward that
	the player claims from the Collections screen.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local Tuning = require(script.Parent.Parent.Config.Tuning)

export type EntryDef = { id: string, name: string, icon: string?, hint: string? }

export type CollectionDef = {
	id: string,
	name: string,
	icon: string,
	description: string,
	entries: { EntryDef },
	reward: Tuning.Reward,
}

local DEFINITIONS: { CollectionDef } = {
	{
		id = "fruits",
		name = "Orchard Album",
		icon = "🧺",
		description = "Pick every kind of fruit that grows in Brightbrook.",
		entries = {
			{ id = "Apple", name = "Apple", icon = "🍎" },
			{ id = "Grapes", name = "Grapes", icon = "🍇" },
			{ id = "Orange", name = "Orange", icon = "🍊" },
			{ id = "GoldenApple", name = "Golden Apple", icon = "🌟" },
			{ id = "Cherry", name = "Cherries", icon = "🍒" },
			{ id = "Starfruit", name = "Starfruit", icon = "⭐" },
		},
		reward = { Tokens = 500, Cosmetics = { "LeafTrail" } },
	},
	{
		id = "fish",
		name = "Angler's Album",
		icon = "🎣",
		description = "Catch every fish (and one boot) in Brightbrook's waters.",
		entries = {
			{ id = "Minnow", name = "Minnow", icon = "🐟" },
			{ id = "Perch", name = "Perch", icon = "🐟" },
			{ id = "Trout", name = "Rainbow Trout", icon = "🐠" },
			{ id = "Pufferfish", name = "Pufferfish", icon = "🐡" },
			{ id = "GoldenCarp", name = "Golden Carp", icon = "🐠" },
			{ id = "MoonKoi", name = "Moon Koi", icon = "🎏" },
			{ id = "OldBoot", name = "Old Boot", icon = "👢" },
		},
		reward = { Tokens = 1500, Pets = { "Turtle" } },
	},
	{
		id = "postcards",
		name = "Postcards of Brightbrook",
		icon = "💌",
		description = "Twelve postcards are hidden around town. Can you find them all?",
		entries = {
			{ id = "Fountain", name = "Town Fountain", hint = "Where wishes are made in the Town Square." },
			{ id = "ClockTower", name = "Clock Tower", hint = "High above the shops, where time is kept." },
			{ id = "BakeryChimney", name = "Bakery Chimney", hint = "Behind the bakery, it smells like fresh bread." },
			{ id = "Mailroom", name = "Mailroom", hint = "Where every parcel starts its journey." },
			{ id = "Playground", name = "Playground", hint = "At the top of the slide in Sunny Park." },
			{ id = "GardenShed", name = "Garden Shed", hint = "Gardener Gwen keeps her tools here." },
			{ id = "MapleLane", name = "Maple Lane", hint = "At the far end of the street where everyone lives." },
			{ id = "Bandstand", name = "Bandstand", hint = "Where the music plays in the park." },
			{ id = "OldDock", name = "Old Dock", hint = "At the very end of the fishing dock." },
			{ id = "Lighthouse", name = "Lighthouse", hint = "At the foot of the tallest light by the lake." },
			{ id = "Lookout", name = "Hilltop Lookout", hint = "Climb the tower in the Hilltop Orchard." },
			{ id = "MoonPond", name = "Moon Pond", hint = "Where the moon likes to swim, up on the hill." },
		},
		reward = { Tokens = 1000, Cosmetics = { "ExplorerHat" } },
	},
	{
		id = "neighbors",
		name = "Friendly Faces",
		icon = "🤝",
		description = "Say hello to everyone who works in Brightbrook.",
		entries = {
			{ id = "Mayor", name = "Mayor Maple", icon = "🎩" },
			{ id = "Postmaster", name = "Postmaster Pia", icon = "📮" },
			{ id = "Baker", name = "Baker Bram", icon = "🥐" },
			{ id = "Shopkeeper", name = "Shopkeeper Sam", icon = "🛍️" },
			{ id = "PetKeeper", name = "Pet Shop Pat", icon = "🐾" },
			{ id = "Fisher", name = "Fisher Finn", icon = "🎣" },
			{ id = "Gardener", name = "Gardener Gwen", icon = "🌻" },
			{ id = "FestivalHost", name = "Festival Host Fay", icon = "🏮" },
		},
		reward = { Tokens = 300 },
	},
}

local byId: { [string]: CollectionDef } = {}
for _, def in DEFINITIONS do
	assert(byId[def.id] == nil, "duplicate collection " .. def.id)
	local seen: { [string]: boolean } = {}
	for _, entry in def.entries do
		assert(not seen[entry.id], "duplicate entry " .. entry.id .. " in " .. def.id)
		seen[entry.id] = true
	end
	byId[def.id] = def
end

local Collections = {}

Collections.List = TableUtil.deepFreeze(DEFINITIONS)

function Collections.get(id: string): CollectionDef?
	return byId[id]
end

function Collections.hasEntry(collectionId: string, entryId: string): boolean
	local def = byId[collectionId]
	if not def then
		return false
	end
	for _, entry in def.entries do
		if entry.id == entryId then
			return true
		end
	end
	return false
end

return table.freeze(Collections)

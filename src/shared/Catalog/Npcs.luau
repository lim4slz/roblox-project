--!strict
--[[
	Npcs
	The townsfolk players talk to. Each NPC has a role, the services offered in
	its dialogue and a few lines of personality. World placement lives in
	server/World/WorldLayout.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type NpcService = "Shop" | "Sell" | "Pets" | "Festival" | "Upgrades" | "Premium" | "Garden" | "Fishing" | "Deliveries"

export type NpcDef = {
	id: string,
	name: string,
	role: string,
	icon: string,
	area: string,
	services: { NpcService },
	greetings: { string },
	-- Character colors (Roblox body colors) and an optional hat kind for silhouettes.
	look: { skin: Color3, shirt: Color3, pants: Color3, hat: string? },
}

local rgb = Color3.fromRGB

local DEFINITIONS: { NpcDef } = {
	{
		id = "Mayor",
		name = "Mayor Maple",
		role = "Mayor of Brightbrook",
		icon = "🎩",
		area = "Town",
		services = {},
		greetings = {
			"Welcome, welcome! Brightbrook is so much brighter with you here.",
			"Have you met everyone in town yet? Friendly faces make a happy town!",
			"Between you and me, there are postcards hidden all over Brightbrook...",
		},
		look = { skin = rgb(234, 184, 146), shirt = rgb(120, 40, 60), pants = rgb(40, 40, 50), hat = "TopHat" },
	},
	{
		id = "Postmaster",
		name = "Postmaster Pia",
		role = "Post Office",
		icon = "📮",
		area = "Town",
		services = { "Deliveries" },
		greetings = {
			"Parcels in, smiles out! Grab a parcel from the counter whenever you like.",
			"Every delivery makes someone's day. And pays nicely, too!",
			"Express parcels pay extra if you're quick on your feet!",
		},
		look = { skin = rgb(160, 110, 80), shirt = rgb(44, 92, 170), pants = rgb(30, 50, 90), hat = "Cap" },
	},
	{
		id = "Baker",
		name = "Baker Bram",
		role = "Bakery",
		icon = "🥐",
		area = "Town",
		services = {},
		greetings = {
			"Mmm, smell that? Fresh bread, every hour, on the hour.",
			"Fruit from Sunny Park makes the best pies. Bring me some sometime!",
			"I once baked a pie so big it needed its own delivery.",
		},
		look = { skin = rgb(240, 200, 170), shirt = rgb(250, 250, 250), pants = rgb(90, 90, 100), hat = "Chef" },
	},
	{
		id = "Shopkeeper",
		name = "Shopkeeper Sam",
		role = "General Store & Market",
		icon = "🛍️",
		area = "Town",
		services = { "Shop", "Sell", "Upgrades", "Premium" },
		greetings = {
			"Buying, selling, browsing? Sam's has it all!",
			"I'll pay fair prices for fruit and fish. Fresher is better!",
			"New furniture just arrived. Your house deserves a little love!",
		},
		look = { skin = rgb(200, 150, 110), shirt = rgb(60, 150, 100), pants = rgb(60, 50, 40) },
	},
	{
		id = "PetKeeper",
		name = "Pet Shop Pat",
		role = "Pet Shop",
		icon = "🐾",
		area = "Town",
		services = { "Pets" },
		greetings = {
			"Every pet here is looking for a best friend. Could it be you?",
			"Pets don't make you faster, but they make every day better!",
			"If you ever see a lost kitten, bring it right back to me, please!",
		},
		look = { skin = rgb(250, 210, 180), shirt = rgb(255, 170, 60), pants = rgb(80, 110, 160) },
	},
	{
		id = "Fisher",
		name = "Fisher Finn",
		role = "Fishing Dock",
		icon = "🎣",
		area = "Lakeside",
		services = { "Fishing" },
		greetings = {
			"Cast your line, wait for the bobber to dip, then reel it in fast!",
			"They say a Moon Koi lives in this lake. I've seen it! Probably.",
			"The Moon Pond up on the hill has rarer fish. Trust old Finn.",
		},
		look = { skin = rgb(190, 140, 100), shirt = rgb(220, 200, 80), pants = rgb(60, 80, 120), hat = "Bucket" },
	},
	{
		id = "Gardener",
		name = "Gardener Gwen",
		role = "Community Garden",
		icon = "🌻",
		area = "Park",
		services = { "Garden" },
		greetings = {
			"Thirsty flowers droop their heads. Give them a splash of water!",
			"When the whole garden blooms, everyone nearby gets a treat!",
			"Gardening is better together. Bring your friends!",
		},
		look = { skin = rgb(120, 80, 60), shirt = rgb(110, 170, 90), pants = rgb(120, 90, 60), hat = "Brim" },
	},
	{
		id = "FestivalHost",
		name = "Festival Host Fay",
		role = "Festival Booth",
		icon = "🏮",
		area = "Town",
		services = { "Festival" },
		greetings = {
			"The Lantern Festival happens every half hour. Catch the lanterns for tickets!",
			"Tickets can be swapped here for very special festival treasures.",
			"Lanterns float up from the square. Be quick, they don't wait!",
		},
		look = { skin = rgb(236, 190, 160), shirt = rgb(226, 60, 50), pants = rgb(255, 205, 80), hat = "Lantern" },
	},
}

local byId: { [string]: NpcDef } = {}
for _, def in DEFINITIONS do
	assert(byId[def.id] == nil, "duplicate npc " .. def.id)
	byId[def.id] = def
end

local Npcs = {}

Npcs.List = TableUtil.deepFreeze(DEFINITIONS)

function Npcs.get(id: string): NpcDef?
	return byId[id]
end

function Npcs.offers(id: string, service: NpcService): boolean
	local def = byId[id]
	return def ~= nil and table.find(def.services, service) ~= nil
end

return table.freeze(Npcs)

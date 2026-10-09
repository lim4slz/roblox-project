--!strict
--[[
	Titles
	Short labels shown under a player's name. Titles are earned automatically
	when their condition becomes true; the player chooses which one to display.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type Condition =
	{ kind: "Default" }
	| { kind: "Stat", stat: string, value: number }
	| { kind: "Level", value: number }
	| { kind: "Reputation", value: number }
	| { kind: "Collection", collection: string }
	| { kind: "Quest", quest: string }
	| { kind: "Pass", pass: string }
	| { kind: "Founder" }

export type TitleDef = {
	id: string,
	text: string,
	color: Color3,
	description: string,
	condition: Condition,
}

local rgb = Color3.fromRGB

local DEFINITIONS: { TitleDef } = {
	{
		id = "Newcomer",
		text = "Newcomer",
		color = rgb(200, 205, 215),
		description = "Welcome to Brightbrook!",
		condition = { kind = "Default" },
	},
	{
		id = "Resident",
		text = "Resident",
		color = rgb(130, 220, 180),
		description = "Finish your first day in town.",
		condition = { kind = "Quest", quest = "fresh_fruit" },
	},
	{
		id = "Courier",
		text = "Courier",
		color = rgb(110, 170, 255),
		description = "Complete 5 deliveries.",
		condition = { kind = "Stat", stat = "Deliveries", value = 5 },
	},
	{
		id = "HeadCourier",
		text = "Head Courier",
		color = rgb(80, 130, 255),
		description = "Complete 50 deliveries.",
		condition = { kind = "Stat", stat = "Deliveries", value = 50 },
	},
	{
		id = "Angler",
		text = "Angler",
		color = rgb(90, 200, 210),
		description = "Catch 10 fish.",
		condition = { kind = "Stat", stat = "FishCaught", value = 10 },
	},
	{
		id = "MasterAngler",
		text = "Master Angler",
		color = rgb(40, 170, 200),
		description = "Complete the Angler's Album.",
		condition = { kind = "Collection", collection = "fish" },
	},
	{
		id = "GreenThumb",
		text = "Green Thumb",
		color = rgb(120, 210, 100),
		description = "Water the Community Garden 25 times.",
		condition = { kind = "Stat", stat = "GardenWaterings", value = 25 },
	},
	{
		id = "Explorer",
		text = "Explorer",
		color = rgb(210, 170, 110),
		description = "Find all 12 postcards.",
		condition = { kind = "Collection", collection = "postcards" },
	},
	{
		id = "Neighbor",
		text = "Good Neighbor",
		color = rgb(255, 170, 120),
		description = "Meet everyone who works in Brightbrook.",
		condition = { kind = "Collection", collection = "neighbors" },
	},
	{
		id = "KittenHero",
		text = "Kitten Hero",
		color = rgb(255, 140, 190),
		description = "Rescue 3 lost kittens.",
		condition = { kind = "Stat", stat = "KittensRescued", value = 3 },
	},
	{
		id = "FestivalStar",
		text = "Festival Star",
		color = rgb(255, 205, 80),
		description = "Join 5 Lantern Festivals.",
		condition = { kind = "Stat", stat = "FestivalsAttended", value = 5 },
	},
	{
		id = "ModelCitizen",
		text = "Model Citizen",
		color = rgb(180, 130, 255),
		description = "Earn 100 Reputation by helping the town.",
		condition = { kind = "Reputation", value = 100 },
	},
	{
		id = "Veteran",
		text = "Veteran",
		color = rgb(220, 220, 235),
		description = "Reach level 20.",
		condition = { kind = "Level", value = 20 },
	},
	{
		id = "VIP",
		text = "VIP",
		color = rgb(255, 200, 60),
		description = "Brightbrook VIP members.",
		condition = { kind = "Pass", pass = "VIP" },
	},
	{
		id = "Founder",
		text = "Founder",
		color = rgb(255, 120, 140),
		description = "Joined during Brightbrook's first month.",
		condition = { kind = "Founder" },
	},
}

local byId: { [string]: TitleDef } = {}
for _, def in DEFINITIONS do
	assert(byId[def.id] == nil, "duplicate title " .. def.id)
	byId[def.id] = def
end

local Titles = {}

Titles.List = TableUtil.deepFreeze(DEFINITIONS)
Titles.Default = "Newcomer"

function Titles.get(id: string): TitleDef?
	return byId[id]
end

return table.freeze(Titles)

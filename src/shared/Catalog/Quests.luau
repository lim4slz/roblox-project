--!strict
--[[
	Quests
	Story quests form the onboarding chain and the long-term goals. They are
	accepted automatically once their requirements are met and complete
	automatically when their last objective is done. Objectives are ORDERED:
	only the current objective receives progress.

	Daily quests are generated each UTC day from the templates below
	(see Logic/QuestLogic.dailySelection).

	Objective types and the activity that advances them:
	  Talk          talk to `npc` (optionally handing in the `bring` items)
	  Deliver       complete a delivery (to `target` when given)
	  Pick          pick fruit (`item` when given)
	  Catch         catch a fish
	  Water         water the Community Garden
	  Postcard      find a hidden postcard
	  EnterArea     reach `area`
	  BuyFurniture  buy any furniture
	  PlaceFurniture place furniture in your house
	  LikeHouse     like a neighbor's house
	  Lantern       catch a festival lantern
	  Rescue        return a lost kitten
	  PartyActivity complete an activity with a party member nearby
	  SellValue     sell items worth `count` Tokens in total
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local Tuning = require(script.Parent.Parent.Config.Tuning)

export type ObjectiveType =
	"Talk"
	| "Deliver"
	| "Pick"
	| "Catch"
	| "Water"
	| "Postcard"
	| "EnterArea"
	| "BuyFurniture"
	| "PlaceFurniture"
	| "LikeHouse"
	| "Lantern"
	| "Rescue"
	| "PartyActivity"
	| "SellValue"

export type ObjectiveDef = {
	type: ObjectiveType,
	count: number,
	text: string,
	npc: string?,
	target: string?,
	item: string?,
	area: string?,
	bring: { [string]: number }?,
}

export type QuestDef = {
	id: string,
	title: string,
	giver: string, -- NPC id shown in the quest log
	description: string,
	level: number,
	requires: { string },
	objectives: { ObjectiveDef },
	reward: Tuning.Reward,
	-- Onboarding funnel step logged to analytics when this quest completes.
	onboardingStep: number?,
}

export type DailyTemplate = {
	id: string,
	title: string,
	type: ObjectiveType,
	minCount: number,
	maxCount: number,
	minLevel: number,
	text: string, -- "%d" is replaced with the target count
	reward: Tuning.Reward,
}

local STORY: { QuestDef } = {
	{
		id = "welcome",
		title = "Welcome to Brightbrook",
		giver = "Mayor",
		description = "Mayor Maple is waiting by the fountain to welcome you to town.",
		level = 1,
		requires = {},
		objectives = {
			{ type = "Talk", npc = "Mayor", count = 1, text = "Say hello to Mayor Maple at the fountain" },
		},
		reward = { XP = 20, Tokens = 25 },
		onboardingStep = 2,
	},
	{
		id = "first_delivery",
		title = "First Delivery",
		giver = "Postmaster",
		description = "Postmaster Pia needs a hand. Grab a parcel at the Post Office and take it to the Bakery.",
		level = 1,
		requires = { "welcome" },
		objectives = {
			{ type = "Deliver", target = "Bakery", count = 1, text = "Deliver a parcel to the Bakery" },
		},
		reward = { XP = 40, Tokens = 50 },
		onboardingStep = 3,
	},
	{
		id = "fresh_fruit",
		title = "Fresh Fruit for the Baker",
		giver = "Baker",
		description = "Baker Bram wants to bake an apple pie. Pick some apples in Sunny Park!",
		level = 1,
		requires = { "first_delivery" },
		objectives = {
			{ type = "Pick", item = "Apple", count = 3, text = "Pick 3 Apples in Sunny Park" },
			{ type = "Talk", npc = "Baker", bring = { Apple = 3 }, count = 1, text = "Bring 3 Apples to Baker Bram" },
		},
		reward = { XP = 30, Tokens = 60, Cosmetics = { "ChefHat" } },
		onboardingStep = 4,
	},
	{
		id = "friend_for_life",
		title = "A Friend for Life",
		giver = "PetKeeper",
		description = "Pet Shop Pat has a kitten looking for a hard-working best friend.",
		level = 1,
		requires = { "first_delivery" },
		objectives = {
			{ type = "Deliver", count = 3, text = "Complete 3 deliveries" },
			{ type = "Talk", npc = "PetKeeper", count = 1, text = "Visit Pet Shop Pat" },
		},
		reward = { XP = 60, Pets = { "Kitten" } },
	},
	{
		id = "gone_fishing",
		title = "Gone Fishing",
		giver = "Fisher",
		description = "Fisher Finn will teach you to fish at Brightbrook Lake.",
		level = 2,
		requires = { "fresh_fruit" },
		objectives = {
			{ type = "Talk", npc = "Fisher", count = 1, text = "Meet Fisher Finn at Brightbrook Lake" },
			{ type = "Catch", count = 1, text = "Catch a fish" },
		},
		reward = { XP = 50, Tokens = 75 },
	},
	{
		id = "home_sweet_home",
		title = "Home Sweet Home",
		giver = "Shopkeeper",
		description = "Your house on Maple Lane could use a personal touch.",
		level = 1,
		requires = { "fresh_fruit" },
		objectives = {
			{ type = "BuyFurniture", count = 1, text = "Buy a piece of furniture" },
			{ type = "PlaceFurniture", count = 1, text = "Place it in your house" },
		},
		reward = { XP = 80, Tokens = 150 },
	},
	{
		id = "festival_first",
		title = "Festival Lights",
		giver = "FestivalHost",
		description = "Lanterns float over the Town Square during every Lantern Festival.",
		level = 1,
		requires = { "fresh_fruit" },
		objectives = {
			{ type = "Lantern", count = 3, text = "Catch 3 lanterns during a Lantern Festival" },
		},
		reward = { XP = 60, Tickets = 5 },
	},
	{
		id = "party_time",
		title = "Better Together",
		giver = "Mayor",
		description = "Everything is more fun with friends. Form a party and work side by side!",
		level = 1,
		requires = { "fresh_fruit" },
		objectives = {
			{ type = "PartyActivity", count = 3, text = "Complete 3 activities with a party member nearby" },
		},
		reward = { XP = 120, Tokens = 150, Reputation = 3 },
	},
	{
		id = "social_butterfly",
		title = "Good Neighbors",
		giver = "Mayor",
		description = "Visit your neighbors on Maple Lane and show some love.",
		level = 1,
		requires = { "home_sweet_home" },
		objectives = {
			{ type = "LikeHouse", count = 2, text = "Like 2 neighbors' houses" },
		},
		reward = { XP = 50, Tokens = 100 },
	},
	{
		id = "helping_hands",
		title = "Helping Hands",
		giver = "Gardener",
		description = "The Community Garden blooms when the whole town pitches in.",
		level = 3,
		requires = { "gone_fishing" },
		objectives = {
			{ type = "Water", count = 3, text = "Water the Community Garden 3 times" },
		},
		reward = { XP = 80, Tokens = 120, Reputation = 5 },
	},
	{
		id = "kitten_rescue",
		title = "Lost and Found",
		giver = "PetKeeper",
		description = "Kittens love to wander off. When one goes missing, bring it back to the Pet Shop.",
		level = 3,
		requires = { "friend_for_life" },
		objectives = {
			{ type = "Rescue", count = 1, text = "Return a lost kitten to the Pet Shop" },
		},
		reward = { XP = 100, Tokens = 100 },
	},
	{
		id = "postcards_intro",
		title = "Postcards from Brightbrook",
		giver = "Mayor",
		description = "The Mayor hid postcards all over town. Find a few to start your album!",
		level = 4,
		requires = { "home_sweet_home" },
		objectives = {
			{ type = "Postcard", count = 3, text = "Find 3 hidden postcards" },
		},
		reward = { XP = 100, Tokens = 200 },
	},
	{
		id = "hilltop",
		title = "The Hilltop Orchard",
		giver = "Gardener",
		description = "Rare cherries grow on the hill above town.",
		level = 5,
		requires = { "helping_hands" },
		objectives = {
			{ type = "EnterArea", area = "Hilltop", count = 1, text = "Climb up to the Hilltop Orchard" },
			{ type = "Pick", item = "Cherry", count = 2, text = "Pick 2 Cherries" },
		},
		reward = { XP = 150, Tokens = 250 },
	},
	{
		id = "head_courier",
		title = "Head Courier",
		giver = "Postmaster",
		description = "Prove you are Brightbrook's most reliable courier.",
		level = 8,
		requires = { "friend_for_life" },
		objectives = {
			{ type = "Deliver", count = 20, text = "Complete 20 deliveries" },
		},
		reward = { XP = 300, Tokens = 500, Cosmetics = { "PostalCap" } },
	},
}

local DAILY: { DailyTemplate } = {
	{
		id = "d_deliver",
		title = "Parcel Rush",
		type = "Deliver",
		minCount = 3,
		maxCount = 5,
		minLevel = 1,
		text = "Complete %d deliveries",
		reward = { Tokens = 80, XP = 60 },
	},
	{
		id = "d_pick",
		title = "Fruit Basket",
		type = "Pick",
		minCount = 8,
		maxCount = 12,
		minLevel = 1,
		text = "Pick %d fruit",
		reward = { Tokens = 60, XP = 50 },
	},
	{
		id = "d_fish",
		title = "Catch of the Day",
		type = "Catch",
		minCount = 3,
		maxCount = 5,
		minLevel = 2,
		text = "Catch %d fish",
		reward = { Tokens = 80, XP = 70 },
	},
	{
		id = "d_water",
		title = "Green Day",
		type = "Water",
		minCount = 2,
		maxCount = 4,
		minLevel = 3,
		text = "Water the garden %d times",
		reward = { Tokens = 70, XP = 60 },
	},
	{
		id = "d_party",
		title = "Teamwork",
		type = "PartyActivity",
		minCount = 3,
		maxCount = 3,
		minLevel = 1,
		text = "Complete %d activities with a party member nearby",
		reward = { Tokens = 100, XP = 80 },
	},
	{
		id = "d_like",
		title = "Spread the Love",
		type = "LikeHouse",
		minCount = 2,
		maxCount = 2,
		minLevel = 1,
		text = "Like %d neighbors' houses",
		reward = { Tokens = 60, XP = 40 },
	},
	{
		id = "d_lantern",
		title = "Lantern Catcher",
		type = "Lantern",
		minCount = 3,
		maxCount = 3,
		minLevel = 1,
		text = "Catch %d festival lanterns",
		reward = { Tokens = 60, Tickets = 3, XP = 50 },
	},
	{
		id = "d_sell",
		title = "Market Day",
		type = "SellValue",
		minCount = 100,
		maxCount = 100,
		minLevel = 1,
		text = "Sell items worth %d Tokens",
		reward = { Tokens = 50, XP = 40 },
	},
}

local storyById: { [string]: QuestDef } = {}
for _, def in STORY do
	assert(storyById[def.id] == nil, "duplicate quest " .. def.id)
	storyById[def.id] = def
end

local dailyById: { [string]: DailyTemplate } = {}
for _, def in DAILY do
	assert(dailyById[def.id] == nil, "duplicate daily quest " .. def.id)
	dailyById[def.id] = def
end

local Quests = {}

Quests.Story = TableUtil.deepFreeze(STORY)
Quests.Daily = TableUtil.deepFreeze(DAILY)

function Quests.get(id: string): QuestDef?
	return storyById[id]
end

function Quests.getDaily(id: string): DailyTemplate?
	return dailyById[id]
end

return table.freeze(Quests)

--!strict
--[[
	Tuning
	Every gameplay / economy number in one place so balancing never requires
	touching logic. See docs/GAME_DESIGN.md for the reasoning behind the values.

	Income target for an engaged player: ~30-45 Tokens per active minute.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type Reward = {
	Tokens: number?,
	Tickets: number?,
	XP: number?,
	Reputation: number?,
	Items: { [string]: number }?,
	Cosmetics: { string }?,
	Furniture: { string }?,
	Pets: { string }?,
	Titles: { string }?,
}

local Tuning = {
	Progression = {
		MaxLevel = 50,
		-- XP needed to go from level L to L+1 = round(XpBase * L ^ XpExponent)
		XpBase = 80,
		XpExponent = 1.35,
		LevelUpTokensPerLevel = 20,
	},

	Backpack = {
		BaseCapacity = 20,
		BigBackpackBonus = 30,
		-- Bought in order with Tokens (a long-term sink).
		Upgrades = {
			{ id = "Satchel", name = "Satchel", bonus = 10, price = 600, level = 2 },
			{ id = "Rucksack", name = "Rucksack", bonus = 15, price = 2000, level = 5 },
			{ id = "ExplorerPack", name = "Explorer Pack", bonus = 20, price = 6000, level = 10 },
		},
	},

	Delivery = {
		BaseTokens = 20,
		TokensPerStud = 1 / 12,
		BaseXP = 35,
		XPPerStud = 1 / 15,
		ExpressMinLevel = 6,
		ExpressChance = 0.3,
		ExpressMultiplier = 1.5,
		-- Par time for express deliveries: distance / ExpressParSpeed + ExpressParBonus seconds.
		ExpressParSpeed = 10,
		ExpressParBonus = 12,
		-- A delivery that is not completed in this time is cancelled.
		ExpireSeconds = 600,
		PickupCooldown = 2,
		TutorialTarget = "Bakery",
	},

	Foraging = {
		RegrowSeconds = 18,
		PlayerCooldown = 0.6,
		-- The very first pick of a new player also yields this item ("first surprise").
		FirstPickBonusItem = "GoldenApple",
	},

	Fishing = {
		MinLevel = 2,
		BiteDelayMin = 2.5,
		BiteDelayMax = 6,
		ReelWindow = 1.8,
		LatencyGrace = 0.35,
		Cooldown = 1.5,
		SessionTimeout = 15,
	},

	Garden = {
		MinLevel = 3,
		HappySeconds = 45,
		BloomPerWatering = 4, -- percent of the bloom meter
		BloomDuration = 45,
		PlayerCooldown = 2,
		BystanderRadius = 70,
		WaterReward = { Tokens = 8, XP = 12, Reputation = 1 },
		BloomParticipantReward = { Tokens = 100, XP = 60, Reputation = 2 },
		BloomBystanderReward = { Tokens = 40, XP = 20 },
	},

	Postcards = {
		Reward = { Tokens = 25, XP = 30 },
	},

	Festival = {
		Period = 1800, -- a Lantern Festival every 30 minutes (UTC aligned)
		Duration = 180,
		AnnounceAhead = 120,
		Offset = 0,
		LanternCount = 24,
		LanternRespawnSeconds = 4,
		MaxLanternsPerPlayer = 15,
		LanternReward = { Tickets = 1, XP = 15 },
	},

	Kitten = {
		MinInterval = 540,
		MaxInterval = 840,
		-- A lost kitten waits this long to be found before wandering home on its own.
		HideTimeout = 300,
		CarryTimeout = 240,
		Reward = { Tokens = 150, XP = 80, Reputation = 3 },
	},

	House = {
		PaintPrice = 100,
		MaxLikesPerDay = 5,
		LikeReward = { XP = 5 },
	},

	Party = {
		MaxSize = 4,
		InviteTimeout = 30,
		InviteCooldown = 4,
		XPBonus = 0.1,
		BonusRadius = 80,
	},

	DailyLogin = {
		VipTokenMultiplier = 1.5,
		VipPlusBonusTokens = 100,
	},

	DailyQuests = {
		Count = 3,
		BonusReward = { Tokens = 150, Tickets = 5, Reputation = 3 },
	},

	Community = {
		-- Weekly cross-server goal: total flowers bloomed (garden waterings) by everyone.
		WeeklyGoal = 25000,
		Reward = { Tokens = 750, Tickets = 10 },
	},

	Monetization = {
		-- Pressure budget: at most this many unsolicited offers per session.
		MaxProactiveOffersPerSession = 1,
		-- ...and never before the player has played this long in the session.
		OfferMinSessionSeconds = 240,
	},

	Titles = {
		ModelCitizenReputation = 100,
	},
}

return TableUtil.deepFreeze(Tuning)

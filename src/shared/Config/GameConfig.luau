--!strict
--[[
	GameConfig
	Infrastructure-level settings: persistence, networking limits, security
	thresholds, scheduling. Gameplay/economy numbers live in Config/Tuning.
	Monetization IDs live in Catalog/Products (they must be filled in after the
	experience is published - see docs/PUBLISHING.md).
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local GameConfig = {
	GameName = "Brightbrook",
	Tagline = "Town & Adventure",
	Version = "1.0.0",

	-- Release date used for the "Founder" title (players who join in the first 30 days).
	LaunchTimestamp = 1793404800, -- 2026-11-01 00:00:00 UTC
	FounderWindowDays = 30,

	Data = {
		StoreName = "BrightbrookPlayerData_v1",
		KeyPrefix = "Player_",
		SchemaVersion = 1,
		-- In Studio, profiles use ProfileStore.Mock so playtests never touch live keys.
		-- Set to false (with Studio API access enabled) to test real persistence.
		UseMockInStudio = true,
		-- PurchaseIds remembered per profile to make receipt processing idempotent.
		PurchaseIdCacheSize = 100,
		MaxTokens = 999_999_999,
		MaxTickets = 999_999,
		MaxItemStack = 999,
	},

	Network = {
		-- Payloads larger than this (in serialized characters) are rejected outright.
		MaxPayloadChars = 2000,
		-- Generic per-player budget across all requests (token bucket).
		GlobalBurst = 30,
		GlobalPerSecond = 12,
	},

	Security = {
		-- Strikes are added for malformed or rate-limited requests and impossible actions.
		StrikeWindowSeconds = 60,
		KickStrikeThreshold = 60,
		-- Extra studs tolerated on top of a ProximityPrompt's activation distance (lag).
		ProximityTolerance = 6,
		-- Interaction range used for NPC/shop requests that do not come from a prompt.
		NpcInteractionRange = 18,
		-- Maximum believable movement speed (studs/s) used to reject teleport exploits.
		MaxTravelSpeed = 16 * 1.6,
	},

	World = {
		DayLengthMinutes = 20,
		ZoneCheckInterval = 0.5,
		SpawnProtectionSeconds = 2,
	},

	Leaderboards = {
		WriteInterval = 150, -- seconds between OrderedDataStore writes for online players
		ReadInterval = 120, -- seconds between refreshes of the top entries
		TopCount = 10,
	},

	CommunityGoal = {
		MapName = "BrightbrookCommunityGoal",
		FlushInterval = 30, -- seconds between MemoryStore increments
		Topic = "BrightbrookCommunity",
	},

	Analytics = {
		-- Prints every analytics event to the output while in Studio.
		VerboseInStudio = true,
		-- Number of recent events kept in memory (debug panel / tests).
		RingBufferSize = 200,
	},
}

return TableUtil.deepFreeze(GameConfig)

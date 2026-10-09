--!strict
--[[
	DailyRewards
	A 7-day login calendar. Claiming on consecutive UTC days advances the streak;
	missing a day restarts at day 1. Day 7 loops back to day 1 afterwards.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local Tuning = require(script.Parent.Parent.Config.Tuning)

export type DayReward = {
	day: number,
	reward: Tuning.Reward,
	-- Cosmetic granted on this day if not owned yet (otherwise `duplicateTokens`).
	cosmetic: string?,
	duplicateTokens: number?,
}

local DAYS: { DayReward } = {
	{ day = 1, reward = { Tokens = 50 } },
	{ day = 2, reward = { Tokens = 75 } },
	{ day = 3, reward = { Tokens = 100, Tickets = 2 } },
	{ day = 4, reward = { Tokens = 125 } },
	{ day = 5, reward = { Tokens = 150, Tickets = 3 } },
	{ day = 6, reward = { Tokens = 200 } },
	{ day = 7, reward = { Tokens = 300, Tickets = 10 }, cosmetic = "PartyCone", duplicateTokens = 200 },
}

local DailyRewards = {}

DailyRewards.Days = TableUtil.deepFreeze(DAYS)
DailyRewards.Length = #DAYS

function DailyRewards.forDay(day: number): DayReward
	local index = ((day - 1) % #DAYS) + 1
	return DAYS[index]
end

return table.freeze(DailyRewards)

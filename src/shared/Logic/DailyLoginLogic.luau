--!strict
--[[
	DailyLoginLogic
	Streak rules for the 7-day login calendar (days are UTC day numbers).
]]

local DailyRewards = require(script.Parent.Parent.Catalog.DailyRewards)
local DataSchema = require(script.Parent.DataSchema)

type PlayerData = DataSchema.PlayerData

export type Status = {
	canClaim: boolean,
	-- Calendar day (1-7) that will be / was claimed today.
	day: number,
	-- Streak value after claiming today.
	streak: number,
}

local DailyLoginLogic = {}

function DailyLoginLogic.status(data: PlayerData, today: number): Status
	local login = data.Login
	if login.LastClaimDay == today then
		return {
			canClaim = false,
			day = ((math.max(login.Streak, 1) - 1) % DailyRewards.Length) + 1,
			streak = login.Streak,
		}
	end
	local streak = if login.LastClaimDay == today - 1 then login.Streak + 1 else 1
	return {
		canClaim = true,
		day = ((streak - 1) % DailyRewards.Length) + 1,
		streak = streak,
	}
end

--- Records today's claim. Returns the calendar entry to grant, or nil if already claimed.
function DailyLoginLogic.claim(data: PlayerData, today: number): DailyRewards.DayReward?
	local status = DailyLoginLogic.status(data, today)
	if not status.canClaim then
		return nil
	end
	data.Login.LastClaimDay = today
	data.Login.Streak = status.streak
	return DailyRewards.forDay(status.day)
end

return table.freeze(DailyLoginLogic)

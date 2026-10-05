--!strict
--[[
	TimeUtil
	Calendar math on UTC unix timestamps. Every server computes the same values
	from the same timestamp, which keeps daily resets, weekly leaderboards and
	scheduled festivals in sync across servers without any messaging.
]]

local SECONDS_PER_DAY = 86400
local SECONDS_PER_WEEK = 604800
-- 1970-01-01 was a Thursday; shifting by 3 days makes weeks start on Monday 00:00 UTC.
local WEEK_OFFSET = 3 * SECONDS_PER_DAY

local TimeUtil = {}

TimeUtil.SECONDS_PER_DAY = SECONDS_PER_DAY
TimeUtil.SECONDS_PER_WEEK = SECONDS_PER_WEEK

--- Days since the unix epoch (UTC). Changes at 00:00 UTC.
function TimeUtil.dayNumber(timestamp: number): number
	return timestamp // SECONDS_PER_DAY
end

--- Weeks since the epoch, with weeks starting Monday 00:00 UTC.
function TimeUtil.weekNumber(timestamp: number): number
	return (timestamp + WEEK_OFFSET) // SECONDS_PER_WEEK
end

function TimeUtil.secondsUntilNextDay(timestamp: number): number
	return SECONDS_PER_DAY - (timestamp % SECONDS_PER_DAY)
end

function TimeUtil.secondsUntilNextWeek(timestamp: number): number
	return SECONDS_PER_WEEK - ((timestamp + WEEK_OFFSET) % SECONDS_PER_WEEK)
end

export type ScheduleState = {
	active: boolean,
	startedAt: number, -- start of the current (or most recent) occurrence
	endsAt: number, -- end of the current (or most recent) occurrence
	nextStart: number, -- start of the next occurrence that has not begun yet
}

--- Evaluates a repeating schedule: an event of `duration` seconds every `period` seconds,
--- with occurrences starting at `offset` seconds past each period boundary (UTC aligned).
function TimeUtil.schedule(timestamp: number, period: number, duration: number, offset: number?): ScheduleState
	assert(period > 0 and duration > 0 and duration <= period, "invalid schedule")
	local shift = offset or 0
	local cycleStart = ((timestamp - shift) // period) * period + shift
	local endsAt = cycleStart + duration
	return {
		active = timestamp >= cycleStart and timestamp < endsAt,
		startedAt = cycleStart,
		endsAt = endsAt,
		nextStart = cycleStart + period,
	}
end

return TimeUtil

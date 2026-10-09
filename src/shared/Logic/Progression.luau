--!strict
--[[
	Progression
	Level curve math. XP is stored as a lifetime total; the level is derived from it.
	XP to go from level L to L+1 = round(XpBase * L ^ XpExponent).
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local MAX_LEVEL = Tuning.Progression.MaxLevel
local BASE = Tuning.Progression.XpBase
local EXPONENT = Tuning.Progression.XpExponent

-- thresholds[L] = total XP needed to reach level L (thresholds[1] = 0)
local thresholds: { number } = { 0 }
for level = 1, MAX_LEVEL - 1 do
	thresholds[level + 1] = thresholds[level] + math.floor(BASE * level ^ EXPONENT + 0.5)
end

local Progression = {}

Progression.MaxLevel = MAX_LEVEL

--- XP needed to advance from `level` to `level + 1` (0 at max level).
function Progression.xpToNext(level: number): number
	if level >= MAX_LEVEL then
		return 0
	end
	return thresholds[level + 1] - thresholds[level]
end

--- Total XP required to reach `level`.
function Progression.totalForLevel(level: number): number
	return thresholds[math.clamp(level, 1, MAX_LEVEL)]
end

--- Level reached with `totalXp` lifetime XP.
function Progression.levelFromXP(totalXp: number): number
	-- Binary search over the cumulative thresholds.
	local low, high = 1, MAX_LEVEL
	while low < high do
		local mid = (low + high + 1) // 2
		if thresholds[mid] <= totalXp then
			low = mid
		else
			high = mid - 1
		end
	end
	return low
end

export type LevelProgress = { level: number, into: number, needed: number, fraction: number }

--- Progress within the current level, for XP bars.
function Progression.progress(totalXp: number): LevelProgress
	local level = Progression.levelFromXP(totalXp)
	if level >= MAX_LEVEL then
		return { level = level, into = 0, needed = 0, fraction = 1 }
	end
	local into = totalXp - thresholds[level]
	local needed = thresholds[level + 1] - thresholds[level]
	return { level = level, into = into, needed = needed, fraction = into / needed }
end

--- Tokens awarded for reaching `level`.
function Progression.levelUpTokens(level: number): number
	return level * Tuning.Progression.LevelUpTokensPerLevel
end

return table.freeze(Progression)

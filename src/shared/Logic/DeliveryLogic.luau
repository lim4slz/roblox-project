--!strict
--[[
	DeliveryLogic
	Reward math, express timing and the anti-teleport travel check for deliveries.
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local config = Tuning.Delivery

local DeliveryLogic = {}

--- Reward for a delivery over `distance` studs.
function DeliveryLogic.reward(distance: number, express: boolean, onTime: boolean): Tuning.Reward
	local tokens = config.BaseTokens + math.floor(distance * config.TokensPerStud)
	local xp = config.BaseXP + math.floor(distance * config.XPPerStud)
	if express and onTime then
		tokens = math.floor(tokens * config.ExpressMultiplier)
		xp = math.floor(xp * config.ExpressMultiplier)
	end
	return { Tokens = tokens, XP = xp }
end

--- Seconds an express delivery may take to earn the bonus.
function DeliveryLogic.parTime(distance: number): number
	return distance / config.ExpressParSpeed + config.ExpressParBonus
end

--- The fastest a real player could possibly travel `distance` studs.
--- Completing a delivery faster than this means the character was teleported.
function DeliveryLogic.minTravelSeconds(distance: number): number
	return distance / GameConfig.Security.MaxTravelSpeed
end

function DeliveryLogic.isPlausible(distance: number, elapsed: number): boolean
	return elapsed >= DeliveryLogic.minTravelSeconds(distance)
end

--- Picks a random destination from `candidates`, avoiding ids in `exclude`.
function DeliveryLogic.chooseTarget(candidates: { string }, exclude: { [string]: boolean }, rng: Random): string?
	local options = {}
	for _, id in candidates do
		if not exclude[id] then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		return nil
	end
	return options[rng:NextInteger(1, #options)]
end

function DeliveryLogic.rollExpress(level: number, rng: Random): boolean
	return level >= config.ExpressMinLevel and rng:NextNumber() < config.ExpressChance
end

return table.freeze(DeliveryLogic)

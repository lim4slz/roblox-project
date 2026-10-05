--!strict
--[[
	Rewards
	Applies a Reward table to player data. This is the only place where
	currencies, XP and ownership are granted, so the invariants live here:
	  * integer, non-negative, capped currencies
	  * XP converted to levels (level-up Tokens included)
	  * ownership grants are idempotent (owning twice is impossible)
	  * items respect backpack capacity; overflow is reported, never silently lost
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Tuning = require(script.Parent.Parent.Config.Tuning)
local Cosmetics = require(script.Parent.Parent.Catalog.Cosmetics)
local Furniture = require(script.Parent.Parent.Catalog.Furniture)
local Pets = require(script.Parent.Parent.Catalog.Pets)
local Titles = require(script.Parent.Parent.Catalog.Titles)
local Items = require(script.Parent.Parent.Catalog.Items)
local Progression = require(script.Parent.Progression)
local Backpack = require(script.Parent.Backpack)
local DataSchema = require(script.Parent.DataSchema)

type PlayerData = DataSchema.PlayerData

export type Summary = {
	tokens: number,
	tickets: number,
	xp: number,
	reputation: number,
	items: { [string]: number },
	dropped: { [string]: number },
	cosmetics: { string },
	furniture: { string },
	pets: { string },
	titles: { string },
	levelsGained: { number },
	levelUpTokens: number,
}

export type Options = {
	-- Backpack capacity (required when the reward contains items).
	capacity: number?,
	-- Multiplier applied to XP (party bonus). Defaults to 1.
	xpMultiplier: number?,
}

local Rewards = {}

local function emptySummary(): Summary
	return {
		tokens = 0,
		tickets = 0,
		xp = 0,
		reputation = 0,
		items = {},
		dropped = {},
		cosmetics = {},
		furniture = {},
		pets = {},
		titles = {},
		levelsGained = {},
		levelUpTokens = 0,
	}
end

local function wholeNonNegative(value: number?): number
	if type(value) ~= "number" or value ~= value or value <= 0 then
		return 0
	end
	return math.floor(value)
end

--- Adds Tokens with the cap. Returns the amount actually added.
function Rewards.addTokens(data: PlayerData, amount: number): number
	local add = math.min(wholeNonNegative(amount), GameConfig.Data.MaxTokens - data.Tokens)
	if add > 0 then
		data.Tokens += add
		data.Stats.TokensEarned += add
	end
	return math.max(add, 0)
end

--- Removes Tokens if affordable. Returns false (no change) otherwise.
function Rewards.spendTokens(data: PlayerData, amount: number): boolean
	local cost = wholeNonNegative(amount)
	if cost <= 0 or data.Tokens < cost then
		return cost == 0 and amount == 0
	end
	data.Tokens -= cost
	data.Stats.TokensSpent += cost
	return true
end

function Rewards.addTickets(data: PlayerData, amount: number): number
	local add = math.min(wholeNonNegative(amount), GameConfig.Data.MaxTickets - data.Tickets)
	if add > 0 then
		data.Tickets += add
	end
	return math.max(add, 0)
end

function Rewards.spendTickets(data: PlayerData, amount: number): boolean
	local cost = wholeNonNegative(amount)
	if cost <= 0 or data.Tickets < cost then
		return false
	end
	data.Tickets -= cost
	return true
end

--- Adds XP and returns the list of levels reached (e.g. {3, 4}).
function Rewards.addXP(data: PlayerData, amount: number): ({ number }, number)
	local add = wholeNonNegative(amount)
	local before = Progression.levelFromXP(data.XP)
	data.XP = math.min(data.XP + add, Progression.totalForLevel(Progression.MaxLevel))
	local after = Progression.levelFromXP(data.XP)
	data.Level = after
	local levels = {}
	local bonus = 0
	for level = before + 1, after do
		table.insert(levels, level)
		bonus += Progression.levelUpTokens(level)
	end
	if bonus > 0 then
		Rewards.addTokens(data, bonus)
	end
	return levels, bonus
end

--- Applies `reward` to `data` and returns what was actually granted.
function Rewards.apply(data: PlayerData, reward: Tuning.Reward, options: Options?): Summary
	local summary = emptySummary()
	local opts: Options = options or {}

	if reward.Tokens then
		summary.tokens = Rewards.addTokens(data, reward.Tokens)
	end
	if reward.Tickets then
		summary.tickets = Rewards.addTickets(data, reward.Tickets)
	end
	if reward.Reputation then
		local add = wholeNonNegative(reward.Reputation)
		data.Reputation += add
		summary.reputation = add
	end
	if reward.XP then
		local multiplier = opts.xpMultiplier or 1
		local xp = wholeNonNegative(reward.XP * multiplier)
		summary.xp = xp
		summary.levelsGained, summary.levelUpTokens = Rewards.addXP(data, xp)
	end
	if reward.Items then
		local capacity = opts.capacity
		assert(capacity ~= nil, "Rewards.apply: capacity is required for item rewards")
		for itemId, amount in reward.Items do
			if Items.exists(itemId) then
				local wanted = wholeNonNegative(amount)
				local added = Backpack.add(data.Backpack, itemId, wanted, capacity)
				if added > 0 then
					summary.items[itemId] = added
				end
				if added < wanted then
					summary.dropped[itemId] = wanted - added
				end
			end
		end
	end
	for _, id in reward.Cosmetics or ({} :: { string }) do
		if Cosmetics.exists(id) and not data.Cosmetics[id] then
			data.Cosmetics[id] = true
			table.insert(summary.cosmetics, id)
		end
	end
	for _, id in reward.Furniture or ({} :: { string }) do
		if Furniture.get(id) and not data.Furniture[id] then
			data.Furniture[id] = true
			table.insert(summary.furniture, id)
		end
	end
	for _, id in reward.Pets or ({} :: { string }) do
		if Pets.exists(id) and not data.Pets[id] then
			data.Pets[id] = true
			table.insert(summary.pets, id)
			if data.Equipped.Pet == "" then
				data.Equipped.Pet = id
			end
		end
	end
	for _, id in reward.Titles or ({} :: { string }) do
		if Titles.get(id) and not data.Titles[id] then
			data.Titles[id] = true
			table.insert(summary.titles, id)
		end
	end
	return summary
end

--- True when nothing at all was granted.
function Rewards.isEmpty(summary: Summary): boolean
	return summary.tokens == 0
		and summary.tickets == 0
		and summary.xp == 0
		and summary.reputation == 0
		and next(summary.items) == nil
		and #summary.cosmetics == 0
		and #summary.furniture == 0
		and #summary.pets == 0
		and #summary.titles == 0
end

--- Scales numeric parts of a reward (e.g. VIP bonus on login Tokens).
function Rewards.scale(reward: Tuning.Reward, tokenMultiplier: number): Tuning.Reward
	local copy = table.clone(reward) :: any
	if copy.Tokens then
		copy.Tokens = math.floor(copy.Tokens * tokenMultiplier)
	end
	return copy
end

--- Merges several rewards into one (numbers add, lists concatenate).
function Rewards.merge(...: Tuning.Reward): Tuning.Reward
	local result: { [string]: any } = {}
	for _, reward in { ... } do
		for key, value in reward :: any do
			if type(value) == "number" then
				result[key] = (result[key] or 0) + value
			elseif key == "Items" then
				result.Items = result.Items or {}
				for itemId, amount in value do
					result.Items[itemId] = (result.Items[itemId] or 0) + amount
				end
			elseif type(value) == "table" then
				result[key] = result[key] or {}
				for _, id in value do
					table.insert(result[key], id)
				end
			end
		end
	end
	return result :: any
end

return table.freeze(Rewards)

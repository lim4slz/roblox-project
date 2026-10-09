--!strict
--[[
	DataSchema
	The shape of a player's saved data, its default template, version migrations
	and a sanitizer that repairs corrupted or hand-edited values on load.

	ProfileStore rules respected here: only string-keyed dictionaries and gap-free
	arrays, no Instances, no userdata, no functions.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Items = require(script.Parent.Parent.Catalog.Items)
local Cosmetics = require(script.Parent.Parent.Catalog.Cosmetics)
local Furniture = require(script.Parent.Parent.Catalog.Furniture)
local Pets = require(script.Parent.Parent.Catalog.Pets)
local Titles = require(script.Parent.Parent.Catalog.Titles)
local Quests = require(script.Parent.Parent.Catalog.Quests)
local Tuning = require(script.Parent.Parent.Config.Tuning)
local Progression = require(script.Parent.Progression)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type QuestProgress = {
	Step: number, -- index of the current objective (1-based)
	Count: number, -- progress within the current objective
	StartedAt: number,
}

export type DailyQuest = {
	Id: string,
	Target: number,
	Count: number,
	Claimed: boolean,
}

export type PlayerData = {
	SchemaVersion: number,
	Tokens: number,
	Tickets: number,
	XP: number,
	Level: number,
	Reputation: number,
	Backpack: { [string]: number },
	BackpackTier: number,
	Cosmetics: { [string]: boolean },
	Furniture: { [string]: boolean },
	Pets: { [string]: boolean },
	Titles: { [string]: boolean },
	Equipped: { Hat: string, Trail: string, Aura: string, Title: string, Pet: string },
	House: { Paint: string, Slots: { [string]: string } },
	Quests: { Active: { [string]: QuestProgress }, Completed: { [string]: number } },
	Daily: { Day: number, Quests: { DailyQuest }, BonusClaimed: boolean },
	Collections: { [string]: { [string]: boolean } },
	ClaimedCollections: { [string]: boolean },
	Stats: { [string]: number },
	Weekly: { Week: number, Deliveries: number, FishCaught: number, Lanterns: number },
	Login: { LastClaimDay: number, Streak: number },
	Likes: { Day: number, Given: { [string]: boolean } },
	Codes: { [string]: boolean },
	Tutorial: { Step: number, Done: boolean },
	Settings: { Music: boolean, Sfx: boolean, PartyInvites: boolean, Hints: boolean },
	Community: { Week: number, Contributed: number, Claimed: boolean },
	Purchases: { string },
	Meta: { FirstJoin: number, LastJoin: number, Sessions: number, RobuxSpent: number, Founder: boolean },
}

local STAT_KEYS = {
	"Deliveries",
	"ExpressDeliveries",
	"FruitPicked",
	"FishCaught",
	"GardenWaterings",
	"BloomsJoined",
	"KittensRescued",
	"LanternsCollected",
	"FestivalsAttended",
	"LikesGiven",
	"LikesReceived",
	"PostcardsFound",
	"PartyActivities",
	"ItemsSold",
	"TokensEarned",
	"TokensSpent",
	"PlaytimeSeconds",
}

local function defaultStats(): { [string]: number }
	local stats = {}
	for _, key in STAT_KEYS do
		stats[key] = 0
	end
	return stats
end

local TEMPLATE: PlayerData = {
	SchemaVersion = GameConfig.Data.SchemaVersion,
	Tokens = 50,
	Tickets = 0,
	XP = 0,
	Level = 1,
	Reputation = 0,
	Backpack = {},
	BackpackTier = 0,
	Cosmetics = {},
	Furniture = { WoodenStool = true, SimpleBed = true },
	Pets = {},
	Titles = { [Titles.Default] = true },
	Equipped = { Hat = "", Trail = "", Aura = "", Title = Titles.Default, Pet = "" },
	House = { Paint = Furniture.DefaultPaint, Slots = { Seat = "WoodenStool", Bed = "SimpleBed" } },
	Quests = { Active = {}, Completed = {} },
	Daily = { Day = 0, Quests = {}, BonusClaimed = false },
	Collections = {},
	ClaimedCollections = {},
	Stats = defaultStats(),
	Weekly = { Week = 0, Deliveries = 0, FishCaught = 0, Lanterns = 0 },
	Login = { LastClaimDay = 0, Streak = 0 },
	Likes = { Day = 0, Given = {} },
	Codes = {},
	Tutorial = { Step = 0, Done = false },
	Settings = { Music = true, Sfx = true, PartyInvites = true, Hints = true },
	Community = { Week = 0, Contributed = 0, Claimed = false },
	Purchases = {},
	Meta = { FirstJoin = 0, LastJoin = 0, Sessions = 0, RobuxSpent = 0, Founder = false },
}
TableUtil.deepFreeze(TEMPLATE)

-- Keys never sent to the client.
local PRIVATE_KEYS = table.freeze({ Purchases = true, Meta = true })

-- MIGRATIONS[n] upgrades data from schema version n to n + 1.
local MIGRATIONS: { [number]: (data: { [string]: any }) -> () } = {}

local DataSchema = {}

DataSchema.Template = TEMPLATE
DataSchema.PrivateKeys = PRIVATE_KEYS
DataSchema.StatKeys = table.freeze(STAT_KEYS)

function DataSchema.newData(): PlayerData
	return TableUtil.deepCopy(TEMPLATE) :: any
end

local function sanitizeNumber(value: any, min: number, max: number, default: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return default
	end
	return math.clamp(math.floor(value), min, max)
end

local function sanitizeBoolSet(value: any): { [string]: boolean }
	local result: { [string]: boolean } = {}
	if type(value) == "table" then
		for key, flag in value do
			if type(key) == "string" and flag == true then
				result[key] = true
			end
		end
	end
	return result
end

--- Runs pending migrations. Returns the list of applied versions.
function DataSchema.migrate(data: { [string]: any }): { number }
	local applied = {}
	local version = if type(data.SchemaVersion) == "number" then data.SchemaVersion else 1
	while version < GameConfig.Data.SchemaVersion do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		table.insert(applied, version)
		version += 1
	end
	data.SchemaVersion = GameConfig.Data.SchemaVersion
	return applied
end

--- Fills missing fields from the template and repairs invalid values in place.
--- Returns a list of human-readable repairs (logged by the server).
function DataSchema.sanitize(raw: { [string]: any }): { string }
	local repairs: { string } = {}
	local function note(message: string)
		table.insert(repairs, message)
	end

	TableUtil.reconcile(raw, TEMPLATE :: any)
	local data = raw :: any

	-- Currencies & counters
	local maxTokens = GameConfig.Data.MaxTokens
	local tokens = sanitizeNumber(data.Tokens, 0, maxTokens, 0)
	if tokens ~= data.Tokens then
		note("Tokens repaired")
	end
	data.Tokens = tokens
	data.Tickets = sanitizeNumber(data.Tickets, 0, GameConfig.Data.MaxTickets, 0)
	data.XP = sanitizeNumber(data.XP, 0, Progression.totalForLevel(Progression.MaxLevel), 0)
	data.Level = Progression.levelFromXP(data.XP)
	data.Reputation = sanitizeNumber(data.Reputation, 0, 1e9, 0)
	data.BackpackTier = sanitizeNumber(data.BackpackTier, 0, #Tuning.Backpack.Upgrades, 0)

	-- Backpack: known items only, positive integer stacks
	local backpack: { [string]: number } = {}
	if type(data.Backpack) == "table" then
		for itemId, count in data.Backpack do
			if type(itemId) == "string" and Items.exists(itemId) then
				local n = sanitizeNumber(count, 0, GameConfig.Data.MaxItemStack, 0)
				if n > 0 then
					backpack[itemId] = n
				end
			else
				note("Removed unknown backpack item " .. tostring(itemId))
			end
		end
	end
	data.Backpack = backpack

	-- Ownership sets (unknown ids are kept: content may come back in a later update)
	data.Cosmetics = sanitizeBoolSet(data.Cosmetics)
	data.Furniture = sanitizeBoolSet(data.Furniture)
	data.Pets = sanitizeBoolSet(data.Pets)
	data.Titles = sanitizeBoolSet(data.Titles)
	data.Titles[Titles.Default] = true
	data.Codes = sanitizeBoolSet(data.Codes)
	data.ClaimedCollections = sanitizeBoolSet(data.ClaimedCollections)

	-- Equipped references must point at owned, existing content of the right slot
	local equipped = data.Equipped
	for _, slot in Cosmetics.Slots do
		local id = equipped[slot]
		local def = if type(id) == "string" then Cosmetics.get(id) else nil
		if type(id) ~= "string" or (id ~= "" and (not def or def.slot ~= slot or not data.Cosmetics[id])) then
			if id ~= "" then
				note("Unequipped invalid " .. slot)
			end
			equipped[slot] = ""
		end
	end
	if type(equipped.Pet) ~= "string" or (equipped.Pet ~= "" and (not Pets.exists(equipped.Pet) or not data.Pets[equipped.Pet])) then
		equipped.Pet = ""
	end
	if type(equipped.Title) ~= "string" or not Titles.get(equipped.Title) or not data.Titles[equipped.Title] then
		equipped.Title = Titles.Default
	end

	-- House
	if type(data.House.Paint) ~= "string" or not Furniture.getPaint(data.House.Paint) then
		data.House.Paint = Furniture.DefaultPaint
	end
	local slots: { [string]: string } = {}
	local used: { [string]: boolean } = {}
	if type(data.House.Slots) == "table" then
		for slotId, furnitureId in data.House.Slots do
			local slot = if type(slotId) == "string" then Furniture.getSlot(slotId) else nil
			local def = if type(furnitureId) == "string" then Furniture.get(furnitureId) else nil
			if slot and def and def.category == slot.category and data.Furniture[furnitureId] and not used[furnitureId] then
				slots[slotId] = furnitureId
				used[furnitureId] = true
			else
				note("Cleared invalid house slot " .. tostring(slotId))
			end
		end
	end
	data.House.Slots = slots

	-- Quests
	local active: { [string]: QuestProgress } = {}
	if type(data.Quests.Active) == "table" then
		for questId, progress in data.Quests.Active do
			local def = if type(questId) == "string" then Quests.get(questId) else nil
			if def and type(progress) == "table" then
				active[questId] = {
					Step = sanitizeNumber(progress.Step, 1, #def.objectives, 1),
					Count = sanitizeNumber(progress.Count, 0, 1e6, 0),
					StartedAt = sanitizeNumber(progress.StartedAt, 0, 1e12, 0),
				}
			else
				note("Removed unknown active quest " .. tostring(questId))
			end
		end
	end
	data.Quests.Active = active
	local completed: { [string]: number } = {}
	if type(data.Quests.Completed) == "table" then
		for questId, count in data.Quests.Completed do
			if type(questId) == "string" then
				completed[questId] = sanitizeNumber(count, 1, 1e6, 1)
			end
		end
	end
	data.Quests.Completed = completed
	for questId in active do
		if completed[questId] then
			active[questId] = nil
		end
	end

	-- Daily quests: drop malformed entries
	local dailyQuests: { DailyQuest } = {}
	if type(data.Daily.Quests) == "table" then
		for _, entry in ipairs(data.Daily.Quests) do
			if type(entry) == "table" and type(entry.Id) == "string" and Quests.getDaily(entry.Id) then
				table.insert(dailyQuests, {
					Id = entry.Id,
					Target = sanitizeNumber(entry.Target, 1, 1e6, 1),
					Count = sanitizeNumber(entry.Count, 0, 1e6, 0),
					Claimed = entry.Claimed == true,
				})
			end
		end
	end
	data.Daily.Quests = dailyQuests
	data.Daily.Day = sanitizeNumber(data.Daily.Day, 0, 1e9, 0)
	data.Daily.BonusClaimed = data.Daily.BonusClaimed == true

	-- Collections: string → set of strings
	local collections: { [string]: { [string]: boolean } } = {}
	if type(data.Collections) == "table" then
		for setId, entries in data.Collections do
			if type(setId) == "string" then
				collections[setId] = sanitizeBoolSet(entries)
			end
		end
	end
	data.Collections = collections

	-- Stats
	for _, key in STAT_KEYS do
		data.Stats[key] = sanitizeNumber(data.Stats[key], 0, 1e12, 0)
	end

	-- Purchase id cache: strings only, bounded size
	local purchases: { string } = {}
	if type(data.Purchases) == "table" then
		for _, purchaseId in ipairs(data.Purchases) do
			if type(purchaseId) == "string" then
				table.insert(purchases, purchaseId)
			end
		end
	end
	while #purchases > GameConfig.Data.PurchaseIdCacheSize do
		table.remove(purchases, 1)
	end
	data.Purchases = purchases

	-- Settings must be booleans
	for key, default in TEMPLATE.Settings :: any do
		if type(data.Settings[key]) ~= "boolean" then
			data.Settings[key] = default
		end
	end

	return repairs
end

--- Copy of the data safe to replicate to the owning client (private keys removed).
function DataSchema.publicView(data: PlayerData): { [string]: any }
	local view = {}
	for key, value in data :: any do
		if not PRIVATE_KEYS[key] then
			view[key] = TableUtil.deepCopy(value)
		end
	end
	return view
end

--- Backpack capacity given the purchased tier and the Big Backpack pass.
function DataSchema.backpackCapacity(data: PlayerData, hasBigBackpack: boolean): number
	local capacity = Tuning.Backpack.BaseCapacity
	for tier = 1, math.min(data.BackpackTier, #Tuning.Backpack.Upgrades) do
		capacity += Tuning.Backpack.Upgrades[tier].bonus
	end
	if hasBigBackpack then
		capacity += Tuning.Backpack.BigBackpackBonus
	end
	return capacity
end

return table.freeze(DataSchema)

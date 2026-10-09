--!strict
--[[
	CollectionLogic
	Records album entries and handles the one-time completion reward.
]]

local Collections = require(script.Parent.Parent.Catalog.Collections)
local Tuning = require(script.Parent.Parent.Config.Tuning)
local DataSchema = require(script.Parent.DataSchema)

type PlayerData = DataSchema.PlayerData

local CollectionLogic = {}

--- Marks an entry as found. Returns (isNewEntry, albumJustCompleted).
function CollectionLogic.record(data: PlayerData, setId: string, entryId: string): (boolean, boolean)
	if not Collections.hasEntry(setId, entryId) then
		return false, false
	end
	local found = data.Collections[setId]
	if not found then
		found = {}
		data.Collections[setId] = found
	end
	if found[entryId] then
		return false, false
	end
	found[entryId] = true
	return true, CollectionLogic.isComplete(data, setId)
end

function CollectionLogic.progress(data: PlayerData, setId: string): (number, number)
	local def = Collections.get(setId)
	if not def then
		return 0, 0
	end
	local found = data.Collections[setId] or {}
	local count = 0
	for _, entry in def.entries do
		if found[entry.id] then
			count += 1
		end
	end
	return count, #def.entries
end

function CollectionLogic.isComplete(data: PlayerData, setId: string): boolean
	local found, total = CollectionLogic.progress(data, setId)
	return total > 0 and found == total
end

function CollectionLogic.has(data: PlayerData, setId: string, entryId: string): boolean
	local found = data.Collections[setId]
	return found ~= nil and found[entryId] == true
end

--- Validates and marks the reward as claimed. Returns the reward to grant.
function CollectionLogic.claim(data: PlayerData, setId: string): (Tuning.Reward?, string?)
	local def = Collections.get(setId)
	if not def then
		return nil, "Unknown album."
	end
	if data.ClaimedCollections[setId] then
		return nil, "You already claimed this reward."
	end
	if not CollectionLogic.isComplete(data, setId) then
		return nil, "Complete the album first!"
	end
	data.ClaimedCollections[setId] = true
	return def.reward, nil
end

return table.freeze(CollectionLogic)

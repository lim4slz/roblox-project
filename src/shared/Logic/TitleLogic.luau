--!strict
--[[
	TitleLogic
	Evaluates title conditions and grants newly earned titles.
]]

local Titles = require(script.Parent.Parent.Catalog.Titles)
local DataSchema = require(script.Parent.DataSchema)
local CollectionLogic = require(script.Parent.CollectionLogic)

type PlayerData = DataSchema.PlayerData

export type Context = { ownsPass: (key: string) -> boolean }

local TitleLogic = {}

function TitleLogic.isEarned(data: PlayerData, def: Titles.TitleDef, context: Context): boolean
	local condition = def.condition :: any
	local kind = condition.kind
	if kind == "Default" then
		return true
	elseif kind == "Stat" then
		return (data.Stats[condition.stat] or 0) >= condition.value
	elseif kind == "Level" then
		return data.Level >= condition.value
	elseif kind == "Reputation" then
		return data.Reputation >= condition.value
	elseif kind == "Collection" then
		return CollectionLogic.isComplete(data, condition.collection)
	elseif kind == "Quest" then
		return data.Quests.Completed[condition.quest] ~= nil
	elseif kind == "Pass" then
		return context.ownsPass(condition.pass)
	elseif kind == "Founder" then
		return data.Meta.Founder
	end
	return false
end

--- Grants every title whose condition is met. Returns the newly granted ids.
function TitleLogic.grantEarned(data: PlayerData, context: Context): { string }
	local granted = {}
	for _, def in Titles.List do
		if not data.Titles[def.id] and TitleLogic.isEarned(data, def, context) then
			data.Titles[def.id] = true
			table.insert(granted, def.id)
		end
	end
	return granted
end

return table.freeze(TitleLogic)

--!strict
--[[
	QuestLogic
	Pure quest state machine shared by server (authoritative) and client (display).

	* Story quests start automatically once level and prerequisites are met.
	* Objectives are ordered; an activity only advances the current objective.
	* "Talk" objectives with `bring` consume the items when the player talks to
	  the NPC while carrying them.
	* Daily quests are chosen deterministically from (userId, day) so every
	  server agrees on a player's dailies without any coordination.
]]

local Quests = require(script.Parent.Parent.Catalog.Quests)
local Tuning = require(script.Parent.Parent.Config.Tuning)
local Backpack = require(script.Parent.Backpack)
local DataSchema = require(script.Parent.DataSchema)

type PlayerData = DataSchema.PlayerData

export type Activity = {
	kind: Quests.ObjectiveType,
	npc: string?,
	target: string?,
	item: string?,
	area: string?,
	amount: number?,
}

export type QuestEvent = {
	kind: "progress" | "objective" | "complete" | "missingItems" | "dailyProgress" | "dailyComplete" | "dailyBonus",
	quest: string,
	daily: boolean,
	bring: { [string]: number }?,
}

local QuestLogic = {}

local function objectiveMatches(objective: Quests.ObjectiveDef, activity: Activity): boolean
	if objective.type ~= activity.kind then
		return false
	end
	if objective.npc and objective.npc ~= activity.npc then
		return false
	end
	if objective.target and objective.target ~= activity.target then
		return false
	end
	if objective.item and objective.item ~= activity.item then
		return false
	end
	if objective.area and objective.area ~= activity.area then
		return false
	end
	return true
end

local function requirementsMet(data: PlayerData, def: Quests.QuestDef): boolean
	if data.Level < def.level then
		return false
	end
	for _, required in def.requires do
		if not data.Quests.Completed[required] then
			return false
		end
	end
	return true
end

--- Starts every story quest whose requirements are now met. Returns the ids started.
function QuestLogic.startEligible(data: PlayerData, now: number): { string }
	local started = {}
	for _, def in Quests.Story do
		if not data.Quests.Completed[def.id] and not data.Quests.Active[def.id] and requirementsMet(data, def) then
			data.Quests.Active[def.id] = { Step = 1, Count = 0, StartedAt = now }
			table.insert(started, def.id)
		end
	end
	return started
end

--- The current objective of an active story quest (nil if not active).
function QuestLogic.currentObjective(data: PlayerData, questId: string): (Quests.ObjectiveDef?, DataSchema.QuestProgress?)
	local progress = data.Quests.Active[questId]
	local def = Quests.get(questId)
	if not progress or not def then
		return nil, nil
	end
	return def.objectives[progress.Step], progress
end

--- Feeds an activity into every active story and daily quest.
--- Mutates `data` and returns what happened, in order.
function QuestLogic.applyActivity(data: PlayerData, activity: Activity): { QuestEvent }
	local events: { QuestEvent } = {}
	local amount = math.max(1, math.floor(activity.amount or 1))

	-- Story quests (iterate in catalog order for deterministic results)
	for _, def in Quests.Story do
		local progress = data.Quests.Active[def.id]
		if progress then
			local objective = def.objectives[progress.Step]
			if objective and objectiveMatches(objective, activity) then
				local bring = objective.bring
				if bring and not Backpack.hasAll(data.Backpack, bring) then
					table.insert(events, { kind = "missingItems", quest = def.id, daily = false, bring = bring })
				else
					if bring then
						for itemId, count in bring do
							Backpack.remove(data.Backpack, itemId, count)
						end
					end
					progress.Count = math.min(progress.Count + amount, objective.count)
					if progress.Count >= objective.count then
						if progress.Step >= #def.objectives then
							data.Quests.Active[def.id] = nil
							data.Quests.Completed[def.id] = (data.Quests.Completed[def.id] or 0) + 1
							table.insert(events, { kind = "complete", quest = def.id, daily = false })
						else
							progress.Step += 1
							progress.Count = 0
							table.insert(events, { kind = "objective", quest = def.id, daily = false })
						end
					else
						table.insert(events, { kind = "progress", quest = def.id, daily = false })
					end
				end
			end
		end
	end

	-- Daily quests
	for _, entry in data.Daily.Quests do
		local template = Quests.getDaily(entry.Id)
		if template and not entry.Claimed and template.type == activity.kind then
			entry.Count = math.min(entry.Count + amount, entry.Target)
			if entry.Count >= entry.Target then
				entry.Claimed = true
				table.insert(events, { kind = "dailyComplete", quest = entry.Id, daily = true })
			else
				table.insert(events, { kind = "dailyProgress", quest = entry.Id, daily = true })
			end
		end
	end

	if #data.Daily.Quests > 0 and not data.Daily.BonusClaimed then
		local allDone = true
		for _, entry in data.Daily.Quests do
			if not entry.Claimed then
				allDone = false
				break
			end
		end
		if allDone then
			data.Daily.BonusClaimed = true
			table.insert(events, { kind = "dailyBonus", quest = "daily_bonus", daily = true })
		end
	end

	return events
end

export type DailyPick = { id: string, target: number }

--- Deterministic daily quest selection for a player and UTC day.
function QuestLogic.dailySelection(userId: number, day: number, level: number): { DailyPick }
	local rng = Random.new(day * 7919 + (userId % 2147483647))
	local pool = {}
	for _, template in Quests.Daily do
		if template.minLevel <= level then
			table.insert(pool, template)
		end
	end
	local picks: { DailyPick } = {}
	local count = math.min(Tuning.DailyQuests.Count, #pool)
	for index = 1, count do
		local chosen = rng:NextInteger(index, #pool)
		pool[index], pool[chosen] = pool[chosen], pool[index]
		local template = pool[index]
		table.insert(picks, { id = template.id, target = rng:NextInteger(template.minCount, template.maxCount) })
	end
	return picks
end

--- Rolls new daily quests when the UTC day changed. Returns true if refreshed.
function QuestLogic.refreshDaily(data: PlayerData, userId: number, day: number): boolean
	if data.Daily.Day == day then
		return false
	end
	data.Daily.Day = day
	data.Daily.BonusClaimed = false
	local quests: { DataSchema.DailyQuest } = {}
	for _, pick in QuestLogic.dailySelection(userId, day, data.Level) do
		table.insert(quests, { Id = pick.id, Target = pick.target, Count = 0, Claimed = false })
	end
	data.Daily.Quests = quests
	return true
end

--- Display text for a daily quest entry.
function QuestLogic.dailyText(entry: DataSchema.DailyQuest): string
	local template = Quests.getDaily(entry.Id)
	if not template then
		return entry.Id
	end
	return (string.gsub(template.text, "%%d", tostring(entry.Target)))
end

return table.freeze(QuestLogic)

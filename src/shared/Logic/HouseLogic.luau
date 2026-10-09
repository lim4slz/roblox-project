--!strict
--[[
	HouseLogic
	Furniture placement rules and the Home Rating.
]]

local Furniture = require(script.Parent.Parent.Catalog.Furniture)
local DataSchema = require(script.Parent.DataSchema)

type PlayerData = DataSchema.PlayerData

local HouseLogic = {}

function HouseLogic.slotAvailable(slotId: string, hasPremium: boolean): boolean
	local slot = Furniture.getSlot(slotId)
	return slot ~= nil and (hasPremium or not slot.premium)
end

--- Places `furnitureId` in `slotId` ("" clears the slot). A piece already placed
--- in another slot moves to the new one.
function HouseLogic.place(data: PlayerData, slotId: string, furnitureId: string, hasPremium: boolean): (boolean, string?)
	local slot = Furniture.getSlot(slotId)
	if not slot then
		return false, "Unknown spot."
	end
	if slot.premium and not hasPremium then
		return false, "This spot needs the Dream Home Upgrade."
	end
	local slots = data.House.Slots
	if furnitureId == "" then
		slots[slotId] = nil
		return true, nil
	end
	local def = Furniture.get(furnitureId)
	if not def then
		return false, "Unknown furniture."
	end
	if not data.Furniture[furnitureId] then
		return false, "You don't own that yet."
	end
	if def.category ~= slot.category then
		return false, string.format("%s doesn't fit in the %s spot.", def.name, slot.name)
	end
	for otherSlot, placed in slots do
		if placed == furnitureId and otherSlot ~= slotId then
			slots[otherSlot] = nil
		end
	end
	slots[slotId] = furnitureId
	return true, nil
end

--- Sum of comfort for furniture in slots the player can currently use.
function HouseLogic.rating(slots: { [string]: string }, hasPremium: boolean): number
	local total = 0
	for slotId, furnitureId in slots do
		local def = Furniture.get(furnitureId)
		if def and HouseLogic.slotAvailable(slotId, hasPremium) then
			total += def.comfort
		end
	end
	return total
end

function HouseLogic.placedCount(slots: { [string]: string }): number
	local count = 0
	for _ in slots do
		count += 1
	end
	return count
end

return table.freeze(HouseLogic)

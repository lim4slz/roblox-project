--!strict
--[[
	Backpack
	Capacity counts the total number of items carried (not distinct stacks), so
	"12 / 20" in the HUD means exactly what it says.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local Items = require(script.Parent.Parent.Catalog.Items)

type BackpackData = { [string]: number }

local Backpack = {}

function Backpack.used(backpack: BackpackData): number
	local total = 0
	for _, count in backpack do
		total += count
	end
	return total
end

function Backpack.free(backpack: BackpackData, capacity: number): number
	return math.max(0, capacity - Backpack.used(backpack))
end

function Backpack.count(backpack: BackpackData, itemId: string): number
	return backpack[itemId] or 0
end

--- Adds up to `amount` of `itemId`, limited by free space and the stack cap.
--- Returns how many were actually added.
function Backpack.add(backpack: BackpackData, itemId: string, amount: number, capacity: number): number
	assert(Items.exists(itemId), "unknown item " .. itemId)
	if amount <= 0 then
		return 0
	end
	local current = backpack[itemId] or 0
	local fit = math.min(amount, Backpack.free(backpack, capacity), GameConfig.Data.MaxItemStack - current)
	if fit <= 0 then
		return 0
	end
	backpack[itemId] = current + fit
	return fit
end

--- Removes exactly `amount` of `itemId`. Returns false (and changes nothing) if not enough.
function Backpack.remove(backpack: BackpackData, itemId: string, amount: number): boolean
	local current = backpack[itemId] or 0
	if amount <= 0 or current < amount then
		return false
	end
	local remaining = current - amount
	if remaining > 0 then
		backpack[itemId] = remaining
	else
		(backpack :: { [string]: number? })[itemId] = nil
	end
	return true
end

--- True if every item in `requirements` is present in the required amount.
function Backpack.hasAll(backpack: BackpackData, requirements: { [string]: number }): boolean
	for itemId, amount in requirements do
		if (backpack[itemId] or 0) < amount then
			return false
		end
	end
	return true
end

--- Total sell value of the given items (all items when `only` is nil).
function Backpack.sellValue(backpack: BackpackData, only: { [string]: number }?): number
	local total = 0
	for itemId, count in only or backpack do
		local def = Items.get(itemId)
		if def then
			total += def.sellPrice * math.min(count, backpack[itemId] or 0)
		end
	end
	return total
end

return table.freeze(Backpack)

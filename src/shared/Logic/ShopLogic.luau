--!strict
--[[
	ShopLogic
	Validation and execution of soft-currency purchases (Tokens / Festival
	Tickets). Robux purchases are handled by the server Monetization service.
]]

local Cosmetics = require(script.Parent.Parent.Catalog.Cosmetics)
local Furniture = require(script.Parent.Parent.Catalog.Furniture)
local Pets = require(script.Parent.Parent.Catalog.Pets)
local Tuning = require(script.Parent.Parent.Config.Tuning)
local DataSchema = require(script.Parent.DataSchema)
local Rewards = require(script.Parent.Rewards)

type PlayerData = DataSchema.PlayerData

export type Kind = "Cosmetic" | "Furniture" | "Pet" | "Backpack" | "Paint"
export type Price = { currency: "Tokens" | "Tickets", amount: number }

export type Context = { hasPremiumHouse: boolean }

local ShopLogic = {}

ShopLogic.Kinds = table.freeze({ "Cosmetic", "Furniture", "Pet", "Backpack", "Paint" })

function ShopLogic.isKind(kind: string): boolean
	return table.find(ShopLogic.Kinds, kind) ~= nil
end

--- Returns the price if the purchase is allowed, otherwise nil and a friendly reason.
function ShopLogic.check(data: PlayerData, kind: Kind, id: string, context: Context): (Price?, string?)
	local price: Price?
	local level = 1
	if kind == "Cosmetic" then
		local def = Cosmetics.get(id)
		if not def or not def.price then
			return nil, "That item isn't for sale."
		end
		if data.Cosmetics[id] then
			return nil, "You already own that."
		end
		price, level = def.price, def.level or 1
	elseif kind == "Furniture" then
		local def = Furniture.get(id)
		if not def or not def.price then
			return nil, "That item isn't for sale."
		end
		if data.Furniture[id] then
			return nil, "You already own that."
		end
		price, level = def.price, def.level
	elseif kind == "Pet" then
		local def = Pets.get(id)
		if not def or not def.price then
			return nil, "That pet isn't available here."
		end
		if data.Pets[id] then
			return nil, "You already adopted that pet."
		end
		price, level = def.price, def.level
	elseif kind == "Backpack" then
		local tier = Tuning.Backpack.Upgrades[data.BackpackTier + 1]
		if not tier or tier.id ~= id then
			return nil, "That upgrade isn't available."
		end
		price, level = { currency = "Tokens", amount = tier.price }, tier.level
	elseif kind == "Paint" then
		local paint = Furniture.getPaint(id)
		if not paint then
			return nil, "Unknown paint."
		end
		if paint.premium and not context.hasPremiumHouse then
			return nil, "This paint needs the Dream Home Upgrade."
		end
		if data.House.Paint == id then
			return nil, "Your house is already that color."
		end
		price = { currency = "Tokens", amount = Tuning.House.PaintPrice }
	else
		return nil, "Unknown item."
	end
	assert(price)
	if data.Level < level then
		return nil, string.format("Reach level %d to unlock this.", level)
	end
	local balance = if price.currency == "Tokens" then data.Tokens else data.Tickets
	if balance < price.amount then
		return nil, if price.currency == "Tokens" then "Not enough Tokens." else "Not enough Festival Tickets."
	end
	return price, nil
end

--- Charges and grants. Returns the price paid or nil and a reason.
function ShopLogic.purchase(data: PlayerData, kind: Kind, id: string, context: Context): (Price?, string?)
	local price, reason = ShopLogic.check(data, kind, id, context)
	if not price then
		return nil, reason
	end
	local paid = if price.currency == "Tokens"
		then Rewards.spendTokens(data, price.amount)
		else Rewards.spendTickets(data, price.amount)
	if not paid then
		return nil, "Payment failed."
	end
	if kind == "Cosmetic" then
		data.Cosmetics[id] = true
	elseif kind == "Furniture" then
		data.Furniture[id] = true
	elseif kind == "Pet" then
		data.Pets[id] = true
	elseif kind == "Backpack" then
		data.BackpackTier += 1
	elseif kind == "Paint" then
		data.House.Paint = id
	end
	return price, nil
end

return table.freeze(ShopLogic)

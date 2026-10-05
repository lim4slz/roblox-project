--!strict
--[[
	Products
	Game passes, developer products and the optional subscription.

	IMPORTANT: Roblox assigns the numeric IDs when you create the products in the
	Creator Dashboard, so they cannot exist before the experience is published.
	An id of 0 means "not configured": the product is hidden from the shop and the
	server logs a startup warning. See docs/PUBLISHING.md for the full checklist
	and the suggested Robux prices below.

	Design rules (see docs/GAME_DESIGN.md "Monetization"):
	  * No paid randomness - every purchase grants exactly what it says.
	  * No paid power - only cosmetics, convenience and currency.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local Tuning = require(script.Parent.Parent.Config.Tuning)

export type PassDef = {
	key: string,
	id: number,
	name: string,
	icon: string,
	description: string,
	perks: { string },
	suggestedPrice: number,
}

export type ProductDef = {
	key: string,
	id: number,
	name: string,
	icon: string,
	description: string,
	grant: Tuning.Reward,
	-- One-time bundles: if already owned, `fallbackGrant` is given instead
	-- (a paid receipt is never refused).
	oneTime: boolean?,
	fallbackGrant: Tuning.Reward?,
	suggestedPrice: number,
}

export type SubscriptionDef = {
	key: string,
	id: string, -- subscription ids are strings such as "EXP-1234567890"
	name: string,
	icon: string,
	description: string,
	perks: { string },
}

local PASSES: { PassDef } = {
	{
		key = "VIP",
		id = 0,
		name = "Brightbrook VIP",
		icon = "⭐",
		description = "Stand out in town with VIP perks.",
		perks = {
			"VIP title and gold crown on your name tag",
			"Exclusive VIP Gold Trail",
			"+50% Tokens from daily login rewards",
		},
		suggestedPrice = 299,
	},
	{
		key = "PremiumHouse",
		id = 0,
		name = "Dream Home Upgrade",
		icon = "🏡",
		description = "Make your house the coziest on Maple Lane.",
		perks = {
			"3 extra furniture slots: two garden spots and a balcony",
			"6 premium house paints",
		},
		suggestedPrice = 249,
	},
	{
		key = "BigBackpack",
		id = 0,
		name = "Big Backpack",
		icon = "🎒",
		description = "Carry more before heading back to the Market.",
		perks = { "+30 backpack capacity, forever" },
		suggestedPrice = 149,
	},
}

local PRODUCTS: { ProductDef } = {
	{
		key = "TokenPouch",
		id = 0,
		name = "Pouch of Tokens",
		icon = "🪙",
		description = "1,000 Tokens.",
		grant = { Tokens = 1000 },
		suggestedPrice = 49,
	},
	{
		key = "TokenChest",
		id = 0,
		name = "Chest of Tokens",
		icon = "💰",
		description = "3,500 Tokens (includes 500 bonus).",
		grant = { Tokens = 3500 },
		suggestedPrice = 129,
	},
	{
		key = "TokenVault",
		id = 0,
		name = "Vault of Tokens",
		icon = "🏦",
		description = "12,500 Tokens (includes 2,500 bonus).",
		grant = { Tokens = 12500 },
		suggestedPrice = 399,
	},
	{
		key = "StarterPack",
		id = 0,
		name = "Starter Pack",
		icon = "🎁",
		description = "1,500 Tokens, a Puppy and the exclusive Sunflower Hat. One per player.",
		grant = { Tokens = 1500, Pets = { "Puppy" }, Cosmetics = { "SunflowerHat" } },
		oneTime = true,
		fallbackGrant = { Tokens = 1500, Tickets = 10 },
		suggestedPrice = 99,
	},
	{
		key = "TicketBundle",
		id = 0,
		name = "Festival Tickets",
		icon = "🎟️",
		description = "25 Festival Tickets for the festival booth.",
		grant = { Tickets = 25 },
		suggestedPrice = 79,
	},
	{
		key = "GoldenPup",
		id = 0,
		name = "Golden Pup",
		icon = "🐕",
		description = "A shimmering Golden Pup companion. Purely cosmetic.",
		grant = { Pets = { "GoldenPup" } },
		oneTime = true,
		fallbackGrant = { Tokens = 2500 },
		suggestedPrice = 199,
	},
}

local SUBSCRIPTIONS: { SubscriptionDef } = {
	{
		key = "VipPlus",
		id = "",
		name = "VIP Plus (monthly)",
		icon = "💠",
		description = "A little extra every day you visit.",
		perks = {
			"+100 bonus Tokens with every daily login reward",
			"Exclusive VIP Plus Trail while subscribed",
		},
	},
}

local passByKey: { [string]: PassDef } = {}
for _, def in PASSES do
	passByKey[def.key] = def
end
local productByKey: { [string]: ProductDef } = {}
for _, def in PRODUCTS do
	productByKey[def.key] = def
end
local subscriptionByKey: { [string]: SubscriptionDef } = {}
for _, def in SUBSCRIPTIONS do
	subscriptionByKey[def.key] = def
end

local Products = {}

Products.Passes = TableUtil.deepFreeze(PASSES)
Products.DevProducts = TableUtil.deepFreeze(PRODUCTS)
Products.Subscriptions = TableUtil.deepFreeze(SUBSCRIPTIONS)

function Products.getPass(key: string): PassDef?
	return passByKey[key]
end

function Products.getProduct(key: string): ProductDef?
	return productByKey[key]
end

function Products.getSubscription(key: string): SubscriptionDef?
	return subscriptionByKey[key]
end

function Products.productByAssetId(assetId: number): ProductDef?
	if assetId == 0 then
		return nil
	end
	for _, def in PRODUCTS do
		if def.id == assetId then
			return def
		end
	end
	return nil
end

function Products.passByAssetId(assetId: number): PassDef?
	if assetId == 0 then
		return nil
	end
	for _, def in PASSES do
		if def.id == assetId then
			return def
		end
	end
	return nil
end

--- Keys of products/passes whose Roblox id has not been configured yet.
function Products.unconfigured(): { string }
	local missing = {}
	for _, def in PASSES do
		if def.id == 0 then
			table.insert(missing, "GamePass." .. def.key)
		end
	end
	for _, def in PRODUCTS do
		if def.id == 0 then
			table.insert(missing, "DevProduct." .. def.key)
		end
	end
	for _, def in SUBSCRIPTIONS do
		if def.id == "" then
			table.insert(missing, "Subscription." .. def.key)
		end
	end
	return missing
end

return table.freeze(Products)

--!strict
--[[
	Rarity tiers shared by items, cosmetics and pets.
]]

export type RarityId = "Junk" | "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type RarityDef = {
	id: RarityId,
	name: string,
	order: number,
	color: Color3,
}

local Rarity = {}

local DEFINITIONS: { [string]: RarityDef } = {
	Junk = { id = "Junk", name = "Junk", order = 0, color = Color3.fromRGB(150, 140, 130) },
	Common = { id = "Common", name = "Common", order = 1, color = Color3.fromRGB(196, 204, 214) },
	Uncommon = { id = "Uncommon", name = "Uncommon", order = 2, color = Color3.fromRGB(102, 214, 122) },
	Rare = { id = "Rare", name = "Rare", order = 3, color = Color3.fromRGB(84, 166, 255) },
	Epic = { id = "Epic", name = "Epic", order = 4, color = Color3.fromRGB(190, 110, 255) },
	Legendary = { id = "Legendary", name = "Legendary", order = 5, color = Color3.fromRGB(255, 196, 64) },
}

Rarity.All = table.freeze(DEFINITIONS)

function Rarity.get(id: string): RarityDef?
	return DEFINITIONS[id]
end

function Rarity.order(id: string): number
	local def = Rarity.get(id)
	return if def then def.order else 0
end

function Rarity.color(id: string): Color3
	local def = Rarity.get(id)
	return if def then def.color else DEFINITIONS.Common.color
end

return table.freeze(Rarity)

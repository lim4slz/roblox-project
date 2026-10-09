--!strict
--[[
	Areas
	Named regions of the map. Some are gated by level: the gate opens locally for
	players who qualify, and the server enforces the requirement both for the
	activities inside and by returning under-levelled players to town.
	World bounds for each area live in server/World/WorldLayout.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type AreaDef = {
	id: string,
	name: string,
	icon: string,
	level: number,
	description: string,
	color: Color3,
}

local rgb = Color3.fromRGB

local DEFINITIONS: { AreaDef } = {
	{
		id = "Town",
		name = "Town Square",
		icon = "⛲",
		level = 1,
		description = "The heart of Brightbrook: shops, the post office and the festival stage.",
		color = rgb(255, 200, 110),
	},
	{
		id = "Residential",
		name = "Maple Lane",
		icon = "🏡",
		level = 1,
		description = "Where everyone lives. Your house is waiting!",
		color = rgb(240, 150, 120),
	},
	{
		id = "Park",
		name = "Sunny Park",
		icon = "🌳",
		level = 1,
		description = "Fruit bushes, the playground and the Community Garden.",
		color = rgb(120, 210, 120),
	},
	{
		id = "Lakeside",
		name = "Brightbrook Lake",
		icon = "🎣",
		level = 2,
		description = "Fishing on the old dock and a lighthouse with a view.",
		color = rgb(110, 190, 240),
	},
	{
		id = "Hilltop",
		name = "Hilltop Orchard",
		icon = "🍒",
		level = 5,
		description = "Rare cherries, the Moon Pond and the best lookout in town.",
		color = rgb(200, 130, 220),
	},
}

local byId: { [string]: AreaDef } = {}
for _, def in DEFINITIONS do
	byId[def.id] = def
end

local Areas = {}

Areas.List = TableUtil.deepFreeze(DEFINITIONS)

function Areas.get(id: string): AreaDef?
	return byId[id]
end

return table.freeze(Areas)

--!strict
--[[
	Emotes
	Default avatar emotes available to every R15 character through
	Humanoid:PlayEmote, so no animation assets are required.
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

export type EmoteDef = { id: string, name: string, icon: string }

local DEFINITIONS: { EmoteDef } = {
	{ id = "wave", name = "Wave", icon = "👋" },
	{ id = "cheer", name = "Cheer", icon = "🙌" },
	{ id = "laugh", name = "Laugh", icon = "😂" },
	{ id = "point", name = "Point", icon = "👉" },
	{ id = "dance", name = "Dance", icon = "💃" },
	{ id = "dance2", name = "Groove", icon = "🕺" },
	{ id = "dance3", name = "Boogie", icon = "🎶" },
}

local Emotes = {}

Emotes.List = TableUtil.deepFreeze(DEFINITIONS)

return table.freeze(Emotes)

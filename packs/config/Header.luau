--[[
	Pet settings. Change anything here and press Play to see it.
	The full guide is in README.md, next to the files you dragged in.
]]

local Config = {}

-- Pets every player gets. Pet names: {{PET_NAMES}}
Config.Pets = { __PETS__ }

-- Who gets pets:
--   "Everyone"   every player gets Config.Pets (default)
--   "Attribute"  only players whose "Pet" attribute is set by your scripts
-- On any player the attribute wins over Config.Pets. From a server Script:
--   {{ATTRIBUTE_EXAMPLES}}
Config.GiveTo = "Everyone"
Config.Attribute = "Pet"

-- false = each player only sees their own pets (lighter on big servers).
Config.ShowOtherPlayersPets = true

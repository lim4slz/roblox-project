--!strict
--[[
	Codes
	Promotional codes redeemable once per player (case-insensitive).
	Add new codes here for live events; `expiresAt` is a UTC unix timestamp.
	Keep codes as one-shot treats, not a retention crutch (docs/LIVEOPS.md).
]]

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local Tuning = require(script.Parent.Parent.Config.Tuning)

export type CodeDef = {
	code: string, -- stored upper-case
	reward: Tuning.Reward,
	expiresAt: number?,
	minLevel: number?,
}

local DEFINITIONS: { CodeDef } = {
	{ code = "WELCOME", reward = { Tokens = 100 } },
	{ code = "BRIGHTBROOK", reward = { Tokens = 50, Tickets = 3 } },
	{ code = "FISHY", reward = { Tokens = 150 }, minLevel = 2, expiresAt = 1798761600 }, -- 2027-01-01 UTC
}

local byCode: { [string]: CodeDef } = {}
for _, def in DEFINITIONS do
	assert(def.code == string.upper(def.code), "codes must be upper-case: " .. def.code)
	assert(byCode[def.code] == nil, "duplicate code " .. def.code)
	byCode[def.code] = def
end

local Codes = {}

Codes.List = TableUtil.deepFreeze(DEFINITIONS)
Codes.MaxLength = 24

--- Normalizes user input: trims whitespace, upper-cases. Returns nil for invalid input.
function Codes.normalize(input: string): string?
	local trimmed = string.match(input, "^%s*(.-)%s*$") or ""
	if #trimmed == 0 or #trimmed > Codes.MaxLength or not string.match(trimmed, "^[%w_%-]+$") then
		return nil
	end
	return string.upper(trimmed)
end

function Codes.get(code: string): CodeDef?
	return byCode[code]
end

return table.freeze(Codes)

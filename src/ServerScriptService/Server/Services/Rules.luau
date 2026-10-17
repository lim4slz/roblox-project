--!strict
-- The live rule set for the current match: base values from Config, modified
-- by the active variant (for the whole match) and by temporary overlays from
-- random events or power-ups (for a few seconds).
--
-- Keys ending in "Multiplier" stack multiplicatively; everything else is
-- replaced by the most recently applied layer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Variants = require(ReplicatedStorage.Shared.Variants)

local Rules = {}

Rules.Changed = Signal.new() :: Signal.Signal<>

local BASE: { [string]: number } = {
	FuseTime = Config.Bomb.FuseTime,
	ReloadMultiplier = 1,
	BlastRadiusMultiplier = 1,
	DamageMultiplier = 1,
	WalkSpeedMultiplier = 1,
	Gravity = 196.2,
	EventInterval = Config.Events.Interval,
}

local variantLayer: { [string]: number } = {}
-- Ordered so the newest overlay wins for replace-style keys.
local overlays: { { id: string, modifiers: { [string]: number } } } = {}

local function isMultiplier(key: string): boolean
	return string.sub(key, -#"Multiplier") == "Multiplier"
end

function Rules.get(key: string): number
	local value = BASE[key]
	assert(value ~= nil, "Unknown rule: " .. key)
	local layers = { variantLayer }
	for _, overlay in overlays do
		table.insert(layers, overlay.modifiers)
	end
	for _, layer in layers do
		local modifier = layer[key]
		if modifier ~= nil then
			if isMultiplier(key) then
				value *= modifier
			else
				value = modifier
			end
		end
	end
	return value
end

function Rules.setVariant(variantId: string)
	variantLayer = table.clone(Variants.get(variantId).Modifiers)
	Rules.Changed:Fire()
end

function Rules.pushOverlay(id: string, modifiers: { [string]: number })
	Rules.popOverlay(id)
	table.insert(overlays, { id = id, modifiers = modifiers })
	Rules.Changed:Fire()
end

function Rules.popOverlay(id: string)
	for index, overlay in overlays do
		if overlay.id == id then
			table.remove(overlays, index)
			Rules.Changed:Fire()
			return
		end
	end
end

function Rules.hasOverlay(id: string): boolean
	for _, overlay in overlays do
		if overlay.id == id then
			return true
		end
	end
	return false
end

function Rules.reset()
	variantLayer = {}
	table.clear(overlays)
	Rules.Changed:Fire()
end

-- Convenience accessors used all over the combat code.
function Rules.reloadTime(): number
	return Config.Bomb.ReloadTime * Rules.get("ReloadMultiplier")
end

function Rules.blastRadius(base: number): number
	return base * Rules.get("BlastRadiusMultiplier")
end

return Rules

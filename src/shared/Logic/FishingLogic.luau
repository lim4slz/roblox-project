--!strict
--[[
	FishingLogic
	The server decides when the fish bites and what is caught; the client only
	says "reel now". A reel is accepted only inside the bite window (plus a
	small latency grace), so auto-clickers that reel early simply fail.
]]

local Items = require(script.Parent.Parent.Catalog.Items)
local Tuning = require(script.Parent.Parent.Config.Tuning)

local config = Tuning.Fishing

local FishingLogic = {}

export type Verdict = "early" | "caught" | "late"

function FishingLogic.biteDelay(rng: Random): number
	return config.BiteDelayMin + rng:NextNumber() * (config.BiteDelayMax - config.BiteDelayMin)
end

--- Judges a reel request made at `now` for a bite that happens at `biteAt`.
function FishingLogic.verdict(now: number, biteAt: number): Verdict
	if now < biteAt - config.LatencyGrace then
		return "early"
	elseif now > biteAt + config.ReelWindow + config.LatencyGrace then
		return "late"
	end
	return "caught"
end

--- Weighted roll on a fishing pool. Returns an item id.
function FishingLogic.roll(poolId: string, rng: Random): string
	local pool = Items.Pools[poolId]
	assert(pool, "unknown fishing pool " .. poolId)
	local total = 0
	for _, entry in pool.entries do
		total += entry.weight
	end
	local pick = rng:NextNumber() * total
	for _, entry in pool.entries do
		pick -= entry.weight
		if pick < 0 then
			return entry.item
		end
	end
	return pool.entries[#pool.entries].item
end

function FishingLogic.poolMinLevel(poolId: string): number
	local pool = Items.Pools[poolId]
	return if pool then pool.minLevel else math.huge
end

return table.freeze(FishingLogic)

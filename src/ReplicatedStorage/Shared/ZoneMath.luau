--!strict
-- The storm's radius is a pure function of how long the battle has been
-- running. Server and clients both evaluate it locally, so the shrinking wall
-- animates smoothly on every screen and the server's damage checks always agree
-- with what players see.

local Config = require(script.Parent.Config)

export type ZoneSample = {
	active: boolean, -- has the storm formed yet?
	radius: number,
	stage: number, -- number of shrinks that have started (0 before the first)
	shrinking: boolean,
	nextChangeIn: number?, -- seconds until the next shrink starts/ends
	damagePerSecond: number,
}

local ZoneMath = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Smooth start and stop so the wall doesn't lurch.
local function easeInOut(t: number): number
	return t * t * (3 - 2 * t)
end

function ZoneMath.sample(elapsed: number, zoneConfig: typeof(Config.Zone)?): ZoneSample
	local zone = zoneConfig or Config.Zone
	local radii = zone.Radii
	local shrinkCount = #radii - 1

	if elapsed < zone.StartDelay then
		return {
			active = false,
			radius = radii[1],
			stage = 0,
			shrinking = false,
			nextChangeIn = zone.StartDelay - elapsed,
			damagePerSecond = 0,
		}
	end

	local sinceStart = elapsed - zone.StartDelay
	local stage = math.min(shrinkCount, math.floor(sinceStart / zone.Interval) + 1)
	local stageStartedAt = (stage - 1) * zone.Interval
	local intoStage = sinceStart - stageStartedAt
	local damage = zone.DamagePerSecond[math.clamp(stage, 1, #zone.DamagePerSecond)]

	if intoStage < zone.ShrinkDuration then
		local alpha = easeInOut(intoStage / zone.ShrinkDuration)
		return {
			active = true,
			radius = lerp(radii[stage], radii[stage + 1], alpha),
			stage = stage,
			shrinking = true,
			nextChangeIn = zone.ShrinkDuration - intoStage,
			damagePerSecond = damage,
		}
	end

	local nextShrinkIn: number? = nil
	if stage < shrinkCount then
		nextShrinkIn = zone.Interval - intoStage
	end
	return {
		active = true,
		radius = radii[stage + 1],
		stage = stage,
		shrinking = false,
		nextChangeIn = nextShrinkIn,
		damagePerSecond = damage,
	}
end

-- Horizontal distance check; the storm is an infinitely tall cylinder.
function ZoneMath.isOutside(position: Vector3, center: Vector3, radius: number): boolean
	local dx = position.X - center.X
	local dz = position.Z - center.Z
	return dx * dx + dz * dz > radius * radius
end

return ZoneMath

--!nonstrict
-- Tests for the pure shared modules: storm timing, bomb launch maths,
-- variants, team lookups and text formatting.

local Vector3 = require("@lune/roblox").Vector3

return function(Expect, ModuleLoader)
	local Config = ModuleLoader.load("src/ReplicatedStorage/Shared/Config")
	local ZoneMath = ModuleLoader.load("src/ReplicatedStorage/Shared/ZoneMath")
	local Trajectory = ModuleLoader.load("src/ReplicatedStorage/Shared/Trajectory")
	local Variants = ModuleLoader.load("src/ReplicatedStorage/Shared/Variants")
	local TeamInfo = ModuleLoader.load("src/ReplicatedStorage/Shared/TeamInfo")
	local Format = ModuleLoader.load("src/ReplicatedStorage/Shared/Format")

	local zone = Config.Zone

	Expect.describe("ZoneMath", function()
		Expect.it("stays dormant before the storm forms", function()
			local sample = ZoneMath.sample(0)
			Expect.equal(sample.active, false)
			Expect.near(sample.nextChangeIn, zone.StartDelay, 1e-6)
		end)

		Expect.it("reaches each radius after each shrink", function()
			for stage = 1, #zone.Radii - 1 do
				local settled = zone.StartDelay + (stage - 1) * zone.Interval + zone.ShrinkDuration + 0.01
				local sample = ZoneMath.sample(settled)
				Expect.near(sample.radius, zone.Radii[stage + 1], 1e-6, "stage " .. stage)
				Expect.equal(sample.shrinking, false)
			end
		end)

		Expect.it("is fully closed before the match timer runs out", function()
			local final = ZoneMath.sample(Config.Match.BattleDuration)
			Expect.near(final.radius, zone.Radii[#zone.Radii], 1e-6)
		end)

		Expect.it("never grows", function()
			local previous = math.huge
			for t = 0, Config.Match.BattleDuration, 0.5 do
				local radius = ZoneMath.sample(t).radius
				Expect.truthy(radius <= previous + 1e-9, "radius grew at t=" .. t)
				previous = radius
			end
		end)

		Expect.it("measures distance horizontally", function()
			Expect.equal(ZoneMath.isOutside(Vector3.new(0, 500, 10), Vector3.zero, 20), false)
			Expect.equal(ZoneMath.isOutside(Vector3.new(30, 0, 0), Vector3.zero, 20), true)
		end)
	end)

	Expect.describe("Trajectory", function()
		Expect.it("maps charge onto the configured speed range", function()
			Expect.near(Trajectory.speedForCharge(0), Config.Bomb.MinThrowSpeed, 1e-6)
			Expect.near(Trajectory.speedForCharge(1), Config.Bomb.MaxThrowSpeed, 1e-6)
			Expect.truthy(Trajectory.speedForCharge(0.5) > Trajectory.speedForCharge(0.25))
		end)

		Expect.it("launches in front of the head and slightly upward", function()
			local origin, velocity = Trajectory.launch(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1), 1, Vector3.zero)
			Expect.truthy(origin.Z < 0, "spawns in front")
			Expect.truthy(velocity.Y > 0, "arcs upward")
		end)

		Expect.it("samples points that fall under gravity", function()
			local points = Trajectory.samplePoints(Vector3.zero, Vector3.new(10, 0, 0), 196.2, 5, 0.1)
			Expect.truthy(points[5].Y < points[1].Y)
		end)
	end)

	Expect.describe("Variants", function()
		Expect.it("falls back to Classic for unknown ids", function()
			Expect.equal(Variants.get("Nope").Id, "Classic")
		end)

		Expect.it("never repeats the avoided variant", function()
			local random = ModuleLoader.Random.new(7)
			for _ = 1, 200 do
				Expect.truthy(Variants.roll(random, "Classic").Id ~= "Classic")
			end
		end)

		Expect.it("uses only modifiers the server understands", function()
			local known = {
				FuseTime = true,
				ReloadMultiplier = true,
				BlastRadiusMultiplier = true,
				DamageMultiplier = true,
				WalkSpeedMultiplier = true,
				Gravity = true,
				EventInterval = true,
			}
			for _, variant in Variants.List do
				for key in variant.Modifiers do
					Expect.truthy(known[key], variant.Id .. " uses unknown modifier " .. key)
				end
			end
		end)
	end)

	Expect.describe("TeamInfo", function()
		Expect.it("pairs each team with its opponent", function()
			Expect.equal(TeamInfo.opponentOf("Blue").Name, "Red")
			Expect.equal(TeamInfo.opponentOf("Red").Name, "Blue")
		end)
	end)

	Expect.describe("Format", function()
		Expect.it("formats clocks, rounding up", function()
			Expect.equal(Format.clock(125.4), "2:06")
			Expect.equal(Format.clock(0), "0:00")
			Expect.equal(Format.clock(59.01), "1:00")
		end)

		Expect.it("formats thousands", function()
			Expect.equal(Format.thousands(1234567), "1,234,567")
			Expect.equal(Format.thousands(999), "999")
		end)

		Expect.it("formats percentages", function()
			Expect.equal(Format.percent(0.426), "43%")
		end)
	end)
end

--[[
	Bunny pet: rig data, hopping and binky animation, idle fidgets, and the
	client module running in the headless runtime.
]]

local roblox = require("@lune/roblox")
local Datatypes = require("../harness/Datatypes")
local Shared = require("../harness/Shared")
local Geo = require("./PetGeometry")

local CFrame, Vector3 = Datatypes.CFrame, roblox.Vector3

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local BunnyModel = Shared.require("Pets.BunnyModel")
	local BunnyAnimation = Shared.require("Pets.BunnyAnimation")
	local BunnyPet = Shared.require("Pets.BunnyPet")
	local PetRig = Shared.require("Pets.PetRig")

	local parts = BunnyModel.Definition.parts
	local NEVER = { math.huge, math.huge }
	local HIDDEN = { "LidL", "LidR", "LashL", "LashR", "MouthOpen" }

	local function stepFor(anim, seconds, speed)
		local binkies = 0
		for _ = 1, math.floor(seconds * 60 + 0.5) do
			binkies += anim:step(1 / 60, speed or 0)
		end
		return binkies
	end

	local function solve(rig, anim)
		return rig:solve(CFrame.identity, anim:pose(), {})
	end

	describe("Bunny model", function()
		it("keeps the 24 original parts plus 5 hidden ones, each on a known bone", function()
			expect(#parts).toBe(29)
			local names = {}
			for _, def in parts do
				expect(names[def.name]).toBeNil()
				names[def.name] = true
			end
			local rig = PetRig.new(BunnyModel.Definition)
			local cframes = rig:solve(CFrame.identity, {}, {})
			for index, def in parts do
				expect((cframes[index].Position - def.cframe.Position).Magnitude).toBeLessThan(1e-4)
				expect(cframes[index].LookVector:Dot(def.cframe.LookVector)).toBeGreaterThan(0.9999)
			end
			-- Sitting on its hind feet and front paws, like in the art.
			expect(Geo.lowest(parts, cframes)).toBeCloseTo(0, 0.01)
		end)

		it("hides the eyelids and the open mouth inside the face until they are animated", function()
			local rig = PetRig.new(BunnyModel.Definition)
			local rest = rig:solve(CFrame.identity, {}, {})
			expect(Geo.inside(parts, rest, "MouthOpen", "Muzzle", 0.001)).toBe(true)
			for _, side in { "L", "R" } do
				expect(Geo.frontZ(parts, rest, "Lid" .. side)).toBeGreaterThan(Geo.frontZ(parts, rest, "Eye" .. side))
				expect(Geo.frontZ(parts, rest, "Lash" .. side)).toBeGreaterThan(Geo.frontZ(parts, rest, "Eye" .. side))
			end

			local open = rig:solve(CFrame.identity, {
				Lids = CFrame.new(BunnyModel.BlinkOffset),
				Mouth = CFrame.new(BunnyModel.MouthOpenOffset),
			}, {})
			expect(Geo.frontZ(parts, open, "MouthOpen")).toBeLessThan(Geo.frontZ(parts, open, "Muzzle"))
			for _, side in { "L", "R" } do
				-- The lid covers the whole front of the eye.
				expect(Geo.frontZ(parts, open, "Lid" .. side)).toBeLessThan(Geo.frontZ(parts, open, "Eye" .. side))
				local lid = parts[Geo.partIndex(parts, "Lid" .. side)]
				local eye = parts[Geo.partIndex(parts, "Eye" .. side)]
				expect(lid.size.X).toBeGreaterThanOrEqual(eye.size.X)
				expect(lid.size.Y).toBeGreaterThanOrEqual(eye.size.Y)
			end
		end)
	end)

	describe("Bunny hops", function()
		it("sits still, hops when walking and makes longer, higher hops when running", function()
			local anim = BunnyAnimation.new(1, NEVER)
			stepFor(anim, 1, 0)
			expect(anim:gait()).toBe("Idle")
			stepFor(anim, 1, 12)
			expect(anim:gait()).toBe("Walk")
			stepFor(anim, 1, 26)
			expect(anim:gait()).toBe("Run")
			stepFor(anim, 1, 0)
			expect(anim:gait()).toBe("Idle")
		end)

		it("leaves the ground in every hop and never sinks into it", function()
			local rig = PetRig.new(BunnyModel.Definition)
			local function heights(speed)
				local anim = BunnyAnimation.new(2, NEVER)
				stepFor(anim, 2, speed)
				local low, high, grounded = math.huge, -math.huge, 0
				local lastPhase, cycles = anim:hopPhase(), 0
				for _ = 1, 4 * 60 do
					anim:step(1 / 60, speed)
					local lowest = Geo.lowest(parts, solve(rig, anim))
					low = math.min(low, lowest)
					high = math.max(high, lowest)
					grounded += if lowest < 0.02 then 1 else 0
					if anim:hopPhase() < lastPhase then
						cycles += 1
					end
					lastPhase = anim:hopPhase()
				end
				return low, high, grounded, cycles
			end

			local low, high, grounded, cycles = heights(12)
			expect(low).toBeGreaterThan(-0.01)
			expect(high).toBeGreaterThan(0.3)
			expect(high).toBeLessThan(0.8)
			expect(grounded).toBeGreaterThan(20) -- it lands between hops
			expect(cycles).toBeGreaterThanOrEqual(10) -- 2.8 hops a second at 12 studs/s

			local runLow, runHigh = heights(26)
			expect(runLow).toBeGreaterThan(-0.01)
			expect(runHigh).toBeGreaterThan(high + 0.3)
		end)

		it("streams its ears back in the air and leans into the hop", function()
			local anim = BunnyAnimation.new(3, NEVER)
			stepFor(anim, 2, 12)
			local earBack, bodyForward = -math.huge, -math.huge
			for _ = 1, 60 do
				anim:step(1 / 60, 12)
				local pose = anim:pose()
				earBack = math.max(earBack, (pose.EarL:ToEulerAnglesYXZ()))
				bodyForward = math.max(bodyForward, -select(1, pose.Body:ToEulerAnglesYXZ()))
			end
			expect(math.deg(earBack)).toBeGreaterThan(30)
			expect(math.deg(bodyForward)).toBeGreaterThan(25)
		end)

		it("grows with its scale", function()
			local anim = BunnyAnimation.new(4, NEVER)
			local rig = PetRig.new(BunnyModel.Definition, 2)
			local low, high = math.huge, -math.huge
			for _ = 1, 3 * 60 do
				anim:step(1 / 60, 12)
				local lowest = Geo.lowest(parts, solve(rig, anim), nil, 2)
				low = math.min(low, lowest)
				high = math.max(high, lowest)
			end
			expect(low).toBeGreaterThan(-0.02)
			expect(high).toBeGreaterThan(0.6) -- twice the hop height
		end)
	end)

	describe("Bunny binky and fidgets", function()
		it("binkies: jumps high with a twist, eyes shut and mouth open, and lands on its feet", function()
			local rig = PetRig.new(BunnyModel.Definition)
			local anim = BunnyAnimation.new(5, NEVER)
			stepFor(anim, 1)
			anim:react()
			expect(anim:step(1 / 60, 0)).toBe(1)
			expect(anim:isReacting()).toBe(true)
			local top, twist, open, shut = -math.huge, 0, false, false
			for _ = 1, math.floor(BunnyAnimation.BinkyLength * 60) do
				anim:step(1 / 60, 0)
				local pose = anim:pose()
				top = math.max(top, Geo.lowest(parts, solve(rig, anim)))
				twist = math.max(twist, math.abs(select(2, pose.Body:ToEulerAnglesYXZ())))
				open = open or pose.Mouth.Position == BunnyModel.MouthOpenOffset
				shut = shut or pose.Lids.Position == BunnyModel.BlinkOffset
			end
			expect(top).toBeGreaterThan(BunnyAnimation.BinkyHeight * 0.8)
			expect(top).toBeLessThan(BunnyAnimation.BinkyHeight * 1.2)
			expect(math.deg(twist)).toBeGreaterThan(20)
			expect(open).toBe(true)
			expect(shut).toBe(true)

			stepFor(anim, 0.2)
			expect(anim:isReacting()).toBe(false)
			local pose = anim:pose()
			expect(pose.Mouth.Position.Magnitude).toBe(0)
			expect(Geo.lowest(parts, solve(rig, anim))).toBeCloseTo(0, 0.02)
		end)

		it("binkies on its own at random intervals, and never when told not to", function()
			local function binkyTimes(seed, every)
				local anim = BunnyAnimation.new(seed, every)
				local times = {}
				for frame = 1, 90 * 60 do
					for _ = 1, anim:step(1 / 60, if frame % 1200 < 600 then 0 else 12) do
						table.insert(times, frame / 60)
					end
				end
				return times
			end
			local times = binkyTimes(42)
			expect(times).toEqual(binkyTimes(42))
			expect(times).never.toEqual(binkyTimes(43))
			expect(times[1]).toBeGreaterThanOrEqual(1.5)
			expect(times[1]).toBeLessThanOrEqual(3.55)
			local every = BunnyAnimation.Every
			for index = 2, #times do
				local gap = times[index] - times[index - 1]
				expect(gap).toBeGreaterThanOrEqual(every[1] + BunnyAnimation.BinkyLength - 0.05)
				expect(gap).toBeLessThanOrEqual(every[2] + BunnyAnimation.BinkyLength + 0.05)
			end
			expect(#times).toBeGreaterThanOrEqual(7)
			expect(#binkyTimes(42, NEVER)).toBe(0)
		end)

		it("does the binkies asked for back to back, at most three queued", function()
			local anim = BunnyAnimation.new(6, NEVER)
			stepFor(anim, 0.5)
			anim:react(2)
			expect(stepFor(anim, 3 * BunnyAnimation.BinkyLength)).toBe(2)
			anim:react(10)
			expect(stepFor(anim, 10 * BunnyAnimation.BinkyLength)).toBe(3)
		end)

		it("twitches its nose, flicks its ears and blinks while sitting", function()
			local anim = BunnyAnimation.new(7, NEVER)
			local twitches, blinks, earMoves = 0, 0, 0
			local wasTwitching, wasBlinking, wasEar = false, false, false
			for _ = 1, 20 * 60 do
				anim:step(1 / 60, 0)
				local pose = anim:pose()
				local twitching = pose.Nose.Position.Y > 0.02
				local blinking = pose.Lids.Position == BunnyModel.BlinkOffset
				local _, earYawL = pose.EarL:ToEulerAnglesYXZ()
				local _, earYawR = pose.EarR:ToEulerAnglesYXZ()
				local ear = math.abs(earYawL) + math.abs(earYawR) > math.rad(4)
				twitches += if twitching and not wasTwitching then 1 else 0
				blinks += if blinking and not wasBlinking then 1 else 0
				earMoves += if ear and not wasEar then 1 else 0
				wasTwitching, wasBlinking, wasEar = twitching, blinking, ear
			end
			expect(twitches).toBeGreaterThanOrEqual(8)
			expect(blinks).toBeGreaterThanOrEqual(4)
			expect(blinks).toBeLessThanOrEqual(14)
			expect(earMoves).toBeGreaterThanOrEqual(4)
		end)
	end)

	describe("Bunny pet on the client", function()
		it("gives every character a bunny that hops after it and binkies with a bubble and a squeak", function()
			local world = t.newWorld()
			local server = world:createServer()
			server:start()
			local alice = server:addPlayer({ userId = 301, name = "Alice", runClient = true })
			world:advance(1)

			local bunny = alice:run(function()
				local model = workspace.AnimatedPets:FindFirstChild("Bunny")
				local anchored, colliding = 0, 0
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						anchored += if part.Anchored then 1 else 0
						colliding += if part.CanCollide or part.CanQuery or part.CanTouch then 1 else 0
					end
				end
				return { parts = #model:GetChildren(), anchored = anchored, colliding = colliding }
			end)
			expect(bunny.parts).toBe(29)
			expect(bunny.anchored).toBe(29)
			expect(bunny.colliding).toBe(0)

			local start = alice:position()
			local character = alice:character()
			for frame = 1, 75 do
				local position = start + Vector3.new(0, 0, -16 * frame / 30)
				alice:run(function()
					character:PivotTo(CFrame.new(position))
				end)
				world:step(1 / 30)
			end
			local body = alice:run(function()
				return workspace.AnimatedPets.Bunny.Body.Position
			end)
			expect((body - alice:position()).Magnitude).toBeLessThan(10)

			local bubbles, texts = 0, {}
			for _ = 1, 12 * 30 do
				world:step(1 / 30)
				alice:run(function()
					for _, gui in workspace.AnimatedPets.Bunny:GetChildren() do
						if gui:IsA("BillboardGui") then
							bubbles = 1
							texts[gui.Text.Text] = true
						end
					end
				end)
			end
			expect(bubbles).toBe(1)
			for text in texts do
				expect(table.find(BunnyPet.Defaults.texts, text)).never.toBeNil()
			end
			local squeaks = 0
			for _, sound in world.soundsPlayed do
				if sound.ctx == alice.ctx.id and sound.soundId == BunnyPet.Defaults.sound then
					squeaks += 1
					expect(sound.speed).toBeGreaterThanOrEqual(0.95)
					expect(sound.speed).toBeLessThanOrEqual(1.2)
				end
			end
			expect(squeaks).toBeGreaterThan(0)
			world:assertHealthy()
		end)

		it("waits for a streamed-in character's root, then binkies on demand and cleans up", function()
			local world = t.newWorld()
			local server = world:createServer()
			local alice = server:addPlayer({ userId = 321, name = "Alice" })
			local ClientBunnyPet = alice:require("ReplicatedStorage.Shared.Pets.BunnyPet")
			alice:run(function()
				local folder = Instance.new("Folder")
				folder.Parent = workspace
				local character = Instance.new("Model")
				local bunny = ClientBunnyPet.new(
					character,
					folder,
					{ raycastParams = RaycastParams.new(), seed = 1, every = false }
				)
				bunny:update(1 / 30)
				expect(bunny.model.Parent).toBeNil()

				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Size = Vector3.new(2, 2, 1)
				root.CFrame = CFrame.new(50, 3, 50)
				root.Parent = character
				bunny:update(1 / 30)
				expect(bunny.model.Parent).toBe(folder)
				local body = bunny.model:FindFirstChild("Body") :: BasePart
				expect((body.Position - Vector3.new(50, 3, 50)).Magnitude).toBeLessThan(7)

				bunny:update(1 / 30)
				expect(bunny.model:FindFirstChild("HopBubble")).toBeNil()
				bunny:react()
				bunny:update(1 / 30)
				expect(bunny.model:FindFirstChild("HopBubble")).never.toBeNil()
				bunny:destroy()
				expect(folder:FindFirstChild("Bunny")).toBeNil()
			end)
			world:assertHealthy()
		end)
	end)
end

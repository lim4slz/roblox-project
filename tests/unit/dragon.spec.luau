--[[
	Dragon pet: rig data, flying, landing, fire breath and the client module
	running in the headless runtime.
]]

local roblox = require("@lune/roblox")
local Datatypes = require("../harness/Datatypes")
local Shared = require("../harness/Shared")
local Geo = require("./PetGeometry")

local CFrame, Vector3, Enum = Datatypes.CFrame, roblox.Vector3, roblox.Enum

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local DragonModel = Shared.require("Pets.DragonModel")
	local DragonAnimation = Shared.require("Pets.DragonAnimation")
	local DragonPet = Shared.require("Pets.DragonPet")
	local PetRig = Shared.require("Pets.PetRig")

	local parts = DragonModel.Definition.parts
	local NEVER = { math.huge, math.huge }

	local function stepFor(anim, seconds, speed)
		local breaths = 0
		for _ = 1, math.floor(seconds * 60 + 0.5) do
			breaths += anim:step(1 / 60, speed or 0)
		end
		return breaths
	end

	local function solve(rig, anim)
		return rig:solve(CFrame.identity, anim:pose(), {})
	end

	local function isFoot(name)
		return string.sub(name, 1, 4) == "Foot"
	end

	-- Highest point of the wing tips (to tell a wing beat).
	local function wingTip(cframes)
		local index = Geo.partIndex(parts, "WingRTip")
		return cframes[index].Position.Y
	end

	describe("Dragon model", function()
		it("keeps the 41 original parts plus 7 hidden ones, each on a known bone", function()
			expect(#parts).toBe(48)
			local names = {}
			for _, def in parts do
				expect(names[def.name]).toBeNil()
				names[def.name] = true
			end
			local rig = PetRig.new(DragonModel.Definition)
			local cframes = rig:solve(CFrame.identity, {}, {})
			for index, def in parts do
				expect((cframes[index].Position - def.cframe.Position).Magnitude).toBeLessThan(1e-4)
				expect(cframes[index].LookVector:Dot(def.cframe.LookVector)).toBeGreaterThan(0.9999)
			end
			-- Standing on its four feet, like in the art.
			expect(Geo.lowest(parts, cframes)).toBeCloseTo(0, 0.01)
			expect(Geo.lowest(parts, cframes, isFoot)).toBeCloseTo(0, 0.01)
			-- The flames glow and the outer ones are see-through.
			for _, name in DragonModel.Flames do
				expect(parts[Geo.partIndex(parts, name)].material).toBe(Enum.Material.Neon)
			end
			expect(parts[Geo.partIndex(parts, "Fire4")].transparency).toBeGreaterThan(0)
		end)

		it("hides the eyelids, the mouth and the flames inside the head until they are animated", function()
			local rig = PetRig.new(DragonModel.Definition)
			local rest = rig:solve(CFrame.identity, {}, {})
			expect(Geo.inside(parts, rest, "Mouth", "Jaw", 0.001)).toBe(true)
			for _, name in DragonModel.Flames do
				expect(Geo.inside(parts, rest, name, "Head", 0.001)).toBe(true)
			end
			for _, side in { "L", "R" } do
				expect(Geo.inside(parts, rest, "Lid" .. side, "Head", 0.001)).toBe(true)
			end

			local pose = {
				Jaw = CFrame.Angles(math.rad(-30), 0, 0),
				Lids = CFrame.new(DragonModel.BlinkOffset),
			}
			for index, name in DragonModel.Flames do
				pose[name] = CFrame.new(DragonModel.FlameStart + DragonModel.FlameSpacing * (index - 1))
			end
			local open = rig:solve(CFrame.identity, pose, {})
			for _, side in { "L", "R" } do
				expect(Geo.frontZ(parts, open, "Lid" .. side)).toBeLessThan(Geo.frontZ(parts, open, "Eye" .. side))
			end
			-- The open jaw drops below the mouth, which shows between them.
			local jaw = open[Geo.partIndex(parts, "Jaw")]
			expect(jaw.LookVector.Y).toBeLessThan(-0.4)
			-- Out, the flames make a line in front of the mouth, each further out.
			local snout = Geo.frontZ(parts, open, "Snout")
			local last = snout + 0.2
			for _, name in DragonModel.Flames do
				local position = open[Geo.partIndex(parts, name)].Position
				expect(position.Z).toBeLessThan(last)
				last = position.Z
			end
			expect(last).toBeLessThan(snout - 2.5)
		end)
	end)

	describe("Dragon flight", function()
		it("hovers, flies and hurries depending on speed", function()
			local anim = DragonAnimation.new(1, NEVER)
			stepFor(anim, 1, 0)
			expect(anim:gait()).toBe("Idle")
			stepFor(anim, 1, 12)
			expect(anim:gait()).toBe("Walk")
			stepFor(anim, 1, 26)
			expect(anim:gait()).toBe("Run")
			stepFor(anim, 1, 0)
			expect(anim:gait()).toBe("Idle")
		end)

		it("flies above the ground, flapping its wings and bobbing with each beat", function()
			local rig = PetRig.new(DragonModel.Definition)
			for _, speed in { 0, 12, 26 } do
				local anim = DragonAnimation.new(2, NEVER)
				stepFor(anim, 1, speed)
				local low, high, tipLow, tipHigh, beats = math.huge, -math.huge, math.huge, -math.huge, 0
				local wasUp = false
				for _ = 1, 3 * 60 do
					anim:step(1 / 60, speed)
					local cframes = solve(rig, anim)
					local lowest = Geo.lowest(parts, cframes)
					low, high = math.min(low, lowest), math.max(high, lowest)
					local tip = wingTip(cframes)
					tipLow, tipHigh = math.min(tipLow, tip), math.max(tipHigh, tip)
					local up = tip > cframes[Geo.partIndex(parts, "Back")].Position.Y + 1
					beats += if up and not wasUp then 1 else 0
					wasUp = up
				end
				expect(low).toBeGreaterThan(DragonAnimation.HoverHeight - 0.7)
				expect(high).toBeLessThan(DragonAnimation.HoverHeight + 0.4)
				expect(high - low).toBeGreaterThan(0.1) -- it bobs
				expect(tipHigh - tipLow).toBeGreaterThan(2.5) -- big wing beats
				expect(beats).toBeGreaterThanOrEqual(5) -- about two beats a second or more
				expect(beats).toBeLessThanOrEqual(10)
			end
		end)

		it("leans into the flight and tucks its legs back when it hurries", function()
			local rig = PetRig.new(DragonModel.Definition)
			local anim = DragonAnimation.new(3, NEVER)
			stepFor(anim, 2, 26)
			local pose = anim:pose()
			expect(math.deg(select(1, pose.Body:ToEulerAnglesXYZ()))).toBeLessThan(-12)
			local cframes = rig:solve(CFrame.identity, pose, {})
			local foot = cframes[Geo.partIndex(parts, "FootBR")].Position
			local hip = rig:boneCFrame("LegBR").Position
			expect(foot.Z - hip.Z).toBeGreaterThan(0.6) -- trailing behind the hip
		end)

		it("lands when its owner stands still for a while and takes off when they move", function()
			local rig = PetRig.new(DragonModel.Definition)
			local anim = DragonAnimation.new(4, NEVER)
			stepFor(anim, DragonAnimation.LandAfter - 0.5, 0)
			expect(anim:isLanded()).toBe(false)
			expect(Geo.lowest(parts, solve(rig, anim))).toBeGreaterThan(1.5)
			stepFor(anim, 2, 0)
			expect(anim:isLanded()).toBe(true)
			local cframes = solve(rig, anim)
			expect(Geo.lowest(parts, cframes)).toBeCloseTo(0, 0.01)
			expect(Geo.lowest(parts, cframes, isFoot)).toBeCloseTo(0, 0.01)
			-- The wings fold back over the body.
			local tip = cframes[Geo.partIndex(parts, "WingRTip")].Position
			expect(tip.Z).toBeGreaterThan(1)
			expect(math.abs(tip.X)).toBeLessThan(3)
			-- Its owner moves: it takes off straight away.
			stepFor(anim, 0.5, 8)
			expect(anim:isLanded()).toBe(false)
			expect(anim:height()).toBeGreaterThan(DragonAnimation.HoverHeight * 0.95)
		end)

		it("grows with its scale", function()
			local anim = DragonAnimation.new(5, NEVER)
			local rig = PetRig.new(DragonModel.Definition, 2)
			local low = math.huge
			for _ = 1, 2 * 60 do
				anim:step(1 / 60, 0)
				low = math.min(low, Geo.lowest(parts, solve(rig, anim), nil, 2))
			end
			expect(low).toBeGreaterThan(2 * (DragonAnimation.HoverHeight - 0.7))
		end)
	end)

	describe("Dragon fire breath and fidgets", function()
		it("rears back, then breathes a stream of flames with its jaw wide open", function()
			local rig = PetRig.new(DragonModel.Definition)
			local anim = DragonAnimation.new(6, NEVER)
			stepFor(anim, 1)
			anim:react()
			-- Rearing back to take a breath, no flames yet.
			local reared = 0
			local frames, reported = 0, nil
			while reported == nil do
				frames += 1
				if anim:step(1 / 120, 0) == 1 then
					reported = frames / 120
				else
					local pose = anim:pose()
					reared = math.max(reared, math.deg(select(1, pose.Head:ToEulerAnglesXYZ())))
					for _, name in DragonModel.Flames do
						expect(pose[name].Position.Magnitude).toBe(0)
					end
				end
				expect(frames).toBeLessThan(120)
			end
			expect(reared).toBeGreaterThan(15)
			expect(reported).toBeGreaterThanOrEqual(DragonAnimation.Inhale)
			expect(reported).toBeLessThanOrEqual(DragonAnimation.Inhale + 1 / 60 + 1e-9)
			expect(anim:isReacting()).toBe(true)

			-- The flames: all four out together for most of the breath, in front of the snout.
			local allOut, frames2 = 0, 0
			local now = reported
			while now < DragonAnimation.Inhale + DragonAnimation.Flames do
				anim:step(1 / 120, 0)
				now += 1 / 120
				frames2 += 1
				local pose = anim:pose()
				local cframes = rig:solve(CFrame.identity, pose, {})
				local head = cframes[Geo.partIndex(parts, "Head")]
				local headFront = -parts[Geo.partIndex(parts, "Head")].size.Z / 2
				local out = 0
				for _, name in DragonModel.Flames do
					local flame = cframes[Geo.partIndex(parts, name)].Position
					if pose[name].Position.Magnitude > 0 then
						-- Out of the mouth: in front of the face.
						expect(head:PointToObjectSpace(flame).Z).toBeLessThan(headFront - 0.3)
						out += 1
					else
						-- A flame that is not out stays inside the head.
						expect(Geo.inside(parts, cframes, name, "Head", 0.001)).toBe(true)
					end
				end
				allOut += if out == 4 then 1 else 0
				if out > 0 then
					expect(math.deg(select(1, pose.Jaw:ToEulerAnglesXYZ()))).toBeLessThan(-15)
				end
			end
			expect(allOut / frames2).toBeGreaterThan(0.6)

			stepFor(anim, 0.5)
			expect(anim:isReacting()).toBe(false)
			local pose = anim:pose()
			for _, name in DragonModel.Flames do
				expect(pose[name].Position.Magnitude).toBe(0)
			end
			expect(math.abs(select(1, pose.Jaw:ToEulerAnglesXYZ()))).toBeLessThan(1e-6)
		end)

		it("breathes fire on its own at random intervals, and never when told not to", function()
			local function breathTimes(seed, every)
				local anim = DragonAnimation.new(seed, every)
				local times = {}
				for frame = 1, 120 * 60 do
					for _ = 1, anim:step(1 / 60, if frame % 1200 < 600 then 0 else 12) do
						table.insert(times, frame / 60)
					end
				end
				return times
			end
			local times = breathTimes(42)
			expect(times).toEqual(breathTimes(42))
			expect(times).never.toEqual(breathTimes(43))
			expect(times[1]).toBeGreaterThanOrEqual(3 + DragonAnimation.Inhale)
			expect(times[1]).toBeLessThanOrEqual(6 + DragonAnimation.Inhale + 0.05)
			local every = DragonAnimation.Every
			for index = 2, #times do
				local gap = times[index] - times[index - 1]
				expect(gap).toBeGreaterThanOrEqual(every[1] + DragonAnimation.BreathLength - 0.05)
				expect(gap).toBeLessThanOrEqual(every[2] + DragonAnimation.BreathLength + 0.05)
			end
			expect(#times).toBeGreaterThanOrEqual(7)
			expect(#breathTimes(42, NEVER)).toBe(0)
		end)

		it("does the fire breaths asked for back to back, at most three queued", function()
			local anim = DragonAnimation.new(7, NEVER)
			stepFor(anim, 0.5)
			anim:react(2)
			expect(stepFor(anim, 3 * DragonAnimation.BreathLength)).toBe(2)
			anim:react(10)
			expect(stepFor(anim, 10 * DragonAnimation.BreathLength)).toBe(3)
		end)

		it("blinks and looks around", function()
			local anim = DragonAnimation.new(8, NEVER)
			local blinks, wasBlinking = 0, false
			local yawLow, yawHigh = math.huge, -math.huge
			for _ = 1, 30 * 60 do
				anim:step(1 / 60, 0)
				local pose = anim:pose()
				local blinking = pose.Lids.Position == DragonModel.BlinkOffset
				blinks += if blinking and not wasBlinking then 1 else 0
				wasBlinking = blinking
				local yaw = select(2, pose.Head:ToEulerAnglesYXZ())
				yawLow, yawHigh = math.min(yawLow, yaw), math.max(yawHigh, yaw)
			end
			expect(blinks).toBeGreaterThanOrEqual(5)
			expect(blinks).toBeLessThanOrEqual(16)
			expect(math.deg(yawHigh - yawLow)).toBeGreaterThan(30)
		end)
	end)

	describe("Dragon pet on the client", function()
		it("gives every character a dragon that flies after it and breathes fire with a bubble and a whoosh", function()
			local world = t.newWorld()
			local server = world:createServer()
			server:start()
			local alice = server:addPlayer({ userId = 501, name = "Alice", runClient = true })
			world:advance(1)

			local dragon = alice:run(function()
				local model = workspace.AnimatedPets:FindFirstChild("Dragon")
				local anchored, colliding, neon = 0, 0, 0
				for _, part in model:GetChildren() do
					if part:IsA("BasePart") then
						anchored += if part.Anchored then 1 else 0
						colliding += if part.CanCollide or part.CanQuery or part.CanTouch then 1 else 0
						neon += if part.Material == Enum.Material.Neon then 1 else 0
					end
				end
				return { parts = #model:GetChildren(), anchored = anchored, colliding = colliding, neon = neon }
			end)
			expect(dragon.parts).toBe(48)
			expect(dragon.anchored).toBe(48)
			expect(dragon.colliding).toBe(0)
			expect(dragon.neon).toBe(4)

			local start = alice:position()
			local character = alice:character()
			for frame = 1, 75 do
				local position = start + Vector3.new(0, 0, -16 * frame / 30)
				alice:run(function()
					character:PivotTo(CFrame.new(position))
				end)
				world:step(1 / 30)
			end
			local body, feet = alice:run(function()
				local model = workspace.AnimatedPets.Dragon
				return model.Body.Position, model.FootFR.Position
			end)
			expect((body - alice:position()).Magnitude).toBeLessThan(14)
			-- Flying: well above its owner's feet.
			local ClientPetKit = alice:require("ReplicatedStorage.Shared.Pets.PetKit")
			local ownerFeet = alice:run(function()
				return ClientPetKit.feetHeight(character:FindFirstChild("HumanoidRootPart"), character)
			end)
			expect(feet.Y - ownerFeet).toBeGreaterThan(1.2)

			local bubbles, texts = 0, {}
			for _ = 1, 12 * 30 do
				world:step(1 / 30)
				alice:run(function()
					for _, gui in workspace.AnimatedPets.Dragon:GetChildren() do
						if gui:IsA("BillboardGui") then
							bubbles = 1
							texts[gui.Text.Text] = true
						end
					end
				end)
			end
			expect(bubbles).toBe(1)
			for text in texts do
				expect(table.find(DragonPet.Defaults.texts, text)).never.toBeNil()
			end
			local whooshes = 0
			for _, sound in world.soundsPlayed do
				if sound.ctx == alice.ctx.id and sound.soundId == DragonPet.Defaults.sound then
					whooshes += 1
					expect(sound.speed).toBeGreaterThanOrEqual(0.9)
					expect(sound.speed).toBeLessThanOrEqual(1.1)
				end
			end
			expect(whooshes).toBeGreaterThan(0)
			world:assertHealthy()
		end)

		it("waits for a streamed-in character's root, then breathes fire on demand and cleans up", function()
			local world = t.newWorld()
			local server = world:createServer()
			local alice = server:addPlayer({ userId = 521, name = "Alice" })
			local ClientDragonPet = alice:require("ReplicatedStorage.Shared.Pets.DragonPet")
			alice:run(function()
				local folder = Instance.new("Folder")
				folder.Parent = workspace
				local character = Instance.new("Model")
				local dragon = ClientDragonPet.new(
					character,
					folder,
					{ raycastParams = RaycastParams.new(), seed = 1, every = false }
				)
				dragon:update(1 / 30)
				expect(dragon.model.Parent).toBeNil()

				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Size = Vector3.new(2, 2, 1)
				root.CFrame = CFrame.new(50, 3, 50)
				root.Parent = character
				dragon:update(1 / 30)
				expect(dragon.model.Parent).toBe(folder)
				local body = dragon.model:FindFirstChild("Body") :: BasePart
				expect((body.Position - Vector3.new(50, 3, 50)).Magnitude).toBeLessThan(12)

				dragon:react()
				dragon:update(1 / 30)
				-- The bubble pops when the flames come out, after the breath in.
				expect(dragon.model:FindFirstChild("RoarBubble")).toBeNil()
				for _ = 1, 15 do
					dragon:update(1 / 30)
				end
				expect(dragon.model:FindFirstChild("RoarBubble")).never.toBeNil()
				dragon:destroy()
				expect(folder:FindFirstChild("Dragon")).toBeNil()
			end)
			world:assertHealthy()
		end)
	end)
end
